import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    readonly property string pickedColor: normalizeHex(Quickshell.env("QS_PICKED_COLOR") || "")

    Component.onCompleted: {
        if (!root.pickedColor) Qt.quit()
        enterAnimation.start()
    }

    function normalizeHex(hex) {
        var value = (hex || "").trim()
        if (!value) return ""
        if (value[0] !== "#") value = "#" + value
        return value.toUpperCase()
    }

    function colorChannels(hex) {
        var value = normalizeHex(hex).replace("#", "")
        if (value.length === 3 || value.length === 4) {
            value = value.split("").map(function(ch) { return ch + ch }).join("")
        }
        return {
            r: parseInt(value.slice(0, 2), 16) || 0,
            g: parseInt(value.slice(2, 4), 16) || 0,
            b: parseInt(value.slice(4, 6), 16) || 0,
            a: value.length >= 8 ? Math.round((parseInt(value.slice(6, 8), 16) / 255) * 1000) / 1000 : 1
        }
    }

    function hslString(hex) {
        var c = colorChannels(hex)
        var r = c.r / 255
        var g = c.g / 255
        var b = c.b / 255
        var max = Math.max(r, g, b)
        var min = Math.min(r, g, b)
        var h = 0
        var s = 0
        var l = (max + min) / 2
        var d = max - min

        if (d !== 0) {
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
            else if (max === g) h = ((b - r) / d + 2) / 6
            else h = ((r - g) / d + 4) / 6
        }

        return "hsl(" + Math.round(h * 360) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)"
    }

    function hsvString(hex) {
        var c = colorChannels(hex)
        var r = c.r / 255
        var g = c.g / 255
        var b = c.b / 255
        var max = Math.max(r, g, b)
        var min = Math.min(r, g, b)
        var d = max - min
        var h = 0
        var s = max === 0 ? 0 : d / max

        if (d !== 0) {
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
            else if (max === g) h = ((b - r) / d + 2) / 6
            else h = ((r - g) / d + 4) / 6
        }

        return "hsv(" + Math.round(h * 360) + ", " + Math.round(s * 100) + "%, " + Math.round(max * 100) + "%)"
    }

    function colorFormats() {
        var hex = root.pickedColor
        var c = colorChannels(hex)
        return [
            { label: "HEX", value: hex },
            { label: "hex lower", value: hex.toLowerCase() },
            { label: "RGB", value: "rgb(" + c.r + ", " + c.g + ", " + c.b + ")" },
            { label: "RGBA", value: "rgba(" + c.r + ", " + c.g + ", " + c.b + ", " + c.a + ")" },
            { label: "HSL", value: hslString(hex) },
            { label: "HSV", value: hsvString(hex) },
            { label: "Qt", value: "Qt.rgba(" + (c.r / 255).toFixed(3) + ", " + (c.g / 255).toFixed(3) + ", " + (c.b / 255).toFixed(3) + ", " + c.a + ")" }
        ]
    }

    function copyValue(value) {
        copyProc.command = ["bash", "-c", "printf '%s\\n' \"$1\" | wl-copy && notify-send '颜色详情' '已复制: '\"$1\"", "qs-copy-color", value]
        copyProc.running = true
    }

    function closeWithAnimation() {
        exitAnimation.start()
    }

    Process {
        id: copyProc
        command: ["true"]
        onExited: root.closeWithAnimation()
    }

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation { target: root; property: "panelOpacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "panelScale"; from: 0.95; to: 1.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        NumberAnimation { target: root; property: "panelY"; from: 15; to: 0; duration: 250; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation { target: root; property: "panelOpacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "panelScale"; to: 0.95; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "panelY"; to: -10; duration: 150; easing.type: Easing.InCubic }
        onFinished: Qt.quit()
    }

    // Background overlay, same structure as close-confirm.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.3)
            WlrLayershell.namespace: "qs-color-viewer-bg"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }
        }
    }

    // Main dialog, matching close-confirm's separate dialog window pattern.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "qs-color-viewer"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: 420
                height: content.implicitHeight + Theme.spacingXL * 2
                radius: Theme.radiusXL
                color: Theme.background
                border.color: Theme.outline
                border.width: 1
                opacity: root.panelOpacity
                scale: root.panelScale
                transform: Translate { y: root.panelY }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 42
                            height: 42
                            radius: Theme.radiusM
                            color: root.pickedColor
                            border.color: Theme.outline
                            border.width: 1
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "颜色详情"
                                font.pixelSize: Theme.fontSizeXL
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "点击任意写法复制"
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                            }
                        }

                        Rectangle {
                            width: 30
                            height: 30
                            radius: Theme.radiusS
                            color: closeArea.containsMouse ? Theme.surfaceVariant : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeS
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeWithAnimation()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 96
                        radius: Theme.radiusL
                        color: root.pickedColor
                        border.color: Theme.outline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.pickedColor
                            font.pixelSize: Theme.fontSizeXL
                            font.weight: Font.Bold
                            color: {
                                var c = root.colorChannels(root.pickedColor)
                                return ((c.r * 299 + c.g * 587 + c.b * 114) / 1000) > 150 ? "#111111" : "#ffffff"
                            }
                        }
                    }

                    Repeater {
                        model: root.colorFormats()

                        Rectangle {
                            id: formatRow
                            required property var modelData

                            Layout.fillWidth: true
                            height: 42
                            radius: Theme.radiusM
                            color: formatArea.containsMouse ? Theme.alpha(Theme.primary, 0.12) : Theme.surface
                            border.color: formatArea.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingM

                                Text {
                                    text: formatRow.modelData.label
                                    font.pixelSize: Theme.fontSizeS
                                    font.weight: Font.DemiBold
                                    color: Theme.textSecondary
                                    Layout.preferredWidth: 76
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: formatRow.modelData.value
                                    font.pixelSize: Theme.fontSizeS
                                    font.family: "monospace"
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "\uf0c5"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: formatArea.containsMouse ? Theme.primary : Theme.textMuted
                                }
                            }

                            MouseArea {
                                id: formatArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyValue(formatRow.modelData.value)
                            }
                        }
                    }
                }
            }
        }
    }
}
