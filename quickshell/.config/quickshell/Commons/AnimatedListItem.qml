// AnimatedListItem.qml - 带交错动画的列表项组件
// 用于列表/网格中的项目入场动画

import QtQuick

Item {
    id: root

    // 公开属性
    property int index: 0
    property int staggerDelay: 30
    property bool animateOnLoad: true
    property alias content: contentLoader.sourceComponent
    property alias contentItem: contentLoader.item

    // 动画配置
    property int enterDuration: 250
    property real enterScale: 0.8
    property real enterOpacity: 0
    property real enterY: 12

    // 悬停效果
    property bool hoverEnabled: true
    property real hoverScale: 1.03
    property real hoverElevation: -2
    property bool hovered: hoverHandler.hovered

    // 内部状态
    opacity: animateOnLoad ? 0 : 1
    scale: animateOnLoad ? enterScale : 1.0
    transform: Translate { id: translateTransform; y: animateOnLoad ? enterY : 0 }

    // 悬停变换
    property real _hoverY: 0
    Behavior on _hoverY {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    // 内容加载器
    Loader {
        id: contentLoader
        anchors.fill: parent
        anchors.topMargin: root._hoverY
    }

    // 悬停处理
    HoverHandler {
        id: hoverHandler
        enabled: root.hoverEnabled
        onHoveredChanged: {
            if (hovered) {
                root.scale = root.hoverScale
                root._hoverY = root.hoverElevation
            } else {
                root.scale = 1.0
                root._hoverY = 0
            }
        }
    }

    // 入场动画
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: root.enterOpacity; to: 1
            duration: root.enterDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            from: root.enterScale; to: 1.0
            duration: root.enterDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            target: translateTransform
            property: "y"
            from: root.enterY; to: 0
            duration: root.enterDuration
            easing.type: Easing.OutCubic
        }
    }

    // 延迟启动器
    Timer {
        id: delayTimer
        interval: root.index * root.staggerDelay
        repeat: false
        onTriggered: enterAnimation.start()
    }

    Component.onCompleted: {
        if (animateOnLoad) {
            delayTimer.start()
        }
    }

    // 手动触发动画
    function animate() {
        opacity = enterOpacity
        scale = enterScale
        translateTransform.y = enterY
        delayTimer.start()
    }

    // 立即显示
    function showImmediate() {
        delayTimer.stop()
        enterAnimation.stop()
        opacity = 1
        scale = 1.0
        translateTransform.y = 0
    }
}
