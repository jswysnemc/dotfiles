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
    readonly property string initialPickedColor: Quickshell.env("QS_PICKED_COLOR") || ""
    property string activePage: initialPickedColor ? "color" : "main"
    property string pickedColor: ""
    property string copyNotice: ""
    property bool isClosing: false

    property string posEnv: Quickshell.env("QS_POS") || "top-left"
    property int marginT: parseInt(Quickshell.env("QS_MARGIN_T")) || 8
    property int marginR: parseInt(Quickshell.env("QS_MARGIN_R")) || 8
    property int marginB: parseInt(Quickshell.env("QS_MARGIN_B")) || 8
    property int marginL: parseInt(Quickshell.env("QS_MARGIN_L")) || 8
    property bool anchorTop: posEnv.indexOf("top") !== -1
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/screenshot-toolbox/screenshot-toolbox.sh"
    property var actions: [
        {
            mode: "region-copy",
            icon: "SEL",
            title: "选框复制",
            desc: "grim + slurp -> wl-copy",
            color: Theme.primary
        },
        {
            mode: "window",
            icon: "WIN",
            title: "窗口截图",
            desc: "鼠标选择窗口",
            color: Theme.secondary
        },
        {
            mode: "fullscreen",
            icon: "FULL",
            title: "全屏截图",
            desc: "grim 全屏保存并复制",
            color: Theme.success
        },
        {
            mode: "scroll",
            icon: "LONG",
            title: "长截图",
            desc: "wayscrollshot",
            color: Theme.tertiary
        },
        {
            mode: "measure",
            icon: "PX",
            title: "像素测量",
            desc: "选框后复制宽高",
            color: Theme.primary
        },
        {
            mode: "ocr",
            icon: "OCR",
            title: "OCR 识别",
            desc: "选区识别并复制文本",
            color: Theme.secondary
        },
        {
            mode: "color",
            icon: "#",
            title: "颜色选取",
            desc: "取色并复制 HEX",
            color: Theme.tertiary
        },
        {
            mode: "region-edit",
            icon: "EDIT",
            title: "截图编辑",
            desc: "选区后打开 markpix",
            color: Theme.warning
        },
        {
            mode: "region-annotate",
            icon: "ANNO",
            title: "选取标注",
            desc: "mark-shot",
            color: Theme.warning
        },
        {
            mode: "fullscreen-annotate",
            icon: "FANN",
            title: "全屏标注",
            desc: "mark-shot --fullscreen",
            color: Theme.secondary
        },
        {
            mode: "region-pin",
            icon: "PIN",
            title: "选区贴图",
            desc: "qt-img-viewer -f",
            color: Theme.success
        },
        {
            mode: "pin-latest",
            icon: "IMG",
            title: "贴最新图",
            desc: "打开最近截图",
            color: Theme.primary
        }
    ]

    Component.onCompleted: {
        if (root.initialPickedColor) root.pickedColor = root.normalizeHex(root.initialPickedColor)
        enterAnimation.start()
    }

    function runAction(mode) {
        if (root.isClosing) return
        root.isClosing = true

        if (mode === "color") {
            actionProc.command = ["bash", "-c", "setsid \"$1\" color-page >/dev/null 2>&1 &", "qs-shot-color", root.scriptPath]
        } else {
            actionProc.command = ["bash", "-c", "setsid \"$1\" \"$2\" >/dev/null 2>&1 &", "qs-shot", root.scriptPath, mode]
        }
        actionProc.running = true
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
        var hex = normalizeHex(root.pickedColor)
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
        root.copyNotice = value
        copyProc.command = ["bash", "-c", "printf '%s\\n' \"$1\" | wl-copy && notify-send '截图工具' '已复制: '\"$1\"", "qs-copy-color", value]
        copyProc.running = true
    }

    function closeWithAnimation() {
        if (root.isClosing) return
        root.isClosing = true
        exitAnimation.start()
    }

    Process {
        id: actionProc
        command: ["true"]
        onExited: Qt.quit()
    }

    Process {
        id: copyProc
        command: ["true"]
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "quickshell-screenshot-toolbox"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.activePage === "color" ? root.activePage = "main" : root.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: card
                anchors.top: root.anchorTop ? parent.top : undefined
                anchors.bottom: root.anchorBottom ? parent.bottom : undefined
                anchors.left: root.anchorLeft ? parent.left : undefined
                anchors.right: root.anchorRight ? parent.right : undefined
                anchors.horizontalCenter: root.anchorHCenter ? parent.horizontalCenter : undefined
                anchors.verticalCenter: root.anchorVCenter ? parent.verticalCenter : undefined
                anchors.topMargin: root.anchorTop ? root.marginT : 0
                anchors.bottomMargin: root.anchorBottom ? root.marginB : 0
                anchors.leftMargin: root.anchorLeft ? root.marginL : 0
                anchors.rightMargin: root.anchorRight ? root.marginR : 0
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
                            visible: root.activePage === "color"
                            width: 30
                            height: 30
                            radius: Theme.radiusS
                            color: backArea.containsMouse ? Theme.surfaceVariant : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf060"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeS
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: backArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activePage = "main"
                            }
                        }

                        Rectangle {
                            width: 42
                            height: 42
                            radius: Theme.radiusM
                            color: root.activePage === "color" && root.pickedColor ? root.pickedColor : Theme.alpha(Theme.primary, 0.16)
                            border.color: root.activePage === "color" ? Theme.outline : "transparent"
                            border.width: root.activePage === "color" ? 1 : 0

                            Text {
                                visible: root.activePage !== "color"
                                anchors.centerIn: parent
                                text: "\uf030"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeL
                                color: Theme.primary
                            }
                        }

                        ColumnLayout {
                            spacing: 2

                            Text {
                                text: root.activePage === "color" ? "颜色详情" : "截图工具箱"
                                font.pixelSize: Theme.fontSizeXL
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: root.activePage === "color" ? "点击任意写法复制" : "选框、窗口、长截图、贴图和编辑"
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 32
                            height: 32
                            radius: Theme.radiusM
                            Layout.alignment: Qt.AlignVCenter
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: closeMa.containsMouse ? 1.1 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeM
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeWithAnimation()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.55 }

                    GridLayout {
                        visible: root.activePage === "main"
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Theme.spacingM
                        columnSpacing: Theme.spacingM

                        Repeater {
                            model: root.actions

                            Rectangle {
                                id: actionTile
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 82
                                radius: Theme.radiusL
                                color: tileArea.containsMouse ? Theme.alpha(modelData.color, 0.14) : Theme.surface
                                border.color: tileArea.containsMouse ? modelData.color : Theme.outline
                                border.width: 1
                                scale: tileArea.pressed ? 0.98 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 42
                                        height: 42
                                        radius: Theme.radiusM
                                        color: Theme.alpha(actionTile.modelData.color, 0.14)

                                        Text {
                                            anchors.centerIn: parent
                                            text: actionTile.modelData.icon
                                            font.family: "monospace"
                                            font.pixelSize: actionTile.modelData.icon.length > 3 ? Theme.fontSizeS : Theme.fontSizeL
                                            font.weight: Font.Bold
                                            color: actionTile.modelData.color
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: actionTile.modelData.title
                                            font.pixelSize: Theme.fontSizeM
                                            font.weight: Font.DemiBold
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: actionTile.modelData.desc
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.textMuted
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runAction(actionTile.modelData.mode)
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: root.activePage === "main"
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: Theme.radiusM
                            color: Theme.surfaceVariant

                            Text {
                                anchors.centerIn: parent
                                text: "后续功能可继续追加到 actions 和脚本 mode"
                                font.pixelSize: Theme.fontSizeXS
                                color: Theme.textMuted
                            }
                        }

                        Rectangle {
                            width: 104
                            height: 36
                            radius: Theme.radiusM
                            color: dirArea.containsMouse ? Theme.alpha(Theme.primary, 0.14) : Theme.surface
                            border.color: dirArea.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Text {
                                    text: "\uf07b"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: Theme.primary
                                }

                                Text {
                                    text: "截图目录"
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: dirArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runAction("open-dir")
                            }
                        }
                    }

                    ColumnLayout {
                        visible: root.activePage === "color"
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            Layout.fillWidth: true
                            height: 96
                            radius: Theme.radiusL
                            color: root.pickedColor || Theme.surface
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
                                required property int index

                                Layout.fillWidth: true
                                height: 42
                                radius: Theme.radiusM
                                color: formatArea.containsMouse ? Theme.alpha(Theme.primary, 0.12) : Theme.surface
                                border.color: formatArea.containsMouse ? Theme.primary : Theme.outline
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

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
}
