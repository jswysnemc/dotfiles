import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    // 音量
    property int volume: 0
    property bool muted: false
    
    // 亮度
    property int brightness: 100
    property int maxBrightness: 100
    
    // WiFi
    property bool wifiConnected: false
    property string wifiSsid: ""
    
    // 蓝牙
    property bool bluetoothPowered: false
    property string bluetoothDevice: ""
    
    // 通知
    property int notificationCount: 0
    property bool dndEnabled: false
    
    // ========== 音量控制 ==========
    property var volumeGetProcess: Process {
        command: ["pactl", "get-sink-volume", "@DEFAULT_SINK@"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                // 解析 "Volume: front-left: 65536 / 100% / ..."
                let match = this.text.match(/(\d+)%/)
                if (match) {
                    manager.volume = parseInt(match[1])
                }
            }
        }
    }
    
    property var muteGetProcess: Process {
        command: ["pactl", "get-sink-mute", "@DEFAULT_SINK@"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.muted = this.text.includes("yes")
            }
        }
    }
    
    property var volumeSetProcess: Process {
        property int targetVolume: 0
        command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", targetVolume + "%"]
        
        onExited: (exitCode, exitStatus) => {
            manager.refreshVolume()
        }
    }
    
    property var muteToggleProcess: Process {
        command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        
        onExited: (exitCode, exitStatus) => {
            manager.refreshMute()
        }
    }
    
    // ========== 亮度控制 ==========
    property var brightnessGetProcess: Process {
        command: ["brightnessctl", "get"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.brightness = parseInt(this.text.trim()) || 0
            }
        }
    }
    
    property var brightnessMaxProcess: Process {
        command: ["brightnessctl", "max"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.maxBrightness = parseInt(this.text.trim()) || 100
            }
        }
    }
    
    property var brightnessSetProcess: Process {
        property int targetBrightness: 0
        command: ["brightnessctl", "set", targetBrightness.toString()]
        
        onExited: (exitCode, exitStatus) => {
            manager.refreshBrightness()
        }
    }
    
    // ========== WiFi 状态 ==========
    property var wifiProcess: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let lines = output.split("\n")
                manager.wifiConnected = false
                manager.wifiSsid = ""
                
                for (let line of lines) {
                    if (line.length === 0) continue
                    let parts = line.split(":")
                    if (parts.length >= 2 && parts[1] === "802-11-wireless") {
                        manager.wifiSsid = parts[0]
                        manager.wifiConnected = true
                        break
                    }
                }
            }
        }
    }
    
    // ========== 蓝牙状态 ==========
    property var bluetoothPowerProcess: Process {
        command: ["bluetoothctl", "show"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.bluetoothPowered = this.text.includes("Powered: yes")
            }
        }
    }
    
    property var bluetoothConnectedProcess: Process {
        command: ["bluetoothctl", "devices", "Connected"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let match = output.match(/Device [0-9A-F:]+ (.+)/i)
                manager.bluetoothDevice = match ? match[1] : ""
            }
        }
    }
    
    // ========== 通知状态 ==========
    property var notificationCountProcess: Process {
        command: ["swaync-client", "-c"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.notificationCount = parseInt(this.text.trim()) || 0
            }
        }
    }
    
    property var dndProcess: Process {
        command: ["swaync-client", "-D"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.dndEnabled = this.text.trim() === "true"
            }
        }
    }
    
    property var dndToggleProcess: Process {
        command: ["swaync-client", "-d"]
        
        onExited: (exitCode, exitStatus) => {
            manager.refreshDnd()
        }
    }
    
    // ========== 定时刷新 ==========
    property var refreshTimer: Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            manager.refreshAll()
        }
    }
    
    // ========== 函数 ==========
    function refreshVolume() {
        volumeGetProcess.running = true
    }
    
    function refreshMute() {
        muteGetProcess.running = true
    }
    
    function refreshBrightness() {
        brightnessGetProcess.running = true
    }
    
    function refreshWifi() {
        wifiProcess.running = true
    }
    
    function refreshBluetooth() {
        bluetoothPowerProcess.running = true
        bluetoothConnectedProcess.running = true
    }
    
    function refreshNotifications() {
        notificationCountProcess.running = true
    }
    
    function refreshDnd() {
        dndProcess.running = true
    }
    
    function refreshAll() {
        refreshVolume()
        refreshMute()
        refreshBrightness()
        refreshWifi()
        refreshBluetooth()
        refreshNotifications()
        refreshDnd()
    }
    
    function setVolume(vol) {
        volumeSetProcess.targetVolume = Math.max(0, Math.min(100, vol))
        volumeSetProcess.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", volumeSetProcess.targetVolume + "%"]
        volumeSetProcess.running = true
    }
    
    function toggleMute() {
        muteToggleProcess.running = true
    }
    
    function setBrightness(val) {
        let target = Math.max(1, Math.min(maxBrightness, val))
        brightnessSetProcess.targetBrightness = target
        brightnessSetProcess.command = ["brightnessctl", "set", target.toString()]
        brightnessSetProcess.running = true
    }
    
    function toggleDnd() {
        dndToggleProcess.running = true
    }
    
    // 计算亮度百分比
    function getBrightnessPercent() {
        if (maxBrightness <= 0) return 100
        return Math.round(brightness * 100 / maxBrightness)
    }
    
    Component.onCompleted: {
        brightnessMaxProcess.running = true
        refreshAll()
    }
}
