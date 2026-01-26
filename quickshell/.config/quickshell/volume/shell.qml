import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "./Theme.js" as Theme

ShellRoot {
    id: root

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
    property int currentTab: 0  // 0: volumes, 1: devices

    // ============ UI ============
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-volume-bg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-volume"
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
            implicitHeight: panelRect.implicitHeight


            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                color: Theme.background
                radius: Theme.radiusL
                border.color: Theme.outline
                border.width: 1
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf028"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: Theme.iconSizeM
                            color: Theme.primary
                        }

                        Text {
                            text: "音量与亮度"
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
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
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    // Tab bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: Theme.radiusM
                        color: Theme.surfaceVariant

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 2
                            spacing: 2

                            Repeater {
                                model: ["音量", "应用", "设备"]

                                Rectangle {
                                    required property int index
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusS
                                    color: root.currentTab === index ? Theme.surface : "transparent"

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeS
                                        font.bold: root.currentTab === index
                                        color: root.currentTab === index ? Theme.primary : Theme.textMuted
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.currentTab = parent.index
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // ============ Tab Content ============
                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: root.currentTab

                        // ============ Volumes Tab ============
                        ColumnLayout {
                            spacing: Theme.spacingL

                            // Brightness Section
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    Text {
                                        text: "\uf185"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: Theme.iconSizeS
                                        color: Theme.warning
                                    }

                                    Text {
                                        text: "亮度"
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: Math.round((root.brightness / root.maxBrightness) * 100) + "%"
                                        font.pixelSize: Theme.fontSizeS
                                        color: Theme.textMuted
                                    }
                                }

                                Rectangle {
                                    id: brightnessSlider
                                    Layout.fillWidth: true
                                    height: 8
                                    radius: 4
                                    color: Theme.surfaceVariant

                                    property real value: root.brightness / root.maxBrightness

                                    Rectangle {
                                        id: brightnessFill
                                        width: brightnessSlider.value * parent.width
                                        height: parent.height
                                        radius: 4
                                        color: Theme.warning

                                        Behavior on width { NumberAnimation { duration: 50 } }
                                    }

                                    Rectangle {
                                        x: Math.max(0, Math.min(brightnessFill.width - width / 2, parent.width - width))
                                        y: -4
                                        width: 16; height: 16; radius: 8
                                        color: Theme.warning
                                        border.color: Theme.surface
                                        border.width: 2
                                        scale: brightnessMa.pressed ? 1.2 : (brightnessMa.containsMouse ? 1.1 : 1.0)

                                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        id: brightnessMa
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onPressed: (mouse) => {
                                            root.setBrightness(Math.max(0, Math.min(1, mouse.x / parent.width)) * 100)
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed) root.setBrightness(Math.max(0, Math.min(1, mouse.x / parent.width)) * 100)
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.4 }

                            // Output Volume Section
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS
                                opacity: root.sink ? 1.0 : 0.5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 28; height: 28; radius: Theme.radiusM
                                        color: outMuteMa.containsMouse ? Theme.surfaceVariant : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.outputMuted ? "\uf026" :
                                                  root.outputVolume < 0.01 ? "\uf026" :
                                                  root.outputVolume < 0.5 ? "\uf027" : "\uf028"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: Theme.iconSizeM
                                            color: root.outputMuted ? Theme.error : Theme.primary
                                        }

                                        MouseArea {
                                            id: outMuteMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleOutputMute()
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            text: "输出音量"
                                            font.pixelSize: Theme.fontSizeM
                                            font.bold: true
                                            color: Theme.textPrimary
                                        }

                                        Text {
                                            text: root.sink?.description ?? "无输出设备"
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.textMuted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        text: Math.round(root.localOutputVolume * 100) + "%"
                                        font.pixelSize: Theme.fontSizeS
                                        color: root.outputMuted ? Theme.error : Theme.textMuted
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
                                        width: Math.min(1, root.localOutputVolume) * parent.width
                                        height: parent.height
                                        radius: 4
                                        color: root.outputMuted ? Theme.error : Theme.primary

                                        Behavior on width { NumberAnimation { duration: 50 } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }

                                    // Over 100% indicator
                                    Rectangle {
                                        visible: root.localOutputVolume > 1.0
                                        x: parent.width
                                        width: Math.min(0.5, root.localOutputVolume - 1.0) * parent.width
                                        height: parent.height
                                        radius: 4
                                        color: Theme.warning
                                        opacity: 0.7
                                    }

                                    Rectangle {
                                        x: Math.max(0, Math.min(outputFill.width - width / 2, parent.width - width))
                                        y: -4
                                        width: 16; height: 16; radius: 8
                                        color: root.outputMuted ? Theme.error : Theme.primary
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
                                            root.isAdjustingOutput = true
                                            root.localOutputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed) {
                                                root.localOutputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            }
                                        }
                                        onReleased: {
                                            root.setOutputVolume(root.localOutputVolume)
                                            root.isAdjustingOutput = false
                                        }

                                        onWheel: (wheel) => {
                                            let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                            root.localOutputVolume = Math.max(0, Math.min(1, root.localOutputVolume + delta))
                                            root.setOutputVolume(root.localOutputVolume)
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.4 }

                            // Input Volume Section
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS
                                opacity: root.source ? 1.0 : 0.5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 28; height: 28; radius: Theme.radiusM
                                        color: inMuteMa.containsMouse ? Theme.surfaceVariant : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.inputMuted ? "\uf131" : "\uf130"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: Theme.iconSizeM
                                            color: root.inputMuted ? Theme.error : Theme.secondary
                                        }

                                        MouseArea {
                                            id: inMuteMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleInputMute()
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            text: "输入音量"
                                            font.pixelSize: Theme.fontSizeM
                                            font.bold: true
                                            color: Theme.textPrimary
                                        }

                                        Text {
                                            text: root.source?.description ?? "无输入设备"
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.textMuted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        text: Math.round(root.localInputVolume * 100) + "%"
                                        font.pixelSize: Theme.fontSizeS
                                        color: root.inputMuted ? Theme.error : Theme.textMuted
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
                                        width: Math.min(1, root.localInputVolume) * parent.width
                                        height: parent.height
                                        radius: 4
                                        color: root.inputMuted ? Theme.error : Theme.secondary

                                        Behavior on width { NumberAnimation { duration: 50 } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }

                                    Rectangle {
                                        x: Math.max(0, Math.min(inputFill.width - width / 2, parent.width - width))
                                        y: -4
                                        width: 16; height: 16; radius: 8
                                        color: root.inputMuted ? Theme.error : Theme.secondary
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
                                            root.isAdjustingInput = true
                                            root.localInputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed) {
                                                root.localInputVolume = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            }
                                        }
                                        onReleased: {
                                            root.setInputVolume(root.localInputVolume)
                                            root.isAdjustingInput = false
                                        }

                                        onWheel: (wheel) => {
                                            let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                            root.localInputVolume = Math.max(0, Math.min(1, root.localInputVolume + delta))
                                            root.setInputVolume(root.localInputVolume)
                                        }
                                    }
                                }
                            }
                        }

                        // ============ Applications Tab ============
                        ColumnLayout {
                            spacing: Theme.spacingM

                            RowLayout {
                                spacing: Theme.spacingS

                                Text {
                                    text: "\uf259"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: Theme.tertiary
                                }

                                Text {
                                    text: "应用程序音量"
                                    font.pixelSize: Theme.fontSizeM
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.appStreams.length + " 个应用"
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.textMuted
                                }
                            }

                            // App streams list
                            Repeater {
                                model: root.appStreams

                                Rectangle {
                                    id: appBox
                                    required property PwNode modelData
                                    Layout.fillWidth: true
                                    height: appRow.implicitHeight + Theme.spacingM * 2
                                    radius: Theme.radiusM
                                    color: Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    // Track this node
                                    PwObjectTracker {
                                        objects: modelData ? [modelData] : []
                                    }

                                    property PwNodeAudio nodeAudio: modelData?.audio ?? null
                                    property real appVolume: nodeAudio?.volume ?? 0
                                    property bool appMuted: nodeAudio?.muted ?? false

                                    // Get app name
                                    readonly property string appName: {
                                        if (!modelData) return "Unknown"
                                        var props = modelData.properties || {}
                                        var name = props["application.name"] ||
                                                   props["media.name"] ||
                                                   modelData.description ||
                                                   modelData.name || "Unknown"
                                        return name
                                    }

                                    // Get app icon name for lookup
                                    readonly property string appIconName: {
                                        if (!modelData) return ""
                                        var props = modelData.properties || {}
                                        return props["application.icon-name"] ||
                                               props["application.name"]?.toLowerCase() ||
                                               modelData.name?.split("-")[0]?.toLowerCase() || ""
                                    }

                                    // Get Nerd Font icon based on app name
                                    readonly property string appNerdIcon: {
                                        var name = appIconName.toLowerCase()
                                        if (name.includes("firefox") || name.includes("floorp")) return "\uf269"
                                        if (name.includes("chrome") || name.includes("chromium")) return "\uf268"
                                        if (name.includes("brave")) return "\uf38a"
                                        if (name.includes("edge")) return "\uf282"
                                        if (name.includes("spotify")) return "\uf1bc"
                                        if (name.includes("discord")) return "\uf392"
                                        if (name.includes("telegram")) return "\uf2c6"
                                        if (name.includes("slack")) return "\uf198"
                                        if (name.includes("teams")) return "\uf871"
                                        if (name.includes("zoom")) return "\uf03d"
                                        if (name.includes("vlc")) return "\uf03d"
                                        if (name.includes("mpv")) return "\uf03d"
                                        if (name.includes("obs")) return "\uf03d"
                                        if (name.includes("steam")) return "\uf1b6"
                                        if (name.includes("lutris")) return "\uf11b"
                                        if (name.includes("wine") || name.includes(".exe")) return "\uf17a"
                                        if (name.includes("code") || name.includes("vscode")) return "\ue70c"
                                        if (name.includes("terminal") || name.includes("konsole") || name.includes("kitty") || name.includes("alacritty")) return "\uf120"
                                        if (name.includes("music") || name.includes("rhythmbox") || name.includes("clementine")) return "\uf001"
                                        if (name.includes("video") || name.includes("totem")) return "\uf03d"
                                        if (name.includes("pipewire") || name.includes("pulse") || name.includes("audio")) return "\uf028"
                                        if (name.includes("speech")) return "\uf130"
                                        if (name.includes("game") || name.includes("yuanshen") || name.includes("genshin")) return "\uf11b"
                                        return "\uf013"  // Default gear icon
                                    }

                                    RowLayout {
                                        id: appRow
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingM

                                        // App icon using Nerd Font
                                        Rectangle {
                                            width: 32; height: 32; radius: Theme.radiusS
                                            color: Theme.surfaceVariant

                                            Text {
                                                anchors.centerIn: parent
                                                text: appBox.appNerdIcon
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: Theme.iconSizeM
                                                color: Theme.tertiary
                                            }
                                        }

                                        // App name and volume slider
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingXS

                                            Text {
                                                text: appBox.appName
                                                font.pixelSize: Theme.fontSizeS
                                                font.bold: true
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingS

                                                Rectangle {
                                                    id: appSlider
                                                    Layout.fillWidth: true
                                                    height: 6
                                                    radius: 3
                                                    color: Theme.surfaceVariant

                                                    Rectangle {
                                                        id: appFill
                                                        width: Math.min(1, appBox.appVolume) * parent.width
                                                        height: parent.height
                                                        radius: 3
                                                        color: appBox.appMuted ? Theme.error : Theme.tertiary

                                                        Behavior on width { NumberAnimation { duration: 50 } }
                                                    }

                                                    Rectangle {
                                                        x: Math.max(0, Math.min(appFill.width - width / 2, parent.width - width))
                                                        y: -3
                                                        width: 12; height: 12; radius: 6
                                                        color: appBox.appMuted ? Theme.error : Theme.tertiary
                                                        border.color: Theme.surface
                                                        border.width: 2
                                                        scale: appMa.pressed ? 1.2 : (appMa.containsMouse ? 1.1 : 1.0)

                                                        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                                                    }

                                                    MouseArea {
                                                        id: appMa
                                                        anchors.fill: parent
                                                        anchors.margins: -6
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor

                                                        onPressed: (mouse) => {
                                                            if (appBox.nodeAudio) {
                                                                appBox.nodeAudio.volume = Math.max(0, Math.min(1, mouse.x / appSlider.width))
                                                            }
                                                        }
                                                        onPositionChanged: (mouse) => {
                                                            if (pressed && appBox.nodeAudio) {
                                                                appBox.nodeAudio.volume = Math.max(0, Math.min(1, mouse.x / appSlider.width))
                                                            }
                                                        }
                                                        onWheel: (wheel) => {
                                                            if (appBox.nodeAudio) {
                                                                let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                                                appBox.nodeAudio.volume = Math.max(0, Math.min(1, appBox.appVolume + delta))
                                                            }
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: Math.round(appBox.appVolume * 100) + "%"
                                                    font.pixelSize: Theme.fontSizeXS
                                                    color: appBox.appMuted ? Theme.error : Theme.textMuted
                                                    Layout.preferredWidth: 32
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                        }

                                        // Mute button
                                        Rectangle {
                                            width: 28; height: 28; radius: Theme.radiusM
                                            color: appMuteMa.containsMouse ? Theme.surfaceVariant : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: appBox.appMuted ? "\uf026" : "\uf028"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: Theme.iconSizeS
                                                color: appBox.appMuted ? Theme.error : Theme.textMuted
                                            }

                                            MouseArea {
                                                id: appMuteMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (appBox.nodeAudio) {
                                                        appBox.nodeAudio.muted = !appBox.appMuted
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty state
                            Text {
                                visible: root.appStreams.length === 0
                                text: "没有正在播放音频的应用"
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.spacingL
                            }
                        }

                        // ============ Devices Tab ============
                        ColumnLayout {
                            spacing: Theme.spacingL

                            // Output Devices
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                RowLayout {
                                    spacing: Theme.spacingS

                                    Text {
                                        text: "\uf028"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: Theme.iconSizeS
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: "输出设备"
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }
                                }

                                Repeater {
                                    model: root.sinks

                                    Rectangle {
                                        required property PwNode modelData
                                        Layout.fillWidth: true
                                        height: 40
                                        radius: Theme.radiusM
                                        color: modelData.id === root.sink?.id ? Theme.alpha(Theme.primary, 0.1) :
                                               sinkMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                        border.color: modelData.id === root.sink?.id ? Theme.primary : "transparent"
                                        border.width: modelData.id === root.sink?.id ? 1 : 0

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingS

                                            Text {
                                                text: modelData.id === root.sink?.id ? "\uf058" : "\uf111"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: modelData.id === root.sink?.id ? Theme.iconSizeS : 8
                                                color: modelData.id === root.sink?.id ? Theme.primary : Theme.textMuted
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.description || modelData.name || "Unknown"
                                                font.pixelSize: Theme.fontSizeS
                                                color: modelData.id === root.sink?.id ? Theme.textPrimary : Theme.textSecondary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: sinkMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefaultSink(modelData)
                                        }
                                    }
                                }

                                Text {
                                    visible: root.sinks.length === 0
                                    text: "未检测到输出设备"
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textMuted
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.4 }

                            // Input Devices
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                RowLayout {
                                    spacing: Theme.spacingS

                                    Text {
                                        text: "\uf130"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: Theme.iconSizeS
                                        color: Theme.secondary
                                    }

                                    Text {
                                        text: "输入设备"
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }
                                }

                                Repeater {
                                    model: root.sources

                                    Rectangle {
                                        required property PwNode modelData
                                        Layout.fillWidth: true
                                        height: 40
                                        radius: Theme.radiusM
                                        color: modelData.id === root.source?.id ? Theme.alpha(Theme.secondary, 0.1) :
                                               sourceMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                        border.color: modelData.id === root.source?.id ? Theme.secondary : "transparent"
                                        border.width: modelData.id === root.source?.id ? 1 : 0

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingS

                                            Text {
                                                text: modelData.id === root.source?.id ? "\uf058" : "\uf111"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: modelData.id === root.source?.id ? Theme.iconSizeS : 8
                                                color: modelData.id === root.source?.id ? Theme.secondary : Theme.textMuted
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.description || modelData.name || "Unknown"
                                                font.pixelSize: Theme.fontSizeS
                                                color: modelData.id === root.source?.id ? Theme.textPrimary : Theme.textSecondary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: sourceMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefaultSource(modelData)
                                        }
                                    }
                                }

                                Text {
                                    visible: root.sources.length === 0
                                    text: "未检测到输入设备"
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }

                    // Keyboard hints
                    Text {
                        Layout.fillWidth: true
                        text: "Esc 关闭 | 滚轮调节音量"
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
