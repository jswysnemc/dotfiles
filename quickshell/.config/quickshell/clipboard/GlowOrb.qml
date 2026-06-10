import QtQuick
import QtQuick.Effects

Rectangle {
    id: orb

    property color glowColor: "#7c5cff"
    property real glowOpacity: 0.55
    property real blur: 1.0

    property bool breathe: true
    property int breatheDuration: 4200
    property real breatheMin: 0.85
    property real breatheMax: 1.15

    width: 180
    height: width
    radius: width / 2
    color: glowColor
    opacity: glowOpacity
    antialiasing: true

    layer.enabled: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        blurMultiplier: 1.4
    }

    SequentialAnimation on scale {
        running: orb.breathe
        loops: Animation.Infinite
        NumberAnimation { to: orb.breatheMax; duration: orb.breatheDuration; easing.type: Easing.InOutSine }
        NumberAnimation { to: orb.breatheMin; duration: orb.breatheDuration; easing.type: Easing.InOutSine }
    }
}
