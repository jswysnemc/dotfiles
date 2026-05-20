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
        if (code === 0) return "晴朗"
        if (code <= 3) return "多云"
        if (code <= 48) return "有雾"
        if (code <= 67) return "小雨"
        if (code <= 77) return "小雪"
        return "雷暴"
    }

    function formatTemp(t) {
        if (!useCelsius) t = t * 9 / 5 + 32
        return Math.round(t) + "°" + (useCelsius ? "C" : "F")
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

    function closeWithAnimation() {
        root.blurActive = false
        exitAnimation.start()
    }

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-weather"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: root.blurActive ? panelRect : null
                radius: Theme.radiusXL + 4
            }
            Connections {
                target: root
                function onBlurActiveChanged() { blurRegion.changed() }
                function onPanelScaleChanged() { blurRegion.changed() }
                function onPanelYChanged() { blurRegion.changed() }
            }
            Connections {
                target: panelRect
                function onXChanged() { blurRegion.changed() }
                function onYChanged() { blurRegion.changed() }
                function onWidthChanged() { blurRegion.changed() }
                function onHeightChanged() { blurRegion.changed() }
            }
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
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
                width: 420
                height: root.showSettings ? 520 : panelRect.implicitHeight
                color: Theme.alpha(Theme.background, 0.88)
                radius: Theme.radiusXL + 4
                border.color: Theme.glassBorder
                border.width: 1.5
                implicitHeight: mainCol.implicitHeight + Theme.spacingXL * 2
                clip: true

                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: root.panelOpacity

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 1.0
                    shadowVerticalOffset: 16
                }

                // 玻璃内描边
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 30
                }

                // Aurora 背景
                AuroraBackground {
                    anchors.fill: parent
                    intensity: 0.32
                    orbScale: 1.4
                    z: 0
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL
                    z: 5

                    // Loading
                    ColumnLayout {
                        visible: root.loading && root.weatherData === null
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        Layout.alignment: Qt.AlignCenter
                        spacing: Theme.spacingM
                        Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.primary; Layout.alignment: Qt.AlignHCenter
                            RotationAnimation on rotation { running: true; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                        }
                        Text { text: "正在获取天气..."; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                    }

                    // Error
                    ColumnLayout {
                        visible: !root.loading && root.errorMsg !== "" && root.weatherData === null
                        Layout.fillWidth: true
                        spacing: Theme.spacingM
                        Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.error; Layout.alignment: Qt.AlignHCenter }
                        Text { text: root.errorMsg; font.pixelSize: Theme.fontSizeM; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter; width: 96; height: 36; radius: Theme.radiusPill
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.primary }
                                GradientStop { position: 1.0; color: Theme.secondary }
                            }
                            Text { anchors.centerIn: parent; text: "重试"; font.pixelSize: Theme.fontSizeM; font.bold: true; color: "#ffffff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fetchWeather() }
                        }
                    }

                    // ===== 主内容 =====
                    ColumnLayout {
                        visible: root.weatherData !== null
                        Layout.fillWidth: true
                        spacing: Theme.spacingL

                        // === HERO ===
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 160

                            // 半透明大图标做背景
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: -6
                                text: root.weatherData ? root.getWeatherIcon(root.weatherData.current.weather_code) : ""
                                font.family: "Weather Icons"
                                font.pixelSize: 150
                                color: Theme.alpha(Theme.primary, 0.55)
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: -10

                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: root.weatherData ? Math.round(root.useCelsius ? root.weatherData.current.temperature_2m : root.weatherData.current.temperature_2m * 9 / 5 + 32) : ""
                                        font.pixelSize: 104
                                        font.weight: Font.Black
                                        font.letterSpacing: -5
                                        color: Theme.textPrimary
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.topMargin: 18
                                        text: "°" + (root.useCelsius ? "C" : "F")
                                        font.pixelSize: 32
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                Text {
                                    text: root.weatherData ? root.getWeatherDesc(root.weatherData.current.weather_code) : ""
                                    font.pixelSize: Theme.fontSizeL
                                    font.weight: Font.Medium
                                    color: Theme.textSecondary
                                }
                            }
                        }

                        // === 位置 + 刷新 ===
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: Theme.radiusPill
                                color: Theme.alpha(Theme.surface, 0.7)
                                border.color: locChipMa.containsMouse ? Theme.primary : Theme.glassBorder
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingS
                                    Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.locationName
                                        font.pixelSize: Theme.fontSizeS
                                        font.weight: Font.Medium
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }
                                    Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 11; color: Theme.textMuted }
                                }
                                MouseArea {
                                    id: locChipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showSettings = true
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 34; Layout.preferredHeight: 34
                                radius: 17
                                color: refreshMa.containsMouse ? Theme.alpha(Theme.primary, 0.2) : Theme.alpha(Theme.surface, 0.7)
                                border.color: Theme.glassBorder
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 13
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
                                        root.cachedTime = 0
                                        root.fetchWeather()
                                    }
                                }
                            }
                        }

                        // === Bento 指标 ===
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: Theme.spacingS
                            columnSpacing: Theme.spacingS

                            StatTile {
                                icon: ""
                                label: "体感"
                                value: root.weatherData ? root.formatTemp(root.weatherData.current.apparent_temperature) : "-"
                                tone: Theme.warning
                            }
                            StatTile {
                                icon: ""
                                label: "湿度"
                                value: root.weatherData ? root.weatherData.current.relative_humidity_2m + "%" : "-"
                                tone: Theme.tertiary
                            }
                            StatTile {
                                icon: ""
                                label: "风速"
                                value: root.weatherData ? Math.round(root.weatherData.current.wind_speed_10m) + " km/h" : "-"
                                tone: Theme.secondary
                            }
                            StatTile {
                                icon: ""
                                label: "日出"
                                value: root.weatherData && root.weatherData.daily ? root.weatherData.daily.sunrise[0].split("T")[1] : "-"
                                tone: Theme.primary
                            }
                            StatTile {
                                icon: ""
                                label: "日落"
                                value: root.weatherData && root.weatherData.daily ? root.weatherData.daily.sunset[0].split("T")[1] : "-"
                                tone: Theme.alpha(Theme.primary, 0.7)
                            }
                            StatTile {
                                icon: ""
                                label: "高/低"
                                value: root.weatherData && root.weatherData.daily ? Math.round(root.weatherData.daily.temperature_2m_max[0]) + "°/" + Math.round(root.weatherData.daily.temperature_2m_min[0]) + "°" : "-"
                                tone: Theme.error
                            }
                        }

                        // === 7 天预报 ===
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "7 天预报"
                                    font.pixelSize: Theme.fontSizeM
                                    font.weight: Font.DemiBold
                                    color: Theme.textPrimary
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 36; height: 4
                                    radius: 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Theme.primary }
                                        GradientStop { position: 1.0; color: Theme.tertiary }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: root.weatherData && root.weatherData.daily ? Math.min(7, root.weatherData.daily.time.length) : 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 102
                                        radius: Theme.radiusM
                                        color: index === 0 ? Theme.alpha(Theme.primary, 0.18) : Theme.alpha(Theme.surface, 0.7)
                                        border.color: index === 0 ? Theme.primary : Theme.alpha(Theme.outline, 0.3)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingXS
                                            Text { text: root.getDayName(root.weatherData.daily.time[index], index); font.pixelSize: Theme.fontSizeXS; font.weight: Font.Medium; color: index === 0 ? Theme.primary : Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: root.getWeatherIcon(root.weatherData.daily.weather_code[index]); font.family: "Weather Icons"; font.pixelSize: 22; color: index === 0 ? Theme.primary : Theme.textSecondary; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: Math.round(root.weatherData.daily.temperature_2m_max[index]) + "°"; font.pixelSize: Theme.fontSizeM; font.weight: Font.Bold; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: Math.round(root.weatherData.daily.temperature_2m_min[index]) + "°"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
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
                    color: Theme.alpha(Theme.background, 0.97)
                    radius: parent.radius
                    z: 40

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXL
                        spacing: Theme.spacingL

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
                                width: 28; height: 28; radius: 14
                                color: closeSetMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                Text { anchors.centerIn: parent; text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: Theme.textSecondary }
                                MouseArea { id: closeSetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.showSettings = false; root.searchResults = [] } }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM
                            Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 16; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "当前位置"; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                Text { text: root.locationName; font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
                            }
                        }

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
                                    text: root.locating ? "" : ""
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: Theme.primary
                                    RotationAnimation on rotation { running: root.locating; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                                }
                                Text { text: root.locating ? "定位中..." : "自动定位"; font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
                            }
                            MouseArea { id: autoLocMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!root.locating) root.geolocate() }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        Text { text: "搜索城市"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }

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
                                    text: root.searching ? "" : ""
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: Theme.textMuted
                                    RotationAnimation on rotation { running: root.searching; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                                }
                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textPrimary
                                    clip: true
                                    onTextChanged: { root.searchQuery = text; searchTimer.restart() }
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
                                            Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: Theme.textMuted }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: modelData.name; font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
                                                Text { text: (modelData.admin1 || "") + (modelData.country ? ", " + modelData.country : ""); font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted; visible: text !== "" }
                                            }
                                        }
                                        MouseArea { id: resultMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectLocation(modelData) }
                                    }
                                }

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

            // Bento 指标单元
            component StatTile: Rectangle {
                property string icon: ""
                property string label: ""
                property string value: ""
                property color tone: Theme.primary

                Layout.fillWidth: true
                implicitHeight: 56
                radius: Theme.radiusM
                color: Theme.alpha(Theme.surface, 0.65)
                border.color: Theme.alpha(tone, 0.3)
                border.width: 1

                Rectangle {
                    width: 3
                    height: parent.height * 0.6
                    radius: 1.5
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.tone
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingS
                    spacing: 0

                    RowLayout {
                        spacing: 4
                        Text {
                            text: parent.parent.parent.icon
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 10
                            color: parent.parent.parent.tone
                        }
                        Text {
                            text: parent.parent.parent.label
                            font.pixelSize: 9
                            color: Theme.textMuted
                            font.letterSpacing: 0.5
                        }
                    }
                    Text {
                        text: parent.parent.value
                        font.pixelSize: Theme.fontSizeM
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
