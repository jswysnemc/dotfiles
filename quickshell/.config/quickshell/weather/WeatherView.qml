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
    required property var controller

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-weather-bg"
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
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "quickshell-weather"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: controller.blurActive && panelRect.width > 0 && panelRect.height > 0 ? panelRect : null
                radius: Theme.radiusXL + 4
            }
            Connections {
                target: controller
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
            implicitWidth: 420
            implicitHeight: controller.showSettings ? 520 : panelRect.implicitHeight

            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                color: Theme.alpha(Theme.background, 0.28)
                radius: Theme.radiusXL + 4
                border.color: Theme.glassBorder
                border.width: 1.5
                implicitHeight: mainCol.implicitHeight + Theme.spacingXL * 2
                clip: true

                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: controller.panelOpacity

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 1.0
                    shadowVerticalOffset: 16
                }

                // 玻璃内描边
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 30
                }

                // Aurora 背景
                AuroraBackground {
                    anchors.fill: parent
                    intensity: 0.32
                    orbScale: 1.4
                    z: 0
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL
                    z: 5

                    // Loading
                    ColumnLayout {
                        visible: controller.loading && controller.weatherData === null
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        Layout.alignment: Qt.AlignCenter
                        spacing: Theme.spacingM
                        Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.primary; Layout.alignment: Qt.AlignHCenter
                            RotationAnimation on rotation { running: true; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                        }
                        Text { text: controller.i18nContext.trLiteral("正在获取天气..."); font.pixelSize: Theme.fontSizeM; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                    }

                    // Error
                    ColumnLayout {
                        visible: !controller.loading && controller.errorMsg !== "" && controller.weatherData === null
                        Layout.fillWidth: true
                        spacing: Theme.spacingM
                        Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.error; Layout.alignment: Qt.AlignHCenter }
                        Text { text: controller.errorMsg; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter; width: 96; height: 36; radius: Theme.radiusPill
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.primary }
                                GradientStop { position: 1.0; color: Theme.secondary }
                            }
                            Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("重试"); font.pixelSize: Theme.fontSizeM; font.bold: true; color: "#ffffff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: controller.fetchWeather() }
                        }
                    }

                    // ===== 主内容 =====
                    ColumnLayout {
                        visible: controller.weatherData !== null
                        Layout.fillWidth: true
                        spacing: Theme.spacingL

                        // === HERO ===
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 160

                            // 半透明大图标做背景
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: -6
                                text: controller.weatherData ? controller.getWeatherIcon(controller.weatherData.current.weather_code) : ""
                                font.family: "Weather Icons"
                                font.pixelSize: 150
                                color: Theme.alpha(Theme.primary, 0.55)
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: -10

                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: controller.weatherData ? Math.round(controller.useCelsius ? controller.weatherData.current.temperature_2m : controller.weatherData.current.temperature_2m * 9 / 5 + 32) : ""
                                        font.pixelSize: 104
                                        font.weight: Font.Black
                                        font.letterSpacing: -5
                                        color: Theme.textPrimary
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.topMargin: 18
                                        text: "°" + (controller.useCelsius ? "C" : "F")
                                        font.pixelSize: 32
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                Text {
                                    text: controller.weatherData ? controller.getWeatherDesc(controller.weatherData.current.weather_code) : ""
                                    font.pixelSize: Theme.fontSizeL
                                    font.weight: Font.Medium
                                    color: Theme.textSecondary
                                }
                            }
                        }

                        // === 位置 + 刷新 ===
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: Theme.radiusPill
                                color: Theme.alpha(Theme.surface, 0.38)
                                border.color: locChipMa.containsMouse ? Theme.primary : Theme.glassBorder
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingS
                                    Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                    Text {
                                        Layout.fillWidth: true
                                        text: controller.locationName
                                        font.pixelSize: Theme.fontSizeS
                                        font.weight: Font.Medium
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }
                                    Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 11; color: Theme.textMuted }
                                }
                                MouseArea {
                                    id: locChipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.showSettings = true
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 34; Layout.preferredHeight: 34
                                radius: 17
                                color: refreshMa.containsMouse ? Theme.alpha(Theme.primary, 0.2) : Theme.alpha(Theme.surface, 0.38)
                                border.color: Theme.glassBorder
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 13
                                    color: controller.refreshing ? Theme.primary : Theme.textSecondary
                                    RotationAnimation on rotation {
                                        running: controller.refreshing
                                        from: 0; to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }
                                }
                                MouseArea {
                                    id: refreshMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        controller.cachedTime = 0
                                        controller.fetchWeather()
                                    }
                                }
                            }
                        }

                        // === Bento 指标 ===
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: Theme.spacingS
                            columnSpacing: Theme.spacingS

                            StatTile {
                                icon: ""
                                label: controller.i18nContext.trLiteral("体感")
                                value: controller.weatherData ? controller.formatTemp(controller.weatherData.current.apparent_temperature) : "-"
                                tone: Theme.warning
                            }
                            StatTile {
                                icon: ""
                                label: controller.i18nContext.trLiteral("湿度")
                                value: controller.weatherData ? controller.weatherData.current.relative_humidity_2m + "%" : "-"
                                tone: Theme.tertiary
                            }
                            StatTile {
                                icon: ""
                                label: controller.i18nContext.trLiteral("风速")
                                value: controller.weatherData ? Math.round(controller.weatherData.current.wind_speed_10m) + " km/h" : "-"
                                tone: Theme.secondary
                            }
                            StatTile {
                                icon: ""
                                label: controller.i18nContext.trLiteral("日出")
                                value: controller.weatherData && controller.weatherData.daily ? controller.weatherData.daily.sunrise[0].split("T")[1] : "-"
                                tone: Theme.primary
                            }
                            StatTile {
                                icon: ""
                                label: controller.i18nContext.trLiteral("日落")
                                value: controller.weatherData && controller.weatherData.daily ? controller.weatherData.daily.sunset[0].split("T")[1] : "-"
                                tone: Theme.alpha(Theme.primary, 0.7)
                            }
                            StatTile {
                                icon: ""
                                label: controller.i18nContext.trLiteral("高/低")
                                value: controller.weatherData && controller.weatherData.daily ? Math.round(controller.weatherData.daily.temperature_2m_max[0]) + "°/" + Math.round(controller.weatherData.daily.temperature_2m_min[0]) + "°" : "-"
                                tone: Theme.error
                            }
                        }

                        // === 7 天预报 ===
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: controller.i18nContext.trLiteral("7 天预报")
                                    font.pixelSize: Theme.fontSizeM
                                    font.weight: Font.DemiBold
                                    color: Theme.textPrimary
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 36; height: 4
                                    radius: 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Theme.primary }
                                        GradientStop { position: 1.0; color: Theme.tertiary }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: controller.weatherData && controller.weatherData.daily ? Math.min(7, controller.weatherData.daily.time.length) : 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 102
                                        radius: Theme.radiusM
                                        color: index === 0 ? Theme.alpha(Theme.primary, 0.18) : Theme.alpha(Theme.surface, 0.38)
                                        border.color: index === 0 ? Theme.primary : Theme.alpha(Theme.outline, 0.3)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingXS
                                            Text { text: controller.getDayName(controller.weatherData.daily.time[index], index); font.pixelSize: Theme.fontSizeXS; font.weight: Font.Medium; color: index === 0 ? Theme.primary : Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: controller.getWeatherIcon(controller.weatherData.daily.weather_code[index]); font.family: "Weather Icons"; font.pixelSize: 22; color: index === 0 ? Theme.primary : Theme.textSecondary; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: Math.round(controller.weatherData.daily.temperature_2m_max[index]) + "°"; font.pixelSize: Theme.fontSizeM; font.weight: Font.Bold; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: Math.round(controller.weatherData.daily.temperature_2m_min[index]) + "°"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Settings overlay
                Rectangle {
                    visible: controller.showSettings
                    anchors.fill: parent
                    color: Theme.alpha(Theme.background, 0.42)
                    radius: parent.radius
                    z: 40

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXL
                        spacing: Theme.spacingL

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: controller.i18nContext.trLiteral("位置设置")
                                font.pixelSize: Theme.fontSizeL
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: closeSetMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                Text { anchors.centerIn: parent; text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: Theme.textSecondary }
                                MouseArea { id: closeSetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { controller.showSettings = false; controller.searchResults = [] } }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM
                            Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 16; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: controller.i18nContext.trLiteral("当前位置"); font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                Text { text: controller.locationName; font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: Theme.radiusM
                            color: autoLocMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                            border.color: Theme.outline
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM
                                Text {
                                    text: controller.locating ? "" : ""
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: Theme.primary
                                    RotationAnimation on rotation { running: controller.locating; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                                }
                                Text { text: controller.locating ? controller.i18nContext.trLiteral("定位中...") : controller.i18nContext.trLiteral("自动定位"); font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
                            }
                            MouseArea { id: autoLocMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!controller.locating) controller.geolocate() }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        Text { text: controller.i18nContext.trLiteral("搜索城市"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: Theme.radiusM
                            color: Theme.surface
                            border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
                            border.width: searchInput.activeFocus ? 2 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS
                                Text {
                                    text: controller.searching ? "" : ""
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: Theme.textMuted
                                    RotationAnimation on rotation { running: controller.searching; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                                }
                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textPrimary
                                    clip: true
                                    onTextChanged: { controller.searchQuery = text; searchTimer.restart() }
                                    Text {
                                        anchors.fill: parent
                                        text: controller.i18nContext.trLiteral("输入城市名称...")
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textMuted
                                        visible: !searchInput.text
                                    }
                                }
                            }
                        }

                        Timer {
                            id: searchTimer
                            interval: 500
                            onTriggered: controller.searchLocation(controller.searchQuery)
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: resultsCol.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: resultsCol
                                width: parent.width
                                spacing: Theme.spacingS

                                Repeater {
                                    model: controller.searchResults

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 50
                                        radius: Theme.radiusM
                                        color: resultMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.outline
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM
                                            Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: Theme.textMuted }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: modelData.name; font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
                                                Text { text: (modelData.admin1 || "") + (modelData.country ? ", " + modelData.country : ""); font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted; visible: text !== "" }
                                            }
                                        }
                                        MouseArea { id: resultMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.selectLocation(modelData) }
                                    }
                                }

                                Text {
                                    visible: controller.searchResults.length === 0 && controller.searchQuery.length >= 2 && !controller.searching
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Theme.spacingL
                                    text: controller.i18nContext.trLiteral("未找到结果")
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }
                }
            }

            // Bento 指标单元
            component StatTile: Rectangle {
                property string icon: ""
                property string label: ""
                property string value: ""
                property color tone: Theme.primary

                Layout.fillWidth: true
                implicitHeight: 56
                radius: Theme.radiusM
                color: Theme.alpha(Theme.surface, 0.65)
                border.color: Theme.alpha(tone, 0.3)
                border.width: 1

                Rectangle {
                    width: 3
                    height: parent.height * 0.6
                    radius: 1.5
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.tone
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingS
                    spacing: 0

                    RowLayout {
                        spacing: 4
                        Text {
                            text: parent.parent.parent.icon
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 10
                            color: parent.parent.parent.tone
                        }
                        Text {
                            text: parent.parent.parent.label
                            font.pixelSize: 9
                            color: Theme.textMuted
                            font.letterSpacing: 0.5
                        }
                    }
                    Text {
                        text: parent.parent.value
                        font.pixelSize: Theme.fontSizeM
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }}
