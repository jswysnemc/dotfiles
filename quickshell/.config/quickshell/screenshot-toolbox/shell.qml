import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

ShellRoot {
    id: root

    I18nContext {
        id: i18n
        catalog: "screenshot-toolbox"
    }

    readonly property var i18nContext: i18n

    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: false
    readonly property string initialPickedColor: Quickshell.env("QS_PICKED_COLOR") || ""
    property string activePage: initialPickedColor ? "color" : "main"
    property string pickedColor: ""
    property string copyNotice: ""
    property bool isClosing: false
    property bool previewLoading: false
    property var previewItems: []

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
            title: i18n.trLiteral("选框复制"),
            desc: "grim + slurp -> wl-copy",
            color: Theme.primary
        },
        {
            mode: "window",
            icon: "WIN",
            title: i18n.trLiteral("窗口截图"),
            desc: i18n.trLiteral("鼠标选择窗口"),
            color: Theme.secondary
        },
        {
            mode: "fullscreen",
            icon: "FULL",
            title: i18n.trLiteral("全屏截图"),
            desc: i18n.trLiteral("grim 全屏保存并复制"),
            color: Theme.success
        },
        {
            mode: "scroll",
            icon: "LONG",
            title: i18n.trLiteral("长截图"),
            desc: "wayscrollshot",
            color: Theme.tertiary
        },
        {
            mode: "measure",
            icon: "PX",
            title: i18n.trLiteral("像素测量"),
            desc: i18n.trLiteral("选框后复制宽高"),
            color: Theme.primary
        },
        {
            mode: "ocr",
            icon: "OCR",
            title: i18n.trLiteral("OCR 识别"),
            desc: i18n.trLiteral("选区识别并复制文本"),
            color: Theme.secondary
        },
        {
            mode: "color",
            icon: "#",
            title: i18n.trLiteral("颜色选取"),
            desc: i18n.trLiteral("取色并复制 HEX"),
            color: Theme.tertiary
        },
        {
            mode: "region-edit",
            icon: "EDIT",
            title: i18n.trLiteral("截图编辑"),
            desc: i18n.trLiteral("选区后打开 markpix"),
            color: Theme.warning
        },
        {
            mode: "region-annotate",
            icon: "ANNO",
            title: i18n.trLiteral("选取标注"),
            desc: "mark-shot",
            color: Theme.warning
        },
        {
            mode: "fullscreen-annotate",
            icon: "FANN",
            title: i18n.trLiteral("全屏标注"),
            desc: "mark-shot --fullscreen",
            color: Theme.secondary
        },
        {
            mode: "region-pin",
            icon: "PIN",
            title: i18n.trLiteral("选区贴图"),
            desc: "qt-img-viewer -f",
            color: Theme.success
        },
        {
            mode: "qr-page",
            icon: "QR",
            title: i18n.trLiteral("QR 扫码"),
            desc: i18n.trLiteral("选区识别二维码"),
            color: Theme.primary
        }
    ]

    Component.onCompleted: {
        if (root.initialPickedColor) root.pickedColor = root.normalizeHex(root.initialPickedColor)
        enterAnimation.start()
    }

    function runAction(mode) {
        if (root.isClosing) return

        if (mode === "fullscreen" && root.activePage === "main" && Quickshell.screens.length > 1) {
            root.activePage = "screen-select"
            root.loadScreenPreviews()
            return
        }

        root.isClosing = true
        root.blurActive = false

        if (mode === "color") {
            actionProc.command = ["bash", "-c", "setsid \"$1\" color-page >/dev/null 2>&1 &", "qs-shot-color", root.scriptPath]
        } else {
            actionProc.command = ["bash", "-c", "setsid \"$1\" \"$2\" >/dev/null 2>&1 &", "qs-shot", root.scriptPath, mode]
        }
        actionProc.running = true
    }

    function runActionWithArg(mode, arg) {
        if (root.isClosing) return
        root.isClosing = true
        root.blurActive = false

        actionProc.command = ["bash", "-c", "setsid \"$1\" \"$2\" \"$3\" >/dev/null 2>&1 &", "qs-shot-arg", root.scriptPath, mode, arg]
        actionProc.running = true
    }

    function screenOptions() {
        if (root.previewItems.length > 0) return root.previewItems

        var options = [
            {
                mode: "fullscreen",
                output: "",
                icon: "ALL",
                title: i18n.trLiteral("全部屏幕"),
                desc: i18n.trLiteral("按逻辑布局拼接")
            }
        ]

        for (var i = 0; i < Quickshell.screens.length; i++) {
            options.push({
                mode: "fullscreen-output",
                output: Quickshell.screens[i].name,
                icon: "MON",
                title: Quickshell.screens[i].name,
                desc: i18n.trLiteral("只截取这个显示器")
            })
        }

        return options
    }

    function loadScreenPreviews() {
        root.previewLoading = true
        previewProc.command = [root.scriptPath, "preview-json"]
        previewProc.running = true
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

    /**
     * 关闭截图工具弹窗窗口。
     *
     * @param 无
     * @returns 无
     */
    function closeWithAnimation() {
        if (root.isClosing) return
        root.isClosing = true
        // 1. 先关闭模糊区域，避免退出前全屏 layer 参与模糊
        root.blurActive = false
        // 2. 立即隐藏卡片并退出，保持与剪贴板一致
        root.panelOpacity = 0
        Qt.quit()
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

    Process {
        id: previewProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.previewItems = JSON.parse(text)
                } catch (e) {
                    console.log("Failed to parse screenshot previews:", e)
                }
                root.previewLoading = false
            }
        }
        onExited: root.previewLoading = false
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

    // ============ UI ============
    ScreenshotToolboxView {
        controller: root
    }
}
