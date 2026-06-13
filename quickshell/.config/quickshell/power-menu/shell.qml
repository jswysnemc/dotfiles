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

    // ============ 状态与属性声明 ============
    property bool confirmMode: false
    property string confirmAction: ""

    // ============ 动画数值状态 ============
    property real bgOpacity: 0
    property real containerOpacity: 0
    property real containerScale: 0.9
    property real containerY: 20
    property bool blurActive: false
    
    // Bento 横向卡片面板尺寸定义
    readonly property int menuWidth: 580
    readonly property int menuHeight: 180
    readonly property int shadowPadding: 0

    // ============ 从环境变量继承定位参数 ============
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

    // ============ 外部直达动作 (Waybar 等集成接口) ============
    property string directAction: Quickshell.env("QS_POWER_ACTION") || ""

    // ============ 进程底层指令执行器 ============
    Process {
        id: cmdProcess
        command: ["bash", "-c", "echo"]
        onExited: Qt.quit()
    }

    // ============ 初始化与直达动作检测 ============
    Component.onCompleted: {
        // 1. 触发全局入场缓动动画
        enterAnimation.start()
    }

    // ============ 入场过渡动画 ============
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
            from: 0.9; to: 1.0
            duration: 350
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }

        NumberAnimation {
            target: root
            property: "containerY"
            from: 20; to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    // ============ 退场过渡动画 ============
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
            to: 0.92
            duration: 180
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "containerY"
            to: -10
            duration: 180
            easing.type: Easing.InCubic
        }

        onFinished: Qt.quit()
    }

    // ============ 交互辅助方法 ============

    /**
     * 触发退场动画并优雅关闭 QML 程序
     */
    function closeWithAnimation() {
        root.blurActive = false
        exitAnimation.start()
    }

    /**
     * 撤销确认动作状态
     */
    function cancelConfirm() {
        if (directAction) {
            // 3. 直达动作在取消时，直接终止退出
            Qt.quit()
        } else {
            // 4. 重置全局确认态属性
            root.confirmMode = false
            root.confirmAction = ""
        }
    }

    /**
     * 通过 Process 异步运行具体动作的 Bash 脚本命令
     * @param {string} actionId - 动作标识 (lock, shutdown 等)。
     * @param {string} command - 需要执行的 Shell 命令。
     * @returns 无返回值。
     */
    function executeAction(actionId, command) {
        if (!command || command.length === 0) return

        root.blurActive = false
        // 5. 将对应命令载入 Process 并触发执行
        cmdProcess.command = ["bash", "-c", command]
        cmdProcess.running = true
    }

    // ============ 视图层渲染 ============

    // ------ 面板一：全屏点击拦截器 ------
    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-power-menu-bg"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // 6. 点击面板以外的区域，向主容器发出关闭请求
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

    // ------ 面板二：关机菜单核心控制窗 ------
    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "qs-power-menu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            implicitWidth: root.menuWidth + root.shadowPadding * 2
            implicitHeight: root.menuHeight + root.shadowPadding * 2

            // 7. 键盘物理快捷键注册
            Shortcut { sequence: "Escape"; onActivated: root.cancelConfirm() }
            Shortcut { sequence: "Left"; onActivated: mainContainer.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: mainContainer.moveRight() }
            Shortcut { sequence: "h"; onActivated: mainContainer.moveLeft() }
            Shortcut { sequence: "l"; onActivated: mainContainer.moveRight() }
            Shortcut { sequence: "Return"; onActivated: mainContainer.activate() }
            Shortcut { sequence: "Space"; onActivated: mainContainer.activate() }

            // 8. 点击窗口背景时优雅淡出
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

            // 9. 挂载已重构的模块化磨砂玻璃主容器
            PowerMenuContainer {
                id: mainContainer
                anchors.fill: parent
                anchors.margins: root.shadowPadding

                // 10. 双向绑定全局确认状态
                confirmMode: root.confirmMode
                confirmAction: root.confirmAction
                initialAction: root.directAction
                onConfirmModeChanged: root.confirmMode = confirmMode
                onConfirmActionChanged: root.confirmAction = confirmAction

                // 11. 绑定动画参数与信号映射
                opacity: root.containerOpacity
                scale: root.containerScale
                y: root.containerY

                onExecute: (actionId, command) => {
                    root.executeAction(actionId, command)
                }

                onCancel: {
                    if (root.directAction) {
                        Qt.quit()
                    } else {
                        root.closeWithAnimation()
                    }
                }
            }
        }
    }
}
