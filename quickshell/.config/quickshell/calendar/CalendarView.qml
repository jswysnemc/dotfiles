import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

Item {
    id: calendarView

    required property var controller

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
                onClicked: controller.closeWithAnimation()
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
                item: controller.blurActive ? panelRect : null
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
            anchors.top: controller.anchorTop && !controller.anchorVCenter
            anchors.bottom: controller.anchorBottom
            anchors.left: controller.anchorLeft
            anchors.right: controller.anchorRight
            margins.top: controller.anchorTop ? controller.marginT : 0
            margins.bottom: controller.anchorBottom ? controller.marginB : 0
            margins.left: controller.anchorLeft ? controller.marginL : 0
            margins.right: controller.anchorRight ? controller.marginR : 0
            implicitWidth: 380
            implicitHeight: panelRect.implicitHeight


            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                color: Theme.alpha(Theme.background, 0.28)
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
                opacity: controller.panelOpacity

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                    onWheel: (wheel) => {
                        if (controller.activeRoute !== "calendar") {
                            return
                        }
                        if (controller.yearSelectMode) {
                            if (wheel.angleDelta.y > 0) controller.yearSelectBase -= 12
                            else if (wheel.angleDelta.y < 0) controller.yearSelectBase += 12
                        } else {
                            if (controller.monthListViewRef) {
                                let velocity = -wheel.angleDelta.y * 6
                                if (velocity !== 0) {
                                    controller.monthListViewRef.flick(0, velocity)
                                }
                            } else {
                                if (wheel.angleDelta.y > 0) controller.prevMonth()
                                else if (wheel.angleDelta.y < 0) controller.nextMonth()
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
                                model: controller.routeItems

                                Rectangle {
                                    id: routeButton
                                    property string routeKey: modelData.key
                                    property bool selected: controller.activeRoute === routeKey

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusS
                                    color: selected ? Theme.alpha(Theme.surface, 0.42) : "transparent"
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
                                        onClicked: controller.selectRoute(routeButton.routeKey)
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM
                        visible: controller.activeRoute === "calendar"

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
                                text: controller.todayDay
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
                                        text: controller.i18nContext.tr("todayDate", {
                                            year: controller.todayYear,
                                            month: controller.getMonthName()
                                        })
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
                                            text: controller.todayWeekday
                                            font.pixelSize: Theme.fontSizeXS
                                            font.weight: Font.Medium
                                            color: Theme.primary
                                        }
                                    }
                                }

                                // 农历 + 节日
                                RowLayout {
                                    visible: controller.todayLunar !== ""
                                    spacing: Theme.spacingS

                                    Text {
                                        text: controller.todayLunar
                                        font.pixelSize: Theme.fontSizeS
                                        color: Theme.textMuted
                                    }

                                    Rectangle {
                                        visible: controller.todayFestival !== ""
                                        implicitWidth: festLabel.implicitWidth + Theme.spacingM
                                        implicitHeight: 22
                                        radius: 11
                                        color: Theme.alpha(Theme.warning, 0.2)
                                        border.color: Theme.alpha(Theme.warning, 0.4)
                                        border.width: 1
                                        Text {
                                            id: festLabel
                                            anchors.centerIn: parent
                                            text: controller.todayFestival
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
                                visible: controller.currentYear !== controller.todayYear || controller.currentMonth !== controller.todayMonth
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
                                        text: controller.i18nContext.trLiteral("今天")
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
                                    onClicked: controller.goToToday()
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
                                    if (controller.yearSelectMode) controller.yearSelectBase -= 12
                                    else controller.prevYear()
                                }
                            }
                        }

                        // Previous month
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: prevMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
                            visible: !controller.yearSelectMode
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
                                onClicked: controller.prevMonth()
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
                                text: controller.yearSelectMode
                                    ? controller.i18nContext.tr("yearRange", {
                                        start: controller.yearSelectBase,
                                        end: controller.yearSelectBase + 11
                                    })
                                    : controller.i18nContext.tr("yearMonth", {
                                        year: controller.currentYear,
                                        month: controller.getMonthName()
                                    })
                                font.pixelSize: Theme.fontSizeL
                                font.bold: true
                                color: controller.yearSelectMode ? Theme.primary : Theme.textPrimary

                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            }

                            MouseArea {
                                id: yearMonthMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    controller.yearSelectMode = !controller.yearSelectMode
                                    if (controller.yearSelectMode) {
                                        controller.yearSelectBase = controller.currentYear - 6
                                    }
                                }
                            }
                        }

                        // Next month
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: nextMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
                            visible: !controller.yearSelectMode
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
                                onClicked: controller.nextMonth()
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
                                    if (controller.yearSelectMode) controller.yearSelectBase += 12
                                    else controller.nextYear()
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
                        visible: controller.yearSelectMode
                        opacity: controller.yearSelectMode ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                        Repeater {
                            model: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: Theme.radiusM
                                color: {
                                    let year = controller.yearSelectBase + index
                                    if (year === controller.currentYear) return Theme.surfaceVariant
                                    if (yearItemMouse.containsMouse) return Theme.surface
                                    return "transparent"
                                }
                                border.color: (controller.yearSelectBase + index) === controller.todayYear ? Theme.primary : "transparent"
                                border.width: (controller.yearSelectBase + index) === controller.todayYear ? 2 : 0
                                scale: yearItemMouse.containsMouse ? 1.05 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: controller.yearSelectBase + index
                                    font.pixelSize: Theme.fontSizeM
                                    font.bold: (controller.yearSelectBase + index) === controller.currentYear
                                    color: {
                                        let year = controller.yearSelectBase + index
                                        if (year === controller.currentYear) return Theme.primary
                                        if (year === controller.todayYear) return Theme.primary
                                        return Theme.textPrimary
                                    }
                                }

                                MouseArea {
                                    id: yearItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        controller.goToYear(controller.yearSelectBase + index)
                                        controller.yearSelectMode = false
                                    }
                                }
                            }
                        }
                    }

                    // Weekday header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: !controller.yearSelectMode

                        Repeater {
                            model: [controller.i18nContext.trLiteral("日"), controller.i18nContext.trLiteral("一"), controller.i18nContext.trLiteral("二"), controller.i18nContext.trLiteral("三"), controller.i18nContext.trLiteral("四"), controller.i18nContext.trLiteral("五"), controller.i18nContext.trLiteral("六")]

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
                        visible: !controller.yearSelectMode
                    }

                    // Days grid (windowed month list)
                    ListView {
                        id: monthListView
                        Layout.fillWidth: true
                        Layout.preferredHeight: controller.daysGridHeight
                        clip: true
                        orientation: ListView.Vertical
                        model: controller.monthModelCount
                        snapMode: ListView.SnapOneItem
                        boundsBehavior: Flickable.DragOverBounds
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        highlightFollowsCurrentItem: true
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: 0
                        highlightMoveDuration: 0
                        cacheBuffer: controller.daysGridHeight * 4
                        interactive: !controller.yearSelectMode
                        visible: !controller.yearSelectMode
                        opacity: !controller.yearSelectMode ? 1 : 0

                        // Smooth scrolling
                        flickDeceleration: 3000
                        maximumFlickVelocity: 2000

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                        Component.onCompleted: {
                            controller.monthListViewRef = monthListView
                            controller.syncListToCurrent()
                            positionViewAtIndex(currentIndex, ListView.Beginning)
                        }

                        onCurrentIndexChanged: {
                            if (controller.ignoreListSync) {
                                return
                            }
                            let info = controller.yearMonthForIndex(currentIndex)
                            controller.currentYear = info.year
                            controller.currentMonth = info.month
                            controller.preloadMonthWindow(info.year, info.month)
                            if (currentIndex < 12 || currentIndex > controller.monthModelCount - 13) {
                                controller.ensureMonthRange(info.year)
                                controller.syncListToCurrent()
                            }
                        }

                        delegate: Item {
                            id: monthPage
                            width: ListView.view.width
                            height: controller.daysGridHeight

                            property int delegateYear: controller.baseYear + Math.floor(index / 12)
                            property int delegateMonth: (index % 12) + 1
                            property string delegateKey: controller.monthKey(delegateYear, delegateMonth)
                            property var monthData: controller.monthDataCache[delegateKey] || null
                            property var dayItems: {
                                if (monthData && monthData.days) return monthData.days
                                return controller.generateFallbackCalendarFor(delegateYear, delegateMonth)
                            }

                            Component.onCompleted: controller.enqueueMonthLoad(delegateYear, delegateMonth)

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
                                        Layout.preferredHeight: controller.dayCellHeight
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
                        text: controller.yearSelectMode ?
                              controller.i18nContext.trLiteral("点击年份选择 | 滚轮切换年份范围") :
                              (controller.hasLunar ? controller.i18nContext.trLiteral("滚轮切换月份 | 点击年月选择年份") : controller.i18nContext.trLiteral("滚轮切换月份"))
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                    }

                    CalendarWorldClockPage {
                        controller: calendarView.controller
                    }
                }

                CalendarLoadingOverlay {
                    controller: calendarView.controller
                }

            }
        }
    }}
