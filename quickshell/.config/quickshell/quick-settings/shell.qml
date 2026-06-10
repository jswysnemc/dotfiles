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

ShellRoot {
    id: root

    I18nContext {
        id: i18n
        catalog: "quick-settings"
    }

    readonly property var i18nContext: i18n

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: true

    // ============ Position from environment ============
    property string posEnv: Quickshell.env("QS_POS") || "top-right"
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

    // ============ Pipewire Audio State ============
    readonly property PwNode sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property PwNode source: Pipewire.ready ? Pipewire.defaultAudioSource : null

    // Bind devices to ensure properties are available
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
    PwObjectTracker {
        objects: root.source ? [root.source] : []
    }

    // Track links to the default sink
    PwNodeLinkTracker {
        id: sinkLinkTracker
        node: root.sink
    }

    // Get application streams connected to default sink
    readonly property var appStreams: {
        if (!Pipewire.ready || !sink) return []

        var connectedStreamIds = {}
        var connectedStreams = []

        // Get link groups from sink tracker
        if (!sinkLinkTracker.linkGroups) return []

        var linkGroupsCount = 0
        if (sinkLinkTracker.linkGroups.length !== undefined) {
            linkGroupsCount = sinkLinkTracker.linkGroups.length
        } else if (sinkLinkTracker.linkGroups.count !== undefined) {
            linkGroupsCount = sinkLinkTracker.linkGroups.count
        }

        for (var i = 0; i < linkGroupsCount; i++) {
            var linkGroup
            if (sinkLinkTracker.linkGroups.get) {
                linkGroup = sinkLinkTracker.linkGroups.get(i)
            } else {
                linkGroup = sinkLinkTracker.linkGroups[i]
            }

            if (!linkGroup || !linkGroup.source) continue

            var sourceNode = linkGroup.source
            if (sourceNode.isStream && sourceNode.audio) {
                if (!connectedStreamIds[sourceNode.id]) {
                    // Check if it's a playback stream (not capture)
                    var props = sourceNode.properties || {}
                    if (!props["stream.capture.sink"]) {
                        connectedStreamIds[sourceNode.id] = true
                        connectedStreams.push(sourceNode)
                    }
                }
            }
        }

        // Fallback: if no streams found via links, get all stream nodes
        if (connectedStreams.length === 0) {
            var nodes = Pipewire.nodes.values
            for (var j = 0; j < nodes.length; j++) {
                var node = nodes[j]
                if (node.isStream && node.audio && !node.isSink) {
                    var nodeProps = node.properties || {}
                    if (!nodeProps["stream.capture.sink"]) {
                        connectedStreams.push(node)
                    }
                }
            }
        }

        return connectedStreams
    }

    // Bind all app stream nodes
    PwObjectTracker {
        id: appStreamsTracker
        objects: root.appStreams
    }

    // Get all sinks and sources
    readonly property var sinks: {
        if (!Pipewire.ready) return []
        var list = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i]
            if (!node.isStream && node.isSink) {
                list.push(node)
            }
        }
        return list
    }

    readonly property var sources: {
        if (!Pipewire.ready) return []
        var list = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i]
            if (!node.isStream && !node.isSink && node.audio) {
                list.push(node)
            }
        }
        return list
    }

    // Bind all device nodes
    PwObjectTracker {
        objects: [...root.sinks, ...root.sources]
    }

    // Output volume
    readonly property real outputVolume: sink?.audio?.volume ?? 0
    readonly property bool outputMuted: sink?.audio?.muted ?? false

    // Input volume
    readonly property real inputVolume: source?.audio?.volume ?? 0
    readonly property bool inputMuted: source?.audio?.muted ?? false

    // Local volume for smooth slider interaction
    property real localOutputVolume: outputVolume
    property real localInputVolume: inputVolume
    property bool isAdjustingOutput: false
    property bool isAdjustingInput: false

    // Sync local volume from device when not adjusting
    onOutputVolumeChanged: {
        if (!isAdjustingOutput) localOutputVolume = outputVolume
    }
    onInputVolumeChanged: {
        if (!isAdjustingInput) localInputVolume = inputVolume
    }

    // Volume control functions
    function setOutputVolume(vol) {
        if (sink?.audio) {
            sink.audio.volume = Math.max(0, Math.min(1.5, vol))
            if (sink.audio.muted) sink.audio.muted = false
        }
    }

    function setInputVolume(vol) {
        if (source?.audio) {
            source.audio.volume = Math.max(0, Math.min(1.5, vol))
            if (source.audio.muted) source.audio.muted = false
        }
    }

    function toggleOutputMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted
    }

    function toggleInputMute() {
        if (source?.audio) source.audio.muted = !source.audio.muted
    }

    function setDefaultSink(node) {
        if (Pipewire.ready) Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        if (Pipewire.ready) Pipewire.preferredDefaultAudioSource = node
    }

    // ============ Brightness State ============
    property real brightness: 100
    property real maxBrightness: 100

    Process {
        id: brightnessGet
        command: ["brightnessctl", "info", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                if (lines.length > 0) {
                    let parts = lines[0].split(",")
                    if (parts.length >= 5) {
                        root.maxBrightness = parseInt(parts[4]) || 100
                        root.brightness = parseInt(parts[2]) || 0
                    }
                }
            }
        }
    }

    Process {
        id: brightnessSet
        command: ["echo"]
    }

    function setBrightness(pct) {
        let v = Math.round(Math.max(1, Math.min(100, pct)))
        brightnessSet.command = ["brightnessctl", "set", v + "%"]
        brightnessSet.running = true
        brightness = (v / 100) * maxBrightness
    }

    // Initialize
    Component.onCompleted: {
        brightnessGet.running = true
        refreshDisplays()
        enterAnimation.start()
    }

    // ============ Animations ============
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

    function closeWithAnimation() {
        root.blurActive = false
        exitAnimation.start()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: brightnessGet.running = true
    }

    // Debounce timer for volume sync
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (isAdjustingOutput && Math.abs(localOutputVolume - outputVolume) >= 0.01) {
                setOutputVolume(localOutputVolume)
            }
            if (isAdjustingInput && Math.abs(localInputVolume - inputVolume) >= 0.01) {
                setInputVolume(localInputVolume)
            }
        }
    }

    // Tab state
    property int currentTab: 0  // 0: volumes, 1: apps, 2: devices, 3: display
    readonly property var tabLabels: [i18n.trLiteral("音量"), i18n.trLiteral("应用"), i18n.trLiteral("设备"), i18n.trLiteral("显示")]

    function selectTab(index) {
        root.currentTab = Math.max(0, Math.min(root.tabLabels.length - 1, index))
        if (root.currentTab === 3) root.refreshDisplays()
    }

    // ============ Display State ============
    property var displayOutputs: []
    property bool displayLoading: false
    readonly property string monitorScript: Quickshell.env("HOME") + "/.config/niri/scripts/niri-monitor-switch.sh"

    Process {
        id: displayGet
        command: [root.monitorScript, "list-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let outputs = JSON.parse(text)
                    root.displayOutputs = outputs.map(o => ({
                        name: o.name,
                        make: o.make || "",
                        model: o.model || "",
                        width: o.current?.width || 0,
                        height: o.current?.height || 0,
                        refresh: o.current?.refresh || 0,
                        scale: o.scale || 1.0,
                        vrr: o.vrr_enabled || false,
                        vrr_supported: o.vrr_supported || false,
                        modes: o.modes || []
                    }))
                } catch (e) {
                    console.log("Failed to parse display outputs:", e)
                }
                root.displayLoading = false
            }
        }
    }

    function refreshDisplays() {
        displayLoading = true
        displayGet.running = true
    }

    function setDisplayMode(output, mode) {
        displaySetProc.command = [root.monitorScript, "set", output, mode, "--save"]
        displaySetProc.running = true
    }

    function saveDisplayConfig() {
        displaySaveProc.running = true
    }

    Process {
        id: displaySetProc
        command: ["echo"]
        onExited: root.refreshDisplays()
    }

    Process {
        id: displaySaveProc
        command: [root.monitorScript, "save"]
    }

    // ============ UI ============
    QuickSettingsView {
        controller: root
    }
}
