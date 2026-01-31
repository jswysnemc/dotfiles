import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

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
        // Check if cache is valid and skip refresh
        let now = Date.now()
        if (weatherData && cachedLat === latitude && cachedLon === longitude && (now - cachedTime) < cacheMaxAge) {
            loading = false
            refreshing = false
            return
        }
        // If we have cached data, show it while refreshing in background
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
                        if (!root.weatherData) root.errorMsg = "解析天气数据失败"
                    }
                } else {
                    if (!root.weatherData) root.errorMsg = "获取天气失败"
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.loading = false
                root.refreshing = false
                if (!root.weatherData) root.errorMsg = "获取天气失败"
            }
        }
    }

    // IP geolocation process
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

    // Location search process
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

    // Config load process
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

    // Config save process
    Process {
        id: saveConfigProc
        command: ["echo"]
    }

    // Cache save process
    Process {
        id: saveCacheProc
        command: ["echo"]
    }

    // Cache load process
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
        if (code === 0) return "\ue30d"
        if (code <= 3) return "\ue302"
        if (code <= 48) return "\ue303"
        if (code <= 57) return "\ue309"
        if (code <= 67) return "\ue308"
        if (code <= 77) return "\ue30a"
        if (code <= 86) return "\ue308"
        return "\ue30f"
    }

    function getWeatherDesc(code) {
        if (code === 0) return "晴朗"
        if (code <= 3) return "多云"
        if (code <= 48) return "有雾"
        if (code <= 67) return "小雨"
        if (code <= 77) return "小雪"
        return "雷暴"
    }

    function formatTemp(t) {
        if (!useCelsius) t = t * 9 / 5 + 32
        return Math.round(t) + "\u00b0" + (useCelsius ? "C" : "F")
    }

    function getDayName(dateStr, idx) {
        if (idx === 0) return "今天"
        if (idx === 1) return "明天"
        var day = new Date(dateStr).getDay()
        var names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
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
        searchProc.command = ["curl", "-s", "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=5&language=zh"]
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

    Component.onCompleted: loadConfig()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-weather"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true


            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: panelRect
                anchors.top: root.anchorTop ? parent.top : undefined
                anchors.bottom: root.anchorBottom ? parent.bottom : undefined
                anchors.left: root.anchorLeft ? parent.left : undefined
                anchors.right: root.anchorRight ? parent.right : undefined
                anchors.horizontalCenter: root.anchorHCenter ? parent.horizontalCenter : undefined
                anchors.verticalCenter: root.anchorVCenter ? parent.verticalCenter : undefined
                anchors.topMargin: root.anchorTop ? root.marginT : 0
                anchors.bottomMargin: root.anchorBottom ? root.marginB : 0
                anchors.leftMargin: root.anchorLeft ? root.marginL : 0
                anchors.rightMargin: root.anchorRight ? root.marginR : 0
                width: 360
                height: root.showSettings ? 450 : panelRect.implicitHeight
                color: Theme.background
                radius: Theme.radiusL
                border.color: Theme.outline
                border.width: 1
                implicitHeight: mainCol.implicitHeight + Theme.spacingXL * 2

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Loading (only when no cached data)
                    Rectangle {
                        visible: root.loading && root.weatherData === null
                        Layout.fillWidth: true; height: 200; color: "transparent"
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: Theme.spacingM
                            Text { text: "\uf110"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.primary; Layout.alignment: Qt.AlignHCenter
                                RotationAnimation on rotation { running: true; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                            }
                            Text { text: "正在获取天气..."; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                        }
                    }

                    // Error (only when no cached data)
                    Rectangle {
                        visible: !root.loading && root.errorMsg !== "" && root.weatherData === null
                        Layout.fillWidth: true; height: 150; color: "transparent"
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: Theme.spacingM
                            Text { text: "\uf071"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.error; Layout.alignment: Qt.AlignHCenter }
                            Text { text: root.errorMsg; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter; width: 80; height: 32; radius: Theme.radiusM; color: Theme.primary
                                Text { anchors.centerIn: parent; text: "重试"; font.pixelSize: Theme.fontSizeS; color: Theme.background }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fetchWeather() }
                            }
                        }
                    }

                    // Content (show when we have data, even if refreshing)
                    ColumnLayout {
                        visible: root.weatherData !== null
                        Layout.fillWidth: true
                        spacing: Theme.spacingL

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingL

                            Text { text: root.weatherData ? root.getWeatherIcon(root.weatherData.current.weather_code) : ""; font.family: "Weather Icons"; font.pixelSize: 64; color: Theme.primary }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: Theme.spacingXS
                                RowLayout {
                                    spacing: Theme.spacingS
                                    Text { text: "位置"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                    Text {
                                        text: root.locationName
                                        font.pixelSize: Theme.fontSizeM
                                        color: locNameMa.containsMouse ? Theme.primary : Theme.textSecondary
                                        MouseArea {
                                            id: locNameMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.showSettings = true
                                        }
                                    }
                                    Text {
                                        text: "\uf013"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 12
                                        color: settingsMa.containsMouse ? Theme.primary : Theme.textMuted
                                        MouseArea {
                                            id: settingsMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.showSettings = true
                                        }
                                    }
                                }
                                Text { text: root.weatherData ? root.formatTemp(root.weatherData.current.temperature_2m) : ""; font.pixelSize: Theme.fontSizeHuge; font.weight: Font.Bold; color: Theme.textPrimary }
                                Text { text: root.weatherData ? root.getWeatherDesc(root.weatherData.current.weather_code) : ""; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                            }

                            Rectangle {
                                width: 32; height: 32; radius: Theme.radiusM
                                color: refreshMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                Text {
                                    id: refreshIcon
                                    anchors.centerIn: parent
                                    text: "\uf021"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeM
                                    color: root.refreshing ? Theme.primary : Theme.textSecondary
                                    RotationAnimation on rotation {
                                        running: root.refreshing
                                        from: 0; to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }
                                }
                                MouseArea {
                                    id: refreshMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.cachedTime = 0  // Force refresh
                                        root.fetchWeather()
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM

                            ColumnLayout {
                                spacing: 2
                                Text { text: "体感"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                Text { text: root.weatherData ? root.formatTemp(root.weatherData.current.apparent_temperature) : ""; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary }
                            }
                            ColumnLayout {
                                spacing: 2
                                Text { text: "湿度"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                Text { text: root.weatherData ? root.weatherData.current.relative_humidity_2m + "%" : ""; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary }
                            }
                            ColumnLayout {
                                spacing: 2
                                Text { text: "风速"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                Text { text: root.weatherData ? Math.round(root.weatherData.current.wind_speed_10m) + " km/h" : ""; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary }
                            }
                            Item { Layout.fillWidth: true }
                            ColumnLayout {
                                spacing: 2
                                Text { text: "最高 / 最低"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                Text { text: root.weatherData && root.weatherData.daily ? root.formatTemp(root.weatherData.daily.temperature_2m_max[0]) + " / " + root.formatTemp(root.weatherData.daily.temperature_2m_min[0]) : ""; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM

                            Text { text: "\uf185"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: Theme.primary }
                            Text { text: root.weatherData && root.weatherData.daily ? root.weatherData.daily.sunrise[0].split("T")[1] : ""; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary }
                            Item { width: Theme.spacingM }
                            Text { text: "\uf186"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: Theme.textMuted }
                            Text { text: root.weatherData && root.weatherData.daily ? root.weatherData.daily.sunset[0].split("T")[1] : ""; font.pixelSize: Theme.fontSizeS; color: Theme.textSecondary }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        Text { text: "7 天预报"; font.pixelSize: Theme.fontSizeM; font.weight: Font.DemiBold; color: Theme.textPrimary }

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingS

                            Repeater {
                                model: root.weatherData && root.weatherData.daily ? Math.min(7, root.weatherData.daily.time.length) : 0

                                Rectangle {
                                    Layout.fillWidth: true; height: 90; radius: Theme.radiusM
                                    color: index === 0 ? Theme.alpha(Theme.primary, 0.15) : Theme.surface
                                    border.color: index === 0 ? Theme.primary : Theme.outline; border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingXS
                                        Text { text: root.getDayName(root.weatherData.daily.time[index], index); font.pixelSize: Theme.fontSizeXS; font.weight: Font.Medium; color: index === 0 ? Theme.primary : Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: root.getWeatherIcon(root.weatherData.daily.weather_code[index]); font.family: "Weather Icons"; font.pixelSize: 20; color: Theme.primary; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: Math.round(root.weatherData.daily.temperature_2m_max[index]) + "\u00b0"; font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter; spacing: 2
                                            Text { text: Math.round(root.weatherData.daily.temperature_2m_min[index]) + "\u00b0"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                            Text { visible: root.weatherData.daily.precipitation_probability_max[index] > 0; text: root.weatherData.daily.precipitation_probability_max[index] + "%"; font.pixelSize: 9; color: Theme.primary }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Settings overlay
                Rectangle {
                    visible: root.showSettings
                    anchors.fill: parent
                    color: Theme.background
                    radius: Theme.radiusL

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXL
                        spacing: Theme.spacingL

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "位置设置"
                                font.pixelSize: Theme.fontSizeL
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 28; height: 28; radius: Theme.radiusM
                                color: closeSetMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: Theme.textSecondary
                                }
                                MouseArea {
                                    id: closeSetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.showSettings = false; root.searchResults = [] }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        // Current location
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM
                            Text {
                                text: "\uf041"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 16
                                color: Theme.primary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "当前位置"
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: root.locationName
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textPrimary
                                }
                            }
                        }

                        // Auto locate button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: Theme.radiusM
                            color: autoLocMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                            border.color: Theme.outline
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM
                                Text {
                                    text: root.locating ? "\uf110" : "\uf192"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: Theme.primary
                                    RotationAnimation on rotation {
                                        running: root.locating
                                        from: 0; to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }
                                }
                                Text {
                                    text: root.locating ? "定位中..." : "自动定位"
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textPrimary
                                }
                            }
                            MouseArea {
                                id: autoLocMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (!root.locating) root.geolocate()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        // Search input
                        Text {
                            text: "搜索城市"
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.textMuted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: Theme.radiusM
                            color: Theme.surface
                            border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
                            border.width: searchInput.activeFocus ? 2 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS
                                Text {
                                    text: root.searching ? "\uf110" : "\uf002"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: Theme.textMuted
                                    RotationAnimation on rotation {
                                        running: root.searching
                                        from: 0; to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }
                                }
                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textPrimary
                                    clip: true
                                    onTextChanged: {
                                        root.searchQuery = text
                                        searchTimer.restart()
                                    }
                                    Text {
                                        anchors.fill: parent
                                        text: "输入城市名称..."
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textMuted
                                        visible: !searchInput.text
                                    }
                                }
                            }
                        }

                        Timer {
                            id: searchTimer
                            interval: 500
                            onTriggered: root.searchLocation(root.searchQuery)
                        }

                        // Search results
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: resultsCol.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: resultsCol
                                width: parent.width
                                spacing: Theme.spacingS

                                Repeater {
                                    model: root.searchResults

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 50
                                        radius: Theme.radiusM
                                        color: resultMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.outline
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM
                                            Text {
                                                text: "\uf041"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 14
                                                color: Theme.textMuted
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: modelData.name
                                                    font.pixelSize: Theme.fontSizeM
                                                    color: Theme.textPrimary
                                                }
                                                Text {
                                                    text: (modelData.admin1 || "") + (modelData.country ? ", " + modelData.country : "")
                                                    font.pixelSize: Theme.fontSizeXS
                                                    color: Theme.textMuted
                                                    visible: text !== ""
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: resultMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectLocation(modelData)
                                        }
                                    }
                                }

                                // Empty hint
                                Text {
                                    visible: root.searchResults.length === 0 && root.searchQuery.length >= 2 && !root.searching
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Theme.spacingL
                                    text: "未找到结果"
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
