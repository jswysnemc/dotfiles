import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "./Theme.js" as Theme

Rectangle {
    id: rootContainer

    // ============ 属性与状态声明 ============
    property int selectedIndex: 0
    property bool confirmMode: false
    property string confirmAction: ""
    property string initialAction: ""
    
    // 动作数据源：横向平铺各卡片
    readonly property var actions: [
        { id: "lock", name: i18n.trLiteral("锁屏"), icon: "\uf023", color: Theme.primary, cmd: "LOCK_GRACE_TIMEOUT=3 qs-lock" },
        { id: "logout", name: i18n.trLiteral("注销"), icon: "\uf2f5", color: Theme.secondary, cmd: "niri msg action quit" },
        { id: "suspend", name: i18n.trLiteral("睡眠"), icon: "\uf186", color: Theme.warning, cmd: "systemctl suspend" },
        { id: "reboot", name: i18n.trLiteral("重启"), icon: "\uf021", color: Theme.warning, cmd: "systemctl reboot" },
        { id: "shutdown", name: i18n.trLiteral("关机"), icon: "\uf011", color: Theme.error, cmd: "systemctl poweroff" }
    ]

    // ============ 信号声明 ============
    signal execute(string actionId, string command)
    signal cancel()

    // ============ 国际化上下文 ============
    I18nContext {
        id: i18n
        catalog: "power-menu"
    }

    Component.onCompleted: {
        if (initialAction.length > 0) {
            confirmAndExecute(initialAction)
        }
    }

    // ============ 基础圆角矩形毛玻璃样式 ============
    color: Theme.alpha(Theme.background, 0.28)
    radius: Theme.radiusXL
    border.color: Theme.glassBorder
    border.width: 1.5

    // ============ 物理折射高光边框 ============
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.glassHighlight
        z: 10
    }

    // 1. 拦截鼠标事件，维持容器独立交互
    MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) { mouse.accepted = true }
    }

    // ============ 核心交互方法分发 ============
    
    /**
     * 水平向左移动选中卡片焦点
     */
    function moveLeft() {
        if (!confirmMode) {
            selectedIndex = (selectedIndex - 1 + actions.length) % actions.length
        }
    }

    /**
     * 水平向右移动选中卡片焦点
     */
    function moveRight() {
        if (!confirmMode) {
            selectedIndex = (selectedIndex + 1) % actions.length
        }
    }

    /**
     * 激活当前卡片对应的行为。
     * @returns 无返回值。
     */
    function activate() {
        if (confirmMode) {
            executeActionById(confirmAction)
        } else {
            confirmAndExecute(actions[selectedIndex].id)
        }
    }

    /**
     * 转入具体行为的确认流程
     * @param {string} actionId - 动作标识。
     * @returns 无返回值。
     */
    function confirmAndExecute(actionId) {
        var action = actions.find(a => a.id === actionId)
        if (!action) return

        if (actionId === "lock") {
            executeActionById(actionId)
        } else {
            confirmMode = true
            confirmAction = actionId
        }
    }

    /**
     * 根据动作标识执行对应命令。
     * @param {string} actionId - 动作标识。
     * @returns 无返回值。
     */
    function executeActionById(actionId) {
        // 1. 根据标识查找动作定义
        var action = actions.find(a => a.id === actionId)
        if (!action) return

        // 2. 将动作标识和命令交给根组件执行
        execute(action.id, action.cmd)
    }

    /**
     * 取消确认或退出主界面
     */
    function cancelConfirm() {
        if (confirmMode) {
            confirmMode = false
            confirmAction = ""
        } else {
            cancel()
        }
    }

    // ============ 视图图层 ============

    // ------ 图层一：横向 Bento 卡片栏 ------
    Item {
        id: orbitalContainer
        anchors.fill: parent
        visible: opacity > 0
        opacity: confirmMode ? 0.0 : 1.0
        z: 20

        // 2. 切换确认态时，卡片栏淡入淡出及向左滑出过渡
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        transform: Translate {
            x: rootContainer.confirmMode ? -20 : 0
            Behavior on x {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // 3. 水平排列卡片
        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Theme.spacingXS
            spacing: Theme.spacingL

            Repeater {
                model: rootContainer.actions
                delegate: PowerCard {
                    // index 和 modelData 将由 QML 引擎隐式且自动注入到 delegate 实例中
                    selectedIndex: rootContainer.selectedIndex

                    onTapped: (actionId) => {
                        rootContainer.confirmAndExecute(actionId)
                    }

                    onHovered: (idx) => {
                        rootContainer.selectedIndex = idx
                    }
                }
            }
        }

        // 4. 底部小字说明文案
        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: Theme.spacingM
            text: i18n.trLiteral("← →  选择  ·  Enter 确认  ·  Esc 取消")
            font.pixelSize: Theme.fontSizeXS
            color: Theme.textSecondary
            opacity: 0.88
        }
    }

    // ------ 图层二：二次确认浮层 ------
    ConfirmOverlay {
        id: confirmOverlay
        anchors.fill: parent
        confirmMode: rootContainer.confirmMode
        confirmAction: rootContainer.confirmAction
        actions: rootContainer.actions
        confirmTitleText: i18n.trLiteral("确定要")
        cancelBtnText: i18n.trLiteral("取消")
        confirmBtnText: i18n.trLiteral("确定")

        onCancel: {
            rootContainer.cancelConfirm()
        }

        onConfirmed: (actionId) => {
            rootContainer.executeActionById(actionId)
        }
    }
}
