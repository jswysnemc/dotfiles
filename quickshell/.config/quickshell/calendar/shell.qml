import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

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

    property bool yearSelectMode: false
    property int yearSelectBase: currentYear - 6

    // Reference to the ListView (set by the delegate)
    property var monthListViewRef: null

    property string scriptPath: Qt.resolvedUrl("lunar_calendar.py").toString().replace("file://", "")
    property string uvPath: "/usr/bin/uv"
    property string rootDir: Quickshell.env("HOME") + "/.config/quickshell"

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
    }

    // ============ UI ============
    Variants {
        model: Quickshell.screens

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
                onClicked: Qt.quit()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-calendar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
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


            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                color: Theme.background
                radius: Theme.radiusL
                border.color: Theme.outline
                border.width: 1
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                    onWheel: (wheel) => {
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

                    // Header: Today's info
                    Rectangle {
                        Layout.fillWidth: true
                        height: 60
                        radius: Theme.radiusM
                        color: Theme.surface
                        border.color: Theme.outline
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            Text {
                                text: root.todayDay
                                font.pixelSize: 36
                                font.bold: true
                                color: Theme.primary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: root.todayYear + "年" + root.todayMonth + "月 " + root.todayWeekday
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textPrimary
                                }

                                Text {
                                    text: root.todayLunar + (root.todayFestival ? " · " + root.todayFestival : "")
                                    font.pixelSize: Theme.fontSizeS
                                    color: root.todayFestival ? Theme.warning : Theme.textMuted
                                    visible: root.todayLunar !== ""
                                }
                            }

                            // Go to today button
                            Rectangle {
                                width: 32; height: 32; radius: Theme.radiusM
                                color: todayMouse.containsMouse ? Theme.surfaceVariant : "transparent"
                                visible: root.currentYear !== root.todayYear || root.currentMonth !== root.todayMonth
                                scale: todayMouse.containsMouse ? 1.1 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf073"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeM
                                    color: Theme.primary
                                }

                                MouseArea {
                                    id: todayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.goToToday()
                                }
                            }

                            // Close button
                            Rectangle {
                                width: 32; height: 32; radius: Theme.radiusM
                                color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                scale: closeMa.containsMouse ? 1.1 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeM
                                    color: Theme.textSecondary
                                }

                                MouseArea {
                                    id: closeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.quit()
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

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

                // Loading overlay
                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.background, 0.9)
                    radius: Theme.radiusL
                    visible: opacity > 0
                    opacity: root.isLoading ? 1 : 0

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
                                running: root.isLoading
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
