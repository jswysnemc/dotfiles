import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

ShellRoot {
    id: root

    I18nContext {
        id: i18n
        catalog: "calendar"
    }

    readonly property var i18nContext: i18n

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: true

    // ============ Position from environment ============
    property string posEnv: Quickshell.env("QS_POS") || "top-right"
    property int marginT: parseInt(Quickshell.env("QS_MARGIN_T")) || 8
    property int marginR: parseInt(Quickshell.env("QS_MARGIN_R")) || 8
    property int marginB: parseInt(Quickshell.env("QS_MARGIN_B")) || 8
    property int marginL: parseInt(Quickshell.env("QS_MARGIN_L")) || 8
    property bool anchorTop: posEnv.indexOf("top") !== -1 || posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    // ============ State ============
    property int currentYear: new Date().getFullYear()
    property int currentMonth: new Date().getMonth() + 1
    property int todayYear: new Date().getFullYear()
    property int todayMonth: new Date().getMonth() + 1
    property int todayDay: new Date().getDate()

    property int dayCellHeight: 48
    property int dayRowCount: 6
    property int daysGridHeight: dayRowCount * dayCellHeight + (dayRowCount - 1) * Theme.spacingXS

    property int monthModelCount: 2400
    property int yearRange: Math.floor(monthModelCount / 12)
    property int baseYear: Math.max(1, todayYear - Math.floor(yearRange / 2))
    property bool ignoreListSync: true

    property var monthDataCache: ({})
    property var monthLoadingCache: ({})
    property var monthLoadQueue: []
    property bool monthProcessBusy: false

    property string currentMonthKey: monthKey(currentYear, currentMonth)
    property var currentMonthData: monthDataCache[currentMonthKey] || null
    property bool hasLunar: currentMonthData ? (currentMonthData.hasLunar || false) : false
    // Only show loading on initial load, not during scrolling
    property bool isLoading: !currentMonthData && Object.keys(monthDataCache).length === 0

    property string todayLunar: ""
    property string todayFestival: ""
    property string todayWeekday: ""

    property string requestedRoute: Quickshell.env("QS_CALENDAR_ROUTE") || "calendar"
    property string activeRoute: requestedRoute === "world-clock" || requestedRoute === "clock" ? "world-clock" : "calendar"
    readonly property var routeItems: [
        { key: "calendar", label: i18n.trLiteral("日历"), icon: "\uf073" },
        { key: "world-clock", label: i18n.trLiteral("世界时钟"), icon: "\uf0ac" }
    ]

    property bool yearSelectMode: false
    property int yearSelectBase: currentYear - 6

    // Reference to the ListView (set by the delegate)
    property var monthListViewRef: null

    property string scriptPath: Qt.resolvedUrl("lunar_calendar.py").toString().replace("file://", "")
    property string worldClockScriptPath: Qt.resolvedUrl("world_clock.py").toString().replace("file://", "")
    property string uvPath: "/usr/bin/uv"
    property string rootDir: Quickshell.env("HOME") + "/.config/quickshell"

    property var worldClockLocal: ({})
    property var worldClockZones: []
    property int worldClockZoneCount: 0
    property string worldClockUpdatedAt: ""
    property bool worldClockLoading: false

    // ============ Processes ============
    Process {
        id: monthProcess
        property string targetKey: ""
        property int targetYear: 0
        property int targetMonth: 0
        property bool handled: false

        command: []
        environment: ({ "LC_ALL": "C", "QS_LANG": i18n.normalizedLanguage })
        onStarted: handled = false
        stdout: StdioCollector {
            onStreamFinished: {
                if (monthProcess.handled) {
                    return
                }
                try {
                    let data = JSON.parse(text)
                    monthProcess.handled = true
                    root.completeMonthLoad(
                        monthProcess.targetKey,
                        monthProcess.targetYear,
                        monthProcess.targetMonth,
                        data.days || [],
                        data.hasLunar || false
                    )
                } catch (e) {
                    console.log("Failed to parse month data:", e, text)
                    monthProcess.handled = true
                    root.completeMonthLoad(
                        monthProcess.targetKey,
                        monthProcess.targetYear,
                        monthProcess.targetMonth,
                        root.generateFallbackCalendarFor(monthProcess.targetYear, monthProcess.targetMonth),
                        false
                    )
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    console.log("Month data error:", text)
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !monthProcess.handled) {
                monthProcess.handled = true
                root.completeMonthLoad(
                    monthProcess.targetKey,
                    monthProcess.targetYear,
                    monthProcess.targetMonth,
                    root.generateFallbackCalendarFor(monthProcess.targetYear, monthProcess.targetMonth),
                    false
                )
            }
        }
    }

    Process {
        id: todayProcess
        command: [root.uvPath, "run", "--directory", root.rootDir, root.scriptPath, "today"]
        environment: ({ "LC_ALL": "C", "QS_LANG": i18n.normalizedLanguage })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    root.todayLunar = data.lunar || ""
                    root.todayFestival = data.festival || ""
                    root.todayWeekday = data.weekday || ""
                } catch (e) {
                    console.log("Failed to parse today data:", e)
                }
            }
        }
    }

    Process {
        id: worldClockProcess
        command: [root.uvPath, "run", "--directory", root.rootDir, root.worldClockScriptPath]
        environment: ({ "LC_ALL": "C.UTF-8", "QS_LANG": i18n.normalizedLanguage })
        onStarted: root.worldClockLoading = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    let zones = data.zones || []
                    root.worldClockLocal = data.local || ({})
                    root.worldClockZones = zones
                    root.worldClockZoneCount = zones.length
                    root.worldClockUpdatedAt = data.updatedAt || ""
                } catch (e) {
                    console.log("Failed to parse world clock data:", e, text)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    console.log("World clock error:", text)
                }
            }
        }
        onExited: root.worldClockLoading = false
    }

    function monthKey(year, month) {
        let mm = month < 10 ? "0" + month : month.toString()
        return year + "-" + mm
    }

    function addMonths(year, month, delta) {
        let d = new Date(year, month - 1 + delta, 1)
        return { year: d.getFullYear(), month: d.getMonth() + 1 }
    }

    function indexForYearMonth(year, month) {
        return (year - baseYear) * 12 + (month - 1)
    }

    function yearMonthForIndex(index) {
        let year = baseYear + Math.floor(index / 12)
        let month = (index % 12) + 1
        return { year: year, month: month }
    }

    function ensureMonthRange(year) {
        let minYear = baseYear
        let maxYear = baseYear + yearRange - 1
        let buffer = 6
        if (year < minYear + buffer || year > maxYear - buffer) {
            baseYear = Math.max(1, year - Math.floor(yearRange / 2))
        }
    }

    function syncListToCurrent() {
        if (!monthListViewRef) {
            return
        }
        ignoreListSync = true
        monthListViewRef.currentIndex = indexForYearMonth(currentYear, currentMonth)
        ignoreListSync = false
    }

    function enqueueMonthLoad(year, month) {
        let key = monthKey(year, month)
        if (monthDataCache[key] || monthLoadingCache[key]) {
            return
        }
        let loading = Object.assign({}, monthLoadingCache)
        loading[key] = true
        monthLoadingCache = loading
        monthLoadQueue.push({ year: year, month: month, key: key })
        runMonthQueue()
    }

    function runMonthQueue() {
        if (monthProcessBusy || monthLoadQueue.length === 0) {
            return
        }
        let job = monthLoadQueue.shift()
        monthProcessBusy = true
        monthProcess.targetKey = job.key
        monthProcess.targetYear = job.year
        monthProcess.targetMonth = job.month
        monthProcess.command = [uvPath, "run", "--directory", rootDir, scriptPath, "month", job.year.toString(), job.month.toString()]
        monthProcess.running = true
    }

    function completeMonthLoad(key, year, month, days, hasLunarValue) {
        let updated = Object.assign({}, monthDataCache)
        updated[key] = { days: days, hasLunar: hasLunarValue }
        monthDataCache = updated

        let loading = Object.assign({}, monthLoadingCache)
        delete loading[key]
        monthLoadingCache = loading

        monthProcessBusy = false
        runMonthQueue()
    }

    function preloadMonthWindow(year, month) {
        enqueueMonthLoad(year, month)
        let prev = addMonths(year, month, -1)
        let next = addMonths(year, month, 1)
        let prev2 = addMonths(year, month, -2)
        let next2 = addMonths(year, month, 2)
        enqueueMonthLoad(prev.year, prev.month)
        enqueueMonthLoad(next.year, next.month)
        enqueueMonthLoad(prev2.year, prev2.month)
        enqueueMonthLoad(next2.year, next2.month)
    }

    function setCurrentMonth(year, month) {
        ensureMonthRange(year)
        currentYear = year
        currentMonth = month
        syncListToCurrent()
        preloadMonthWindow(year, month)
    }

    function loadTodayInfo() {
        todayProcess.running = true
    }

    function selectRoute(route) {
        if (route !== "calendar" && route !== "world-clock") {
            route = "calendar"
        }
        activeRoute = route
        if (route === "world-clock") {
            yearSelectMode = false
            loadWorldClock()
        }
    }

    function loadWorldClock() {
        if (worldClockProcess.running) {
            return
        }
        worldClockProcess.command = [uvPath, "run", "--directory", rootDir, worldClockScriptPath]
        worldClockProcess.running = true
    }

    function prevMonth() {
        scrollByMonths(-1)
    }

    function nextMonth() {
        scrollByMonths(1)
    }

    function goToToday() {
        let today = new Date()
        setCurrentMonth(today.getFullYear(), today.getMonth() + 1)
    }

    function prevYear() {
        scrollByMonths(-12)
    }

    function nextYear() {
        scrollByMonths(12)
    }

    function goToYear(year) {
        setCurrentMonth(year, currentMonth)
    }

    function scrollByMonths(delta) {
        if (monthListViewRef) {
            let targetIndex = monthListViewRef.currentIndex + delta
            if (targetIndex < 0 || targetIndex >= monthModelCount) {
                let target = addMonths(currentYear, currentMonth, delta)
                setCurrentMonth(target.year, target.month)
                return
            }
            monthListViewRef.currentIndex = targetIndex
            return
        }
        let target = addMonths(currentYear, currentMonth, delta)
        setCurrentMonth(target.year, target.month)
    }

    function getMonthName() {
        let months = [i18n.trLiteral("一月"), i18n.trLiteral("二月"), i18n.trLiteral("三月"), i18n.trLiteral("四月"), i18n.trLiteral("五月"), i18n.trLiteral("六月"),
                      i18n.trLiteral("七月"), i18n.trLiteral("八月"), i18n.trLiteral("九月"), i18n.trLiteral("十月"), i18n.trLiteral("十一月"), i18n.trLiteral("十二月")]
        return months[currentMonth - 1]
    }

    function generateFallbackCalendarFor(year, month) {
        let firstDay = new Date(year, month - 1, 1)
        let lastDay = new Date(year, month, 0)
        let daysInMonth = lastDay.getDate()
        let firstWeekday = firstDay.getDay()
        let prevLastDay = new Date(year, month - 1, 0)
        let prevDays = prevLastDay.getDate()

        let days = []

        for (let i = 0; i < firstWeekday; i++) {
            let d = prevDays - firstWeekday + 1 + i
            let m = month === 1 ? 12 : month - 1
            let y = month === 1 ? year - 1 : year
            days.push({ day: d, currentMonth: false, isToday: false, lunar: "", festival: "", year: y, month: m })
        }

        let today = new Date()
        for (let d = 1; d <= daysInMonth; d++) {
            let isToday = (year === today.getFullYear() && month === today.getMonth() + 1 && d === today.getDate())
            days.push({ day: d, currentMonth: true, isToday: isToday, lunar: "", festival: getFallbackFestival(month, d), year: year, month: month })
        }

        let remaining = 42 - days.length
        let nextMon = month === 12 ? 1 : month + 1
        let nextYr = month === 12 ? year + 1 : year
        for (let d = 1; d <= remaining; d++) {
            days.push({ day: d, currentMonth: false, isToday: false, lunar: "", festival: "", year: nextYr, month: nextMon })
        }

        return days
    }

    function getFallbackFestival(month, day) {
        let festivals = { "1-1": i18n.trLiteral("元旦"), "2-14": i18n.trLiteral("情人节"), "3-8": i18n.trLiteral("妇女节"), "5-1": i18n.trLiteral("劳动节"), "6-1": i18n.trLiteral("儿童节"), "10-1": i18n.trLiteral("国庆节"), "12-25": i18n.trLiteral("圣诞节") }
        return festivals[month + "-" + day] || ""
    }

    Component.onCompleted: {
        setCurrentMonth(currentYear, currentMonth)
        loadTodayInfo()
        if (activeRoute === "world-clock") {
            loadWorldClock()
        }
        enterAnimation.start()
    }

    // ============ 入场动画 ============
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "panelOpacity"
            from: 0; to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "panelScale"
            from: 0.95; to: 1.0
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            target: root
            property: "panelY"
            from: 15; to: 0
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    // ============ 退场动画 ============
    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "panelOpacity"
            to: 0
            duration: 150
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "panelScale"
            to: 0.95
            duration: 150
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "panelY"
            to: -10
            duration: 150
            easing.type: Easing.InCubic
        }

        onFinished: Qt.quit()
    }

    /**
     * 关闭日历弹窗窗口。
     *
     * @param 无
     * @returns 无
     */
    function closeWithAnimation() {
        // 1. 先关闭模糊区域，避免退出前全屏 layer 参与模糊
        root.blurActive = false
        // 2. 立即隐藏卡片并退出，保持与剪贴板一致
        root.panelOpacity = 0
        Qt.quit()
    }

    Timer {
        interval: 30000
        running: root.activeRoute === "world-clock"
        repeat: true
        onTriggered: root.loadWorldClock()
    }

    // ============ UI ============
    CalendarView {
        controller: root
    }
}
