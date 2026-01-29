import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // ============ Position from environment ============
    property string posEnv: Quickshell.env("QS_POS") || "top-left"
    property int marginT: parseInt(Quickshell.env("QS_MARGIN_T")) || 8
    property int marginR: parseInt(Quickshell.env("QS_MARGIN_R")) || 8
    property int marginB: parseInt(Quickshell.env("QS_MARGIN_B")) || 8
    property int marginL: parseInt(Quickshell.env("QS_MARGIN_L")) || 8
    property bool anchorTop: posEnv.indexOf("top") !== -1 || posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    // ============ Config paths ============
    readonly property string configDir: Quickshell.env("HOME") + "/.cache/wf-recorder-sh"

    // ============ State ============
    property bool isRecording: false
    property string duration: "00:00"

    // Settings
    property string codec: "libx264"
    property string framerate: ""
    property string audio: "on"
    property string fileFormat: "auto"
    property string renderDevice: ""
    property var renderDevices: []

    Component.onCompleted: {
        loadStatus()
        loadConfig()
        loadRenderDevices()
    }

    // ============ Config ============
    function loadStatus() { statusProc.running = true }

    function loadConfig() {
        codecLoader.running = true
        fpsLoader.running = true
        audioLoader.running = true
        formatLoader.running = true
        renderLoader.running = true
    }

    function loadRenderDevices() { renderDevicesProc.running = true }

    function saveConfig(key, value) {
        var path = root.configDir + "/" + key
        if (value === "" || value === "auto") {
            configSaver.command = ["rm", "-f", path]
        } else {
            configSaver.command = ["bash", "-c", "mkdir -p '" + root.configDir + "' && echo -n '" + value + "' > '" + path + "'"]
        }
        configSaver.running = true
    }

    // ============ Actions ============
    function startFullscreen() { fullscreenProc.running = true }
    function startRegion() { regionProc.running = true }
    function startGif() { gifMarkerProc.running = true }
    function stopRecording() { stopProc.running = true }
    function forceStop() { forceStopProc.running = true }
    function openOutputDir() { openDirProc.running = true }

    // ============ Processes ============
    Process {
        id: statusProc
        command: ["bash", "-c", "~/.config/waybar/scripts/wf-recorder.sh is-active && echo recording || echo idle"]
        stdout: StdioCollector {
            onStreamFinished: { root.isRecording = text.trim() === "recording" }
        }
    }
    Process {
        id: durationProc
        command: ["bash", "-c", "~/.config/waybar/scripts/wf-recorder.sh waybar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var status = JSON.parse(text)
                    if (status.text) {
                        var m = status.text.match(/(\d{1,2}:\d{2}(?::\d{2})?)/)
                        if (m) root.duration = m[1]
                    }
                } catch (e) {}
            }
        }
    }

    // Config loaders
    Process { id: codecLoader; command: ["cat", root.configDir + "/codec"]; stdout: StdioCollector { onStreamFinished: { if (text.trim()) root.codec = text.trim() } } }
    Process { id: fpsLoader; command: ["cat", root.configDir + "/framerate"]; stdout: StdioCollector { onStreamFinished: { root.framerate = text.trim() } } }
    Process { id: audioLoader; command: ["cat", root.configDir + "/audio"]; stdout: StdioCollector { onStreamFinished: { if (text.trim()) root.audio = text.trim() } } }
    Process { id: formatLoader; command: ["cat", root.configDir + "/container_ext"]; stdout: StdioCollector { onStreamFinished: { root.fileFormat = text.trim() || "auto" } } }
    Process { id: renderLoader; command: ["cat", root.configDir + "/drm_device"]; stdout: StdioCollector { onStreamFinished: { root.renderDevice = text.trim() } } }
    Process {
        id: renderDevicesProc
        command: ["bash", "-c", "for d in /dev/dri/renderD*; do [ -r \"$d\" ] && echo \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.renderDevices = text.trim().split("\n").filter(function(d) { return d.length > 0 })
            }
        }
    }
    Process { id: configSaver }

    // Recording - 命令在后台运行，QuickShell 退出不影响
    Process {
        id: fullscreenProc
        command: ["bash", "-c", "RECORD_MODE=full MENU_BACKEND=none setsid ~/.config/waybar/scripts/wf-recorder.sh start &"]
        onExited: Qt.quit()
    }
    Process {
        id: regionProc
        command: ["bash", "-c", "RECORD_MODE=region MENU_BACKEND=none setsid ~/.config/waybar/scripts/wf-recorder.sh start &"]
        onExited: Qt.quit()
    }
    Process {
        id: gifMarkerProc
        command: ["bash", "-c", "mkdir -p \"${XDG_RUNTIME_DIR:-/run/user/$UID}/wfrec\" && touch \"${XDG_RUNTIME_DIR:-/run/user/$UID}/wfrec/is_gif\" && RECORD_MODE=region MENU_BACKEND=none setsid ~/.config/waybar/scripts/wf-recorder.sh start &"]
        onExited: Qt.quit()
    }
    Process { id: stopProc; command: ["bash", "-c", "~/.config/waybar/scripts/wf-recorder.sh stop"]; onExited: loadStatus() }
    Process { id: forceStopProc; command: ["pkill", "-9", "wf-recorder"]; onExited: loadStatus() }
    Process { id: openDirProc; command: ["bash", "-c", "xdg-open \"$(xdg-user-dir VIDEOS)/wf-recorder\""] }

    Timer {
        interval: 1000; repeat: true; running: root.isRecording
        onTriggered: { loadStatus(); durationProc.running = true }
    }

    // ============ UI ============
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "quickshell-recorder-bg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "quickshell-recorder"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: root.anchorTop && !root.anchorVCenter
            anchors.bottom: root.anchorBottom
            anchors.left: root.anchorLeft
            anchors.right: root.anchorRight
            margins.top: root.anchorTop ? root.marginT : 0
            margins.bottom: root.anchorBottom ? root.marginB : 0
            margins.left: root.anchorLeft ? root.marginL : 0
            margins.right: root.anchorRight ? root.marginR : 0
            implicitWidth: 360
            implicitHeight: panelContent.implicitHeight + Theme.spacingL * 2

            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

            Rectangle {
                id: panelContent
                anchors.fill: parent
                color: Theme.background
                radius: Theme.radiusL
                border.color: Theme.outline
                border.width: 1
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                MouseArea { anchors.fill: parent; onClicked: function(e) { e.accepted = true } }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // ========== Header ==========
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: root.isRecording ? "\uf111" : "\uf03d"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: Theme.iconSizeL
                            color: root.isRecording ? Theme.error : Theme.primary

                            SequentialAnimation on opacity {
                                running: root.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                        Text {
                            text: root.isRecording ? "录制中" : "屏幕录制"
                            font.pixelSize: Theme.fontSizeL
                            font.weight: Font.Bold
                            color: root.isRecording ? Theme.error : Theme.textPrimary
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: root.isRecording
                            text: root.duration
                            font.pixelSize: Theme.fontSizeL
                            font.weight: Font.Bold
                            font.family: "monospace"
                            color: Theme.error
                        }
                        Rectangle {
                            width: 28; height: 28; radius: Theme.radiusS
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeS; color: Theme.textSecondary }
                            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.5 }

                    // ========== Recording Mode Buttons ==========
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS
                        visible: !root.isRecording

                        // Fullscreen
                        Rectangle {
                            Layout.fillWidth: true
                            height: 64
                            radius: Theme.radiusM
                            color: fullMa.containsMouse ? Theme.alpha(Theme.primary, 0.15) : Theme.surface
                            border.color: fullMa.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "\uf108"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: Theme.primary; Layout.alignment: Qt.AlignHCenter }
                                Text { text: "全屏"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                            }
                            MouseArea { id: fullMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startFullscreen() }
                        }

                        // Region
                        Rectangle {
                            Layout.fillWidth: true
                            height: 64
                            radius: Theme.radiusM
                            color: regionMa.containsMouse ? Theme.alpha(Theme.primary, 0.15) : Theme.surface
                            border.color: regionMa.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "\uf247"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: Theme.primary; Layout.alignment: Qt.AlignHCenter }
                                Text { text: "区域"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                            }
                            MouseArea { id: regionMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startRegion() }
                        }

                        // GIF
                        Rectangle {
                            Layout.fillWidth: true
                            height: 64
                            radius: Theme.radiusM
                            color: gifMa.containsMouse ? Theme.alpha(Theme.secondary, 0.15) : Theme.surface
                            border.color: gifMa.containsMouse ? Theme.secondary : Theme.outline
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "\uf1c5"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: Theme.secondary; Layout.alignment: Qt.AlignHCenter }
                                Text { text: "GIF"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                            }
                            MouseArea { id: gifMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startGif() }
                        }

                        // Open Folder
                        Rectangle {
                            width: 64
                            height: 64
                            radius: Theme.radiusM
                            color: folderMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                            border.color: Theme.outline
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "\uf07b"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: Theme.textSecondary; Layout.alignment: Qt.AlignHCenter }
                                Text { text: "文件夹"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                            }
                            MouseArea { id: folderMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openOutputDir() }
                        }
                    }

                    // ========== Recording Controls ==========
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS
                        visible: root.isRecording

                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: Theme.radiusM
                            color: stopMa.containsMouse ? Theme.alpha(Theme.error, 0.25) : Theme.alpha(Theme.error, 0.15)
                            border.color: Theme.error; border.width: 1

                            RowLayout {
                                anchors.centerIn: parent; spacing: Theme.spacingS
                                Text { text: "\uf04d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: Theme.error }
                                Text { text: "停止录制"; font.pixelSize: Theme.fontSizeM; font.weight: Font.DemiBold; color: Theme.error }
                            }
                            MouseArea { id: stopMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stopRecording() }
                        }

                        Rectangle {
                            width: 48; height: 48; radius: Theme.radiusM
                            color: forceMa.containsMouse ? Theme.alpha(Theme.warning, 0.2) : Theme.surface
                            border.color: forceMa.containsMouse ? Theme.warning : Theme.outline; border.width: 1

                            Text { anchors.centerIn: parent; text: "\uf071"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: forceMa.containsMouse ? Theme.warning : Theme.textMuted }
                            MouseArea { id: forceMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.forceStop() }
                            ToolTip { visible: forceMa.containsMouse; text: "强制停止"; delay: 300 }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.5; visible: !root.isRecording }

                    // ========== Settings (All in one) ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS
                        visible: !root.isRecording

                        // Row 1: Codec
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Text { text: "编码器"; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary; Layout.preferredWidth: 50 }

                            Repeater {
                                model: [
                                    { value: "libx264", label: "CPU" },
                                    { value: "h264_vaapi", label: "H264" },
                                    { value: "hevc_vaapi", label: "HEVC" },
                                    { value: "av1_vaapi", label: "AV1" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: Theme.radiusS
                                    color: root.codec === modelData.value ? Theme.alpha(Theme.primary, 0.2) : (codecItemMa.containsMouse ? Theme.surfaceVariant : "transparent")
                                    border.color: root.codec === modelData.value ? Theme.primary : Theme.outline
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXS
                                        color: root.codec === modelData.value ? Theme.primary : Theme.textSecondary
                                    }
                                    MouseArea {
                                        id: codecItemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.codec = modelData.value
                                            root.saveConfig("codec", modelData.value)
                                            // CPU 编码器不需要渲染设备，清除配置
                                            if (modelData.value === "libx264") {
                                                root.renderDevice = ""
                                                root.saveConfig("drm_device", "")
                                            } else {
                                                // VAAPI 编码器需要渲染设备，自动设置第一个可用设备
                                                if (root.renderDevice === "" && root.renderDevices.length > 0) {
                                                    root.renderDevice = root.renderDevices[0]
                                                    root.saveConfig("drm_device", root.renderDevices[0])
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Row 2: Framerate
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Text { text: "帧率"; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary; Layout.preferredWidth: 50 }

                            Repeater {
                                model: [
                                    { value: "", label: "Auto" },
                                    { value: "30", label: "30" },
                                    { value: "60", label: "60" },
                                    { value: "120", label: "120" },
                                    { value: "144", label: "144" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: Theme.radiusS
                                    color: root.framerate === modelData.value ? Theme.alpha(Theme.primary, 0.2) : (fpsItemMa.containsMouse ? Theme.surfaceVariant : "transparent")
                                    border.color: root.framerate === modelData.value ? Theme.primary : Theme.outline
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXS
                                        color: root.framerate === modelData.value ? Theme.primary : Theme.textSecondary
                                    }
                                    MouseArea {
                                        id: fpsItemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.framerate = modelData.value; root.saveConfig("framerate", modelData.value) }
                                    }
                                }
                            }
                        }

                        // Row 3: Format + Audio
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Text { text: "格式"; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary; Layout.preferredWidth: 50 }

                            Repeater {
                                model: [
                                    { value: "auto", label: "Auto" },
                                    { value: "mp4", label: "MP4" },
                                    { value: "mkv", label: "MKV" },
                                    { value: "webm", label: "WebM" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: Theme.radiusS
                                    color: root.fileFormat === modelData.value ? Theme.alpha(Theme.primary, 0.2) : (fmtItemMa.containsMouse ? Theme.surfaceVariant : "transparent")
                                    border.color: root.fileFormat === modelData.value ? Theme.primary : Theme.outline
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXS
                                        color: root.fileFormat === modelData.value ? Theme.primary : Theme.textSecondary
                                    }
                                    MouseArea {
                                        id: fmtItemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.fileFormat = modelData.value; root.saveConfig("container_ext", modelData.value === "auto" ? "" : modelData.value) }
                                    }
                                }
                            }

                            // Audio toggle
                            Rectangle {
                                width: 70
                                height: 28
                                radius: Theme.radiusS
                                color: root.audio === "on" ? Theme.alpha(Theme.success, 0.2) : Theme.surfaceVariant
                                border.color: root.audio === "on" ? Theme.success : Theme.outline
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: root.audio === "on" ? "󰕾" : "󰖁"; font.pixelSize: Theme.fontSizeS; color: root.audio === "on" ? Theme.success : Theme.textMuted }
                                    Text { text: root.audio === "on" ? "音频" : "静音"; font.pixelSize: Theme.fontSizeXS; color: root.audio === "on" ? Theme.success : Theme.textMuted }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.audio = root.audio === "on" ? "off" : "on"; root.saveConfig("audio", root.audio) }
                                }
                            }
                        }

                        // Row 4: Render Device (only if VAAPI codec selected)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS
                            visible: root.codec.indexOf("vaapi") !== -1 && root.renderDevices.length > 0

                            Text { text: "设备"; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary; Layout.preferredWidth: 50 }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: Theme.radiusS
                                color: root.renderDevice === "" ? Theme.alpha(Theme.primary, 0.2) : (autoRenderMa.containsMouse ? Theme.surfaceVariant : "transparent")
                                border.color: root.renderDevice === "" ? Theme.primary : Theme.outline
                                border.width: 1

                                Text { anchors.centerIn: parent; text: "Auto"; font.pixelSize: Theme.fontSizeXS; color: root.renderDevice === "" ? Theme.primary : Theme.textSecondary }
                                MouseArea { id: autoRenderMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.renderDevice = ""; root.saveConfig("drm_device", "") } }
                            }

                            Repeater {
                                model: root.renderDevices
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: Theme.radiusS
                                    color: root.renderDevice === modelData ? Theme.alpha(Theme.primary, 0.2) : (renderItemMa.containsMouse ? Theme.surfaceVariant : "transparent")
                                    border.color: root.renderDevice === modelData ? Theme.primary : Theme.outline
                                    border.width: 1

                                    Text { anchors.centerIn: parent; text: modelData.replace("/dev/dri/", ""); font.pixelSize: Theme.fontSizeXS; color: root.renderDevice === modelData ? Theme.primary : Theme.textSecondary }
                                    MouseArea { id: renderItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.renderDevice = modelData; root.saveConfig("drm_device", modelData) } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
