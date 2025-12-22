import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    // 播放状态
    property bool hasPlayer: false
    property string playerName: ""
    property string status: "Stopped"  // Playing, Paused, Stopped
    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property int position: 0       // 当前位置（秒）
    property int length: 0         // 总长度（秒）
    property real volume: 1.0
    property bool shuffle: false
    property string loopStatus: "None"  // None, Track, Playlist
    
    // 格式化时间
    function formatTime(seconds) {
        if (seconds <= 0) return "0:00"
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    
    // 获取播放器列表
    property var listPlayersProcess: Process {
        command: ["playerctl", "--list-all"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var players = this.text.trim()
                manager.hasPlayer = players.length > 0
                if (manager.hasPlayer) {
                    manager.playerName = players.split("\n")[0]
                } else {
                    manager.playerName = ""
                    manager.status = "Stopped"
                    manager.title = ""
                    manager.artist = ""
                    manager.album = ""
                    manager.artUrl = ""
                }
            }
        }
    }
    
    // 获取元数据
    property var metadataProcess: Process {
        command: ["playerctl", "metadata", "--format", 
            "{{status}}|{{title}}|{{artist}}|{{album}}|{{mpris:artUrl}}|{{position}}|{{mpris:length}}|{{volume}}|{{shuffle}}|{{loop}}"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length >= 6) {
                    manager.status = parts[0] || "Stopped"
                    manager.title = parts[1] || ""
                    manager.artist = parts[2] || ""
                    manager.album = parts[3] || ""
                    manager.artUrl = parts[4] || ""
                    manager.position = Math.floor((parseInt(parts[5]) || 0) / 1000000)
                    manager.length = Math.floor((parseInt(parts[6]) || 0) / 1000000)
                    manager.volume = parseFloat(parts[7]) || 1.0
                    manager.shuffle = parts[8] === "true"
                    manager.loopStatus = parts[9] || "None"
                }
            }
        }
    }
    
    // 获取系统音量
    property var volumeGetProcess: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                // 输出格式: "Volume: 0.50" 或 "Volume: 0.50 [MUTED]"
                var match = this.text.match(/Volume:\s*([\d.]+)/)
                if (match) {
                    manager.volume = parseFloat(match[1])
                }
            }
        }
    }
    
    // 定时刷新
    property var refreshTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            listPlayersProcess.running = true
            volumeGetProcess.running = true
            if (manager.hasPlayer) {
                metadataProcess.running = true
            }
        }
    }
    
    // 播放控制进程
    property var playPauseProcess: Process {
        command: ["playerctl", "play-pause"]
    }
    
    property var nextProcess: Process {
        command: ["playerctl", "next"]
    }
    
    property var prevProcess: Process {
        command: ["playerctl", "previous"]
    }
    
    property var stopProcess: Process {
        command: ["playerctl", "stop"]
    }
    
    property var volumeProcess: Process {
        property real targetVolume: 1.0
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (targetVolume * 100).toFixed(0) + "%"]
    }
    
    property var seekProcess: Process {
        property int targetPosition: 0
        command: ["playerctl", "position", targetPosition.toString()]
    }
    
    property var shuffleProcess: Process {
        command: ["playerctl", "shuffle", "toggle"]
    }
    
    property var loopProcess: Process {
        property string mode: "None"
        command: ["playerctl", "loop", mode]
    }
    
    // 控制函数
    function playPause() {
        playPauseProcess.running = true
    }
    
    function next() {
        nextProcess.running = true
    }
    
    function previous() {
        prevProcess.running = true
    }
    
    function stop() {
        stopProcess.running = true
    }
    
    function setVolume(vol) {
        volumeProcess.targetVolume = Math.max(0, Math.min(1, vol))
        volumeProcess.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(volumeProcess.targetVolume * 100) + "%"]
        volumeProcess.running = true
    }
    
    function seek(pos) {
        seekProcess.targetPosition = pos
        seekProcess.command = ["playerctl", "position", seekProcess.targetPosition.toString()]
        seekProcess.running = true
    }
    
    function toggleShuffle() {
        shuffleProcess.running = true
    }
    
    function cycleLoop() {
        var nextMode = "None"
        if (loopStatus === "None") nextMode = "Playlist"
        else if (loopStatus === "Playlist") nextMode = "Track"
        else nextMode = "None"
        
        loopProcess.mode = nextMode
        loopProcess.command = ["playerctl", "loop", loopProcess.mode]
        loopProcess.running = true
    }
    
    // 初始化
    Component.onCompleted: {
        listPlayersProcess.running = true
    }
}
