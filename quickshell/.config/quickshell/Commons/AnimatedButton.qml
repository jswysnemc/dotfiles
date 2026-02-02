// AnimatedButton.qml - 带动画反馈的按钮组件
// 提供统一的悬停、按下、点击动画效果

import QtQuick

Rectangle {
    id: root

    // 公开属性
    property alias text: label.text
    property alias icon: iconText.text
    property alias iconSize: iconText.font.pixelSize
    property alias fontSize: label.font.pixelSize
    property alias textColor: label.color
    property alias iconColor: iconText.color

    // 颜色配置
    property color normalColor: "transparent"
    property color hoverColor: Qt.rgba(0, 0, 0, 0.05)
    property color pressColor: Qt.rgba(0, 0, 0, 0.1)
    property color activeColor: normalColor

    // 动画配置
    property int animDuration: 120
    property real hoverScale: 1.0
    property real pressScale: 0.96
    property bool enableRipple: true

    // 状态
    property bool hovered: hoverHandler.hovered
    property bool pressed: tapHandler.pressed
    property bool active: false

    // 信号
    signal clicked()
    signal pressAndHold()

    // 默认样式
    color: {
        if (pressed) return pressColor
        if (active) return activeColor
        if (hovered) return hoverColor
        return normalColor
    }

    scale: pressed ? pressScale : (hovered ? hoverScale : 1.0)

    // 动画行为
    Behavior on color {
        ColorAnimation { duration: root.animDuration }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.color {
        ColorAnimation { duration: root.animDuration }
    }

    // 涟漪效果
    Rectangle {
        id: ripple
        anchors.centerIn: parent
        width: 0
        height: width
        radius: width / 2
        color: Qt.rgba(0, 0, 0, 0.1)
        opacity: 0
        visible: root.enableRipple

        ParallelAnimation {
            id: rippleAnimation

            NumberAnimation {
                target: ripple
                property: "width"
                from: 0
                to: Math.max(root.width, root.height) * 2.5
                duration: 400
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: ripple
                property: "opacity"
                from: 0.3
                to: 0
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }

    // 内容布局
    Row {
        anchors.centerIn: parent
        spacing: (iconText.text && label.text) ? 6 : 0

        Text {
            id: iconText
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
            visible: text !== ""
        }

        Text {
            id: label
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            visible: text !== ""
        }
    }

    // 交互处理
    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        id: tapHandler
        onTapped: {
            if (root.enableRipple) {
                rippleAnimation.stop()
                ripple.width = 0
                ripple.opacity = 0.3
                rippleAnimation.start()
            }
            root.clicked()
        }
        onLongPressed: root.pressAndHold()
    }
}
