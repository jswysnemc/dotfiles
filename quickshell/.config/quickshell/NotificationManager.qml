import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    property int notificationCount: 0
    property bool dndEnabled: false
    property var notifications: []
    
    // 缓存文件路径
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/quickshell-notifications/notifications.json"
    readonly property string stateFile: Quickshell.env("HOME") + "/.cache/quickshell-notifications/state.json"
    readonly property string daemonScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/notification_daemon.py"
    
    // 读取通知列表
    property var loadNotificationsProcess: Process {
        command: ["cat", manager.cacheFile]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    manager.notifications = JSON.parse(this.text) || []
                    manager.notificationCount = manager.notifications.length
                } catch (e) {
                    manager.notifications = []
                    manager.notificationCount = 0
                }
            }
        }
    }
    
    // 读取状态
    property var loadStateProcess: Process {
        command: ["cat", manager.stateFile]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var state = JSON.parse(this.text) || {}
                    manager.dndEnabled = state.dnd || false
                } catch (e) {
                    manager.dndEnabled = false
                }
            }
        }
    }
    
    // 定时刷新
    property var refreshTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            loadNotificationsProcess.running = true
            loadStateProcess.running = true
        }
    }
    
    // 清除所有通知
    property var clearAllProcess: Process {
        command: ["python3", manager.daemonScript, "--clear"]
    }
    
    // 切换勿扰模式
    property var toggleDndProcess: Process {
        command: ["python3", manager.daemonScript, "--toggle-dnd"]
        
        onExited: {
            loadStateProcess.running = true
        }
    }
    
    // 调用通知动作 (使用 makoctl invoke)
    property var invokeProcess: Process {
        property string appName: ""
        command: ["bash", "-c", ""]
    }
    
    // 函数
    function refresh() {
        loadNotificationsProcess.running = true
        loadStateProcess.running = true
    }
    
    function clearAll() {
        clearAllProcess.running = true
    }
    
    function toggleDnd() {
        toggleDndProcess.running = true
    }
    
    function removeNotification(index) {
        // 从列表中移除指定通知并保存
        if (index >= 0 && index < notifications.length) {
            var newList = notifications.slice()
            newList.splice(index, 1)
            notifications = newList
            notificationCount = newList.length
            // 保存到文件
            saveNotificationsProcess.running = true
        }
    }
    
    // 保存通知列表
    property var saveNotificationsProcess: Process {
        command: ["bash", "-c", "echo '" + JSON.stringify(manager.notifications) + "' > " + manager.cacheFile]
    }
    
    // 点击通知执行动作
    function activateNotification(notification) {
        var app = (notification.app || "").toLowerCase()
        
        // 构建激活命令 - 通过 App ID 查找窗口
        var appId = app
        if (app.includes("qq")) appId = "qq"
        else if (app.includes("discord")) appId = "discord"
        else if (app.includes("telegram")) appId = "telegram"
        else if (app.includes("firefox")) appId = "firefox"
        else if (app.includes("chrome")) appId = "chrome"
        
        // 使用 niri 激活窗口
        var cmd = "niri msg windows | grep -B1 'App ID: \"" + appId + "\"' | head -1 | grep -oP '\\d+' | head -1 | xargs -I{} niri msg action focus-window --id {}"
        activateAppProcess.command = ["bash", "-c", cmd]
        activateAppProcess.running = true
    }
    
    // 复制文本到剪贴板
    function copyToClipboard(text) {
        copyProcess.command = ["bash", "-c", "echo -n '" + text.replace(/'/g, "'\\''") + "' | wl-copy"]
        copyProcess.running = true
    }
    
    property var activateAppProcess: Process {
        command: ["true"]
    }
    
    property var copyProcess: Process {
        command: ["true"]
    }
    
    // 初始化
    Component.onCompleted: {
        refresh()
    }
}
