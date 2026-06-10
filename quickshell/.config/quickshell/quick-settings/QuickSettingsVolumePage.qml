import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

// ============ Volumes Tab — Bento ============
ColumnLayout {
    required property var controller
    Layout.fillWidth: true
    spacing: Theme.spacingM

    // === Brightness hero card ===
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 96
        radius: Theme.radiusL
        color: Theme.alpha(Theme.surface, 0.7)
        border.color: Theme.alpha(Theme.warning, 0.3)
        border.width: 1

        // 左侧 tone 条
        Rectangle {
            width: 4
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingM
            radius: 2
            color: Theme.warning
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            anchors.leftMargin: Theme.spacingL + 8
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Text {
                    text: "\uf185"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 14
                    color: Theme.warning
                }
                Text {
                    text: controller.i18nContext.trLiteral("亮度")
                    font.pixelSize: Theme.fontSizeS
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5
                    color: Theme.textMuted
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Math.round((controller.brightness / controller.maxBrightness) * 100) + "%"
                    font.pixelSize: 28
                    font.weight: Font.Black
                    color: Theme.textPrimary
                }
            }

            Rectangle {
                id: brightnessSlider
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.alpha(Theme.warning, 0.18)

                property real value: controller.brightness / controller.maxBrightness

                Rectangle {
                    id: brightnessFill
                    width: brightnessSlider.value * parent.width
                    height: parent.height
                    radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.warning, 0.7) }
                        GradientStop { position: 1.0; color: Theme.warning }
                    }
                    Behavior on width { NumberAnimation { duration: 50 } }
                }

                Rectangle {
                    x: Math.max(0, Math.min(brightnessFill.width - width / 2, parent.width - width))
                    y: -5
                    width: 16; height: 16; radius: 8
                    color: Theme.warning
                    border.color: Theme.surface
                    border.width: 2
                    scale: brightnessMa.pressed ? 1.25 : (brightnessMa.containsMouse ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: brightnessMa
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => {
                        controller.setBrightness(Math.max(0, Math.min(1, mouse.x / parent.width)) * 100)
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) controller.setBrightness(Math.max(0, Math.min(1, mouse.x / parent.width)) * 100)
                        }
                    }
                }
            }
        }
    // === Output card ===
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 104
        radius: Theme.radiusL
        color: Theme.alpha(Theme.surface, 0.7)
        border.color: Theme.alpha(controller.outputMuted ? Theme.error : Theme.primary, 0.3)
        border.width: 1
        opacity: controller.sink ? 1.0 : 0.5

        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        Rectangle {
            width: 4
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingM
            radius: 2
            color: controller.outputMuted ? Theme.error : Theme.primary
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            anchors.leftMargin: Theme.spacingL + 8
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: outMuteMa.containsMouse ? Theme.alpha(controller.outputMuted ? Theme.error : Theme.primary, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: controller.outputMuted ? "\uf026" :
                              controller.outputVolume < 0.01 ? "\uf026" :
                              controller.outputVolume < 0.5 ? "\uf027" : "\uf028"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 16
                        color: controller.outputMuted ? Theme.error : Theme.primary
                    }

                    MouseArea {
                        id: outMuteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controller.toggleOutputMute()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    Text {
                        text: controller.i18nContext.trLiteral("输出")
                        font.pixelSize: Theme.fontSizeS
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5
                        color: Theme.textMuted
                    }
                    Text {
                        text: controller.sink?.description ?? controller.i18nContext.trLiteral("无输出设备")
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: Math.round(controller.localOutputVolume * 100) + "%"
                    font.pixelSize: 28
                    font.weight: Font.Black
                    color: controller.outputMuted ? Theme.error : Theme.textPrimary
                }
            }

        Rectangle {
            id: outputSlider
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Theme.surfaceVariant

            Rectangle {
                id: outputFill
                width: Math.min(1, controller.localOutputVolume) * parent.width
                height: parent.height
                radius: 4
                color: controller.outputMuted ? Theme.error : Theme.primary

                Behavior on width { NumberAnimation { duration: 50 } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Over 100% indicator
            Rectangle {
                visible: controller.localOutputVolume > 1.0
                x: parent.width
                width: Math.min(0.5, controller.localOutputVolume - 1.0) * parent.width
                height: parent.height
                radius: 4
                color: Theme.warning
                opacity: 0.7
            }

            Rectangle {
                x: Math.max(0, Math.min(outputFill.width - width / 2, parent.width - width))
                y: -4
                width: 16; height: 16; radius: 8
                color: controller.outputMuted ? Theme.error : Theme.primary
                border.color: Theme.surface
                border.width: 2
                scale: outputMa.pressed ? 1.2 : (outputMa.containsMouse ? 1.1 : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: outputMa
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: (mouse) => {
                    controller.isAdjustingOutput = true
                    controller.localOutputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        controller.localOutputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                    }
                }
                onReleased: {
                    controller.setOutputVolume(controller.localOutputVolume)
                    controller.isAdjustingOutput = false
                }

                onWheel: (wheel) => {
                    let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                    controller.localOutputVolume = Math.max(0, Math.min(1, controller.localOutputVolume + delta))
                    controller.setOutputVolume(controller.localOutputVolume)
                }
            }
        }
        }
    }
    // === Input card ===
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 104
        radius: Theme.radiusL
        color: Theme.alpha(Theme.surface, 0.7)
        border.color: Theme.alpha(controller.inputMuted ? Theme.error : Theme.secondary, 0.3)
        border.width: 1
        opacity: controller.source ? 1.0 : 0.5
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        Rectangle {
            width: 4
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingM
            radius: 2
            color: controller.inputMuted ? Theme.error : Theme.secondary
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            anchors.leftMargin: Theme.spacingL + 8
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: inMuteMa.containsMouse ? Theme.alpha(controller.inputMuted ? Theme.error : Theme.secondary, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: controller.inputMuted ? "\uf131" : "\uf130"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 16
                        color: controller.inputMuted ? Theme.error : Theme.secondary
                    }

                    MouseArea {
                        id: inMuteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controller.toggleInputMute()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    Text {
                        text: controller.i18nContext.trLiteral("输入")
                        font.pixelSize: Theme.fontSizeS
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5
                        color: Theme.textMuted
                    }
                    Text {
                        text: controller.source?.description ?? controller.i18nContext.trLiteral("无输入设备")
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: Math.round(controller.localInputVolume * 100) + "%"
                    font.pixelSize: 28
                    font.weight: Font.Black
                    color: controller.inputMuted ? Theme.error : Theme.textPrimary
                }
            }

        Rectangle {
            id: inputSlider
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Theme.surfaceVariant

            Rectangle {
                id: inputFill
                width: Math.min(1, controller.localInputVolume) * parent.width
                height: parent.height
                radius: 4
                color: controller.inputMuted ? Theme.error : Theme.secondary

                Behavior on width { NumberAnimation { duration: 50 } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Rectangle {
                x: Math.max(0, Math.min(inputFill.width - width / 2, parent.width - width))
                y: -4
                width: 16; height: 16; radius: 8
                color: controller.inputMuted ? Theme.error : Theme.secondary
                border.color: Theme.surface
                border.width: 2
                scale: inputMa.pressed ? 1.2 : (inputMa.containsMouse ? 1.1 : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: inputMa
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: (mouse) => {
                    controller.isAdjustingInput = true
                    controller.localInputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        controller.localInputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                    }
                }
                onReleased: {
                    controller.setInputVolume(controller.localInputVolume)
                    controller.isAdjustingInput = false
                }

                onWheel: (wheel) => {
                    let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                    controller.localInputVolume = Math.max(0, Math.min(1, controller.localInputVolume + delta))
                    controller.setInputVolume(controller.localInputVolume)
                }
            }
        }
    }
}
}
