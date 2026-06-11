import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

Item {
    id: quickSettingsView

    required property var controller

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-volume-bg"
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
            WlrLayershell.namespace: "quickshell-volume"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: controller.blurActive ? panelRect : null
                radius: Theme.radiusXL
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
                color: Theme.alpha(Theme.background, 0.42)
                radius: Theme.radiusXL
                border.color: Theme.glassBorder
                border.width: 1.5
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                // 高级光影效果 (Quick Settings Premium Shadow)
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 0.8
                    shadowVerticalOffset: 12
                }

                // 玻璃高光
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
                    intensity: 0.25
                    orbScale: 1.4
                    z: 0
                }

                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: controller.panelOpacity

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf013"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: Theme.iconSizeM
                            color: Theme.primary
                        }

                        Text {
                            text: controller.i18nContext.trLiteral("快捷设置")
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

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
                                onClicked: controller.closeWithAnimation()
                            }
                        }
                    }

                    // Tab bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: Theme.radiusM
                        color: Theme.surfaceVariant

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 2
                            spacing: 2

                            Repeater {
                                model: controller.tabLabels

                                Rectangle {
                                    id: tabButton
                                    required property int index
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusS
                                    color: controller.currentTab === index ? Theme.surface : "transparent"

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeS
                                        font.bold: controller.currentTab === index
                                        color: controller.currentTab === index ? Theme.primary : Theme.textMuted
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controller.selectTab(tabButton.index)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // ============ Tab Content ============
                    StackLayout {
                        id: tabStack
                        Layout.fillWidth: true
                        Layout.preferredHeight: {
                            let item = tabStack.itemAt(controller.currentTab)
                            return item ? item.implicitHeight : 0
                        }
                        clip: true
                        currentIndex: controller.currentTab

                        QuickSettingsVolumePage {
                            controller: quickSettingsView.controller
                        }

                        QuickSettingsApplicationsPage {
                            controller: quickSettingsView.controller
                        }

                        QuickSettingsDevicesPage {
                            controller: quickSettingsView.controller
                        }

                        QuickSettingsDisplayPage {
                            controller: quickSettingsView.controller
                        }

                    }

                    // Keyboard hints
                    Text {
                        Layout.fillWidth: true
                        text: controller.i18nContext.trLiteral("Esc 关闭 | 滚轮调节音量")
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
