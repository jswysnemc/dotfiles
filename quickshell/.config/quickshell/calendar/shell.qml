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
        { key: "calendar", label: "日历", icon: "\uf073" },
        { key: "world-clock", label: "世界时钟", icon: "\uf0ac" }
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
        environment: ({ "LC_ALL": "C" })
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
        environment: ({ "LC_ALL": "C" })
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
        environment: ({ "LC_ALL": "C.UTF-8" })
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
        let months = ["一月", "二月", "三月", "四月", "五月", "六月",
                      "七月", "八月", "九月", "十月", "十一月", "十二月"]
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
        let festivals = { "1-1": "元旦", "2-14": "情人节", "3-8": "妇女节", "5-1": "劳动节", "6-1": "儿童节", "10-1": "国庆节", "12-25": "圣诞节" }
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

    function closeWithAnimation() {
        root.blurActive = false
        exitAnimation.start()
    }

    Timer {
        interval: 30000
        running: root.activeRoute === "world-clock"
        repeat: true
        onTriggered: root.loadWorldClock()
    }

    // ============ UI ============
    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-calendar-bg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }
        }
    }

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-calendar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: root.blurActive ? panelRect : null
                radius: Theme.radiusXL
            }
            Connections {
                target: root
                function onBlurActiveChanged() { blurRegion.changed() }
                function onPanelScaleChanged() { blurRegion.changed() }
                function onPanelYChanged() { blurRegion.changed() }
            }
            Connections {
                target: panelRect
                function onXChanged() { blurRegion.changed() }
                function onYChanged() { blurRegion.changed() }
                function onWidthChanged() { blurRegion.changed() }
                function onHeightChanged() { blurRegion.changed() }
            }
            anchors.top: root.anchorTop && !root.anchorVCenter
            anchors.bottom: root.anchorBottom
            anchors.left: root.anchorLeft
            anchors.right: root.anchorRight
            margins.top: root.anchorTop ? root.marginT : 0
            margins.bottom: root.anchorBottom ? root.marginB : 0
            margins.left: root.anchorLeft ? root.marginL : 0
            margins.right: root.anchorRight ? root.marginR : 0
            implicitWidth: 380
            implicitHeight: panelRect.implicitHeight


            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                color: Theme.alpha(Theme.background, 0.88)
                radius: Theme.radiusXL
                border.color: Theme.glassBorder
                border.width: 1.5
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                // 高级光影
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 0.9
                    shadowVerticalOffset: 14
                }

                // 玻璃内描边
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 10
                }

                // Aurora 装饰
                AuroraBackground {
                    anchors.fill: parent
                    intensity: 0.26
                    orbScale: 1.5
                    z: 0
                }

                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: root.panelOpacity

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                    onWheel: (wheel) => {
                        if (root.activeRoute !== "calendar") {
                            return
                        }
                        if (root.yearSelectMode) {
                            if (wheel.angleDelta.y > 0) root.yearSelectBase -= 12
                            else if (wheel.angleDelta.y < 0) root.yearSelectBase += 12
                        } else {
                            if (root.monthListViewRef) {
                                let velocity = -wheel.angleDelta.y * 6
                                if (velocity !== 0) {
                                    root.monthListViewRef.flick(0, velocity)
                                }
                            } else {
                                if (wheel.angleDelta.y > 0) root.prevMonth()
                                else if (wheel.angleDelta.y < 0) root.nextMonth()
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Page route switcher
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radiusM
                        color: Theme.alpha(Theme.surfaceVariant, 0.78)
                        border.color: Theme.alpha(Theme.outline, 0.55)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 3

                            Repeater {
                                model: root.routeItems

                                Rectangle {
                                    id: routeButton
                                    property string routeKey: modelData.key
                                    property bool selected: root.activeRoute === routeKey

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusS
                                    color: selected ? Theme.alpha(Theme.surface, 0.92) : "transparent"
                                    border.color: selected ? Theme.alpha(Theme.primary, 0.28) : "transparent"
                                    border.width: selected ? 1 : 0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: modelData.icon
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 12
                                            color: routeButton.selected ? Theme.primary : Theme.textMuted
                                        }

                                        Text {
                                            text: modelData.label
                                            font.pixelSize: Theme.fontSizeS
                                            font.bold: routeButton.selected
                                            color: routeButton.selected ? Theme.primary : Theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectRoute(routeButton.routeKey)
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM
                        visible: root.activeRoute === "calendar"

                    // === Header: Today's info — Hero ===
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 124
                        radius: Theme.radiusL
                        color: Theme.alpha(Theme.surface, 0.65)
                        border.color: Theme.alpha(Theme.primary, 0.32)
                        border.width: 1.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingL
                            spacing: Theme.spacingL

                            // 巨型日期
                            Text {
                                text: root.todayDay
                                font.pixelSize: 84
                                font.weight: Font.Black
                                font.letterSpacing: -3
                                color: Theme.primary
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // 垂直分隔
                            Rectangle {
                                Layout.preferredWidth: 2
                                Layout.preferredHeight: 64
                                Layout.alignment: Qt.AlignVCenter
                                radius: 1
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.alpha(Theme.primary, 0.0) }
                                    GradientStop { position: 0.5; color: Theme.alpha(Theme.primary, 0.4) }
                                    GradientStop { position: 1.0; color: Theme.alpha(Theme.primary, 0.0) }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Theme.spacingS

                                // 年月 + 星期 chip
                                RowLayout {
                                    spacing: Theme.spacingS

                                    Text {
                                        text: root.todayYear + "年" + root.todayMonth + "月"
                                        font.pixelSize: Theme.fontSizeL
                                        font.weight: Font.Bold
                                        color: Theme.textPrimary
                                    }

                                    Rectangle {
                                        implicitWidth: weekdayLabel.implicitWidth + Theme.spacingM
                                        implicitHeight: 22
                                        radius: 11
                                        color: Theme.alpha(Theme.primary, 0.18)
                                        Text {
                                            id: weekdayLabel
                                            anchors.centerIn: parent
                                            text: root.todayWeekday
                                            font.pixelSize: Theme.fontSizeXS
                                            font.weight: Font.Medium
                                            color: Theme.primary
                                        }
                                    }
                                }

                                // 农历 + 节日
                                RowLayout {
                                    visible: root.todayLunar !== ""
                                    spacing: Theme.spacingS

                                    Text {
                                        text: root.todayLunar
                                        font.pixelSize: Theme.fontSizeS
                                        color: Theme.textMuted
                                    }

                                    Rectangle {
                                        visible: root.todayFestival !== ""
                                        implicitWidth: festLabel.implicitWidth + Theme.spacingM
                                        implicitHeight: 22
                                        radius: 11
                                        color: Theme.alpha(Theme.warning, 0.2)
                                        border.color: Theme.alpha(Theme.warning, 0.4)
                                        border.width: 1
                                        Text {
                                            id: festLabel
                                            anchors.centerIn: parent
                                            text: root.todayFestival
                                            font.pixelSize: Theme.fontSizeXS
                                            font.weight: Font.Medium
                                            color: Theme.warning
                                        }
                                    }
                                }
                            }

                            // Today pill
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: todayBtnLabel.implicitWidth + Theme.spacingM * 2 + 18
                                implicitHeight: 32
                                radius: 16
                                color: todayMouse.containsMouse ? Theme.alpha(Theme.primary, 0.22) : Theme.alpha(Theme.primary, 0.12)
                                border.color: Theme.alpha(Theme.primary, 0.4)
                                border.width: 1
                                visible: root.currentYear !== root.todayYear || root.currentMonth !== root.todayMonth
                                scale: todayMouse.containsMouse ? 1.05 : 1.0
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "\uf073"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 11
                                        color: Theme.primary
                                    }
                                    Text {
                                        id: todayBtnLabel
                                        text: "今天"
                                        font.pixelSize: Theme.fontSizeS
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: todayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.goToToday()
                                }
                            }

                        }
                    }

                    // Month navigation
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        // Previous year
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: prevYearMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
                            scale: prevYearMouse.containsMouse ? 1.1 : 1.0

                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf100"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeS
                                color: Theme.primary
                            }

                            MouseArea {
                                id: prevYearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.yearSelectMode) root.yearSelectBase -= 12
                                    else root.prevYear()
                                }
                            }
                        }

                        // Previous month
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: prevMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
                            visible: !root.yearSelectMode
                            scale: prevMouse.containsMouse ? 1.1 : 1.0

                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf104"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeM
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.prevMonth()
                            }
                        }

                        // Current year/month (clickable)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: Theme.radiusM
                            color: yearMonthMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: root.yearSelectMode ?
                                      (root.yearSelectBase + "年 - " + (root.yearSelectBase + 11) + "年") :
                                      (root.currentYear + "年 " + root.getMonthName())
                                font.pixelSize: Theme.fontSizeL
                                font.bold: true
                                color: root.yearSelectMode ? Theme.primary : Theme.textPrimary

                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            }

                            MouseArea {
                                id: yearMonthMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.yearSelectMode = !root.yearSelectMode
                                    if (root.yearSelectMode) {
                                        root.yearSelectBase = root.currentYear - 6
                                    }
                                }
                            }
                        }

                        // Next month
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: nextMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
                            visible: !root.yearSelectMode
                            scale: nextMouse.containsMouse ? 1.1 : 1.0

                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf105"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeM
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextMonth()
                            }
                        }

                        // Next year
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: nextYearMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
                            scale: nextYearMouse.containsMouse ? 1.1 : 1.0

                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf101"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeS
                                color: Theme.primary
                            }

                            MouseArea {
                                id: nextYearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.yearSelectMode) root.yearSelectBase += 12
                                    else root.nextYear()
                                }
                            }
                        }
                    }

                    // Year selection grid
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: Theme.spacingS
                        columnSpacing: Theme.spacingS
                        visible: root.yearSelectMode
                        opacity: root.yearSelectMode ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                        Repeater {
                            model: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: Theme.radiusM
                                color: {
                                    let year = root.yearSelectBase + index
                                    if (year === root.currentYear) return Theme.surfaceVariant
                                    if (yearItemMouse.containsMouse) return Theme.surface
                                    return "transparent"
                                }
                                border.color: (root.yearSelectBase + index) === root.todayYear ? Theme.primary : "transparent"
                                border.width: (root.yearSelectBase + index) === root.todayYear ? 2 : 0
                                scale: yearItemMouse.containsMouse ? 1.05 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.yearSelectBase + index
                                    font.pixelSize: Theme.fontSizeM
                                    font.bold: (root.yearSelectBase + index) === root.currentYear
                                    color: {
                                        let year = root.yearSelectBase + index
                                        if (year === root.currentYear) return Theme.primary
                                        if (year === root.todayYear) return Theme.primary
                                        return Theme.textPrimary
                                    }
                                }

                                MouseArea {
                                    id: yearItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.goToYear(root.yearSelectBase + index)
                                        root.yearSelectMode = false
                                    }
                                }
                            }
                        }
                    }

                    // Weekday header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: !root.yearSelectMode

                        Repeater {
                            model: ["日", "一", "二", "三", "四", "五", "六"]

                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.pixelSize: Theme.fontSizeS
                                font.bold: true
                                color: index === 0 || index === 6 ? Theme.error : Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.6
                        visible: !root.yearSelectMode
                    }

                    // Days grid (windowed month list)
                    ListView {
                        id: monthListView
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.daysGridHeight
                        clip: true
                        orientation: ListView.Vertical
                        model: root.monthModelCount
                        snapMode: ListView.SnapOneItem
                        boundsBehavior: Flickable.DragOverBounds
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        highlightFollowsCurrentItem: true
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: 0
                        highlightMoveDuration: 0
                        cacheBuffer: root.daysGridHeight * 4
                        interactive: !root.yearSelectMode
                        visible: !root.yearSelectMode
                        opacity: !root.yearSelectMode ? 1 : 0

                        // Smooth scrolling
                        flickDeceleration: 3000
                        maximumFlickVelocity: 2000

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                        Component.onCompleted: {
                            root.monthListViewRef = monthListView
                            root.syncListToCurrent()
                            positionViewAtIndex(currentIndex, ListView.Beginning)
                        }

                        onCurrentIndexChanged: {
                            if (root.ignoreListSync) {
                                return
                            }
                            let info = root.yearMonthForIndex(currentIndex)
                            root.currentYear = info.year
                            root.currentMonth = info.month
                            root.preloadMonthWindow(info.year, info.month)
                            if (currentIndex < 12 || currentIndex > root.monthModelCount - 13) {
                                root.ensureMonthRange(info.year)
                                root.syncListToCurrent()
                            }
                        }

                        delegate: Item {
                            id: monthPage
                            width: ListView.view.width
                            height: root.daysGridHeight

                            property int delegateYear: root.baseYear + Math.floor(index / 12)
                            property int delegateMonth: (index % 12) + 1
                            property string delegateKey: root.monthKey(delegateYear, delegateMonth)
                            property var monthData: root.monthDataCache[delegateKey] || null
                            property var dayItems: {
                                if (monthData && monthData.days) return monthData.days
                                return root.generateFallbackCalendarFor(delegateYear, delegateMonth)
                            }

                            Component.onCompleted: root.enqueueMonthLoad(delegateYear, delegateMonth)

                            GridLayout {
                                anchors.fill: parent
                                columns: 7
                                rowSpacing: Theme.spacingXS
                                columnSpacing: 0

                                Repeater {
                                    model: monthPage.dayItems

                                    Rectangle {
                                        id: dayCell
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.dayCellHeight
                                        color: {
                                            if (modelData.isToday) return Theme.surfaceVariant
                                            if (dayMouse.containsMouse && modelData.currentMonth) return Theme.alpha(Theme.textPrimary, 0.08)
                                            return "transparent"
                                        }
                                        radius: Theme.radiusM
                                        border.color: modelData.isToday ? Theme.primary : "transparent"
                                        border.width: modelData.isToday ? 2 : 0
                                        scale: dayMouse.containsMouse && modelData.currentMonth ? 1.05 : 1.0

                                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.day
                                                font.pixelSize: Theme.fontSizeM
                                                font.bold: modelData.isToday
                                                color: {
                                                    if (!modelData.currentMonth) return Theme.textMuted
                                                    if (modelData.isToday) return Theme.primary
                                                    let dayIndex = index % 7
                                                    if (dayIndex === 0 || dayIndex === 6) return Theme.error
                                                    return Theme.textPrimary
                                                }
                                                opacity: modelData.currentMonth ? 1 : 0.5
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.lunar || ""
                                                font.pixelSize: 9
                                                color: {
                                                    if (modelData.festival) return Theme.warning
                                                    if (!modelData.currentMonth) return Theme.textMuted
                                                    return Theme.textMuted
                                                }
                                                opacity: modelData.currentMonth ? 1 : 0.5
                                                visible: modelData.lunar !== ""
                                            }
                                        }

                                        MouseArea {
                                            id: dayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: modelData.currentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                if (modelData.currentMonth) {
                                                    console.log("Selected:", modelData.year + "-" + modelData.month + "-" + modelData.day)
                                                }
                                            }
                                        }

                                        // Festival indicator dot
                                        Rectangle {
                                            width: 4; height: 4; radius: 2
                                            color: Theme.warning
                                            visible: modelData.festival !== "" && modelData.currentMonth
                                            scale: dayMouse.containsMouse ? 1.5 : 1.0

                                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Footer hint
                    Text {
                        Layout.fillWidth: true
                        text: root.yearSelectMode ?
                              "点击年份选择 | 滚轮切换年份范围" :
                              (root.hasLunar ? "滚轮切换月份 | 点击年月选择年份" : "滚轮切换月份")
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                    }

                    ColumnLayout {
                        id: worldClockPage
                        Layout.fillWidth: true
                        spacing: Theme.spacingM
                        visible: root.activeRoute === "world-clock"

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 118
                            radius: Theme.radiusL
                            color: Theme.alpha(Theme.surface, 0.66)
                            border.color: Theme.alpha(Theme.tertiary, 0.32)
                            border.width: 1.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingL
                                spacing: Theme.spacingM

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    width: 58
                                    height: 58
                                    radius: 29
                                    color: Theme.alpha(Theme.tertiary, 0.16)
                                    border.color: Theme.alpha(Theme.tertiary, 0.38)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf0ac"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 24
                                        color: Theme.tertiary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        text: root.worldClockLocal.time || "--:--"
                                        font.pixelSize: 48
                                        font.weight: Font.Black
                                        font.letterSpacing: -2
                                        color: Theme.textPrimary
                                    }

                                    RowLayout {
                                        spacing: Theme.spacingS

                                        Text {
                                            text: root.worldClockLocal.dateText || "等待同步"
                                            font.pixelSize: Theme.fontSizeS
                                            color: Theme.textSecondary
                                        }

                                        Rectangle {
                                            implicitWidth: localZoneLabel.implicitWidth + Theme.spacingM
                                            implicitHeight: 22
                                            radius: 11
                                            color: Theme.alpha(Theme.primary, 0.14)

                                            Text {
                                                id: localZoneLabel
                                                anchors.centerIn: parent
                                                text: root.worldClockLocal.timezoneLabel || "本地"
                                                font.pixelSize: Theme.fontSizeXS
                                                font.weight: Font.Medium
                                                color: Theme.primary
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    implicitWidth: syncLabel.implicitWidth + Theme.spacingM
                                    implicitHeight: 24
                                    radius: 12
                                    color: Theme.alpha(root.worldClockLoading ? Theme.warning : Theme.success, 0.14)
                                    border.color: Theme.alpha(root.worldClockLoading ? Theme.warning : Theme.success, 0.32)
                                    border.width: 1

                                    Text {
                                        id: syncLabel
                                        anchors.centerIn: parent
                                        text: root.worldClockLoading ? "同步中" : "已同步"
                                        font.pixelSize: Theme.fontSizeXS
                                        font.weight: Font.Medium
                                        color: root.worldClockLoading ? Theme.warning : Theme.success
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Text {
                                text: "全球时间线"
                                font.pixelSize: Theme.fontSizeL
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: refreshClockLabel.implicitWidth + Theme.spacingM * 2 + 14
                                implicitHeight: 30
                                radius: 15
                                color: refreshClockMouse.containsMouse ? Theme.alpha(Theme.primary, 0.18) : Theme.alpha(Theme.primary, 0.1)
                                border.color: Theme.alpha(Theme.primary, 0.28)
                                border.width: 1
                                scale: refreshClockMouse.containsMouse ? 1.04 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "\uf2f1"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 11
                                        color: Theme.primary
                                    }

                                    Text {
                                        id: refreshClockLabel
                                        text: "刷新"
                                        font.pixelSize: Theme.fontSizeS
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: refreshClockMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.loadWorldClock()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 232
                            radius: Theme.radiusL
                            color: Theme.alpha(Theme.surface, 0.48)
                            border.color: Theme.alpha(Theme.outline, 0.5)
                            border.width: 1
                            visible: root.worldClockZoneCount === 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingM

                                Text {
                                    text: "\uf110"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 22
                                    color: Theme.primary
                                    Layout.alignment: Qt.AlignHCenter

                                    RotationAnimator on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: root.worldClockLoading
                                    }
                                }

                                Text {
                                    text: root.worldClockLoading ? "正在同步世界时钟..." : "世界时钟暂无数据"
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textMuted
                                }
                            }
                        }

                        GridLayout {
                            id: worldClockGrid
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: Theme.spacingS
                            columnSpacing: Theme.spacingS
                            visible: root.worldClockZoneCount > 0

                            Repeater {
                                model: root.worldClockZoneCount

                                Rectangle {
                                    id: zoneCard
                                    property var zoneData: root.worldClockZones[index] || ({})
                                    property int zoneDayDelta: zoneData.dayDelta || 0
                                    property real zoneDayProgress: zoneData.dayProgress || 0
                                    property bool isLocalZone: zoneData.isLocal || false

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 88
                                    radius: Theme.radiusL
                                    color: Theme.alpha(Theme.surface, isLocalZone ? 0.78 : 0.58)
                                    border.color: isLocalZone ? Theme.alpha(Theme.primary, 0.5) : Theme.alpha(Theme.outline, 0.52)
                                    border.width: isLocalZone ? 1.5 : 1
                                    clip: true

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingS

                                            Text {
                                                Layout.fillWidth: true
                                                text: zoneCard.zoneData.city || ""
                                                font.pixelSize: Theme.fontSizeS
                                                font.weight: Font.DemiBold
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: zoneCard.zoneData.offset || ""
                                                font.pixelSize: 9
                                                color: Theme.textMuted
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingS

                                            Text {
                                                text: zoneCard.zoneData.time || "--:--"
                                                font.pixelSize: 26
                                                font.weight: Font.Black
                                                font.letterSpacing: -1
                                                color: isLocalZone ? Theme.primary : Theme.textPrimary
                                            }

                                            Rectangle {
                                                visible: zoneCard.zoneDayDelta !== 0
                                                implicitWidth: dayDeltaLabel.implicitWidth + Theme.spacingS
                                                implicitHeight: 18
                                                radius: 9
                                                color: Theme.alpha(zoneCard.zoneDayDelta > 0 ? Theme.success : Theme.warning, 0.16)

                                                Text {
                                                    id: dayDeltaLabel
                                                    anchors.centerIn: parent
                                                    text: zoneCard.zoneDayDelta > 0 ? "明天" : "昨天"
                                                    font.pixelSize: 9
                                                    font.weight: Font.Medium
                                                    color: zoneCard.zoneDayDelta > 0 ? Theme.success : Theme.warning
                                                }
                                            }

                                            Item { Layout.fillWidth: true }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (zoneCard.zoneData.country || "") + " · " + (zoneCard.zoneData.dateText || "")
                                            font.pixelSize: 9
                                            color: Theme.textMuted
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        width: parent.width * zoneCard.zoneDayProgress
                                        height: 3
                                        radius: 2
                                        color: isLocalZone ? Theme.primary : Theme.tertiary
                                        opacity: 0.72

                                        Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "每 30 秒自动同步 | 夏令时来自系统 zoneinfo"
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.textMuted
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Loading overlay
                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.background, 0.9)
                    radius: Theme.radiusL
                    visible: opacity > 0
                    opacity: root.activeRoute === "calendar" && root.isLoading ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM

                        Text {
                            id: loadingIcon
                            text: "\uf110"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 24
                            color: Theme.primary
                            Layout.alignment: Qt.AlignHCenter

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.activeRoute === "calendar" && root.isLoading
                            }
                        }

                        Text {
                            text: "加载中..."
                            font.pixelSize: Theme.fontSizeM
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }
}
