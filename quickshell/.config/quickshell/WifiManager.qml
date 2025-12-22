import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    property string currentSsid: ""
    property string wifiDevice: ""  // WiFi device name (e.g., wlan0, wlp2s0)
    property bool isConnected: false
    property bool isScanning: false
    property var networkList: []
    property var savedNetworks: []  // List of saved network names
    
    // Process for getting saved networks
    property var savedNetworksProcess: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let lines = output.split("\n")
                let saved = []
                
                for (let line of lines) {
                    if (line.length === 0) continue
                    let parts = line.split(":")
                    // Only include WiFi connections
                    if (parts.length >= 2 && parts[1] === "802-11-wireless") {
                        saved.push(parts[0])
                    }
                }
                manager.savedNetworks = saved
            }
        }
    }
    
    // Process for getting current connection
    property var currentConnectionProcess: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let lines = output.split("\n")
                manager.isConnected = false
                manager.currentSsid = ""
                manager.wifiDevice = ""
                
                for (let line of lines) {
                    if (line.length === 0) continue
                    let parts = line.split(":")
                    if (parts.length >= 3 && parts[1] === "802-11-wireless") {
                        manager.currentSsid = parts[0]
                        manager.wifiDevice = parts[2]
                        manager.isConnected = true
                        break
                    }
                }
                
                // 如果没有连接，尝试获取WiFi设备名
                if (!manager.wifiDevice) {
                    manager.getWifiDevice()
                }
            }
        }
    }
    
    // Process for getting WiFi device name
    property var wifiDeviceProcess: Process {
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let lines = output.split("\n")
                
                for (let line of lines) {
                    if (line.length === 0) continue
                    let parts = line.split(":")
                    if (parts.length >= 2 && parts[1] === "wifi") {
                        manager.wifiDevice = parts[0]
                        break
                    }
                }
            }
        }
    }
    
    // 快速获取缓存的网络列表（不触发重新扫描）
    property var quickScanProcess: Process {
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.parseNetworkList(this.text)
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            // 快速加载完成后，触发后台重新扫描
            if (exitCode === 0) {
                manager.backgroundRescan()
            }
        }
    }
    
    // 完整扫描网络（触发重新扫描）
    property var scanProcess: Process {
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.parseNetworkList(this.text)
                manager.isScanning = false
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.isScanning = false
        }
    }
    
    // 解析网络列表的通用函数
    function parseNetworkList(text) {
        let output = text.trim()
        let lines = output.split("\n")
        let networks = []
        let seenSsids = new Set()
        
        for (let line of lines) {
            if (line.length === 0) continue
            // Handle escaped colons in SSID (nmcli uses \: for literal colons)
            let parts = []
            let current = ""
            let escaped = false
            
            for (let i = 0; i < line.length; i++) {
                let ch = line[i]
                if (escaped) {
                    current += ch
                    escaped = false
                } else if (ch === '\\') {
                    escaped = true
                } else if (ch === ':') {
                    parts.push(current)
                    current = ""
                } else {
                    current += ch
                }
            }
            parts.push(current)
            
            if (parts.length >= 3 && parts[0].length > 0) {
                let ssid = parts[0]
                // Skip duplicates, keep the one with higher signal
                if (!seenSsids.has(ssid)) {
                    seenSsids.add(ssid)
                    networks.push({
                        ssid: ssid,
                        signal: parseInt(parts[1]) || 0,
                        security: parts[2] || ""
                    })
                }
            }
        }
        
        // Sort by signal strength (descending)
        networks.sort((a, b) => b.signal - a.signal)
        manager.networkList = networks
    }
    
    // Process for connecting to a network
    property var connectProcess: Process {
        property string targetSsid: ""
        property string targetSecurity: ""
        
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("连接结果:", this.text)
                // Refresh current connection status
                manager.checkCurrentConnection()
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (connectProcess.targetSecurity !== "" && connectProcess.targetSecurity !== "--") {
                    console.log("需要密码连接到:", connectProcess.targetSsid)
                    console.log("请在终端执行: nmcli device wifi connect '" + connectProcess.targetSsid + "' --ask")
                }
            }
            manager.checkCurrentConnection()
        }
    }
    
    // Process for disconnecting
    property var disconnectProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("断开连接:", this.text)
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                console.log("断开连接错误:", this.text)
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.checkCurrentConnection()
            manager.refreshSavedNetworks()
        }
    }
    
    // Process for forgetting a network
    property var forgetProcess: Process {
        property string targetSsid: ""
        
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("忘记网络:", this.text)
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.refreshSavedNetworks()
            manager.checkCurrentConnection()
        }
    }
    
    // Process for getting saved password (uses pkexec for sudo)
    property string queriedPassword: ""
    property var passwordQueryProcess: Process {
        property string targetSsid: ""
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                // nmcli -s -t 输出格式: 802-11-wireless-security.psk:密码
                if (output.includes(":")) {
                    manager.queriedPassword = output.split(":").slice(1).join(":").trim()
                } else {
                    manager.queriedPassword = output || ""
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) {
                    console.log("密码查询错误:", this.text)
                }
            }
        }
    }
    
    signal passwordQueried(string ssid, string password)
    
    // 刷新计数器（每3次快速刷新后做一次完整扫描）
    property int refreshCount: 0
    
    // Auto-refresh timer
    property var refreshTimer: Timer {
        interval: 8000  // 8 seconds
        running: true
        repeat: true
        onTriggered: {
            manager.refreshCount++
            if (manager.refreshCount >= 3) {
                // 每3次做一次完整扫描
                manager.refreshCount = 0
                manager.scanNetworks()
            } else {
                // 其他时候使用缓存快速刷新
                manager.quickScan()
            }
        }
    }
    
    function checkCurrentConnection() {
        currentConnectionProcess.running = true
    }
    
    function refreshSavedNetworks() {
        savedNetworksProcess.running = true
    }
    
    function isSavedNetwork(ssid) {
        return savedNetworks.indexOf(ssid) !== -1
    }
    
    function scanNetworks() {
        if (manager.isScanning) return
        manager.isScanning = true
        scanProcess.running = true
    }
    
    // 快速扫描（使用缓存）
    function quickScan() {
        quickScanProcess.running = true
    }
    
    // 后台重新扫描
    function backgroundRescan() {
        if (manager.isScanning) return
        manager.isScanning = true
        scanProcess.running = true
    }
    
    function connectTo(ssid, security) {
        console.log("尝试连接到:", ssid)
        connectProcess.targetSsid = ssid
        connectProcess.targetSecurity = security
        connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid]
        connectProcess.running = true
    }
    
    function connectWithPassword(ssid, password) {
        console.log("使用密码连接到:", ssid)
        connectProcess.targetSsid = ssid
        connectProcess.targetSecurity = "WPA"
        connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        connectProcess.running = true
    }
    
    function getWifiDevice() {
        wifiDeviceProcess.running = true
    }
    
    function disconnect() {
        // 使用当前连接的SSID断开，而不是设备名
        if (manager.currentSsid) {
            console.log("断开连接:", manager.currentSsid)
            disconnectProcess.command = ["nmcli", "connection", "down", manager.currentSsid]
        } else if (manager.wifiDevice) {
            console.log("断开设备:", manager.wifiDevice)
            disconnectProcess.command = ["nmcli", "device", "disconnect", manager.wifiDevice]
        } else {
            console.log("没有找到WiFi连接或设备")
            return
        }
        disconnectProcess.running = true
    }
    
    function forgetNetwork(ssid) {
        console.log("忘记网络:", ssid)
        forgetProcess.targetSsid = ssid
        forgetProcess.command = ["nmcli", "connection", "delete", ssid]
        forgetProcess.running = true
    }
    
    function queryPassword(ssid) {
        passwordQueryProcess.targetSsid = ssid
        // 使用 pkexec 获取 sudo 权限来查看密码
        passwordQueryProcess.command = ["pkexec", "nmcli", "-s", "-t", "-f", "802-11-wireless-security.psk", "connection", "show", ssid]
        passwordQueryProcess.running = true
    }
    
    Component.onCompleted: {
        // 初始化：先快速加载缓存数据，再后台扫描
        getWifiDevice()
        refreshSavedNetworks()
        checkCurrentConnection()
        quickScan()  // 使用快速扫描而不是完整扫描
    }
}
