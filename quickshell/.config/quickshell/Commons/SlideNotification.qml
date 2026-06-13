// SlideNotification.qml - 滑入通知组件
// 用于通知弹窗的入场/退场动画

import QtQuick

Item {
    id: root

    // 公开属性
    property bool show: false
    property alias content: contentLoader.sourceComponent
    property alias contentItem: contentLoader.item

    // 动画配置
    property string direction: "right"  // "left", "right", "top", "bottom"
    property int enterDuration: 300
    property int exitDuration: 200
    property real slideDistance: 80

    // 内部状态
    property bool _visible: false
    visible: _visible
    opacity: 0

    // 位置偏移
    property real _offsetX: 0
    property real _offsetY: 0

    transform: Translate {
        x: root._offsetX
        y: root._offsetY
    }

    // 内容加载器
    Loader {
        id: contentLoader
        anchors.fill: parent
    }

    /**
     * 计算通知入场时的位移。
     *
     * @param 无
     * @returns 包含 x 与 y 的位移对象
     */
    function getEnterOffset() {
        switch (direction) {
            case "left": return { x: -slideDistance, y: 0 }
            case "right": return { x: slideDistance, y: 0 }
            case "top": return { x: 0, y: -slideDistance }
            case "bottom": return { x: 0, y: slideDistance }
            default: return { x: slideDistance, y: 0 }
        }
    }

    /**
     * 计算通知退场时的位移。
     *
     * @param 无
     * @returns 包含 x 与 y 的位移对象
     */
    function getExitOffset() {
        switch (direction) {
            case "left": return { x: -slideDistance * 0.5, y: 0 }
            case "right": return { x: slideDistance * 0.5, y: 0 }
            case "top": return { x: 0, y: -slideDistance * 0.5 }
            case "bottom": return { x: 0, y: slideDistance * 0.5 }
            default: return { x: slideDistance * 0.5, y: 0 }
        }
    }

    // 入场动画
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0; to: 1
            duration: root.enterDuration * 0.7
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "_offsetX"
            from: getEnterOffset().x; to: 0
            duration: root.enterDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            target: root
            property: "_offsetY"
            from: getEnterOffset().y; to: 0
            duration: root.enterDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        onStarted: root._visible = true
    }

    // 退场动画
    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: 1; to: 0
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "_offsetX"
            from: 0; to: getExitOffset().x
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "_offsetY"
            from: 0; to: getExitOffset().y
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        onFinished: root._visible = false
    }

    onShowChanged: {
        if (show) {
            exitAnimation.stop()
            enterAnimation.start()
        } else {
            hideImmediate()
        }
    }

    /**
     * 立即显示通知。
     *
     * @param 无
     * @returns 无
     */
    function showImmediate() {
        enterAnimation.stop()
        exitAnimation.stop()
        _visible = true
        opacity = 1
        _offsetX = 0
        _offsetY = 0
    }

    /**
     * 立即隐藏通知。
     *
     * @param 无
     * @returns 无
     */
    function hideImmediate() {
        enterAnimation.stop()
        exitAnimation.stop()
        _visible = false
        opacity = 0
        _offsetX = 0
        _offsetY = 0
    }

    /**
     * 立即关闭通知并触发回调。
     *
     * @param callback 关闭后执行的回调函数
     * @returns 无
     */
    function dismiss(callback) {
        hideImmediate()
        if (callback) callback()
    }
}
