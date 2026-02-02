import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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

    function closeWithAnimation() {
        exitAnimation.start()
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
                root.lastError = "连接失败"
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
        root.lastError = text || "连接失败"
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
                    root.lastError = "未找到已连接的 Wi-Fi 设备"
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
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-wifi-bg"
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
            WlrLayershell.namespace: "quickshell-wifi"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.showPasswordDialog ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
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


            Shortcut { sequence: "Escape"; onActivated: { root.showPasswordDialog = false; root.showInfoDialog = false; root.closeWithAnimation() } }

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

                        Text { text: "\uf1eb"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: root.wifiEnabled ? Theme.primary : Theme.textMuted }
                        Text { text: "Wi-Fi"; font.pixelSize: Theme.fontSizeL; font.weight: Font.Bold; color: Theme.textPrimary; Layout.fillWidth: true }

                        // Toggle
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: root.wifiEnabled ? Theme.primary : Theme.surfaceVariant

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.wifiEnabled ? parent.width - width - 3 : 3
                                color: Theme.textPrimary
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleWifi(!root.wifiEnabled) }
                        }

                        // Refresh
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: refreshMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: refreshMa.pressed ? 0.9 : (refreshMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent; text: "\uf021"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: Theme.textSecondary
                                RotationAnimation on rotation { running: root.wifiScanning; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                            }
                            MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.wifiEnabled && !root.wifiScanning; onClicked: scanWifi.running = true }
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

                    // Tab bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Repeater {
                            model: [{ icon: "\uf1eb", label: "Wi-Fi", idx: 0 }, { icon: "\uf6ff", label: "以太网", idx: 1 }]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: Theme.radiusM
                                color: root.currentTab === modelData.idx ? Theme.primary : Theme.surface
                                border.color: root.currentTab === modelData.idx ? Theme.primary : Theme.outline
                                scale: tabMa.pressed ? 0.97 : 1.0

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeM
                                    font.weight: root.currentTab === modelData.idx ? Font.Bold : Font.Medium
                                    color: root.currentTab === modelData.idx ? Theme.background : Theme.textSecondary

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea { id: tabMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = modelData.idx }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // Content
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.currentTab

                        // ===== WiFi Tab =====
                        // Item height: 56px + spacing 10px = 66px per item
                        property int itemHeight: 66
                        property int maxVisibleItems: 7

                        ScrollView {
                            id: wifiScroll
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(parent.maxVisibleItems * parent.itemHeight, wifiContent.implicitHeight)
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            contentWidth: availableWidth

                            ColumnLayout {
                                id: wifiContent
                                width: wifiScroll.availableWidth
                                spacing: Theme.spacingM

                                // Disabled state
                                Rectangle {
                                    visible: !root.wifiEnabled
                                    Layout.fillWidth: true; height: 120; color: "transparent"
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: Theme.spacingM
                                        Text { text: "\uf1eb"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 48; color: Theme.textMuted; opacity: 0.5; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "Wi-Fi 已关闭"; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
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

                                // Known Networks Section
                                ColumnLayout {
                                    visible: root.wifiEnabled && root.wifiNetworks.some(n => n.known)
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    Text { text: "已知网络"; font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                    Repeater {
                                        model: root.wifiEnabled ? root.wifiNetworks.filter(n => n.known) : []

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 56
                                            radius: Theme.radiusM
                                            color: knownHover.hovered ? Theme.surfaceVariant : Theme.surface
                                            border.color: modelData.connected ? Theme.primary : Theme.outline
                                            border.width: 1

                                            HoverHandler {
                                                id: knownHover
                                            }

                                            ColumnLayout {
                                                id: knownColumn
                                                width: parent.width - Theme.spacingM * 2
                                                x: Theme.spacingM
                                                y: Theme.spacingM
                                                spacing: Theme.spacingS

                                                RowLayout {
                                                    id: knownRow
                                                    Layout.fillWidth: true
                                                    spacing: Theme.spacingM

                                                    // WiFi icon - left side
                                                    Rectangle {
                                                        id: knownIconBg
                                                        width: 36; height: 36; radius: Theme.radiusS
                                                        Layout.alignment: Qt.AlignVCenter
                                                        color: modelData.connected ? Theme.alpha(Theme.primary, 0.15) : Theme.surfaceVariant
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf1eb"
                                                            font.family: "Symbols Nerd Font Mono"
                                                            font.pixelSize: Theme.iconSizeM
                                                            color: modelData.connected ? Theme.primary : Theme.textSecondary
                                                        }
                                                    }

                                                    // Network info
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
                                                                text: modelData.ssid
                                                                font.pixelSize: Theme.fontSizeM
                                                                font.weight: modelData.connected ? Font.Bold : Font.Medium
                                                                color: Theme.textPrimary
                                                                elide: Text.ElideRight
                                                            }
                                                            Rectangle {
                                                                visible: modelData.connected
                                                                width: 40; height: 16
                                                                radius: Theme.radiusPill
                                                                color: Theme.alpha(Theme.success, 0.2)
                                                                Text { anchors.centerIn: parent; text: "已连接"; font.pixelSize: Theme.fontSizeXS; color: Theme.success }
                                                            }
                                                            Rectangle {
                                                                visible: root.connectingTo === modelData.ssid
                                                                width: 50; height: 16
                                                                radius: Theme.radiusPill
                                                                color: Theme.alpha(Theme.warning, 0.2)
                                                                Text { anchors.centerIn: parent; text: "连接中..."; font.pixelSize: Theme.fontSizeXS; color: Theme.warning }
                                                            }
                                                        }

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: Theme.spacingXS
                                                            Text {
                                                                visible: modelData.security && modelData.security !== ""
                                                                text: "\uf023"
                                                                font.family: "Symbols Nerd Font Mono"
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                Layout.minimumWidth: 0
                                                                text: modelData.security || "开放"
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }

                                                    // Buttons - right side
                                                    RowLayout {
                                                        id: knownBtnRow
                                                        Layout.alignment: Qt.AlignVCenter
                                                        spacing: Theme.spacingS

                                                        // Info button (connected only)
                                                        Rectangle {
                                                            visible: modelData.connected
                                                            width: 28; height: 28; radius: 14
                                                            color: knInfoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                            border.color: Theme.primary; border.width: 1
                                                            Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                            MouseArea { id: knInfoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showNetworkInfo(modelData.ssid) }
                                                        }

                                                    // Connect button (not connected, known, on hover)
                                                    Rectangle {
                                                        visible: !modelData.connected && root.connectingTo !== modelData.ssid && knownHover.hovered
                                                        width: 28; height: 28; radius: Theme.radiusS
                                                        color: knConnMa.containsMouse ? Theme.alpha(Theme.primary, 0.8) : Theme.primary
                                                        Text { anchors.centerIn: parent; text: "\uf061"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeS; color: Theme.background }
                                                        MouseArea { id: knConnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.connectToWifi(modelData.ssid, "") }
                                                    }

                                                    // Forget button (known, not connected, on hover)
                                                    Rectangle {
                                                        visible: !modelData.connected && root.connectingTo !== modelData.ssid && knownHover.hovered
                                                        width: 44; height: 28; radius: Theme.radiusS
                                                        color: knForgetMa.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: "忘记"; font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: knForgetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.forgetWifi(modelData.ssid) }
                                                    }

                                                    // Disconnect button (connected only)
                                                    Rectangle {
                                                        visible: modelData.connected
                                                        width: 70; height: 28
                                                        radius: Theme.radiusS
                                                            color: knDiscMa.containsMouse ? Theme.alpha(Theme.error, 0.3) : Theme.alpha(Theme.error, 0.15)
                                                            border.color: Theme.error
                                                            Text { anchors.centerIn: parent; text: "断开连接"; font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                            MouseArea { id: knDiscMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.disconnectWifi(modelData.ssid) }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Available Networks Section
                                ColumnLayout {
                                    visible: root.wifiEnabled && root.wifiNetworks.some(n => !n.known)
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    Text { text: "可用网络"; font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                    Repeater {
                                        model: root.wifiEnabled ? root.wifiNetworks.filter(n => !n.known) : []

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 56
                                            radius: Theme.radiusM
                                            color: availHover.hovered ? Theme.surfaceVariant : Theme.surface
                                            border.color: root.connectingTo === modelData.ssid ? Theme.warning : Theme.outline
                                            border.width: 1

                                            HoverHandler {
                                                id: availHover
                                            }

                                            ColumnLayout {
                                                id: availColumn
                                                width: parent.width - Theme.spacingM * 2
                                                x: Theme.spacingM
                                                y: Theme.spacingM
                                                spacing: Theme.spacingS

                                                RowLayout {
                                                    id: availRow
                                                    Layout.fillWidth: true
                                                    spacing: Theme.spacingM

                                                    // WiFi icon - left side
                                                    Rectangle {
                                                        id: availIconBg
                                                        width: 36; height: 36; radius: Theme.radiusS
                                                        Layout.alignment: Qt.AlignVCenter
                                                        color: Theme.surfaceVariant
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf1eb"
                                                            font.family: "Symbols Nerd Font Mono"
                                                            font.pixelSize: Theme.iconSizeM
                                                            color: Theme.textSecondary
                                                            opacity: Math.max(0.5, modelData.signal / 100)
                                                        }
                                                    }

                                                    // Network info
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
                                                                text: modelData.ssid
                                                                font.pixelSize: Theme.fontSizeM
                                                                font.weight: Font.Medium
                                                                color: Theme.textPrimary
                                                                elide: Text.ElideRight
                                                            }
                                                            Rectangle {
                                                                visible: root.connectingTo === modelData.ssid
                                                                width: 50; height: 16
                                                                radius: Theme.radiusPill
                                                                color: Theme.alpha(Theme.warning, 0.2)
                                                                Text { anchors.centerIn: parent; text: "连接中..."; font.pixelSize: Theme.fontSizeXS; color: Theme.warning }
                                                            }
                                                        }

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: Theme.spacingXS
                                                            Text {
                                                                visible: modelData.security && modelData.security !== ""
                                                                text: "\uf023"
                                                                font.family: "Symbols Nerd Font Mono"
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                Layout.minimumWidth: 0
                                                                text: modelData.security || "开放"
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }

                                                    // Button - right side
                                                    Rectangle {
                                                        id: availBtn
                                                        visible: root.connectingTo !== modelData.ssid
                                                        Layout.alignment: Qt.AlignVCenter
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: avPwdMa.containsMouse ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha(Theme.primary, 0.15)
                                                        border.color: Theme.primary
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "连接"
                                                            font.pixelSize: Theme.fontSizeXS
                                                            color: Theme.primary
                                                        }
                                                        MouseArea {
                                                            id: avPwdMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (modelData.security && modelData.security !== "") {
                                                                    root.passwordDialogSsid = modelData.ssid
                                                                    root.passwordDialogSecurity = modelData.security
                                                                    root.showPasswordDialog = true
                                                                } else {
                                                                    root.connectToWifi(modelData.ssid, "")
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Scanning indicator
                                Rectangle {
                                    visible: root.wifiEnabled && root.wifiScanning && root.wifiNetworks.length === 0
                                    Layout.fillWidth: true; height: 80; color: "transparent"
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

                        // ===== Ethernet Tab =====
                        ColumnLayout {
                            spacing: Theme.spacingM

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: ethContent.implicitHeight + Theme.spacingM * 2
                                radius: Theme.radiusM
                                color: Theme.surface
                                border.color: root.ethernetConnected ? Theme.primary : Theme.outline
                                border.width: 1

                                RowLayout {
                                    id: ethContent
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 36; height: 36; radius: Theme.radiusS
                                        color: Theme.surfaceVariant
                                        border.color: root.ethernetConnected ? Theme.primary : Theme.outline
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: "ETH"
                                            font.pixelSize: Theme.fontSizeS
                                            font.weight: Font.DemiBold
                                            color: root.ethernetConnected ? Theme.primary : Theme.textMuted
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            spacing: Theme.spacingS
                                            Text {
                                                text: root.ethernetDetails.name || "以太网"
                                                font.pixelSize: Theme.fontSizeM
                                                font.weight: Font.Medium
                                                color: Theme.textPrimary
                                            }
                                            Rectangle {
                                                visible: root.ethernetConnected
                                                width: ethConnLabel.implicitWidth + 8
                                                height: ethConnLabel.implicitHeight + 4
                                                radius: Theme.radiusPill
                                                color: Theme.alpha(Theme.success, 0.2)
                                                Text { id: ethConnLabel; anchors.centerIn: parent; text: "已连接"; font.pixelSize: Theme.fontSizeXS; color: Theme.success }
                                            }
                                        }

                                        Text {
                                            text: root.ethernetConnected ? (root.ethernetDetails.ifname || "") : "未连接"
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.textMuted
                                        }
                                    }
                                }
                            }

                            // Ethernet details
                            ColumnLayout {
                                visible: root.ethernetConnected
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: "连接详情"; font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: ethDetailsCol.implicitHeight + Theme.spacingM * 2
                                    radius: Theme.radiusM
                                    color: Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    ColumnLayout {
                                        id: ethDetailsCol
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingS

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "IP 地址"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                            Text { text: root.ethernetDetails.ip || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "网关"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                            Text { text: root.ethernetDetails.gateway || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "DNS"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                            Text { text: root.ethernetDetails.dns || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // ===== Password Dialog =====
                Rectangle {
                    visible: root.showPasswordDialog
                    anchors.fill: parent
                    color: Theme.alpha(Theme.background, 0.95)
                    radius: Theme.radiusL
                    onVisibleChanged: {
                        if (visible) {
                            Qt.callLater(function () {
                                passwordInput.forceActiveFocus();
                            });
                        }
                    }

                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingL * 4
                        spacing: Theme.spacingL

                        Text {
                            text: "连接到 " + root.passwordDialogSsid
                            font.pixelSize: Theme.fontSizeL
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "请输入密码"
                            font.pixelSize: Theme.fontSizeM
                            color: Theme.textMuted
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: Theme.radiusM
                            color: Theme.surface
                            border.color: passwordInput.activeFocus ? Theme.primary : Theme.outline
                            border.width: 1

                            TextInput {
                                id: passwordInput
                                anchors.margins: Theme.spacingM
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textPrimary
                                echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                                clip: true
                                focus: root.showPasswordDialog
                                onAccepted: {
                                    if (text !== "") {
                                        root.showPasswordDialog = false
                                        root.passwordVisible = false
                                        root.connectToWifi(root.passwordDialogSsid, text)
                                        text = ""
                                    }
                                }
                            }

                            Text {
                                visible: passwordInput.text === ""
                                text: "密码"
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textMuted
                            }

                            // Eye toggle button
                            Rectangle {
                                id: eyeBtn
                                width: 32; height: 32
                                radius: Theme.radiusS
                                color: eyeMa.containsMouse ? Theme.surfaceVariant : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: root.passwordVisible ? "\uf06e" : "\uf070"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: Theme.textMuted
                                }

                                MouseArea {
                                    id: eyeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.passwordVisible = !root.passwordVisible
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                onClicked: passwordInput.forceActiveFocus()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: Theme.radiusM
                                color: cancelMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                                border.color: Theme.outline

                                Text { anchors.centerIn: parent; text: "取消"; font.pixelSize: Theme.fontSizeM; color: Theme.textSecondary }
                                MouseArea {
                                    id: cancelMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.showPasswordDialog = false; root.passwordVisible = false; passwordInput.text = "" }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: Theme.radiusM
                                color: confirmMa.containsMouse ? Theme.alpha(Theme.primary, 0.8) : Theme.primary

                                Text { anchors.centerIn: parent; text: "连接"; font.pixelSize: Theme.fontSizeM; font.weight: Font.Bold; color: Theme.background }
                                MouseArea {
                                    id: confirmMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (passwordInput.text !== "") {
                                            root.showPasswordDialog = false
                                            root.passwordVisible = false
                                            root.connectToWifi(root.passwordDialogSsid, passwordInput.text)
                                            passwordInput.text = ""
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== Info Dialog =====
                Rectangle {
                    visible: root.showInfoDialog
                    anchors.fill: parent
                    color: Theme.alpha(Theme.background, 0.95)
                    radius: Theme.radiusL

                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingL * 4
                        spacing: Theme.spacingL

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.infoDialogData ? root.infoDialogData.ssid : ""
                                font.pixelSize: Theme.fontSizeL
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: closeInfoMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeS; color: Theme.textSecondary }
                                MouseArea { id: closeInfoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showInfoDialog = false }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: infoCol.implicitHeight + Theme.spacingM * 2
                            radius: Theme.radiusM
                            color: Theme.surface
                            border.color: Theme.outline
                            border.width: 1

                            ColumnLayout {
                                id: infoCol
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "安全性"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: root.infoDialogData ? (root.infoDialogData.security || "开放") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "信号"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: root.infoDialogData ? (root.infoDialogData.signal + "% " + (root.infoDialogData.signalDbm || "")) : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                }
                                RowLayout {
                                    visible: root.infoDialogData && root.infoDialogData.band !== undefined && root.infoDialogData.band !== ""
                                    Layout.fillWidth: true
                                    Text { text: "频段"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: root.infoDialogData ? (root.infoDialogData.band || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                }
                                RowLayout {
                                    visible: root.infoDialogData && root.infoDialogData.speed !== undefined && root.infoDialogData.speed !== ""
                                    Layout.fillWidth: true
                                    Text { text: "速率"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: root.infoDialogData ? (root.infoDialogData.speed || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "IP 地址"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: root.infoDialogData ? (root.infoDialogData.ip || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "网关"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: root.infoDialogData ? (root.infoDialogData.gateway || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "DNS"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: root.infoDialogData ? (root.infoDialogData.dns || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                }
                            }
                        }

                        // Forget button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: Theme.radiusM
                            color: forgetInfoMa.containsMouse ? Theme.alpha(Theme.error, 0.3) : Theme.alpha(Theme.error, 0.15)
                            border.color: Theme.error

                            Text { anchors.centerIn: parent; text: "忘记此网络"; font.pixelSize: Theme.fontSizeM; color: Theme.error }
                            MouseArea {
                                id: forgetInfoMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.forgetWifi(root.infoDialogData.ssid)
                                    root.showInfoDialog = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
