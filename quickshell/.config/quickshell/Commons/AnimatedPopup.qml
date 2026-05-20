// AnimatedPopup.qml - 带动画的弹窗容器组件
// 提供统一的入场/退场动画效果

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "./Theme.js" as Theme

Item {
    id: root

    // 公开属性
    property bool show: false
    property alias content: contentLoader.sourceComponent
    property alias contentItem: contentLoader.item

    // 玻璃容器选项
    property bool glass: false
    property real glassRadius: Theme.radiusXL
    property color glassColor: Theme.alpha(Theme.background, 0.85)
    property color glassBorderColor: Theme.glassBorder
    property color glassHighlightColor: Theme.glassHighlight
    property color glassShadowColor: Theme.shadowColor
    property real glassShadowBlur: 0.9
    property int glassShadowOffsetY: 14

    // 动画配置
    property int enterDuration: 280
    property int exitDuration: 200
    property real enterScale: 0.85
    property real exitScale: 0.95
    property real enterY: 15
    property real exitY: -10

    // 内部状态
    property bool _animating: false
    property bool _visible: false

    visible: _visible
    opacity: 0
    scale: enterScale

    // 玻璃背景层（可选）
    Rectangle {
        id: glassLayer
        anchors.fill: parent
        visible: root.glass
        radius: root.glassRadius
        color: root.glassColor
        border.color: root.glassBorderColor
        border.width: 1.5

        layer.enabled: root.glass
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.glassShadowColor
            shadowBlur: root.glassShadowBlur
            shadowVerticalOffset: root.glassShadowOffsetY
        }

        // 顶部内发光高光
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: root.glassHighlightColor
        }
    }

    // 内容加载器
    Loader {
        id: contentLoader
        anchors.fill: parent
    }

    // 入场动画
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0; to: 1
            duration: root.enterDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            from: root.enterScale; to: 1.0
            duration: root.enterDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }

        NumberAnimation {
            target: root
            property: "y"
            from: root.enterY; to: 0
            duration: root.enterDuration
            easing.type: Easing.OutCubic
        }

        onStarted: root._animating = true
        onFinished: root._animating = false
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
            property: "scale"
            from: 1.0; to: root.exitScale
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "y"
            from: 0; to: root.exitY
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        onStarted: root._animating = true
        onFinished: {
            root._animating = false
            root._visible = false
        }
    }

    onShowChanged: {
        if (show) {
            exitAnimation.stop()
            _visible = true
            enterAnimation.start()
        } else {
            enterAnimation.stop()
            exitAnimation.start()
        }
    }

    // 立即显示（无动画）
    function showImmediate() {
        enterAnimation.stop()
        exitAnimation.stop()
        _visible = true
        opacity = 1
        scale = 1.0
        y = 0
    }

    // 立即隐藏（无动画）
    function hideImmediate() {
        enterAnimation.stop()
        exitAnimation.stop()
        _visible = false
        opacity = 0
        scale = enterScale
    }
}


    // 入场动画
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0; to: 1
            duration: root.enterDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            from: root.enterScale; to: 1.0
            duration: root.enterDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }

        NumberAnimation {
            target: root
            property: "y"
            from: root.enterY; to: 0
            duration: root.enterDuration
            easing.type: Easing.OutCubic
        }

        onStarted: root._animating = true
        onFinished: root._animating = false
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
            property: "scale"
            from: 1.0; to: root.exitScale
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "y"
            from: 0; to: root.exitY
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        onStarted: root._animating = true
        onFinished: {
            root._animating = false
            root._visible = false
        }
    }

    onShowChanged: {
        if (show) {
            exitAnimation.stop()
            _visible = true
            enterAnimation.start()
        } else {
            enterAnimation.stop()
            exitAnimation.start()
        }
    }

    // 立即显示（无动画）
    function showImmediate() {
        enterAnimation.stop()
        exitAnimation.stop()
        _visible = true
        opacity = 1
        scale = 1.0
        y = 0
    }

    // 立即隐藏（无动画）
    function hideImmediate() {
        enterAnimation.stop()
        exitAnimation.stop()
        _visible = false
        opacity = 0
        scale = enterScale
    }
}
