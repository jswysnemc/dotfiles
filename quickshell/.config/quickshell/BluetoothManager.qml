import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    property bool powered: false
    property bool scanning: false
    property string connectedDevice: ""
    property string connectedDeviceMac: ""
    property var pairedDevices: []
    property var availableDevices: []
    
    // 获取蓝牙电源状态
    property var powerStatusProcess: Process {
        command: ["bluetoothctl", "show"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text
                manager.powered = output.includes("Powered: yes")
            }
        }
    }
    
    // 获取已配对设备
    property var pairedProcess: Process {
        command: ["bluetoothctl", "devices", "Paired"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let lines = output.split("\n")
                let devices = []
                
                for (let line of lines) {
                    if (line.length === 0) continue
                    // 格式: Device XX:XX:XX:XX:XX:XX DeviceName
                    let match = line.match(/Device ([0-9A-F:]+) (.+)/i)
                    if (match) {
                        devices.push({
                            mac: match[1],
                            name: match[2],
                            paired: true,
                            connected: false
                        })
                    }
                }
                manager.pairedDevices = devices
                // 检查每个设备的连接状态
                manager.checkConnectedDevices()
            }
        }
    }
    
    // 扫描可用设备
    property var scanProcess: Process {
        command: ["bluetoothctl", "--timeout", "5", "scan", "on"]
        
        onExited: (exitCode, exitStatus) => {
            manager.scanning = false
            manager.getAvailableDevices()
        }
    }
    
    // 获取可用设备列表
    property var availableProcess: Process {
        command: ["bluetoothctl", "devices"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let lines = output.split("\n")
                let devices = []
                let pairedMacs = manager.pairedDevices.map(d => d.mac)
                
                for (let line of lines) {
                    if (line.length === 0) continue
                    let match = line.match(/Device ([0-9A-F:]+) (.+)/i)
                    if (match) {
                        let mac = match[1]
                        let isPaired = pairedMacs.includes(mac)
                        devices.push({
                            mac: mac,
                            name: match[2],
                            paired: isPaired,
                            connected: mac === manager.connectedDeviceMac
                        })
                    }
                }
                manager.availableDevices = devices
            }
        }
    }
    
    // 获取连接状态
    property var connectedProcess: Process {
        command: ["bluetoothctl", "devices", "Connected"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                let lines = output.split("\n")
                manager.connectedDevice = ""
                manager.connectedDeviceMac = ""
                
                for (let line of lines) {
                    if (line.length === 0) continue
                    let match = line.match(/Device ([0-9A-F:]+) (.+)/i)
                    if (match) {
                        manager.connectedDeviceMac = match[1]
                        manager.connectedDevice = match[2]
                        break
                    }
                }
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.getAvailableDevices()
        }
    }
    
    // 连接设备
    property var connectProcess: Process {
        property string targetMac: ""
        property string targetName: ""
        
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("连接结果:", this.text)
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) {
                    console.log("连接错误:", this.text)
                }
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.checkConnectedDevices()
            manager.getPairedDevices()
        }
    }
    
    // 断开连接
    property var disconnectProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("断开结果:", this.text)
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.checkConnectedDevices()
        }
    }
    
    // 配对设备
    property var pairProcess: Process {
        property string targetMac: ""
        
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("配对结果:", this.text)
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.getPairedDevices()
        }
    }
    
    // 移除设备
    property var removeProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("移除结果:", this.text)
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.getPairedDevices()
            manager.checkConnectedDevices()
        }
    }
    
    // 电源开关
    property var powerProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("电源操作:", this.text)
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            manager.checkPowerStatus()
        }
    }
    
    // 自动刷新
    property var refreshTimer: Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            manager.checkConnectedDevices()
            manager.getPairedDevices()
        }
    }
    
    // 函数
    function checkPowerStatus() {
        powerStatusProcess.running = true
    }
    
    function getPairedDevices() {
        pairedProcess.running = true
    }
    
    function getAvailableDevices() {
        availableProcess.running = true
    }
    
    function checkConnectedDevices() {
        connectedProcess.running = true
    }
    
    function startScan() {
        if (manager.scanning) return
        manager.scanning = true
        scanProcess.running = true
    }
    
    function connectDevice(mac, name) {
        console.log("连接设备:", name, mac)
        connectProcess.targetMac = mac
        connectProcess.targetName = name
        connectProcess.command = ["bluetoothctl", "connect", mac]
        connectProcess.running = true
    }
    
    function disconnectDevice(mac) {
        console.log("断开设备:", mac)
        disconnectProcess.command = ["bluetoothctl", "disconnect", mac]
        disconnectProcess.running = true
    }
    
    function pairDevice(mac) {
        console.log("配对设备:", mac)
        pairProcess.targetMac = mac
        pairProcess.command = ["bluetoothctl", "pair", mac]
        pairProcess.running = true
    }
    
    function removeDevice(mac) {
        console.log("移除设备:", mac)
        removeProcess.command = ["bluetoothctl", "remove", mac]
        removeProcess.running = true
    }
    
    function setPower(on) {
        powerProcess.command = ["bluetoothctl", "power", on ? "on" : "off"]
        powerProcess.running = true
    }
    
    function trustDevice(mac) {
        let p = Qt.createQmlObject('import Quickshell.Io; Process {}', manager)
        p.command = ["bluetoothctl", "trust", mac]
        p.running = true
    }
    
    Component.onCompleted: {
        checkPowerStatus()
        getPairedDevices()
        checkConnectedDevices()
    }
}
