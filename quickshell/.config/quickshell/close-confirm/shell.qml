import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    Process {
        id: closeProcess
        command: ["niri", "msg", "action", "close-window"]
        onExited: Qt.quit()
    }

    function confirmClose() {
        closeProcess.running = true
    }

    // Background overlay
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData

            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.3)
            WlrLayershell.namespace: "qs-close-confirm-bg"
            WlrLayershell.layer: WlrLayer.Overlay
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

    // Main dialog
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-close-confirm"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
            Shortcut { sequence: "Return"; onActivated: root.confirmClose() }
            Shortcut { sequence: "y"; onActivated: root.confirmClose() }
            Shortcut { sequence: "n"; onActivated: Qt.quit() }

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: 280
                height: contentCol.implicitHeight + Theme.spacingXL * 2
                color: Theme.background
                radius: Theme.radiusXL
                border.color: Theme.outline
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.centerIn: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Icon
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 56
                        height: 56
                        radius: 28
                        color: Theme.alpha(Theme.error, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 26
                            color: Theme.error
                        }
                    }

                    // Title
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "关闭窗口"
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Message
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "确定要关闭当前窗口吗？"
                        font.pixelSize: Theme.fontSizeM
                        color: Theme.textSecondary
                    }

                    // Buttons
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 100
                            height: 36
                            radius: Theme.radiusM
                            color: cancelHover.hovered ? Theme.surfaceVariant : Theme.surface
                            border.color: Theme.outline
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "取消 (N)"
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textSecondary
                            }

                            HoverHandler { id: cancelHover }
                            TapHandler { onTapped: Qt.quit() }
                        }

                        Rectangle {
                            width: 100
                            height: 36
                            radius: Theme.radiusM
                            color: confirmHover.hovered ? Theme.alpha(Theme.error, 0.8) : Theme.error

                            Text {
                                anchors.centerIn: parent
                                text: "关闭 (Y)"
                                font.pixelSize: Theme.fontSizeM
                                font.bold: true
                                color: Theme.surface
                            }

                            HoverHandler { id: confirmHover }
                            TapHandler { onTapped: root.confirmClose() }
                        }
                    }

                    // Hint
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Y 确认 | N/Esc 取消"
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
