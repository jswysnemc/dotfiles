import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // Position from environment
    property string posEnv: Quickshell.env("QS_POS") || "center"
    property int marginT: parseInt(Quickshell.env("QS_MARGIN_T")) || 0
    property int marginR: parseInt(Quickshell.env("QS_MARGIN_R")) || 0
    property int marginB: parseInt(Quickshell.env("QS_MARGIN_B")) || 0
    property int marginL: parseInt(Quickshell.env("QS_MARGIN_L")) || 0
    property bool anchorTop: posEnv.indexOf("top") !== -1
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    // State
    property int selectedIndex: 0
    property bool confirmMode: false
    property string confirmAction: ""

    // Direct action from environment (for waybar integration)
    property string directAction: Quickshell.env("QS_POWER_ACTION") || ""

    // Power actions
    readonly property var actions: [
        { id: "lock", name: "锁屏", icon: "\uf023", color: Theme.primary, cmd: "loginctl lock-session" },
        { id: "logout", name: "注销", icon: "\uf2f5", color: Theme.secondary, cmd: "niri msg action quit" },
        { id: "suspend", name: "睡眠", icon: "\uf186", color: Theme.warning, cmd: "systemctl suspend" },
        { id: "reboot", name: "重启", icon: "\uf021", color: Theme.warning, cmd: "systemctl reboot" },
        { id: "shutdown", name: "关机", icon: "\uf011", color: Theme.error, cmd: "systemctl poweroff" }
    ]

    // Check for direct action on startup
    Component.onCompleted: {
        if (directAction) {
            var action = actions.find(a => a.id === directAction)
            if (action) {
                if (directAction === "lock") {
                    executeAction(directAction)
                } else {
                    confirmMode = true
                    confirmAction = directAction
                }
            }
        }
    }

    Process {
        id: cmdProcess
        command: ["bash", "-c", "echo"]
        onExited: Qt.quit()
    }

    function executeAction(actionId) {
        var action = actions.find(a => a.id === actionId)
        if (action) {
            cmdProcess.command = ["bash", "-c", action.cmd]
            cmdProcess.running = true
        }
    }

    function confirmAndExecute(actionId) {
        if (actionId === "lock") {
            executeAction(actionId)
        } else {
            confirmMode = true
            confirmAction = actionId
        }
    }

    function cancelConfirm() {
        // If triggered from waybar (direct action), quit on cancel
        if (directAction) {
            Qt.quit()
        } else {
            confirmMode = false
            confirmAction = ""
        }
    }

    // Keyboard navigation
    function moveLeft() {
        if (!confirmMode) {
            selectedIndex = (selectedIndex - 1 + actions.length) % actions.length
        }
    }

    function moveRight() {
        if (!confirmMode) {
            selectedIndex = (selectedIndex + 1) % actions.length
        }
    }

    function activate() {
        if (confirmMode) {
            executeAction(confirmAction)
        } else {
            confirmAndExecute(actions[selectedIndex].id)
        }
    }

    // UI
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.3)
            WlrLayershell.namespace: "qs-power-menu-bg"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.confirmMode) {
                        root.cancelConfirm()
                    } else {
                        Qt.quit()
                    }
                }
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
            WlrLayershell.namespace: "qs-power-menu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.confirmMode ? root.cancelConfirm() : Qt.quit() }
            Shortcut { sequence: "Left"; onActivated: root.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: root.moveRight() }
            Shortcut { sequence: "h"; onActivated: root.moveLeft() }
            Shortcut { sequence: "l"; onActivated: root.moveRight() }
            Shortcut { sequence: "Return"; onActivated: root.activate() }
            Shortcut { sequence: "Space"; onActivated: root.activate() }

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.confirmMode) {
                        root.cancelConfirm()
                    } else {
                        Qt.quit()
                    }
                }
            }

            Rectangle {
                id: mainContainer
                anchors.centerIn: parent
                implicitWidth: contentCol.implicitWidth + Theme.spacingXL * 2
                implicitHeight: contentCol.implicitHeight + Theme.spacingXL * 2
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
                    spacing: Theme.spacingL

                    // Title
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.confirmMode ? "确认操作" : "电源菜单"
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Confirm dialog
                    ColumnLayout {
                        visible: root.confirmMode
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spacingM

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                var action = root.actions.find(a => a.id === root.confirmAction)
                                return action ? "确定要" + action.name + "吗？" : ""
                            }
                            font.pixelSize: Theme.fontSizeM
                            color: Theme.textSecondary
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 80
                                height: 36
                                radius: Theme.radiusM
                                color: cancelHover.hovered ? Theme.surfaceVariant : Theme.surface
                                border.color: Theme.outline
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "取消"
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textSecondary
                                }

                                HoverHandler { id: cancelHover }
                                TapHandler { onTapped: root.cancelConfirm() }
                            }

                            Rectangle {
                                width: 80
                                height: 36
                                radius: Theme.radiusM
                                color: {
                                    var action = root.actions.find(a => a.id === root.confirmAction)
                                    return action ? (confirmHover.hovered ? Theme.alpha(action.color, 0.8) : action.color) : Theme.error
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "确定"
                                    font.pixelSize: Theme.fontSizeM
                                    font.bold: true
                                    color: Theme.surface
                                }

                                HoverHandler { id: confirmHover }
                                TapHandler { onTapped: root.executeAction(root.confirmAction) }
                            }
                        }
                    }

                    // Action buttons
                    RowLayout {
                        visible: !root.confirmMode
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spacingM

                        Repeater {
                            model: root.actions

                            Rectangle {
                                id: actionBtn
                                required property var modelData
                                required property int index

                                width: 80
                                height: 90
                                radius: Theme.radiusL
                                color: {
                                    if (root.selectedIndex === index) {
                                        return Theme.alpha(modelData.color, 0.15)
                                    }
                                    return btnHover.hovered ? Theme.surfaceVariant : Theme.surface
                                }
                                border.color: root.selectedIndex === index ? modelData.color : Theme.outline
                                border.width: root.selectedIndex === index ? 2 : 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 48
                                        height: 48
                                        radius: 24
                                        color: Theme.alpha(actionBtn.modelData.color, 0.1)

                                        Text {
                                            anchors.centerIn: parent
                                            text: actionBtn.modelData.icon
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 22
                                            color: actionBtn.modelData.color
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: actionBtn.modelData.name
                                        font.pixelSize: Theme.fontSizeS
                                        color: root.selectedIndex === actionBtn.index ? actionBtn.modelData.color : Theme.textSecondary
                                    }
                                }

                                HoverHandler {
                                    id: btnHover
                                    onHoveredChanged: {
                                        if (hovered) root.selectedIndex = actionBtn.index
                                    }
                                }

                                TapHandler {
                                    onTapped: root.confirmAndExecute(actionBtn.modelData.id)
                                }
                            }
                        }
                    }

                    // Hint
                    Text {
                        visible: !root.confirmMode
                        Layout.alignment: Qt.AlignHCenter
                        text: "方向键选择 | Enter 确认 | Esc 取消"
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
