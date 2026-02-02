import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // ============ Animation State ============
    property real bgOpacity: 0
    property real containerOpacity: 0
    property real containerScale: 0.85
    property real containerY: 25

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
        // 启动入场动画
        enterAnimation.start()
    }

    // ============ 入场动画 ============
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "bgOpacity"
            from: 0; to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "containerOpacity"
            from: 0; to: 1
            duration: 300
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "containerScale"
            from: 0.85; to: 1.0
            duration: 350
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }

        NumberAnimation {
            target: root
            property: "containerY"
            from: 25; to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    // ============ 退场动画 ============
    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "bgOpacity"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "containerOpacity"
            to: 0
            duration: 150
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "containerScale"
            to: 0.9
            duration: 180
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "containerY"
            to: -15
            duration: 180
            easing.type: Easing.InCubic
        }

        onFinished: Qt.quit()
    }

    function closeWithAnimation() {
        exitAnimation.start()
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

            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.3 * root.bgOpacity)
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
                        root.closeWithAnimation()
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

            Shortcut { sequence: "Escape"; onActivated: root.confirmMode ? root.cancelConfirm() : root.closeWithAnimation() }
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
                        root.closeWithAnimation()
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

                // 动画属性
                opacity: root.containerOpacity
                scale: root.containerScale
                transform: Translate { y: root.containerY }

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

                        // 确认对话框入场动画
                        opacity: root.confirmMode ? 1 : 0
                        scale: root.confirmMode ? 1 : 0.9
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

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
                                scale: cancelTap.pressed ? 0.95 : (cancelHover.hovered ? 1.03 : 1.0)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "取消"
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textSecondary
                                }

                                HoverHandler { id: cancelHover }
                                TapHandler { id: cancelTap; onTapped: root.cancelConfirm() }
                            }

                            Rectangle {
                                width: 80
                                height: 36
                                radius: Theme.radiusM
                                color: {
                                    var action = root.actions.find(a => a.id === root.confirmAction)
                                    return action ? (confirmHover.hovered ? Theme.alpha(action.color, 0.8) : action.color) : Theme.error
                                }
                                scale: confirmTap.pressed ? 0.95 : (confirmHover.hovered ? 1.03 : 1.0)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "确定"
                                    font.pixelSize: Theme.fontSizeM
                                    font.bold: true
                                    color: Theme.surface
                                }

                                HoverHandler { id: confirmHover }
                                TapHandler { id: confirmTap; onTapped: root.executeAction(root.confirmAction) }
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

                                // 交错入场动画
                                opacity: 0
                                scale: 0.7
                                transform: Translate { id: btnTranslate; y: 20 }

                                Component.onCompleted: btnEnterAnim.start()

                                ParallelAnimation {
                                    id: btnEnterAnim

                                    PauseAnimation { duration: actionBtn.index * 60 }

                                    SequentialAnimation {
                                        PauseAnimation { duration: actionBtn.index * 60 }
                                        NumberAnimation {
                                            target: actionBtn
                                            property: "opacity"
                                            to: 1
                                            duration: 250
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    SequentialAnimation {
                                        PauseAnimation { duration: actionBtn.index * 60 }
                                        NumberAnimation {
                                            target: actionBtn
                                            property: "scale"
                                            to: 1.0
                                            duration: 300
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.5
                                        }
                                    }

                                    SequentialAnimation {
                                        PauseAnimation { duration: actionBtn.index * 60 }
                                        NumberAnimation {
                                            target: btnTranslate
                                            property: "y"
                                            to: 0
                                            duration: 250
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                // 悬停/选中缩放
                                property real hoverScale: btnTap.pressed ? 0.95 : (btnHover.hovered ? 1.08 : 1.0)
                                Behavior on hoverScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS
                                    scale: actionBtn.hoverScale

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 48
                                        height: 48
                                        radius: 24
                                        color: Theme.alpha(actionBtn.modelData.color, 0.1)

                                        // 选中时的脉冲效果
                                        property real pulseScale: 1.0
                                        scale: pulseScale

                                        SequentialAnimation on pulseScale {
                                            running: root.selectedIndex === actionBtn.index
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 1.08; duration: 600; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                        }

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

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }
                                }

                                HoverHandler {
                                    id: btnHover
                                    onHoveredChanged: {
                                        if (hovered) root.selectedIndex = actionBtn.index
                                    }
                                }

                                TapHandler {
                                    id: btnTap
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
