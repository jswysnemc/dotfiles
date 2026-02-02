// LoadingSpinner.qml - 加载动画组件
// 提供多种加载动画样式

import QtQuick

Item {
    id: root

    // 公开属性
    property bool running: true
    property color color: "#00696e"
    property int size: 24
    property string style: "spinner"  // "spinner", "dots", "pulse", "ring"

    width: size
    height: size

    // 旋转图标样式
    Text {
        id: spinnerIcon
        visible: root.style === "spinner"
        anchors.centerIn: parent
        text: "\uf110"
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: root.size
        color: root.color

        RotationAnimator on rotation {
            running: root.running && root.style === "spinner"
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }

    // 三点跳动样式
    Row {
        visible: root.style === "dots"
        anchors.centerIn: parent
        spacing: root.size * 0.15

        Repeater {
            model: 3

            Rectangle {
                id: dot
                required property int index
                width: root.size * 0.22
                height: width
                radius: width / 2
                color: root.color
                opacity: 0.3

                SequentialAnimation on opacity {
                    running: root.running && root.style === "dots"
                    loops: Animation.Infinite
                    PauseAnimation { duration: dot.index * 150 }
                    NumberAnimation { to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { to: 0.3; duration: 300; easing.type: Easing.InCubic }
                    PauseAnimation { duration: (2 - dot.index) * 150 }
                }

                SequentialAnimation on y {
                    running: root.running && root.style === "dots"
                    loops: Animation.Infinite
                    PauseAnimation { duration: dot.index * 150 }
                    NumberAnimation { to: -root.size * 0.15; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { to: 0; duration: 300; easing.type: Easing.InCubic }
                    PauseAnimation { duration: (2 - dot.index) * 150 }
                }
            }
        }
    }

    // 脉冲样式
    Rectangle {
        visible: root.style === "pulse"
        anchors.centerIn: parent
        width: root.size * 0.6
        height: width
        radius: width / 2
        color: root.color

        SequentialAnimation on scale {
            running: root.running && root.style === "pulse"
            loops: Animation.Infinite
            NumberAnimation { to: 1.2; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
        }

        SequentialAnimation on opacity {
            running: root.running && root.style === "pulse"
            loops: Animation.Infinite
            NumberAnimation { to: 0.5; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
        }
    }

    // 环形样式
    Item {
        visible: root.style === "ring"
        anchors.centerIn: parent
        width: root.size
        height: root.size

        Rectangle {
            id: ring
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: root.size * 0.1
            border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.2)
        }

        // 旋转弧线
        Canvas {
            id: arcCanvas
            anchors.fill: parent
            rotation: arcRotation

            property real arcRotation: 0
            property real arcLength: 0.25

            RotationAnimator on arcRotation {
                running: root.running && root.style === "ring"
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
            }

            SequentialAnimation on arcLength {
                running: root.running && root.style === "ring"
                loops: Animation.Infinite
                NumberAnimation { to: 0.7; duration: 600; easing.type: Easing.InOutCubic }
                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutCubic }
            }

            onArcLengthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = root.color
                ctx.lineWidth = root.size * 0.1
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.arc(
                    width / 2, height / 2,
                    (width - root.size * 0.1) / 2,
                    -Math.PI / 2,
                    -Math.PI / 2 + arcLength * Math.PI * 2
                )
                ctx.stroke()
            }
        }
    }
}
