import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    // 天气数据
    property string city: ""
    property string area: ""
    property string temp: "--"
    property string feelsLike: "--"
    property string humidity: "--"
    property string windSpeed: "--"
    property string windDir: ""
    property string weatherDesc: "加载中..."
    property string icon: "󰖐"
    property string observationTime: ""
    property string uvIndex: "0"
    property string pressure: ""
    property string visibility: ""
    property var forecast: []
    
    property bool loading: true
    property bool refreshing: false  // 后台刷新中（不影响界面显示）
    property string error: ""
    property string lastUpdateTime: ""  // 本地刷新时间
    
    // 脚本路径
    readonly property string scriptPath: Qt.resolvedUrl("scripts/weather_fetch.py").toString().replace("file://", "")
    
    property bool fromCache: false
    
    // 解析天气数据的通用函数
    function parseWeatherData(text) {
        try {
            let data = JSON.parse(text)
            if (data.error && !data.loading) {
                manager.error = data.error
                return false
            }
            
            if (data.loading) {
                // 无缓存，等待后台加载
                return false
            }
            
            manager.error = ""
            manager.city = data.city || ""
            manager.area = data.area || ""
            manager.temp = data.temp || "--"
            manager.feelsLike = data.feelsLike || "--"
            manager.humidity = data.humidity || "--"
            manager.windSpeed = data.windSpeed || "--"
            manager.windDir = data.windDir || ""
            manager.weatherDesc = data.weatherDesc || ""
            manager.icon = data.icon || "󰖐"
            manager.observationTime = data.observationTime || ""
            manager.uvIndex = data.uvIndex || "0"
            manager.pressure = data.pressure || ""
            manager.visibility = data.visibility || ""
            manager.forecast = data.forecast || []
            manager.fromCache = data._from_cache || false
            
            // 从缓存中读取刷新时间
            if (data._last_update) {
                manager.lastUpdateTime = data._last_update
            }
            
            return true
        } catch (e) {
            manager.error = "解析数据失败"
            return false
        }
    }
    
    // 读取缓存（快速启动）
    property var cacheProcess: Process {
        command: ["python3", manager.scriptPath, "--cache"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (manager.parseWeatherData(this.text)) {
                    manager.loading = false
                    // 有缓存，后台刷新（刷新时间从缓存中读取）
                    backgroundRefreshTimer.start()
                } else {
                    // 无缓存，直接获取
                    weatherProcess.running = true
                }
            }
        }
    }
    
    // 后台刷新延迟（避免同时请求）
    property var backgroundRefreshTimer: Timer {
        interval: 500
        onTriggered: {
            manager.refreshing = true  // 显示刷新状态
            forceRefreshProcess.running = true
        }
    }
    
    // 强制刷新（后台更新，不影响界面）
    property var forceRefreshProcess: Process {
        command: ["python3", manager.scriptPath, "--force"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.parseWeatherData(this.text)  // 刷新时间从返回数据中读取
                manager.loading = false
                manager.refreshing = false
                manager.fromCache = false
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    manager.error = this.text.trim()
                }
                manager.refreshing = false
            }
        }
    }
    
    // 获取天气数据（使用缓存）
    property var weatherProcess: Process {
        command: ["python3", manager.scriptPath]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.loading = false
                manager.parseWeatherData(this.text)  // 刷新时间从数据中读取
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    manager.error = this.text.trim()
                    manager.loading = false
                }
            }
        }
    }
    
    // 使用指定城市获取天气
    property var weatherWithCityProcess: Process {
        property string targetCity: ""
        command: ["python3", manager.scriptPath, targetCity, "--force"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                manager.loading = false
                manager.parseWeatherData(this.text)
            }
        }
    }
    
    // 定时刷新（每30分钟）
    property var refreshTimer: Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        onTriggered: manager.refresh()
    }
    
    function refresh() {
        manager.refreshing = true
        forceRefreshProcess.running = true
    }
    
    function refreshWithCity(cityName) {
        manager.loading = true
        weatherWithCityProcess.targetCity = cityName
        weatherWithCityProcess.command = ["python3", manager.scriptPath, cityName, "--force"]
        weatherWithCityProcess.running = true
    }
    
    // 快速启动（先读缓存）
    function quickStart() {
        cacheProcess.running = true
    }
    
    // 获取当前时间字符串
    function getCurrentTime() {
        let now = new Date()
        let h = now.getHours().toString().padStart(2, '0')
        let m = now.getMinutes().toString().padStart(2, '0')
        return h + ":" + m
    }
    
    // 获取星期几
    function getDayOfWeek(dateStr) {
        if (!dateStr) return ""
        let date = new Date(dateStr)
        let days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let today = new Date()
        
        if (date.toDateString() === today.toDateString()) {
            return "今天"
        }
        
        let tomorrow = new Date(today)
        tomorrow.setDate(tomorrow.getDate() + 1)
        if (date.toDateString() === tomorrow.toDateString()) {
            return "明天"
        }
        
        return days[date.getDay()]
    }
    
    Component.onCompleted: {
        quickStart()  // 先读缓存，再后台刷新
    }
}
