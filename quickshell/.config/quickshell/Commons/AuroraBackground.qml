// AuroraBackground.qml - 背景级别的 aurora 光晕装饰
// 在容器内 2~3 个位置散布柔光彩球,默认低饱和度,营造氛围

import QtQuick
import "./Theme.js" as Theme

Item {
    id: root

    clip: true

    property color colorA: Theme.primary
    property color colorB: Theme.secondary
    property color colorC: Theme.tertiary

    property real intensity: 0.4
    property real orbScale: 1.0

    GlowOrb {
        x: -width * 0.25
        y: -height * 0.15
        width: 260 * root.orbScale
        glowColor: root.colorA
        glowOpacity: root.intensity
        breatheDuration: 5200
    }

    GlowOrb {
        x: root.width - width * 0.6
        y: root.height * 0.55
        width: 200 * root.orbScale
        glowColor: root.colorB
        glowOpacity: root.intensity * 0.9
        breatheDuration: 6100
        breatheMin: 0.9
        breatheMax: 1.2
    }

    GlowOrb {
        x: root.width * 0.55
        y: -height * 0.35
        width: 160 * root.orbScale
        glowColor: root.colorC
        glowOpacity: root.intensity * 0.7
        breatheDuration: 7300
        breatheMin: 0.8
        breatheMax: 1.05
    }
}
