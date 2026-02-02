// AnimatedToggle.qml - 带动画的开关组件
// 提供流畅的切换动画效果

import QtQuick

Rectangle {
    id: root

    // 公开属性
    property bool checked: false
    property bool enabled: true

    // 颜色配置
    property color trackOffColor: Qt.rgba(0.5, 0.5, 0.5, 0.3)
    property color trackOnColor: "#00696e"
    property color thumbColor: "#ffffff"
    property color thumbShadowColor: Qt.rgba(0, 0, 0, 0.2)

    // 尺寸配置
    property real trackWidth: 44
    property real trackHeight: 24
    property real thumbSize: 18
    property real thumbMargin: 3

    // 动画配置
    property int animDuration: 200

    // 信号
    signal toggled(bool checked)

    // 默认尺寸
    width: trackWidth
    height: trackHeight
    radius: height / 2

    // 轨道颜色
    color: checked ? trackOnColor : trackOffColor
    opacity: enabled ? 1.0 : 0.5

    Behavior on color {
        ColorAnimation { duration: root.animDuration }
    }

    // 滑块
    Rectangle {
        id: thumb
        width: root.thumbSize
        height: root.thumbSize
        radius: height / 2
        color: root.thumbColor

        // 位置动画
        x: root.checked
            ? root.width - width - root.thumbMargin
            : root.thumbMargin
        anchors.verticalCenter: parent.verticalCenter

        Behavior on x {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.0
            }
        }

        // 按下时缩放
        scale: tapHandler.pressed ? 0.9 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        // 阴影效果
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            color: "transparent"
            border.color: root.thumbShadowColor
            border.width: 1
            z: -1
        }
    }

    // 悬停光晕
    Rectangle {
        anchors.centerIn: thumb
        width: thumb.width + 12
        height: width
        radius: width / 2
        color: root.checked
            ? Qt.rgba(root.trackOnColor.r, root.trackOnColor.g, root.trackOnColor.b, 0.15)
            : Qt.rgba(0.5, 0.5, 0.5, 0.1)
        opacity: hoverHandler.hovered ? 1 : 0
        visible: root.enabled

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Behavior on color {
            ColorAnimation { duration: root.animDuration }
        }
    }

    // 交互
    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
    }

    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
