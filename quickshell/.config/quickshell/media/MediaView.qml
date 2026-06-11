import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
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
            WlrLayershell.namespace: "quickshell-media"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: controller.blurActive && controller.initialized && panelRect.width > 0 && panelRect.height > 0 ? panelRect : null
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
            implicitWidth: 400
            implicitHeight: Math.min(720, panelRect.implicitHeight)


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
                implicitHeight: Math.max(controller.hasPlayer ? 520 : 250, mainCol.implicitHeight + Theme.spacingL * 2)
                color: Theme.alpha(Theme.background, 0.28)
                radius: Theme.radiusXL
                border.color: Theme.glassBorder
                border.width: 1.5

                // 多层发光阴影 (Premium Shadow)
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 0.8
                    shadowVerticalOffset: 12
                    shadowHorizontalOffset: 0
                }

                // Wait for initialization before showing
                opacity: controller.initialized ? controller.panelOpacity : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

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

                // Background art blur effect
                Item {
                    anchors.fill: parent
                    clip: true
                    visible: controller.artUrl !== ""
                    opacity: 0.25

                    Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: -60
                        source: controller.artUrl
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: 64
                            blur: 1.0
                            contrast: 0.1
                            saturation: 0.2
                        }
                    }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    // Header with player selector
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

                        // Player switcher (if multiple players)
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
                                onClicked: controller.closeWithAnimation()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // No player state
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

                    // Keyboard hints
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
    }}
