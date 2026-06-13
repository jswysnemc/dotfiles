import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import "./BluetoothUtils.js" as BluetoothUtils
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

ShellRoot {
    id: root

    I18nContext {
        id: i18n
        catalog: "bluetooth"
    }

    readonly property var i18nContext: i18n

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: false

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

    /**
     * 关闭蓝牙弹窗窗口。
     *
     * @param 无
     * @returns 无
     */
    function closeWithAnimation() {
        // 1. 先关闭模糊区域，避免退出前全屏 layer 参与模糊
        root.blurActive = false
        // 2. 立即隐藏卡片并退出，保持与剪贴板一致
        root.panelOpacity = 0
        Qt.quit()
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
        if (dev.pairing) return i18n.trLiteral("配对中...")
        if (dev.state === BluetoothDeviceState.Connecting) return i18n.trLiteral("连接中...")
        if (dev.state === BluetoothDeviceState.Disconnecting) return i18n.trLiteral("断开中...")
        if (dev.blocked) return i18n.trLiteral("已阻止")
        if (dev.connected) return i18n.trLiteral("已连接")
        if (dev.paired || dev.trusted) return i18n.trLiteral("已配对")
        return i18n.trLiteral("可用")
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
            root.lastError = i18n.trLiteral("连接失败")
        }
    }

    function disconnectDevice(dev) {
        if (!dev) return
        try {
            dev.disconnect()
        } catch (e) {
            root.lastError = i18n.trLiteral("断开失败")
        }
    }

    function forgetDevice(dev) {
        if (!dev) return
        try {
            dev.trusted = false
            dev.forget()
        } catch (e) {
            root.lastError = i18n.trLiteral("忘记失败")
        }
    }

    function pairDevice(dev) {
        if (!dev) return
        var addr = deviceAddress(dev)
        if (!addr) {
            root.lastError = i18n.trLiteral("无法获取设备地址")
            return
        }
        setScanActive(false, 0)
        var intervalSec = Math.max(1, Math.round(connectRetryIntervalMs / 1000))
        try {
            Quickshell.execDetached(["bash", Quickshell.shellDir + "/bluetooth-connect.sh", String(addr), String(pairWaitSeconds), String(connectAttempts), String(intervalSec)])
        } catch (e) {
            root.lastError = i18n.trLiteral("配对失败")
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
    BluetoothView {
        controller: root
    }
}
