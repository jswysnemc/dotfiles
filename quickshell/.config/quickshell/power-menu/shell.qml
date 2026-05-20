import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

ShellRoot {
    id: root

    // ============ Animation State ============
    property real bgOpacity: 0
    property real containerOpacity: 0
    property real containerScale: 0.85
    property real containerY: 25
    property bool blurActive: true
    readonly property int menuSize: 520

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
        root.blurActive = false
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
            root.blurActive = false
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
            root.blurActive = false
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
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.45 * root.bgOpacity)
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
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-power-menu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: root.blurActive ? mainContainer : null
                shape: RegionShape.Ellipse
            }
            Connections {
                target: root
                function onBlurActiveChanged() { blurRegion.changed() }
                function onContainerScaleChanged() { blurRegion.changed() }
                function onContainerYChanged() { blurRegion.changed() }
            }
            Connections {
                target: mainContainer
                function onXChanged() { blurRegion.changed() }
                function onYChanged() { blurRegion.changed() }
                function onWidthChanged() { blurRegion.changed() }
                function onHeightChanged() { blurRegion.changed() }
            }
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
                width: root.menuSize
                height: root.menuSize
                color: Theme.alpha(Theme.background, 0.88)
                radius: width / 2
                border.color: Theme.glassBorder
                border.width: 1.5

                // 高级光影效果 (Power Menu Special Shadow)
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.alpha("#000000", 0.28)
                    shadowBlur: 1.0
                    shadowVerticalOffset: 18
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

                // Aurora 装饰球需要单独圆形遮罩，否则会在圆外露出外接矩形。
                Item {
                    anchors.fill: parent
                    z: 0
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                        maskSource: ShaderEffectSource {
                            sourceItem: Rectangle {
                                width: mainContainer.width
                                height: mainContainer.height
                                radius: width / 2
                            }
                        }
                    }

                    AuroraBackground {
                        anchors.fill: parent
                        intensity: 0.35
                        orbScale: 1.0
                    }
                }

                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: root.containerOpacity

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                // 当前选中的动作
                readonly property var currentAction: root.actions[root.selectedIndex]

                // ===== 确认对话框 (覆盖在轨道上方) =====
                Item {
                    anchors.fill: parent
                    visible: root.confirmMode
                    opacity: root.confirmMode ? 1 : 0
                    z: 30
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.parent.radius
                        color: Theme.alpha(Theme.background, 0.65)
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXL

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 100; height: 100; radius: 50
                            color: {
                                var action = root.actions.find(a => a.id === root.confirmAction)
                                return action ? Theme.alpha(action.color, 0.18) : Theme.alpha(Theme.error, 0.18)
                            }
                            border.width: 2
                            border.color: {
                                var action = root.actions.find(a => a.id === root.confirmAction)
                                return action ? action.color : Theme.error
                            }
                            Text {
                                anchors.centerIn: parent
                                text: {
                                    var action = root.actions.find(a => a.id === root.confirmAction)
                                    return action ? action.icon : ""
                                }
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 44
                                color: {
                                    var action = root.actions.find(a => a.id === root.confirmAction)
                                    return action ? action.color : Theme.error
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "确定要"
                            font.pixelSize: Theme.fontSizeM
                            color: Theme.textMuted
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                var action = root.actions.find(a => a.id === root.confirmAction)
                                return action ? action.name : ""
                            }
                            font.pixelSize: 36
                            font.weight: Font.Black
                            color: {
                                var action = root.actions.find(a => a.id === root.confirmAction)
                                return action ? action.color : Theme.error
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Theme.spacingL
                            spacing: Theme.spacingL

                            Rectangle {
                                width: 100; height: 44
                                radius: Theme.radiusPill
                                color: cancelHover.hovered ? Theme.surfaceVariant : Theme.surface
                                border.color: Theme.outline
                                border.width: 1
                                scale: cancelTap.pressed ? 0.95 : (cancelHover.hovered ? 1.04 : 1.0)
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
                                width: 100; height: 44
                                radius: Theme.radiusPill
                                color: {
                                    var action = root.actions.find(a => a.id === root.confirmAction)
                                    return action ? (confirmHover.hovered ? Theme.alpha(action.color, 0.8) : action.color) : Theme.error
                                }
                                scale: confirmTap.pressed ? 0.95 : (confirmHover.hovered ? 1.04 : 1.0)
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: {
                                        var action = root.actions.find(a => a.id === root.confirmAction)
                                        return action ? Theme.alpha(action.color, 0.5) : Theme.alpha(Theme.error, 0.5)
                                    }
                                    shadowBlur: 0.8
                                    shadowVerticalOffset: 6
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "确定"
                                    font.pixelSize: Theme.fontSizeM
                                    font.bold: true
                                    color: "#ffffff"
                                }
                                HoverHandler { id: confirmHover }
                                TapHandler { id: confirmTap; onTapped: root.executeAction(root.confirmAction) }
                            }
                        }
                    }
                }

                // ===== 轨道布局 =====
                Item {
                    id: orbital
                    anchors.fill: parent
                    visible: !root.confirmMode
                    z: 20

                    readonly property real centerX: width / 2
                    readonly property real centerY: height / 2
                    readonly property real orbitRadius: 180
                    readonly property int btnCount: root.actions.length

                    // 中央 Hub
                    Rectangle {
                        anchors.centerIn: parent
                        width: 200; height: 200
                        radius: 100
                        color: Theme.alpha(Theme.surface, 0.8)
                        border.width: 1.5
                        border.color: mainContainer.currentAction ? Theme.alpha(mainContainer.currentAction.color, 0.45) : Theme.glassBorder

                        Behavior on border.color { ColorAnimation { duration: 220 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: mainContainer.currentAction ? Theme.alpha(mainContainer.currentAction.color, 0.55) : Theme.shadowColor
                            shadowBlur: 1.0
                            shadowVerticalOffset: 0
                            shadowOpacity: 0.7
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 76; height: 76; radius: 38
                                color: mainContainer.currentAction ? Theme.alpha(mainContainer.currentAction.color, 0.15) : Theme.surface
                                Behavior on color { ColorAnimation { duration: 220 } }

                                // 呼吸脉冲
                                property real pulse: 1.0
                                scale: pulse
                                SequentialAnimation on pulse {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.08; duration: 1100; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0;  duration: 1100; easing.type: Easing.InOutSine }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: mainContainer.currentAction ? mainContainer.currentAction.icon : ""
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 36
                                    color: mainContainer.currentAction ? mainContainer.currentAction.color : Theme.primary

                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: mainContainer.currentAction ? mainContainer.currentAction.name : ""
                                font.pixelSize: 22
                                font.weight: Font.Black
                                color: Theme.textPrimary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Enter 确认"
                                font.pixelSize: Theme.fontSizeXS
                                color: Theme.textMuted
                                opacity: 0.7
                            }
                        }
                    }

                    // 轨道线圈
                    Rectangle {
                        anchors.centerIn: parent
                        width: orbital.orbitRadius * 2 + 56
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.alpha(Theme.outline, 0.45)
                    }

                    // 5 个动作按钮 (圆周分布)
                    Repeater {
                        model: root.actions

                        Rectangle {
                            id: actionBtn
                            required property var modelData
                            required property int index

                            readonly property real angle: -Math.PI / 2 + index * (2 * Math.PI / orbital.btnCount)
                            readonly property bool isSelected: root.selectedIndex === index

                            width: 68; height: 68
                            radius: 34
                            x: orbital.centerX + Math.cos(angle) * orbital.orbitRadius - width / 2
                            y: orbital.centerY + Math.sin(angle) * orbital.orbitRadius - height / 2

                            color: isSelected ? Theme.alpha(modelData.color, 0.2) : Theme.alpha(Theme.surface, 0.85)
                            border.color: isSelected ? modelData.color : Theme.alpha(Theme.outline, 0.5)
                            border.width: isSelected ? 2 : 1
                            scale: isSelected ? 1.12 : (btnHover.hovered ? 1.06 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            // 交错入场
                            opacity: 0
                            transform: Scale { id: btnInitScale; origin.x: actionBtn.width / 2; origin.y: actionBtn.height / 2; xScale: 0.4; yScale: 0.4 }
                            Component.onCompleted: btnEnter.start()

                            SequentialAnimation {
                                id: btnEnter
                                PauseAnimation { duration: 80 + actionBtn.index * 60 }
                                ParallelAnimation {
                                    NumberAnimation { target: actionBtn; property: "opacity"; to: 1.0; duration: 300 }
                                    NumberAnimation { target: btnInitScale; property: "xScale"; to: 1.0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                    NumberAnimation { target: btnInitScale; property: "yScale"; to: 1.0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                }
                            }

                            // 选中时的光圈
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 16
                                height: parent.height + 16
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: actionBtn.modelData.color
                                opacity: actionBtn.isSelected ? 0.6 : 0
                                visible: opacity > 0
                                scale: actionBtn.isSelected ? 1.0 : 0.7

                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: actionBtn.modelData.icon
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 26
                                color: actionBtn.modelData.color
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

                    // 提示
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: Theme.spacingL
                        text: "← →  选择  ·  Enter 确认  ·  Esc 取消"
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
