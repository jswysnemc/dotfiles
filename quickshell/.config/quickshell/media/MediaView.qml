import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

Item {
    id: mediaView

    required property var controller

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-media-bg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            visible: !controller.closing

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
            readonly property int shadowPadding: 0
            readonly property int contentWidth: 400
            screen: modelData

            color: "transparent"
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "quickshell-media"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            visible: !controller.closing
            anchors.top: controller.anchorTop && !controller.anchorVCenter
            anchors.bottom: controller.anchorBottom
            anchors.left: controller.anchorLeft
            anchors.right: controller.anchorRight
            margins.top: controller.anchorTop ? controller.marginT - shadowPadding : 0
            margins.bottom: controller.anchorBottom ? controller.marginB - shadowPadding : 0
            margins.left: controller.anchorLeft ? controller.marginL - shadowPadding : 0
            margins.right: controller.anchorRight ? controller.marginR - shadowPadding : 0
            implicitWidth: contentWidth + shadowPadding * 2
            implicitHeight: Math.min(720, panelRect.implicitHeight) + shadowPadding * 2

            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }
            Shortcut { sequence: "Space"; onActivated: controller.playPause() }
            Shortcut { sequence: "Left"; onActivated: controller.previous() }
            Shortcut { sequence: "Right"; onActivated: controller.next() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                anchors.margins: panel.shadowPadding
                implicitHeight: Math.max(controller.hasPlayer ? 520 : 250, mainCol.implicitHeight + Theme.spacingL * 2)
                color: Theme.alpha(Theme.background, 0.28)
                radius: Theme.radiusXL
                border.color: Theme.glassBorder
                border.width: 1.5

                // 1. 初始化完成后再显示面板，避免媒体数据未就绪时闪烁
                opacity: controller.initialized ? controller.panelOpacity : 0

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusXL
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 10
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    // 顶部标题和播放器切换
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf001"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: Theme.iconSizeM
                            color: Theme.primary
                        }

                        Text {
                            text: controller.i18nContext.trLiteral("媒体播放")
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        // 多播放器切换
                        Rectangle {
                            visible: controller.playersList.length > 1
                            width: playerSwitchRow.implicitWidth + Theme.spacingM * 2
                            height: 28
                            radius: Theme.radiusPill
                            color: Theme.surfaceVariant
                            border.color: Theme.outline
                            border.width: 1

                            RowLayout {
                                id: playerSwitchRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: 20; height: 20; radius: 10
                                    color: prevPlayerMa.containsMouse ? Theme.surface : "transparent"
                                    scale: prevPlayerMa.containsMouse ? 1.1 : 1.0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf104"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 10
                                        color: Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: prevPlayerMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controller.prevPlayer()
                                    }
                                }

                                Text {
                                    text: (controller.currentPlayerIndex + 1) + "/" + controller.playersList.length
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.textMuted
                                }

                                Rectangle {
                                    width: 20; height: 20; radius: 10
                                    color: nextPlayerMa.containsMouse ? Theme.surface : "transparent"
                                    scale: nextPlayerMa.containsMouse ? 1.1 : 1.0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf105"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 10
                                        color: Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: nextPlayerMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controller.nextPlayer()
                                    }
                                }
                            }
                        }

                        // 关闭按钮
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

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // 无播放器状态
                    Rectangle {
                        visible: !controller.hasPlayer
                        Layout.fillWidth: true
                        height: 180
                        color: "transparent"
                        opacity: !controller.hasPlayer ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingL

                            Text {
                                text: "\uf001"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 48
                                color: Theme.textMuted
                                opacity: 0.5
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: controller.i18nContext.trLiteral("没有正在播放的媒体")
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textMuted
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: controller.i18nContext.trLiteral("播放音乐或视频后在此控制")
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                                opacity: 0.7
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    MediaPlayerContent {
                        controller: mediaView.controller
                    }

                    // 键盘提示
                    Text {
                        Layout.fillWidth: true
                        text: controller.i18nContext.trLiteral("Space 播放/暂停 | Left/Right 上/下一曲")
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        visible: controller.hasPlayer
                    }
                }
            }
        }
    }
}
