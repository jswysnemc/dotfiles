import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import "./BluetoothUtils.js" as BluetoothUtils
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15

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

    // ============ State ============
    property var adapter: Bluetooth.defaultAdapter
    property bool ctlPowered: false
    property bool ctlDiscovering: false
    property bool ctlDiscoverable: false

    readonly property bool btEnabled: adapter ? adapter.enabled : ctlPowered
    readonly property bool btScanning: ((adapter && adapter.discovering) ? true : (root.ctlDiscovering === true)) || scanStopTimer.running || fallbackScanProcess.running
    readonly property bool btDiscoverable: ctlDiscoverable

    property var btDevices: []
    property string expandedMac: ""
    property string lastError: ""

    property int pairWaitSeconds: 20
    property int connectAttempts: 5
    property int connectRetryIntervalMs: 2000

    Component.onCompleted: {
        refreshBluetooth()
        enterAnimation.start()
    }

    // ============ 入场动画 ============
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "panelOpacity"
            from: 0; to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "panelScale"
            from: 0.95; to: 1.0
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            target: root
            property: "panelY"
            from: 15; to: 0
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    // ============ 退场动画 ============
    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "panelOpacity"
            to: 0
            duration: 150
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "panelScale"
            to: 0.95
            duration: 150
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "panelY"
            to: -10
            duration: 150
            easing.type: Easing.InCubic
        }

        onFinished: Qt.quit()
    }

    function closeWithAnimation() {
        exitAnimation.start()
    }

    function refreshBluetooth() {
        btStatusProc.running = true
        refreshDevices()
    }

    function refreshDevices() {
        if (!adapter || !adapter.devices) {
            root.btDevices = []
            return
        }
        var list = adapter.devices.values.filter(d => d && !d.blocked)
        list = BluetoothUtils.dedupeDevices(list)
        root.btDevices = sortDevices(list)
    }

    function sortDevices(list) {
        var out = list.slice()
        out.sort((a, b) => {
            var aConnected = a.connected ? 1 : 0
            var bConnected = b.connected ? 1 : 0
            if (aConnected !== bConnected) return bConnected - aConnected
            var aPaired = (a.paired || a.trusted) ? 1 : 0
            var bPaired = (b.paired || b.trusted) ? 1 : 0
            if (aPaired !== bPaired) return bPaired - aPaired
            var aSignal = (a.signalStrength !== undefined && a.signalStrength > 0) ? a.signalStrength : 0
            var bSignal = (b.signalStrength !== undefined && b.signalStrength > 0) ? b.signalStrength : 0
            if (aSignal !== bSignal) return bSignal - aSignal
            return (displayName(a) || "").localeCompare(displayName(b) || "")
        })
        return out
    }

    function normalizeMac(value) {
        if (!value) return ""
        return value.toUpperCase().replace(/[^0-9A-F]/g, "")
    }

    function deviceAddress(dev) {
        return BluetoothUtils.macFromDevice(dev)
    }

    function displayName(dev) {
        if (!dev) return ""
        var name = (dev.name || dev.deviceName || "").trim()
        var addr = deviceAddress(dev)
        if (!name) return addr || ""
        var macNorm = normalizeMac(addr)
        var nameNorm = normalizeMac(name)
        if (macNorm && nameNorm && macNorm === nameNorm) return addr || name
        return name
    }

    function deviceIconLabel(dev) {
        var icon = BluetoothUtils.deviceIcon(dev ? (dev.name || dev.deviceName) : "", dev ? dev.icon : "")
        if (icon.indexOf("phone") !== -1) return "PH"
        if (icon.indexOf("headphones") !== -1) return "HP"
        if (icon.indexOf("earbuds") !== -1) return "EB"
        if (icon.indexOf("headset") !== -1) return "HS"
        if (icon.indexOf("speaker") !== -1) return "SP"
        if (icon.indexOf("keyboard") !== -1) return "KB"
        if (icon.indexOf("mouse") !== -1) return "MS"
        if (icon.indexOf("watch") !== -1) return "WT"
        if (icon.indexOf("tv") !== -1) return "TV"
        if (icon.indexOf("gamepad") !== -1) return "GP"
        if (icon.indexOf("microphone") !== -1) return "MC"
        return "BT"
    }

    function isDeviceBusy(dev) {
        if (!dev) return false
        return dev.pairing || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting
    }

    function canConnect(dev) {
        if (!dev) return false
        return !dev.connected && (dev.paired || dev.trusted) && !dev.pairing && !dev.blocked
    }

    function canDisconnect(dev) {
        if (!dev) return false
        return dev.connected && !dev.pairing && !dev.blocked
    }

    function canPair(dev) {
        if (!dev) return false
        return !dev.connected && !dev.paired && !dev.trusted && !dev.pairing && !dev.blocked
    }

    function getSignalPercent(dev) {
        return BluetoothUtils.signalPercent(dev, null, 0)
    }

    function getBatteryPercent(dev) {
        return BluetoothUtils.batteryPercent(dev)
    }

    function deviceStatusLabel(dev) {
        if (!dev) return ""
        if (dev.pairing) return "配对中..."
        if (dev.state === BluetoothDeviceState.Connecting) return "连接中..."
        if (dev.state === BluetoothDeviceState.Disconnecting) return "断开中..."
        if (dev.blocked) return "已阻止"
        if (dev.connected) return "已连接"
        if (dev.paired || dev.trusted) return "已配对"
        return "可用"
    }

    function connectDevice(dev) {
        if (!dev) return
        root.lastError = ""
        if (dev.connected) {
            disconnectDevice(dev)
            return
        }
        if (canPair(dev)) {
            pairDevice(dev)
            return
        }
        connectDeviceWithTrust(dev)
    }

    function connectDeviceWithTrust(dev) {
        if (!dev) return
        try {
            dev.trusted = true
            dev.connect()
        } catch (e) {
            root.lastError = "连接失败"
        }
    }

    function disconnectDevice(dev) {
        if (!dev) return
        try {
            dev.disconnect()
        } catch (e) {
            root.lastError = "断开失败"
        }
    }

    function forgetDevice(dev) {
        if (!dev) return
        try {
            dev.trusted = false
            dev.forget()
        } catch (e) {
            root.lastError = "忘记失败"
        }
    }

    function pairDevice(dev) {
        if (!dev) return
        var addr = deviceAddress(dev)
        if (!addr) {
            root.lastError = "无法获取设备地址"
            return
        }
        setScanActive(false, 0)
        var intervalSec = Math.max(1, Math.round(connectRetryIntervalMs / 1000))
        try {
            Quickshell.execDetached(["bash", Quickshell.shellDir + "/bluetooth-connect.sh", String(addr), String(pairWaitSeconds), String(connectAttempts), String(intervalSec)])
        } catch (e) {
            root.lastError = "配对失败"
        }
    }

    function setScanActive(active, durationMs) {
        var usedNative = false
        try {
            if (adapter && adapter.startDiscovery !== undefined) {
                if (active) adapter.startDiscovery()
                else adapter.stopDiscovery()
                usedNative = true
            }
        } catch (e) {}

        if (!usedNative) {
            if (active) {
                fallbackScanProcess.running = true
            } else {
                fallbackScanProcess.running = false
                scanOffProc.running = true
            }
        }

        if (active && durationMs && durationMs > 0) {
            scanStopTimer.interval = durationMs
            scanStopTimer.restart()
        } else {
            scanStopTimer.stop()
        }
        btStatusProc.running = true
    }

    function toggleScan() {
        if (!root.btEnabled) return
        setScanActive(!root.btScanning, 8000)
    }

    function toggleBluetooth(enable) {
        btPowerProc.enable = enable
        btPowerProc.command = ["bluetoothctl", "power", enable ? "on" : "off"]
        btPowerProc.running = true
    }

    function toggleDiscoverable(enable) {
        discoverableProc.enable = enable
        discoverableProc.command = ["bluetoothctl", "discoverable", enable ? "on" : "off"]
        discoverableProc.running = true
    }

    // ============ Bluetooth Processes ============
    Process {
        id: btStatusProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var enabled = root.ctlPowered
                var scanning = root.ctlDiscovering
                var discoverable = root.ctlDiscoverable
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.indexOf("Powered:") === 0) {
                        enabled = line.indexOf("yes") !== -1
                    } else if (line.indexOf("Discovering:") === 0) {
                        scanning = line.indexOf("yes") !== -1
                    } else if (line.indexOf("Discoverable:") === 0) {
                        discoverable = line.indexOf("yes") !== -1
                    }
                }
                root.ctlPowered = enabled
                root.ctlDiscovering = scanning
                root.ctlDiscoverable = discoverable
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) root.lastError = text.trim()
            }
        }
    }

    Process {
        id: btPowerProc
        property bool enable: true
        command: ["bluetoothctl", "power", enable ? "on" : "off"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ctlPowered = btPowerProc.enable
                refreshDevices()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) root.lastError = text.trim()
            }
        }
    }

    Process {
        id: discoverableProc
        property bool enable: true
        command: ["bluetoothctl", "discoverable", enable ? "on" : "off"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ctlDiscoverable = discoverableProc.enable
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) root.lastError = text.trim()
            }
        }
    }

    Process {
        id: scanOnProc
        command: ["bluetoothctl", "scan", "on"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ctlDiscovering = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) root.lastError = text.trim()
            }
        }
    }

    Process {
        id: fallbackScanProcess
        command: ["sh", "-c", "(echo 'scan on'; sleep 3600) | bluetoothctl"]
        onExited: {}
    }

    Process {
        id: scanOffProc
        command: ["bluetoothctl", "scan", "off"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ctlDiscovering = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) root.lastError = text.trim()
            }
        }
    }

    Timer {
        id: scanStopTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (root.btScanning) {
                setScanActive(false, 0)
            }
        }
    }

    Timer {
        id: deviceRefreshTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: refreshDevices()
    }

    Timer {
        id: statusRefreshTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: btStatusProc.running = true
    }

    // ============ UI ============
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-bt-bg"
            WlrLayershell.layer: WlrLayer.Top
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-bt"
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
            implicitWidth: 380
            implicitHeight: Math.min(720, panelRect.implicitHeight)


            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                color: Theme.background
                radius: Theme.radiusL
                border.color: Theme.outline
                border.width: 1
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                // 动画属性
                opacity: root.panelOpacity
                scale: root.panelScale
                transform: Translate { y: root.panelY }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text { text: "\uf293"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: root.btEnabled ? Theme.primary : Theme.textMuted }
                        Text { text: "蓝牙"; font.pixelSize: Theme.fontSizeL; font.weight: Font.Bold; color: Theme.textPrimary; Layout.fillWidth: true }

                        // Toggle
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: root.btEnabled ? Theme.primary : Theme.surfaceVariant

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.btEnabled ? parent.width - width - 3 : 3
                                color: Theme.textPrimary
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleBluetooth(!root.btEnabled) }
                        }

                        // Discoverable
                        Rectangle {
                            width: 48; height: 28; radius: Theme.radiusS
                            color: root.btDiscoverable ? Theme.alpha(Theme.primary, 0.2) : "transparent"
                            border.color: root.btDiscoverable ? Theme.primary : Theme.outline
                            scale: discoverMa.pressed ? 0.95 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text { anchors.centerIn: parent; text: "可见"; font.pixelSize: Theme.fontSizeXS; color: root.btDiscoverable ? Theme.primary : Theme.textSecondary }
                            MouseArea { id: discoverMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: root.btEnabled; onClicked: root.toggleDiscoverable(!root.btDiscoverable) }
                        }

                        // Scan
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: scanMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: scanMa.pressed ? 0.9 : (scanMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent; text: "\uf021"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: Theme.textSecondary
                                RotationAnimation on rotation { running: root.btScanning; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                            }
                            MouseArea { id: scanMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.btEnabled; onClicked: root.toggleScan() }
                        }

                        // Close
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: closeMa.pressed ? 0.9 : (closeMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: Theme.textSecondary }
                            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeWithAnimation() }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // Item height: ~70px per item (including spacing)
                    property int btItemHeight: 70
                    property int btMaxVisibleItems: 7

                    ScrollView {
                        id: btScroll
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(parent.btMaxVisibleItems * parent.btItemHeight, btContent.implicitHeight)
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        contentWidth: availableWidth

                        ColumnLayout {
                            id: btContent
                            width: btScroll.availableWidth
                            spacing: Theme.spacingM

                            // Disabled state
                            Rectangle {
                                visible: !root.btEnabled
                                Layout.fillWidth: true; height: 120; color: "transparent"
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: Theme.spacingM
                                    Text { text: "\uf293"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 48; color: Theme.textMuted; opacity: 0.5; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "蓝牙已关闭"; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                                }
                            }

                            // Error banner
                            Rectangle {
                                visible: root.lastError !== ""
                                Layout.fillWidth: true
                                radius: Theme.radiusM
                                color: Theme.alpha(Theme.error, 0.12)
                                border.color: Theme.error
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    Text {
                                        text: root.lastError
                                        font.pixelSize: Theme.fontSizeS
                                        color: Theme.error
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        color: closeErrMa.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                        Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 10; color: Theme.error }
                                        MouseArea {
                                            id: closeErrMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.lastError = ""
                                        }
                                    }
                                }
                            }

                            // Connected devices
                            ColumnLayout {
                                visible: root.btEnabled && root.btDevices.some(d => d.connected)
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: "已连接"; font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Repeater {
                                    model: root.btDevices.filter(d => d.connected)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: connColumn.implicitHeight + Theme.spacingM * 2
                                        radius: Theme.radiusM
                                        color: connHover.hovered ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.primary
                                        border.width: 1
                                        readonly property bool isBusy: root.isDeviceBusy(modelData)

                                        HoverHandler { id: connHover }

                                        ColumnLayout {
                                            id: connColumn
                                            width: parent.width - Theme.spacingM * 2
                                            x: Theme.spacingM
                                            y: Theme.spacingM
                                            spacing: Theme.spacingS

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingM

                                                Rectangle {
                                                    width: 36; height: 36; radius: Theme.radiusS
                                                    Layout.alignment: Qt.AlignVCenter
                                                    color: Theme.alpha(Theme.primary, 0.12)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root.deviceIconLabel(modelData)
                                                        font.pixelSize: Theme.fontSizeS
                                                        font.weight: Font.DemiBold
                                                        color: Theme.primary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: Theme.spacingS
                                                        Text {
                                                            Layout.fillWidth: true
                                                            Layout.minimumWidth: 0
                                                            text: root.displayName(modelData)
                                                            font.pixelSize: Theme.fontSizeM
                                                            font.weight: Font.Bold
                                                            color: Theme.textPrimary
                                                            elide: Text.ElideRight
                                                        }
                                                        Rectangle {
                                                            width: 40; height: 16
                                                            radius: Theme.radiusPill
                                                            color: Theme.alpha(Theme.success, 0.2)
                                                            Text { anchors.centerIn: parent; text: "已连接"; font.pixelSize: Theme.fontSizeXS; color: Theme.success }
                                                        }
                                                        Rectangle {
                                                            visible: isBusy
                                                            width: 50; height: 16
                                                            radius: Theme.radiusPill
                                                            color: Theme.alpha(Theme.warning, 0.2)
                                                            Text { anchors.centerIn: parent; text: "处理中..."; font.pixelSize: Theme.fontSizeXS; color: Theme.warning }
                                                        }
                                                    }

                                                    Text { text: root.deviceAddress(modelData) || ""; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: infoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                        border.color: Theme.primary; border.width: 1
                                                        Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                        MouseArea {
                                                            id: infoMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.expandedMac = (root.expandedMac === root.deviceAddress(modelData)) ? "" : root.deviceAddress(modelData)
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 70; height: 28
                                                        radius: Theme.radiusS
                                                        color: discMa.containsMouse ? Theme.alpha(Theme.error, 0.3) : Theme.alpha(Theme.error, 0.15)
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: "断开"; font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: discMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.disconnectDevice(modelData) }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: forgetMa.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: "忘记"; font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: forgetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.forgetDevice(modelData) }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: root.expandedMac === root.deviceAddress(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: infoCol.implicitHeight + Theme.spacingM * 2
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                border.color: Theme.outline
                                                border.width: 1

                                                ColumnLayout {
                                                    id: infoCol
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    spacing: Theme.spacingS

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "地址"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: root.deviceAddress(modelData) || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "配对"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.paired ? "是" : "否"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "可信"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.trusted ? "是" : "否"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "信号"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var p = root.getSignalPercent(modelData)
                                                                return p === null ? "-" : (p + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "电量"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var b = root.getBatteryPercent(modelData)
                                                                return b === null ? "-" : (b + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Paired devices
                            ColumnLayout {
                                visible: root.btEnabled && root.btDevices.some(d => !d.connected && (d.paired || d.trusted))
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: "已配对"; font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Repeater {
                                    model: root.btDevices.filter(d => !d.connected && (d.paired || d.trusted))

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: pairColumn.implicitHeight + Theme.spacingM * 2
                                        radius: Theme.radiusM
                                        color: pairHover.hovered ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.outline
                                        border.width: 1
                                        readonly property bool isBusy: root.isDeviceBusy(modelData)

                                        HoverHandler { id: pairHover }

                                        ColumnLayout {
                                            id: pairColumn
                                            width: parent.width - Theme.spacingM * 2
                                            x: Theme.spacingM
                                            y: Theme.spacingM
                                            spacing: Theme.spacingS

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingM

                                                Rectangle {
                                                    width: 36; height: 36; radius: Theme.radiusS
                                                    Layout.alignment: Qt.AlignVCenter
                                                    color: Theme.surfaceVariant
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root.deviceIconLabel(modelData)
                                                        font.pixelSize: Theme.fontSizeS
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textSecondary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        text: root.displayName(modelData)
                                                        font.pixelSize: Theme.fontSizeM
                                                        font.weight: Font.Medium
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }
                                                    Text { text: root.deviceStatusLabel(modelData) + " · " + (root.deviceAddress(modelData) || ""); font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: pairInfoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                        border.color: Theme.primary; border.width: 1
                                                        Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                        MouseArea {
                                                            id: pairInfoMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.expandedMac = (root.expandedMac === root.deviceAddress(modelData)) ? "" : root.deviceAddress(modelData)
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: connMa.containsMouse ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha(Theme.primary, 0.15)
                                                        border.color: Theme.primary
                                                        Text { anchors.centerIn: parent; text: "连接"; font.pixelSize: Theme.fontSizeXS; color: Theme.primary }
                                                        MouseArea { id: connMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.connectDevice(modelData) }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: forget2Ma.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: "忘记"; font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: forget2Ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.forgetDevice(modelData) }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: root.expandedMac === root.deviceAddress(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: infoColPaired.implicitHeight + Theme.spacingM * 2
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                border.color: Theme.outline
                                                border.width: 1

                                                ColumnLayout {
                                                    id: infoColPaired
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    spacing: Theme.spacingS

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "地址"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: root.deviceAddress(modelData) || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "配对"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.paired ? "是" : "否"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "可信"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.trusted ? "是" : "否"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "信号"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var p2 = root.getSignalPercent(modelData)
                                                                return p2 === null ? "-" : (p2 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "电量"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var b2 = root.getBatteryPercent(modelData)
                                                                return b2 === null ? "-" : (b2 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Available devices
                            ColumnLayout {
                                visible: root.btEnabled && root.btDevices.some(d => !d.connected && !d.paired && !d.trusted)
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: "可用设备"; font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Repeater {
                                    model: root.btDevices.filter(d => !d.connected && !d.paired && !d.trusted)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: availColumn.implicitHeight + Theme.spacingM * 2
                                        radius: Theme.radiusM
                                        color: availHover.hovered ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.outline
                                        border.width: 1
                                        readonly property bool isBusy: root.isDeviceBusy(modelData)

                                        HoverHandler { id: availHover }

                                        ColumnLayout {
                                            id: availColumn
                                            width: parent.width - Theme.spacingM * 2
                                            x: Theme.spacingM
                                            y: Theme.spacingM
                                            spacing: Theme.spacingS

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingM

                                                Rectangle {
                                                    width: 36; height: 36; radius: Theme.radiusS
                                                    Layout.alignment: Qt.AlignVCenter
                                                    color: Theme.surfaceVariant
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root.deviceIconLabel(modelData)
                                                        font.pixelSize: Theme.fontSizeS
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textSecondary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        text: root.displayName(modelData)
                                                        font.pixelSize: Theme.fontSizeM
                                                        font.weight: Font.Medium
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }
                                                    Text { text: root.deviceAddress(modelData) || ""; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: availInfoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                        border.color: Theme.primary; border.width: 1
                                                        Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                        MouseArea {
                                                            id: availInfoMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.expandedMac = (root.expandedMac === root.deviceAddress(modelData)) ? "" : root.deviceAddress(modelData)
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: pairMa.containsMouse ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha(Theme.primary, 0.15)
                                                        border.color: Theme.primary
                                                        Text { anchors.centerIn: parent; text: "配对"; font.pixelSize: Theme.fontSizeXS; color: Theme.primary }
                                                        MouseArea { id: pairMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pairDevice(modelData) }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: root.expandedMac === root.deviceAddress(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: infoColAvail.implicitHeight + Theme.spacingM * 2
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                border.color: Theme.outline
                                                border.width: 1

                                                ColumnLayout {
                                                    id: infoColAvail
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    spacing: Theme.spacingS

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "地址"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: root.deviceAddress(modelData) || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "配对"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.paired ? "是" : "否"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "可信"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.trusted ? "是" : "否"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "信号"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var p3 = root.getSignalPercent(modelData)
                                                                return p3 === null ? "-" : (p3 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: "电量"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var b3 = root.getBatteryPercent(modelData)
                                                                return b3 === null ? "-" : (b3 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty state
                            Rectangle {
                                visible: root.btEnabled && root.btDevices.length === 0
                                Layout.fillWidth: true; height: 120; color: "transparent"
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: Theme.spacingM
                                    Text { text: "\uf293"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.textMuted; opacity: 0.5; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "未发现设备"; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                                    Text { text: "点击刷新开始扫描"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                                }
                            }

                            // Scanning indicator
                            Rectangle {
                                visible: root.btEnabled && root.btScanning && root.btDevices.length === 0
                                Layout.fillWidth: true; height: 120; color: "transparent"
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: Theme.spacingM
                                    Text {
                                        text: "\uf110"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 24
                                        color: Theme.primary
                                        Layout.alignment: Qt.AlignHCenter
                                        RotationAnimation on rotation { running: true; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                                    }
                                    Text { text: "正在扫描..."; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
