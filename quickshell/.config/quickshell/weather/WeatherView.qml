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
    id: weatherView

    // ============ 属性声明 ============
    required property var controller

    // ============ 全屏拦截器挂载 ============
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
            visible: !controller.closing

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // 1. 点击背景淡出关闭组件
            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }
        }
    }

    // ============ 主天气面板窗口挂载 ============
    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            readonly property int shadowPadding: 0
            readonly property int contentWidth: 380 // 微调面板宽为 380px，显得紧凑细腻
            screen: modelData

            color: "transparent"
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "quickshell-weather"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            visible: !controller.closing
            
            // 定位锚定
            anchors.top: controller.anchorTop && !controller.anchorVCenter
            anchors.bottom: controller.anchorBottom
            anchors.left: controller.anchorLeft
            anchors.right: controller.anchorRight
            margins.top: controller.anchorTop ? controller.marginT - shadowPadding : 0
            margins.bottom: controller.anchorBottom ? controller.marginB - shadowPadding : 0
            margins.left: controller.anchorLeft ? controller.marginL - shadowPadding : 0
            margins.right: controller.anchorRight ? controller.marginR - shadowPadding : 0
            
            implicitWidth: contentWidth + shadowPadding * 2
            implicitHeight: (controller.showSettings ? 520 : panelRect.implicitHeight) + shadowPadding * 2

            // 快捷键注册
            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            // ------ 面板主容器 ------
            Rectangle {
                id: panelRect
                anchors.fill: parent
                anchors.margins: panel.shadowPadding
                color: Theme.alpha(Theme.background, 0.28)
                radius: Theme.radiusXL + 4
                border.color: Theme.glassBorder
                border.width: 1.5
                implicitHeight: mainCol.implicitHeight + Theme.spacingXL * 2

                opacity: controller.panelOpacity

                // 2. 玻璃物理折射内边缘
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 30
                }

                // 3. 天气感知色彩渗透层 (Weather-Adaptive Bleed)
                Rectangle {
                    id: bleedGlow
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -60
                    anchors.topMargin: -60
                    width: 250
                    height: 250
                    radius: width / 2
                    z: 2

                    // 根据当前的 Open-Meteo 天气代码选择对应的壁纸提取色彩做高斯渐变晕斑
                    color: {
                        if (!controller.weatherData) return "transparent"
                        var code = controller.weatherData.current.weather_code
                        // 晴天/少云
                        if (code >= 0 && code <= 3) return Theme.alpha(Theme.warning, 0.14)
                        // 雨/雪/阵雨
                        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 86)) return Theme.alpha(Theme.primary, 0.15)
                        // 雾/雷暴/沙尘
                        return Theme.alpha(Theme.tertiary, 0.14)
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.25
                    }

                    Behavior on color { ColorAnimation { duration: Theme.animSlow } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                // ------ 核心垂直布局列 ------
                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL
                    z: 5

                    // A. 正在加载数据提示
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

                    // B. 数据获取失败重试卡片
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

                    // C. 天气主内容排版 (三个重构后的高品质子组件依次堆叠)
                    ColumnLayout {
                        visible: controller.weatherData !== null
                        Layout.fillWidth: true
                        spacing: Theme.spacingL

                        // 4. 英雄温控与位置刷新芯片区
                        WeatherHeroCard {
                            controller: weatherView.controller
                        }

                        // 5. 6 项气象指标 Bento 网格卡片
                        WeatherBentoGrid {
                            controller: weatherView.controller
                        }

                        // 6. 7 天预报垂直温差区间滑轨列表
                        WeatherForecastList {
                            controller: weatherView.controller
                        }
                    }
                }

                // ------ 位置定位设置 Overlay 遮罩 ------
                WeatherSettings {
                    controller: weatherView.controller
                }
            }
        }
    }
}
