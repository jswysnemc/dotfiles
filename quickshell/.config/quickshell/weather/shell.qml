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
        catalog: "weather"
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
    property bool anchorTop: posEnv.indexOf("top") !== -1
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    property var weatherData: null
    property bool loading: false
    property bool refreshing: false
    property string errorMsg: ""

    property real latitude: 39.9042
    property real longitude: 116.4074
    property string locationName: "Beijing"
    property bool useCelsius: true

    // Location settings
    property bool showSettings: false
    property bool locating: false
    property string searchQuery: ""
    property var searchResults: []
    property bool searching: false
    readonly property string configPath: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/quickshell/weather/config.json"
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/weather/cache.json"
    property int cacheMaxAge: 30 * 60 * 1000  // 30 minutes in ms
    property real cachedLat: 0
    property real cachedLon: 0
    property int cachedTime: 0

    function fetchWeather() {
        let now = Date.now()
        if (weatherData && cachedLat === latitude && cachedLon === longitude && (now - cachedTime) < cacheMaxAge) {
            loading = false
            refreshing = false
            return
        }
        if (weatherData) {
            refreshing = true
        } else {
            loading = true
        }
        root.errorMsg = ""
        weatherProc.running = true
    }

    function saveWeatherCache() {
        let cache = JSON.stringify({
            data: weatherData,
            lat: latitude,
            lon: longitude,
            time: Date.now()
        })
        saveCacheProc.command = ["bash", "-c", "mkdir -p \"$(dirname '" + cachePath + "')\" && echo '" + cache.replace(/'/g, "'\\''") + "' > '" + cachePath + "'"]
        saveCacheProc.running = true
    }

    Process {
        id: weatherProc
        command: ["curl", "-s", "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max&timezone=auto&forecast_days=7"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                root.refreshing = false
                if (text && text.trim()) {
                    try {
                        root.weatherData = JSON.parse(text)
                        root.cachedLat = root.latitude
                        root.cachedLon = root.longitude
                        root.cachedTime = Date.now()
                        root.saveWeatherCache()
                        root.errorMsg = ""
                    }
                    catch (e) {
                        if (!root.weatherData) root.errorMsg = i18n.trLiteral("解析天气数据失败")
                    }
                } else {
                    if (!root.weatherData) root.errorMsg = i18n.trLiteral("获取天气失败")
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.loading = false
                root.refreshing = false
                if (!root.weatherData) root.errorMsg = i18n.trLiteral("获取天气失败")
            }
        }
    }

    Process {
        id: geolocateProc
        command: ["curl", "-s", "http://ip-api.com/json/?fields=status,city,lat,lon"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.locating = false
                try {
                    let data = JSON.parse(text)
                    if (data.status === "success") {
                        root.latitude = data.lat
                        root.longitude = data.lon
                        root.locationName = data.city || "Unknown"
                        root.saveConfig()
                        root.fetchWeather()
                    }
                } catch (e) {
                    console.log("Geolocation failed:", e)
                }
            }
        }
        onExited: (code) => { if (code !== 0) root.locating = false }
    }

    Process {
        id: searchProc
        command: ["echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false
                try {
                    let data = JSON.parse(text)
                    root.searchResults = (data.results || []).slice(0, 5)
                } catch (e) {
                    root.searchResults = []
                }
            }
        }
        onExited: (code) => { if (code !== 0) root.searching = false }
    }

    Process {
        id: loadConfigProc
        command: ["cat", root.configPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let cfg = JSON.parse(text)
                    if (cfg.latitude) root.latitude = cfg.latitude
                    if (cfg.longitude) root.longitude = cfg.longitude
                    if (cfg.locationName) root.locationName = cfg.locationName
                    if (cfg.useCelsius !== undefined) root.useCelsius = cfg.useCelsius
                } catch (e) {}
                root.fetchWeather()
            }
        }
        onExited: (code) => { if (code !== 0) root.fetchWeather() }
    }

    Process {
        id: saveConfigProc
        command: ["echo"]
    }

    Process {
        id: saveCacheProc
        command: ["echo"]
    }

    Process {
        id: loadCacheProc
        command: ["cat", root.cachePath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let cache = JSON.parse(text)
                    if (cache.data && cache.lat && cache.lon && cache.time) {
                        root.weatherData = cache.data
                        root.cachedLat = cache.lat
                        root.cachedLon = cache.lon
                        root.cachedTime = cache.time
                    }
                } catch (e) {}
                loadConfigProc.running = true
            }
        }
        onExited: (code) => { if (code !== 0) loadConfigProc.running = true }
    }

    function getWeatherIcon(code) {
        if (code === 0) return ""
        if (code <= 3) return ""
        if (code <= 48) return ""
        if (code <= 57) return ""
        if (code <= 67) return ""
        if (code <= 77) return ""
        if (code <= 86) return ""
        return ""
    }

    function getWeatherDesc(code) {
        if (code === 0) return i18n.trLiteral("晴朗")
        if (code <= 3) return i18n.trLiteral("多云")
        if (code <= 48) return i18n.trLiteral("有雾")
        if (code <= 67) return i18n.trLiteral("小雨")
        if (code <= 77) return i18n.trLiteral("小雪")
        return i18n.trLiteral("雷暴")
    }

    function formatTemp(t) {
        if (!useCelsius) t = t * 9 / 5 + 32
        return Math.round(t) + "°" + (useCelsius ? "C" : "F")
    }

    function getDayName(dateStr, idx) {
        if (idx === 0) return i18n.trLiteral("今天")
        if (idx === 1) return i18n.trLiteral("明天")
        var day = new Date(dateStr).getDay()
        var names = [i18n.trLiteral("周日"), i18n.trLiteral("周一"), i18n.trLiteral("周二"), i18n.trLiteral("周三"), i18n.trLiteral("周四"), i18n.trLiteral("周五"), i18n.trLiteral("周六")]
        return names[day]
    }

    function loadConfig() {
        loadCacheProc.running = true
    }

    function saveConfig() {
        let cfg = JSON.stringify({
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            useCelsius: useCelsius
        })
        saveConfigProc.command = ["bash", "-c", "mkdir -p \"$(dirname '" + configPath + "')\" && echo '" + cfg + "' > '" + configPath + "'"]
        saveConfigProc.running = true
    }

    function geolocate() {
        locating = true
        geolocateProc.running = true
    }

    function searchLocation(query) {
        if (!query || query.length < 2) {
            searchResults = []
            return
        }
        searching = true
        var language = i18n.normalizedLanguage === "zh_CN" ? "zh" : "en"
        searchProc.command = ["curl", "-s", "https://geocoding-api.open-meteo.com/v1/search?name="
            + encodeURIComponent(query) + "&count=5&language=" + language]
        searchProc.running = true
    }

    function selectLocation(result) {
        latitude = result.latitude
        longitude = result.longitude
        locationName = result.name + (result.admin1 ? ", " + result.admin1 : "")
        searchResults = []
        searchQuery = ""
        showSettings = false
        saveConfig()
        fetchWeather()
    }

    Component.onCompleted: {
        loadConfig()
        enterAnimation.start()
    }

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation { target: root; property: "panelOpacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "panelScale"; from: 0.95; to: 1.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        NumberAnimation { target: root; property: "panelY"; from: 15; to: 0; duration: 250; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation { target: root; property: "panelOpacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "panelScale"; to: 0.95; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "panelY"; to: -10; duration: 150; easing.type: Easing.InCubic }
        onFinished: Qt.quit()
    }

    /**
     * 关闭天气弹窗窗口。
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

    // ============ UI ============
    WeatherView {
        controller: root
    }
}
