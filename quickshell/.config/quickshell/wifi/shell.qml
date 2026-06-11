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
        catalog: "wifi"
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

    // Parse position string to anchors
    property bool anchorTop: posEnv.indexOf("top") !== -1 || posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    // ============ State ============
    property int currentTab: 0  // 0 = WiFi, 1 = Ethernet

    // WiFi state
    property bool wifiEnabled: true
    property bool wifiScanning: false
    property var wifiNetworks: []
    property string connectedNetwork: ""
    property string connectingTo: ""
    property string lastError: ""

    // Dialogs
    property bool showPasswordDialog: false
    property bool passwordVisible: false
    property string passwordDialogSsid: ""
    property string passwordDialogSecurity: ""

    property bool showInfoDialog: false
    property var infoDialogData: null

    // Ethernet state
    property bool ethernetConnected: false
    property var ethernetDetails: ({})

    // Cache
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/wifi/cache.json"
    property bool cacheLoaded: false

    function loadCache() {
        loadCacheProc.running = true
    }

    function saveCache() {
        var cache = JSON.stringify({
            wifiEnabled: wifiEnabled,
            wifiNetworks: wifiNetworks,
            connectedNetwork: connectedNetwork,
            ethernetConnected: ethernetConnected,
            ethernetDetails: ethernetDetails,
            timestamp: Date.now()
        })
        saveCacheProc.command = ["bash", "-c", "mkdir -p \"$(dirname '" + cachePath + "')\" && cat > '" + cachePath + "' << 'EOFCACHE'\n" + cache + "\nEOFCACHE"]
        saveCacheProc.running = true
    }

    Process {
        id: loadCacheProc
        command: ["cat", root.cachePath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        var cache = JSON.parse(text)
                        // Load cached data immediately
                        root.wifiEnabled = cache.wifiEnabled !== undefined ? cache.wifiEnabled : true
                        root.wifiNetworks = cache.wifiNetworks || []
                        root.connectedNetwork = cache.connectedNetwork || ""
                        root.ethernetConnected = cache.ethernetConnected || false
                        root.ethernetDetails = cache.ethernetDetails || {}
                        // Get known networks list
                        if (root.wifiNetworks.length > 0) {
                            getKnownNetworks.running = true
                        }
                    } catch (e) {}
                }
                root.cacheLoaded = true
                // Start background refresh
                checkWifiStatus.running = true
                checkEthernetStatus.running = true
            }
        }
        onExited: (code, status) => {
            if (!root.cacheLoaded) {
                root.cacheLoaded = true
                checkWifiStatus.running = true
                checkEthernetStatus.running = true
            }
        }
    }

    Process {
        id: saveCacheProc
        command: ["echo"]
    }

    Component.onCompleted: {
        loadCache()
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
     * 关闭无线网络弹窗窗口。
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

    // ============ WiFi Processes ============
    Process {
        id: checkWifiStatus
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled"
                if (root.wifiEnabled) scanWifi.running = true
            }
        }
    }

    Process {
        id: scanWifi
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list", "--rescan", "yes"]
        environment: ({ "LC_ALL": "C" })
        onStarted: root.wifiScanning = true
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiScanning = false
                parseWifiNetworks(text)
            }
        }
        onExited: (code, status) => { root.wifiScanning = false }
    }

    Process {
        id: getKnownNetworks
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        environment: ({ "LC_ALL": "C" })
        property var knownList: []
        stdout: StdioCollector {
            onStreamFinished: {
                var known = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    if (parts.length >= 2 && parts[1] === "802-11-wireless") {
                        known.push(parts[0])
                    }
                }
                getKnownNetworks.knownList = known
                // Re-parse networks with known status
                if (root.wifiNetworks.length > 0) {
                    root.wifiNetworks = root.wifiNetworks.map(n => ({
                        ssid: n.ssid,
                        signal: n.signal,
                        security: n.security,
                        connected: n.connected,
                        known: known.indexOf(n.ssid) >= 0
                    }))
                }
            }
        }
    }

    Process {
        id: toggleWifiProc
        property bool enable: true
        command: ["nmcli", "radio", "wifi", enable ? "on" : "off"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = toggleWifiProc.enable
                if (toggleWifiProc.enable) {
                    scanWifi.running = true
                } else {
                    root.wifiNetworks = []
                }
            }
        }
    }

    function toggleWifi(enable) {
        toggleWifiProc.enable = enable
        toggleWifiProc.command = ["nmcli", "radio", "wifi", enable ? "on" : "off"]
        toggleWifiProc.running = true
    }

    Process {
        id: connectWifiProc
        command: ["echo"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                handleConnectOutput(text)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                handleConnectOutput(text)
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.connectingTo !== "" && root.lastError === "") {
                root.lastError = i18n.trLiteral("连接失败")
            }
            root.connectingTo = ""
            scanWifi.running = true
        }
    }

    function connectToWifi(ssid, password) {
        root.connectingTo = ssid
        root.passwordDialogSsid = ssid
        root.lastError = ""
        if (password && password !== "") {
            connectWifiProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        } else {
            connectWifiProc.command = ["nmcli", "device", "wifi", "connect", ssid]
        }
        connectWifiProc.running = true
    }

    function handleConnectOutput(output) {
        var text = (output || "").trim()
        if (!text) return
        if (text.indexOf("successfully activated") !== -1 || text.indexOf("Connection successfully") !== -1) {
            root.connectingTo = ""
            root.lastError = ""
            scanWifi.running = true
            getKnownNetworks.running = true
            return
        }
        if (text.indexOf("Secrets were required") !== -1 || text.indexOf("no secrets provided") !== -1) {
            // Need password - show dialog
            root.connectingTo = ""
            root.lastError = ""
            root.showPasswordDialog = true
            return
        }
        root.connectingTo = ""
        root.lastError = text || i18n.trLiteral("连接失败")
        scanWifi.running = true
    }

    Process {
        id: disconnectWifiProc
        command: ["echo"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                scanWifi.running = true
            }
        }
    }

    function disconnectWifi(ssid) {
        disconnectWifiProc.command = ["nmcli", "connection", "down", "id", ssid]
        disconnectWifiProc.running = true
    }

    Process {
        id: forgetWifiProc
        command: ["echo"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                scanWifi.running = true
                getKnownNetworks.running = true
            }
        }
    }

    function forgetWifi(ssid) {
        forgetWifiProc.command = ["nmcli", "connection", "delete", "id", ssid]
        forgetWifiProc.running = true
    }

    Process {
        id: findWifiDevice
        property string ssid: ""
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                var ifname = ""
                var fallback = ""
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(":")
                    if (parts.length < 4) continue
                    var dev = parts[0]
                    var type = parts[1]
                    var state = parts[2]
                    var conn = parts[3]
                    if (type !== "wifi" || state !== "connected") continue
                    if (!fallback) fallback = dev
                    if (conn === findWifiDevice.ssid) {
                        ifname = dev
                        break
                    }
                }
                if (!ifname) ifname = fallback
                if (!ifname) {
                    root.lastError = i18n.trLiteral("未找到已连接的 Wi-Fi 设备")
                    return
                }
                getWifiDetails.ifname = ifname
                getWifiDetails.ssid = findWifiDevice.ssid
                getWifiDetails.running = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    root.lastError = text.trim()
                }
            }
        }
    }

    Process {
        id: getWifiDetails
        property string ssid: ""
        property string ifname: ""
        command: ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", ifname]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                var details = { ssid: getWifiDetails.ssid, device: getWifiDetails.ifname }
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var idx = line.indexOf(":")
                    if (idx === -1) continue
                    var key = line.substring(0, idx)
                    var val = line.substring(idx + 1)
                    if (key.indexOf("IP4.ADDRESS") === 0) details.ip = val.split("/")[0]
                    else if (key === "IP4.GATEWAY") details.gateway = val
                    else if (key.indexOf("IP4.DNS") === 0) details.dns = val
                }
                // Get more details via iw
                getWifiLinkDetails.ifname = details.device || "wlan0"
                getWifiLinkDetails.details = details
                getWifiLinkDetails.running = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    root.lastError = text.trim()
                }
            }
        }
    }

    Process {
        id: getWifiLinkDetails
        property string ifname: "wlan0"
        property var details: ({})
        command: ["sh", "-c", "iw dev '" + ifname + "' link 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = getWifiLinkDetails.details
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim().toLowerCase()
                    if (line.indexOf("tx bitrate:") === 0) {
                        d.speed = lines[i].trim().substring(11).trim().split(" ").slice(0, 2).join(" ")
                    } else if (line.indexOf("freq:") === 0) {
                        var freq = parseInt(lines[i].trim().substring(5))
                        if (freq >= 5925) d.band = "6 GHz"
                        else if (freq >= 5150) d.band = "5 GHz"
                        else if (freq >= 2400) d.band = "2.4 GHz"
                    } else if (line.indexOf("signal:") === 0) {
                        d.signalDbm = lines[i].trim().substring(7).trim()
                    }
                }
                // Find security from networks list
                var net = root.wifiNetworks.find(n => n.ssid === d.ssid)
                if (net) {
                    d.security = net.security
                    d.signal = net.signal
                }
                root.infoDialogData = d
                root.showInfoDialog = true
            }
        }
    }

    function showNetworkInfo(ssid) {
        findWifiDevice.ssid = ssid
        findWifiDevice.running = true
    }

    function parseWifiNetworks(output) {
        var lines = output.trim().split("\n")
        var nets = []
        var seen = {}
        root.connectedNetwork = ""
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(":")
            if (parts.length >= 4 && parts[0] !== "") {
                var ssid = parts[0]
                if (seen[ssid]) continue
                seen[ssid] = true
                var isConnected = parts[3] === "*"
                var known = getKnownNetworks.knownList.indexOf(ssid) >= 0
                nets.push({
                    ssid: ssid,
                    signal: parseInt(parts[1]) || 0,
                    security: parts[2] || "",
                    connected: isConnected,
                    known: known || isConnected
                })
                if (isConnected) root.connectedNetwork = ssid
            }
        }
        nets.sort((a, b) => {
            if (a.connected !== b.connected) return b.connected - a.connected
            if (a.known !== b.known) return b.known - a.known
            return b.signal - a.signal
        })
        root.wifiNetworks = nets
        // Get known networks list
        getKnownNetworks.running = true
        // Save to cache
        root.saveCache()
    }

    // ============ Ethernet Processes ============
    Process {
        id: checkEthernetStatus
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                var connected = false
                var ifname = ""
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    if (parts.length >= 3 && parts[1] === "ethernet" && parts[2] === "connected") {
                        connected = true
                        ifname = parts[0]
                        break
                    }
                }
                root.ethernetConnected = connected
                if (connected) {
                    getEthernetDetails.ifname = ifname
                    getEthernetDetails.running = true
                }
            }
        }
    }

    Process {
        id: getEthernetDetails
        property string ifname: ""
        command: ["nmcli", "-t", "-f", "GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", ifname]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                var details = { ifname: getEthernetDetails.ifname }
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var idx = line.indexOf(":")
                    if (idx === -1) continue
                    var key = line.substring(0, idx)
                    var val = line.substring(idx + 1)
                    if (key === "GENERAL.CONNECTION") details.name = val
                    else if (key.indexOf("IP4.ADDRESS") === 0) details.ip = val.split("/")[0]
                    else if (key === "IP4.GATEWAY") details.gateway = val
                    else if (key.indexOf("IP4.DNS") === 0) details.dns = val
                }
                root.ethernetDetails = details
                root.saveCache()
            }
        }
    }

    // ============ UI ============
    WifiView {
        controller: root
    }
}
