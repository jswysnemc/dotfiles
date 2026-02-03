import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

// Minimalist Lockscreen - Left/Right Split Layout, Centered Design
// Left: Time, Date, Weather, Media | Right: Login Area

ShellRoot {
    id: root

    // ==================== Configuration ====================
    property int graceDuration: {
        var envTimeout = Quickshell.env("LOCK_GRACE_TIMEOUT")
        var t = parseInt(envTimeout)
        return (!isNaN(t) && t >= 0) ? t : 5
    }

    property string phase: graceDuration > 0 ? "grace" : "locked"
    property int graceRemaining: graceDuration
    property bool inputEnabled: false
    property point lastMousePos: Qt.point(-1, -1)

    // Grace period animation properties
    property real graceProgress: 1.0 - (graceRemaining / graceDuration)
    property real smoothGraceProgress: 0.0
    property bool isTransitioning: false
    property real ringScale: 1.0
    property real lockIconScale: 0.0
    property real transitionFade: 0.0

    Behavior on smoothGraceProgress {
        NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
    }

    onGraceProgressChanged: smoothGraceProgress = graceProgress

    // ==================== Theme Colors ====================
    readonly property color primaryColor: "#3b82f6"
    readonly property color secondaryColor: "#8b5cf6"
    readonly property color errorColor: "#ef4444"
    readonly property color textColor: "#ffffff"
    readonly property color textMuted: Qt.rgba(1, 1, 1, 0.7)
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.5)
    readonly property color cardBg: Qt.rgba(0, 0, 0, 0.35)
    readonly property color cardBorder: Qt.rgba(255, 255, 255, 0.1)

    // ==================== Auth State ====================
    property bool authInProgress: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string userName: Quickshell.env("USER") || "User"
    property string homeDir: Quickshell.env("HOME") || "/home"
    property bool virtualKeyboardVisible: false

    // ==================== Time Properties ====================
    property string currentTime: ""
    property string currentDate: ""
    property string lunarDate: ""
    property string lunarYear: ""
    property string festival: ""
    property string wallpaperPath: ""
    property string screenshotPath: ""

    // ==================== Weather Properties ====================
    property var weatherData: null
    property bool weatherLoading: false
    property string weatherError: ""
    property real latitude: 39.9042
    property real longitude: 116.4074
    property string locationName: "Beijing"
    readonly property string weatherConfigPath: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/quickshell/weather/config.json"
    readonly property string weatherCachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/weather/cache.json"

    // ==================== Media Properties ====================
    property var playersList: []
    property int currentPlayerIndex: 0
    property var activePlayer: {
        if (playersList.length === 0) return null
        if (currentPlayerIndex >= playersList.length) currentPlayerIndex = 0
        return playersList[currentPlayerIndex]
    }
    property bool hasPlayer: activePlayer !== null
    property bool isPlaying: false
    // Media properties - manually managed to ensure proper updates on track change
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string artUrl: ""
    property real mediaPosition: 0
    property real mediaLength: 0

    function updateMediaProperties() {
        if (!hasPlayer || !activePlayer) {
            trackTitle = ""
            trackArtist = ""
            trackAlbum = ""
            artUrl = ""
            mediaPosition = 0
            mediaLength = 0
            return
        }
        trackTitle = activePlayer.trackTitle || ""
        trackArtist = activePlayer.trackArtist || ""
        trackAlbum = activePlayer.trackAlbum || ""
        artUrl = activePlayer.trackArtUrl || ""
        mediaLength = activePlayer.length !== undefined ? activePlayer.length : 0
        mediaPosition = activePlayer.position !== undefined ? activePlayer.position : 0
    }

    function updateMediaPosition() {
        if (hasPlayer && activePlayer) {
            mediaPosition = activePlayer.position !== undefined ? activePlayer.position : 0
        }
    }

    // Lyrics
    property var lyricsLines: []
    property bool lyricsLoaded: false
    property string currentLyric: ""
    property string nextLyric: ""
    property int currentLyricIndex: -1
    property string lastFetchedTrackKey: ""
    property string playerctlName: {
        if (!activePlayer || !activePlayer.dbusName) return ""
        var name = activePlayer.dbusName
        var prefix = "org.mpris.MediaPlayer2."
        if (name.startsWith(prefix)) {
            return name.substring(prefix.length)
        }
        return name
    }
    property string trackKey: trackTitle + "||" + trackArtist + "||" + trackAlbum + "||" + playerctlName

    // ==================== Timers ====================

    Timer {
        id: inputDelayTimer
        interval: 800
        running: phase === "grace"
        onTriggered: inputEnabled = true
    }

    Timer {
        id: graceTimer
        interval: 1000
        repeat: true
        running: phase === "grace" && !isTransitioning
        onTriggered: {
            graceRemaining--
            if (graceRemaining <= 0) {
                triggerTransition()
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            currentTime = Qt.formatTime(now, "HH:mm")
            var weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
            currentDate = Qt.formatDate(now, "M月d日 ") + weekdays[now.getDay()]
        }
    }

    Timer {
        interval: 500
        running: hasPlayer && phase === "locked"
        repeat: true
        onTriggered: {
            if (activePlayer) {
                updateMediaPosition()
                if (isPlaying) updateCurrentLyric()
            }
        }
    }

    Timer {
        interval: 100
        running: isPlaying && lyricsLoaded && lyricsLines.length > 0
        repeat: true
        onTriggered: updateCurrentLyric()
    }

    Timer {
        id: lyricsFetchTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (shouldFetchLyrics()) {
                fetchLyrics()
            }
        }
    }

    Timer {
        interval: 1000
        running: phase === "locked"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            refreshPlayersList()
            updateMediaProperties()
            updatePlayingState()
            if (activePlayer) {
                scheduleLyricsFetch()
            }
        }
    }

    // ==================== Media Functions ====================

    function refreshPlayersList() {
        var list = []
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            list.push(players[i])
        }
        playersList = list
    }

    function updatePlayingState() {
        isPlaying = hasPlayer && activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    }

    function formatTime(s) {
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function playPause() {
        if (hasPlayer) {
            activePlayer.togglePlaying()
            Qt.callLater(updatePlayingState)
        }
    }

    function nextTrack() {
        if (hasPlayer && activePlayer.canGoNext) {
            // 记录旧曲目 key，清空歌词状态
            trackChangeChecker.oldTrackKey = trackKey
            trackChangeChecker.attempts = 0
            resetLyricsState()

            activePlayer.next()
            trackChangeChecker.start()
        }
    }

    function previousTrack() {
        if (hasPlayer && activePlayer.canGoPrevious) {
            // 记录旧曲目 key，清空歌词状态
            trackChangeChecker.oldTrackKey = trackKey
            trackChangeChecker.attempts = 0
            resetLyricsState()

            activePlayer.previous()
            trackChangeChecker.start()
        }
    }

    Timer {
        id: trackChangeChecker
        interval: 150
        repeat: true
        property string oldTrackKey: ""
        property int attempts: 0

        onTriggered: {
            attempts++

            // 直接从 activePlayer 读取最新值
            var newTitle = activePlayer ? (activePlayer.trackTitle || "") : ""
            var newArtist = activePlayer ? (activePlayer.trackArtist || "") : ""
            var newAlbum = activePlayer ? (activePlayer.trackAlbum || "") : ""
            var newArtUrl = activePlayer ? (activePlayer.trackArtUrl || "") : ""
            var newLength = activePlayer ? (activePlayer.length !== undefined ? activePlayer.length : 0) : 0
            var newKey = newTitle + "||" + newArtist + "||" + newAlbum + "||" + playerctlName

            // 如果曲目信息变了，或者尝试了太多次（2秒），就停止
            if (newKey !== oldTrackKey || attempts > 13) {
                stop()

                // 更新所有媒体属性
                trackTitle = newTitle
                trackArtist = newArtist
                trackAlbum = newAlbum
                artUrl = newArtUrl
                mediaLength = newLength
                mediaPosition = activePlayer ? (activePlayer.position !== undefined ? activePlayer.position : 0) : 0

                updatePlayingState()

                scheduleLyricsFetch()
            }
        }
    }

    Connections {
        target: Mpris.players
        function onObjectInsertedPost() { root.refreshPlayersList() }
        function onObjectRemovedPost() { root.refreshPlayersList() }
    }

    Connections {
        target: root.activePlayer
        function onPlaybackStateChanged() { root.updatePlayingState() }
        function onTrackTitleChanged() {
            root.updateMediaProperties()
            root.scheduleLyricsFetch()
        }
        function onTrackArtistChanged() {
            root.updateMediaProperties()
            root.scheduleLyricsFetch()
        }
        function onTrackArtUrlChanged() { root.updateMediaProperties() }
        function onLengthChanged() {
            root.updateMediaProperties()
            root.scheduleLyricsFetch()
        }
        function onTrackAlbumChanged() {
            root.updateMediaProperties()
            root.scheduleLyricsFetch()
        }
    }

    onActivePlayerChanged: {
        updateMediaProperties()
        updatePlayingState()
        if (activePlayer) {
            scheduleLyricsFetch()
        }
    }

    // ==================== Lyrics Functions ====================

    function resetLyricsState() {
        lyricsLoaded = false
        lyricsLines = []
        currentLyric = ""
        nextLyric = ""
        currentLyricIndex = -1
    }

    function shouldFetchLyrics() {
        return trackTitle && trackKey !== lastFetchedTrackKey
    }

    function scheduleLyricsFetch() {
        if (!shouldFetchLyrics()) return
        resetLyricsState()
        lyricsFetchTimer.restart()
    }

    Process {
        id: lyricsFetcher
        command: ["echo"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    if (data.success && data.synced && data.lines) {
                        root.lyricsLines = data.lines
                        root.lyricsLoaded = true
                        root.updateCurrentLyric()
                    } else {
                        root.lyricsLoaded = false
                    }
                } catch (e) {
                    root.lyricsLoaded = false
                }
            }
        }
    }

    function fetchLyrics() {
        if (!trackTitle) return
        lastFetchedTrackKey = trackKey
        resetLyricsState()

        var scriptPath = homeDir + "/.config/quickshell/media/lyrics_fetcher.py"
        var uvPath = "/usr/bin/uv"
        var rootDir = homeDir + "/.config/quickshell"

        lyricsFetcher.command = [uvPath, "run", "--directory", rootDir, scriptPath, "fetch",
            trackTitle, trackArtist || "", trackAlbum || "", mediaLength > 0 ? mediaLength.toString() : "0", playerctlName || ""]
        lyricsFetcher.running = true
    }

    function updateCurrentLyric() {
        if (!lyricsLoaded || lyricsLines.length === 0) return

        let pos = mediaPosition
        let newIndex = -1

        for (let i = 0; i < lyricsLines.length; i++) {
            if (lyricsLines[i].time <= pos) {
                newIndex = i
            } else {
                break
            }
        }

        if (newIndex !== currentLyricIndex) {
            currentLyricIndex = newIndex
            if (newIndex >= 0) {
                currentLyric = lyricsLines[newIndex].text
                nextLyric = (newIndex + 1 < lyricsLines.length) ? lyricsLines[newIndex + 1].text : ""
            } else if (lyricsLines.length > 0) {
                currentLyric = ""
                nextLyric = lyricsLines[0].text
            }
        }
    }

    // ==================== Weather Functions ====================

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
        return Math.round(t) + "\u00b0"
    }

    Process {
        id: weatherCacheLoader
        command: ["cat", root.weatherCachePath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let cache = JSON.parse(text)
                    if (cache.data) {
                        root.weatherData = cache.data
                    }
                } catch (e) {}
                weatherConfigLoader.running = true
            }
        }
        onExited: (code) => { if (code !== 0) weatherConfigLoader.running = true }
    }

    Process {
        id: weatherConfigLoader
        command: ["cat", root.weatherConfigPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let cfg = JSON.parse(text)
                    if (cfg.latitude) root.latitude = cfg.latitude
                    if (cfg.longitude) root.longitude = cfg.longitude
                    if (cfg.locationName) root.locationName = cfg.locationName
                } catch (e) {}
                if (!root.weatherData) {
                    weatherFetcher.running = true
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && !root.weatherData) {
                weatherFetcher.running = true
            }
        }
    }

    Process {
        id: weatherFetcher
        command: ["curl", "-s", "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherLoading = false
                try {
                    root.weatherData = JSON.parse(text)
                    root.weatherError = ""
                } catch (e) {
                    if (!root.weatherData) root.weatherError = "获取失败"
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.weatherLoading = false
                if (!root.weatherData) root.weatherError = "网络错误"
            }
        }
        onRunningChanged: {
            if (running) root.weatherLoading = true
        }
    }

    // ==================== Processes ====================

    Process {
        id: lunarProcess
        command: [homeDir + "/.config/quickshell/.venv/bin/python",
                  homeDir + "/.config/quickshell/lockscreen/lunar_info.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var info = JSON.parse(data)
                    if (info.hasLunar) {
                        lunarDate = info.lunarFull || ""
                        lunarYear = (info.ganzhiYear || "") + (info.zodiac ? "年 " + info.zodiac + "年" : "")
                        festival = info.festival || ""
                    }
                } catch (e) {
                    console.log("Failed to parse lunar info:", e)
                }
            }
        }
    }

    Process {
        id: wallpaperProcess
        command: ["readlink", "-f", homeDir + "/.cache/current_wallpaper"]
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (path) {
                    wallpaperPath = "file://" + path
                }
            }
        }
    }

    Process {
        id: screenshotProcess
        command: ["grim", "/tmp/lockscreen-screenshot.png"]
        onRunningChanged: {
            if (!running && screenshotPath === "") {
                screenshotPath = "file:///tmp/lockscreen-screenshot.png?" + Date.now()
            }
        }
    }

    Image {
        id: screenshotLoader
        source: screenshotPath
        asynchronous: false
        visible: false
        onStatusChanged: {
            if (status === Image.Ready && !sessionLock.locked) {
                sessionLock.locked = true
            }
        }
    }

    property bool screenshotReady: screenshotLoader.status === Image.Ready

    Component.onCompleted: {
        lunarProcess.running = true
        wallpaperProcess.running = true
        screenshotProcess.running = true
        weatherCacheLoader.running = true
        refreshPlayersList()
    }

    // ==================== PAM Authentication ====================

    PamContext {
        id: pamFace
        config: "sudo"
        user: userName

        onActiveChanged: {
            if (active) {
                authInProgress = true
                statusMessage = "正在进行人脸识别..."
            }
        }

        onPamMessage: {
            if (pamFace.responseRequired) {
                if (pamFace.responseVisible) {
                    pamFace.respond(userName)
                } else {
                    pamFace.abort()
                    statusMessage = "人脸识别失败，请输入密码"
                    authInProgress = false
                }
            } else {
                statusMessage = pamFace.message
            }
        }

        onCompleted: function(result) {
            authInProgress = false
            statusMessage = ""
            if (result === PamResult.Success) {
                sessionLock.locked = false
            } else {
                statusMessage = "请输入密码"
            }
        }

        onError: function(err) {
            authInProgress = false
            statusMessage = "请输入密码"
        }
    }

    PamContext {
        id: pamPassword
        config: "qs-lock"
        user: userName

        onActiveChanged: {
            if (active) {
                authInProgress = true
                statusMessage = "正在验证密码..."
            }
        }

        onPamMessage: {
            if (pamPassword.responseRequired) {
                if (pendingPassword.length > 0) {
                    pamPassword.respond(pendingPassword)
                    pendingPassword = ""
                    return
                }
                if (pamPassword.responseVisible) {
                    pamPassword.respond(userName)
                } else {
                    statusMessage = pamPassword.message || "请输入密码"
                    authInProgress = false
                }
            } else {
                statusMessage = pamPassword.message
            }
        }

        onCompleted: function(result) {
            authInProgress = false
            statusMessage = ""
            if (result === PamResult.Success) {
                sessionLock.locked = false
            } else {
                errorMessage = "密码错误"
                errorClearTimer.restart()
            }
        }

        onError: function(err) {
            authInProgress = false
            statusMessage = ""
            errorMessage = "认证错误"
            errorClearTimer.restart()
        }
    }

    property string pendingPassword: ""

    Timer {
        id: errorClearTimer
        interval: 3000
        onTriggered: errorMessage = ""
    }

    // ==================== Transition Animation ====================
    function triggerTransition() {
        graceTimer.stop()
        isTransitioning = true
        transitionSequence.start()
    }

    SequentialAnimation {
        id: transitionSequence

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "ringScale"
                from: 1.0
                to: 0.0
                duration: 300
                easing.type: Easing.InBack
                easing.overshoot: 1.7
            }
        }

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: root
                    property: "lockIconScale"
                    from: 0.0
                    to: 1.15
                    duration: 200
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: root
                    property: "lockIconScale"
                    to: 1.0
                    duration: 150
                    easing.type: Easing.InOutQuad
                }
            }

            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation {
                    target: root
                    property: "transitionFade"
                    from: 0.0
                    to: 1.0
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }
        }

        PauseAnimation { duration: 200 }

        ScriptAction {
            script: {
                phase = "locked"
                isTransitioning = false
            }
        }
    }

    function dismiss() {
        if (phase === "grace" && !isTransitioning) {
            graceTimer.stop()
            sessionLock.locked = false
        }
    }

    // ==================== Session Lock ====================
    WlSessionLock {
        id: sessionLock
        locked: graceDuration === 0

        onLockedChanged: {
            if (!locked) {
                Qt.quit()
            }
        }

        surface: Component {
            WlSessionLockSurface {
                id: lockSurface
                color: "#000000"

                // Blurred screenshot for grace phase
                MultiEffect {
                    anchors.fill: parent
                    source: screenshotLoader
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.6
                    blurMax: 64
                    visible: phase === "grace"
                }

                // Wallpaper background (locked phase)
                Image {
                    id: wallpaperImage
                    anchors.fill: parent
                    source: wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: phase === "locked"

                    Rectangle {
                        anchors.fill: parent
                        visible: wallpaperImage.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#1a1a2e" }
                            GradientStop { position: 0.5; color: "#16213e" }
                            GradientStop { position: 1.0; color: "#0f0f23" }
                        }
                    }
                }

                // Dark overlay
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, phase === "grace" ? 0.2 : 0.55)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                // ==================== Grace Phase UI ====================
                Item {
                    id: graceUI
                    anchors.fill: parent
                    opacity: phase === "grace" || isTransitioning ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        enabled: phase === "grace" && !isTransitioning
                        onPositionChanged: function(mouse) {
                            if (!inputEnabled || isTransitioning) return
                            if (lastMousePos.x >= 0 && lastMousePos.y >= 0) {
                                var dx = Math.abs(mouse.x - lastMousePos.x)
                                var dy = Math.abs(mouse.y - lastMousePos.y)
                                if (dx > 10 || dy > 10) {
                                    root.dismiss()
                                }
                            }
                            lastMousePos = Qt.point(mouse.x, mouse.y)
                        }
                        onClicked: function(mouse) {
                            if (!inputEnabled || isTransitioning) return
                            if (mouse.button === Qt.RightButton) {
                                root.triggerTransition()
                            } else {
                                root.dismiss()
                            }
                        }
                        onWheel: if (inputEnabled && !isTransitioning) root.dismiss()
                    }

                    Keys.onPressed: function(event) {
                        if (!inputEnabled || isTransitioning) return
                        if (event.key === Qt.Key_L && (event.modifiers & Qt.MetaModifier)) {
                            root.triggerTransition()
                            event.accepted = true
                            return
                        }
                        root.dismiss()
                    }
                    focus: phase === "grace"

                    // Center ring progress
                    Item {
                        anchors.centerIn: parent
                        width: 200
                        height: 200

                        Canvas {
                            id: ringCanvas
                            anchors.centerIn: parent
                            width: 140
                            height: 140

                            property real prog: smoothGraceProgress
                            property real scale: ringScale

                            onProgChanged: requestPaint()
                            onScaleChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                var cx = width / 2
                                var cy = height / 2
                                var radius = 60 * scale
                                var thickness = 3

                                if (radius < 1) return

                                ctx.beginPath()
                                ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                                ctx.lineWidth = thickness
                                ctx.strokeStyle = isTransitioning ? "#FFFFFF" : "rgba(255, 255, 255, 0.08)"
                                ctx.stroke()

                                if (!isTransitioning && prog > 0) {
                                    var startAngle = -Math.PI / 2
                                    var endAngle = startAngle + (Math.PI * 2 * prog)

                                    ctx.beginPath()
                                    ctx.arc(cx, cy, radius, startAngle, endAngle)
                                    ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
                                    ctx.lineWidth = thickness
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }

                                if (isTransitioning && scale > 0.01) {
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                                    ctx.strokeStyle = "#FFFFFF"
                                    ctx.lineWidth = thickness * 1.5
                                    ctx.shadowColor = "rgba(255, 255, 255, 0.5)"
                                    ctx.shadowBlur = 10
                                    ctx.stroke()
                                    ctx.shadowBlur = 0
                                }
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            scale: lockIconScale
                            opacity: lockIconScale > 0 ? 1 : 0
                            visible: isTransitioning

                            Canvas {
                                anchors.fill: parent

                                function drawRoundedRect(ctx, x, y, w, h, r) {
                                    ctx.beginPath()
                                    ctx.moveTo(x + r, y)
                                    ctx.lineTo(x + w - r, y)
                                    ctx.arcTo(x + w, y, x + w, y + r, r)
                                    ctx.lineTo(x + w, y + h - r)
                                    ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                                    ctx.lineTo(x + r, y + h)
                                    ctx.arcTo(x, y + h, x, y + h - r, r)
                                    ctx.lineTo(x, y + r)
                                    ctx.arcTo(x, y, x + r, y, r)
                                    ctx.closePath()
                                }

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    var cx = width / 2
                                    var cy = height / 2

                                    ctx.fillStyle = "#FFFFFF"
                                    ctx.strokeStyle = "#FFFFFF"
                                    ctx.lineWidth = 4
                                    ctx.lineCap = "round"

                                    var bodyW = 28
                                    var bodyH = 22
                                    var bodyR = 4
                                    var bodyY = cy - 2

                                    drawRoundedRect(ctx, cx - bodyW/2, bodyY, bodyW, bodyH, bodyR)
                                    ctx.fill()

                                    ctx.beginPath()
                                    ctx.arc(cx, bodyY - 2, 8, Math.PI, 0)
                                    ctx.stroke()
                                }

                                Component.onCompleted: requestPaint()
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 120
                        text: graceRemaining + " 秒后自动锁定"
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        font.letterSpacing: 0.5
                        color: Qt.rgba(1, 1, 1, 0.3)
                        opacity: isTransitioning ? 0 : 1
                        visible: !isTransitioning
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 50
                        text: "移动鼠标或按任意键取消 | 右键立即锁定"
                        font.pixelSize: 11
                        font.weight: Font.Light
                        color: Qt.rgba(1, 1, 1, 0.2)
                        opacity: isTransitioning ? 0 : 1
                        visible: !isTransitioning
                    }
                }

                // ==================== Locked Phase UI ====================
                Item {
                    id: lockedUI
                    anchors.fill: parent
                    opacity: phase === "locked" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                    }

                    // ===== Main Container - Centered Left/Right Split =====
                    Row {
                        id: mainContainer
                        anchors.centerIn: parent
                        spacing: 60

                        // ===== Left Panel: Time, Date, Weather, Media =====
                        Column {
                            id: leftPanel
                            spacing: 28
                            width: 380

                            // Time Display
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: currentTime
                                    font.pixelSize: 120
                                    font.weight: Font.ExtraLight
                                    font.letterSpacing: -4
                                    color: root.textColor
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Qt.rgba(0, 0, 0, 0.5)
                                        shadowBlur: 0.3
                                        shadowVerticalOffset: 2
                                    }
                                }

                                // Date with decorative lines
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 16

                                    Rectangle {
                                        width: 32
                                        height: 2
                                        color: root.primaryColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        spacing: 4

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: currentDate
                                            font.pixelSize: 18
                                            font.weight: Font.Normal
                                            font.letterSpacing: 1
                                            color: root.textMuted
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: lunarYear + (lunarDate.length > 0 ? "  " + lunarDate : "")
                                            font.pixelSize: 13
                                            color: root.textDim
                                            visible: lunarDate.length > 0
                                        }
                                    }

                                    Rectangle {
                                        width: 32
                                        height: 2
                                        color: root.primaryColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Festival badge
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: festival.length > 0
                                    width: festivalText.width + 28
                                    height: 28
                                    radius: 14
                                    color: Qt.rgba(251, 191, 36, 0.15)
                                    border.color: Qt.rgba(251, 191, 36, 0.4)
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: "\uf005"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 11
                                            color: "#fbbf24"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            id: festivalText
                                            text: festival
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            color: "#fbbf24"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            // Weather Card
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: weatherRow.implicitWidth + 32
                                height: weatherRow.implicitHeight + 20
                                radius: 14
                                color: root.cardBg
                                border.color: root.cardBorder
                                border.width: 1
                                visible: weatherData !== null

                                Row {
                                    id: weatherRow
                                    anchors.centerIn: parent
                                    spacing: 14

                                    Text {
                                        text: weatherData && weatherData.current ? root.getWeatherIcon(weatherData.current.weather_code) : ""
                                        font.family: "Weather Icons"
                                        font.pixelSize: 28
                                        color: root.primaryColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        Row {
                                            spacing: 8

                                            Text {
                                                text: weatherData && weatherData.current ? root.formatTemp(weatherData.current.temperature_2m) : ""
                                                font.pixelSize: 22
                                                font.weight: Font.Medium
                                                color: root.textColor
                                            }

                                            Text {
                                                text: weatherData && weatherData.current ? root.getWeatherDesc(weatherData.current.weather_code) : ""
                                                font.pixelSize: 13
                                                color: root.textMuted
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 2
                                            }
                                        }

                                        Row {
                                            spacing: 12

                                            Text {
                                                text: weatherData && weatherData.current ? "体感 " + root.formatTemp(weatherData.current.apparent_temperature) : ""
                                                font.pixelSize: 11
                                                color: root.textDim
                                            }

                                            Text {
                                                text: weatherData && weatherData.current ? "湿度 " + weatherData.current.relative_humidity_2m + "%" : ""
                                                font.pixelSize: 11
                                                color: root.textDim
                                            }

                                            Text {
                                                text: root.locationName
                                                font.pixelSize: 11
                                                color: root.textDim
                                                opacity: 0.7
                                            }
                                        }
                                    }
                                }
                            }

                            // Media Card
                            Rectangle {
                                id: mediaCard
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 340
                                height: mediaCardContent.implicitHeight + 28
                                radius: 16
                                color: root.cardBg
                                border.color: root.cardBorder
                                border.width: 1
                                visible: hasPlayer
                                opacity: hasPlayer ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }

                                // Background album art blur
                                Item {
                                    anchors.fill: parent
                                    clip: true
                                    visible: artUrl !== ""
                                    opacity: 0.12

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: -20
                                        source: artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            blurEnabled: true
                                            blurMax: 64
                                            blur: 1.0
                                        }
                                    }
                                }

                                Row {
                                    id: mediaCardContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 14
                                    spacing: 14

                                    // Album art
                                    Rectangle {
                                        width: 72
                                        height: 72
                                        radius: 10
                                        color: Qt.rgba(1, 1, 1, 0.1)

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            source: artUrl
                                            fillMode: Image.PreserveAspectCrop
                                            visible: artUrl !== ""

                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskThresholdMin: 0.5
                                                maskSpreadAtMin: 1.0
                                                maskSource: ShaderEffectSource {
                                                    sourceItem: Rectangle {
                                                        width: 70
                                                        height: 70
                                                        radius: 9
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: artUrl === ""
                                            text: "\uf001"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 24
                                            color: root.textMuted
                                            opacity: 0.5
                                        }

                                        // Playing indicator
                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: -3
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: isPlaying ? "#22c55e" : "#f59e0b"

                                            Text {
                                                anchors.centerIn: parent
                                                text: isPlaying ? "\uf04b" : "\uf04c"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 7
                                                color: "#000"
                                            }
                                        }
                                    }

                                    // Track info and controls
                                    Column {
                                        width: parent.width - 86 - parent.spacing
                                        spacing: 6

                                        // Title and Artist
                                        Column {
                                            width: parent.width
                                            spacing: 1

                                            Text {
                                                width: parent.width
                                                text: trackTitle || "未知曲目"
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                color: root.textColor
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: trackArtist
                                                font.pixelSize: 11
                                                color: root.primaryColor
                                                elide: Text.ElideRight
                                                visible: trackArtist !== ""
                                            }
                                        }

                                        // Lyrics
                                        Column {
                                            width: parent.width
                                            spacing: 1
                                            visible: lyricsLoaded && currentLyric !== ""

                                            Text {
                                                width: parent.width
                                                text: currentLyric
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: root.textMuted
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: nextLyric
                                                font.pixelSize: 9
                                                color: root.textDim
                                                elide: Text.ElideRight
                                                visible: nextLyric !== ""
                                                opacity: 0.6
                                            }
                                        }

                                        // Progress bar
                                        Item {
                                            width: parent.width
                                            height: 16

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 3
                                                radius: 1.5
                                                color: Qt.rgba(1, 1, 1, 0.15)

                                                Rectangle {
                                                    width: mediaLength > 0 ? (mediaPosition / mediaLength) * parent.width : 0
                                                    height: parent.height
                                                    radius: 1.5
                                                    color: root.primaryColor

                                                    Behavior on width {
                                                        NumberAnimation { duration: 100 }
                                                    }
                                                }
                                            }

                                            Text {
                                                anchors.left: parent.left
                                                anchors.bottom: parent.bottom
                                                text: formatTime(mediaPosition)
                                                font.pixelSize: 8
                                                color: root.textDim
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                text: formatTime(mediaLength)
                                                font.pixelSize: 8
                                                color: root.textDim
                                            }
                                        }

                                        // Playback controls
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 16

                                            Rectangle {
                                                width: 26
                                                height: 26
                                                radius: 13
                                                color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                                opacity: activePlayer && activePlayer.canGoPrevious ? 1 : 0.4

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf048"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 11
                                                    color: root.textColor
                                                }

                                                MouseArea {
                                                    id: prevMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: previousTrack()
                                                }
                                            }

                                            Rectangle {
                                                width: 32
                                                height: 32
                                                radius: 16
                                                color: playMa.containsMouse ? Qt.lighter(root.primaryColor, 1.15) : root.primaryColor

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: isPlaying ? "\uf04c" : "\uf04b"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 12
                                                    color: "#000"
                                                }

                                                MouseArea {
                                                    id: playMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: playPause()
                                                }
                                            }

                                            Rectangle {
                                                width: 26
                                                height: 26
                                                radius: 13
                                                color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                                opacity: activePlayer && activePlayer.canGoNext ? 1 : 0.4

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf051"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 11
                                                    color: root.textColor
                                                }

                                                MouseArea {
                                                    id: nextMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: nextTrack()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== Vertical Divider =====
                        Rectangle {
                            id: divider
                            width: 1
                            height: leftPanel.height * 0.7
                            anchors.verticalCenter: parent.verticalCenter
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.2; color: Qt.rgba(1, 1, 1, 0.15) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.2) }
                                GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.15) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // ===== Right Panel: Login Area =====
                        Column {
                            id: rightPanel
                            spacing: 20
                            width: 300
                            anchors.verticalCenter: parent.verticalCenter

                            // Face recognition status
                            property string faceAuthStatus: {
                                if (pamFace.active) return "scanning"
                                if (errorMessage.length > 0) return "failed"
                                return ""
                            }

                            // User avatar with enhanced face recognition animation
                            Item {
                                id: avatarContainer
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 120
                                height: 120

                                // Static outer ring border
                                Rectangle {
                                    id: outerRingBorder
                                    anchors.centerIn: parent
                                    width: 118
                                    height: 118
                                    radius: 59
                                    color: "transparent"
                                    border.width: 3
                                    border.color: {
                                        if (rightPanel.faceAuthStatus === "scanning") return "#60a5fa"
                                        if (rightPanel.faceAuthStatus === "failed") return "#f87171"
                                        return Qt.rgba(1, 1, 1, 0.25)
                                    }

                                    Behavior on border.color { ColorAnimation { duration: 200 } }
                                }

                                // Scanning ring animation (pulsing outward)
                                Rectangle {
                                    id: scanRing
                                    anchors.centerIn: parent
                                    width: parent.width + 16
                                    height: parent.height + 16
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 3
                                    border.color: "#60a5fa"
                                    opacity: 0
                                    visible: rightPanel.faceAuthStatus === "scanning"

                                    SequentialAnimation on opacity {
                                        running: rightPanel.faceAuthStatus === "scanning"
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.8; duration: 600 }
                                        NumberAnimation { to: 0; duration: 600 }
                                    }

                                    SequentialAnimation on scale {
                                        running: rightPanel.faceAuthStatus === "scanning"
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 1.35; duration: 1200 }
                                        NumberAnimation { to: 1.0; duration: 0 }
                                    }
                                }

                                // Second scanning ring (offset timing)
                                Rectangle {
                                    id: scanRing2
                                    anchors.centerIn: parent
                                    width: parent.width + 16
                                    height: parent.height + 16
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: "#60a5fa"
                                    opacity: 0
                                    visible: rightPanel.faceAuthStatus === "scanning"

                                    SequentialAnimation on opacity {
                                        running: rightPanel.faceAuthStatus === "scanning"
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: 400 }
                                        NumberAnimation { to: 0.5; duration: 400 }
                                        NumberAnimation { to: 0; duration: 400 }
                                    }

                                    SequentialAnimation on scale {
                                        running: rightPanel.faceAuthStatus === "scanning"
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: 400 }
                                        NumberAnimation { to: 1.5; duration: 800 }
                                        NumberAnimation { to: 1.0; duration: 0 }
                                    }
                                }

                                // Avatar background circle
                                Rectangle {
                                    id: avatarBg
                                    anchors.centerIn: parent
                                    width: 100
                                    height: 100
                                    radius: 50
                                    color: {
                                        if (rightPanel.faceAuthStatus === "scanning") return "#1e40af"
                                        if (rightPanel.faceAuthStatus === "failed") return "#7f1d1d"
                                        return avatarMouse.containsMouse ? Qt.lighter(root.primaryColor, 1.15) : root.primaryColor
                                    }

                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    // Gradient overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                                            GradientStop { position: 0.5; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.2) }
                                        }
                                    }

                                    // Face icon / scanning icon
                                    Text {
                                        id: avatarIcon
                                        anchors.centerIn: parent
                                        text: {
                                            if (rightPanel.faceAuthStatus === "scanning") return "\uf2f1"
                                            if (rightPanel.faceAuthStatus === "failed") return "\uf057"
                                            return "\uf007"
                                        }
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 42
                                        color: root.textColor

                                        RotationAnimator on rotation {
                                            running: rightPanel.faceAuthStatus === "scanning"
                                            from: 0; to: 360
                                            duration: 2000
                                            loops: Animation.Infinite
                                        }
                                    }

                                    // Click area
                                    MouseArea {
                                        id: avatarMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !pamPassword.active && !pamPassword.responseRequired
                                        onClicked: root.startAuth()
                                    }
                                }

                                // Scanning line animation
                                Rectangle {
                                    id: scanLine
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 80
                                    height: 2
                                    radius: 1
                                    color: "#60a5fa"
                                    opacity: 0.8
                                    visible: rightPanel.faceAuthStatus === "scanning"

                                    SequentialAnimation on y {
                                        running: rightPanel.faceAuthStatus === "scanning"
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 15; to: 105; duration: 1000; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 105; to: 15; duration: 1000; easing.type: Easing.InOutSine }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 0.3; color: "#60a5fa" }
                                            GradientStop { position: 0.7; color: "#60a5fa" }
                                            GradientStop { position: 1.0; color: "transparent" }
                                        }
                                    }
                                }
                            }

                            // Username and status
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: userName
                                    font.pixelSize: 24
                                    font.weight: Font.Medium
                                    font.letterSpacing: 1
                                    color: root.textColor
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: statusMessage
                                    font.pixelSize: 12
                                    color: root.secondaryColor
                                    visible: statusMessage.length > 0
                                }
                            }

                            // Password input
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                height: 52
                                radius: 26
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: passwordField.activeFocus ? root.primaryColor : Qt.rgba(1, 1, 1, 0.15)
                                border.width: passwordField.activeFocus ? 2 : 1

                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 20
                                    spacing: 12

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "\uf023"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 15
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                    }

                                    TextInput {
                                        id: passwordField
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 70
                                        color: root.textColor
                                        font.pixelSize: 14
                                        font.letterSpacing: 2
                                        echoMode: TextInput.Password
                                        clip: true

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Enter password"
                                            color: Qt.rgba(1, 1, 1, 0.35)
                                            font.pixelSize: 13
                                            font.letterSpacing: 0.5
                                            visible: !passwordField.text && !passwordField.activeFocus
                                        }

                                        onAccepted: {
                                            if (text.length > 0) {
                                                root.startAuthWithPassword(text)
                                                text = ""
                                            }
                                        }

                                        Keys.onEscapePressed: {
                                            text = ""
                                            errorMessage = ""
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: pamPassword.active ? "\uf110" : "\uf054"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 14
                                        color: root.primaryColor
                                        visible: passwordField.text.length > 0 || pamPassword.active

                                        RotationAnimator on rotation {
                                            running: pamPassword.active
                                            from: 0; to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -12
                                            enabled: !authInProgress && passwordField.text.length > 0
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.startAuthWithPassword(passwordField.text)
                                                passwordField.text = ""
                                            }
                                        }
                                    }
                                }
                            }

                            // Error message
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: errorMessage.length > 0
                                width: errorText.width + 24
                                height: 28
                                radius: 14
                                color: Qt.rgba(239, 68, 68, 0.15)
                                border.color: Qt.rgba(239, 68, 68, 0.3)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "\uf071"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 11
                                        color: root.errorColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        id: errorText
                                        text: errorMessage
                                        font.pixelSize: 12
                                        color: root.errorColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Hint and keyboard button
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 16
                                visible: !authInProgress && !pamPassword.responseRequired && passwordField.text.length === 0

                                Text {
                                    text: "点击头像进行人脸识别"
                                    font.pixelSize: 11
                                    font.letterSpacing: 0.3
                                    color: Qt.rgba(1, 1, 1, 0.35)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: keyboardBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: root.virtualKeyboardVisible ? root.primaryColor : Qt.rgba(1, 1, 1, 0.2)

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf11c"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 12
                                        color: root.virtualKeyboardVisible ? root.primaryColor : Qt.rgba(1, 1, 1, 0.5)
                                    }

                                    MouseArea {
                                        id: keyboardBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.virtualKeyboardVisible = !root.virtualKeyboardVisible
                                    }
                                }
                            }
                        }
                    }

                    // ===== Bottom Lock Indicator =====
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: virtualKeyboard.visible ? virtualKeyboard.top : parent.bottom
                        anchors.bottomMargin: virtualKeyboard.visible ? 15 : 30
                        text: "\uf023  Locked"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        color: Qt.rgba(1, 1, 1, 0.2)

                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 200 } }
                    }

                    // ===== Virtual Keyboard =====
                    Rectangle {
                        id: virtualKeyboard
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width - 40, 700)
                        height: 290
                        radius: 20
                        color: Qt.rgba(0, 0, 0, 0.75)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        visible: root.virtualKeyboardVisible
                        z: 1000

                        property bool shiftPressed: false
                        property bool capsLock: false

                        // Close button
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 12
                            width: 28
                            height: 28
                            radius: 14
                            color: closeKbArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 12
                                color: root.textColor
                            }

                            MouseArea {
                                id: closeKbArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.virtualKeyboardVisible = false
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            // Number row
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Repeater {
                                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ?
                                           ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+"] :
                                           ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
                                    delegate: Rectangle {
                                        width: 42
                                        height: 40
                                        radius: 8
                                        color: keyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.15)

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.textColor
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: keyMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                passwordField.text += modelData
                                                if (virtualKeyboard.shiftPressed) virtualKeyboard.shiftPressed = false
                                            }
                                        }
                                    }
                                }
                            }

                            // First letter row
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Repeater {
                                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ?
                                           ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "{", "}"] :
                                           ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]"]
                                    delegate: Rectangle {
                                        width: 42
                                        height: 40
                                        radius: 8
                                        color: keyMa2.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.15)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.textColor
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: keyMa2
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                passwordField.text += modelData
                                                if (virtualKeyboard.shiftPressed) virtualKeyboard.shiftPressed = false
                                            }
                                        }
                                    }
                                }
                            }

                            // Second letter row
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Repeater {
                                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ?
                                           ["A", "S", "D", "F", "G", "H", "J", "K", "L", ":", "\""] :
                                           ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"]
                                    delegate: Rectangle {
                                        width: 42
                                        height: 40
                                        radius: 8
                                        color: keyMa3.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.15)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.textColor
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: keyMa3
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                passwordField.text += modelData
                                                if (virtualKeyboard.shiftPressed) virtualKeyboard.shiftPressed = false
                                            }
                                        }
                                    }
                                }
                            }

                            // Third letter row with Shift and Backspace
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                // Shift key
                                Rectangle {
                                    width: 68
                                    height: 40
                                    radius: 8
                                    color: virtualKeyboard.shiftPressed ? root.primaryColor : (shiftMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                                    border.width: 1
                                    border.color: virtualKeyboard.shiftPressed ? Qt.lighter(root.primaryColor, 1.3) : Qt.rgba(1, 1, 1, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Shift"
                                        color: virtualKeyboard.shiftPressed ? "#000" : root.textColor
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: shiftMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: virtualKeyboard.shiftPressed = !virtualKeyboard.shiftPressed
                                    }
                                }

                                Repeater {
                                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ?
                                           ["Z", "X", "C", "V", "B", "N", "M", "<", ">", "?"] :
                                           ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
                                    delegate: Rectangle {
                                        width: 42
                                        height: 40
                                        radius: 8
                                        color: keyMa4.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.15)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.textColor
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: keyMa4
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                passwordField.text += modelData
                                                if (virtualKeyboard.shiftPressed) virtualKeyboard.shiftPressed = false
                                            }
                                        }
                                    }
                                }

                                // Backspace key
                                Rectangle {
                                    width: 68
                                    height: 40
                                    radius: 8
                                    color: bsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u232b"
                                        font.pixelSize: 20
                                        color: root.textColor
                                    }

                                    MouseArea {
                                        id: bsMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (passwordField.text.length > 0) {
                                                passwordField.text = passwordField.text.slice(0, -1)
                                            }
                                        }
                                    }
                                }
                            }

                            // Space row with Caps, Space, Enter
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                // Caps Lock
                                Rectangle {
                                    width: 68
                                    height: 40
                                    radius: 8
                                    color: virtualKeyboard.capsLock ? root.primaryColor : (capsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                                    border.width: 1
                                    border.color: virtualKeyboard.capsLock ? Qt.lighter(root.primaryColor, 1.3) : Qt.rgba(1, 1, 1, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Caps"
                                        color: virtualKeyboard.capsLock ? "#000" : root.textColor
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: capsMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: virtualKeyboard.capsLock = !virtualKeyboard.capsLock
                                    }
                                }

                                // Space bar
                                Rectangle {
                                    width: 320
                                    height: 40
                                    radius: 8
                                    color: spaceMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Space"
                                        color: root.textMuted
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: spaceMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: passwordField.text += " "
                                    }
                                }

                                // Enter key
                                Rectangle {
                                    width: 90
                                    height: 40
                                    radius: 8
                                    color: enterMa.containsMouse ? Qt.lighter(root.primaryColor, 1.15) : root.primaryColor

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: "Enter"
                                            color: "#000"
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            text: "\uf061"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 11
                                            color: "#000"
                                        }
                                    }

                                    MouseArea {
                                        id: enterMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (passwordField.text.length > 0) {
                                                root.startAuthWithPassword(passwordField.text)
                                                passwordField.text = ""
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==================== Global Key Handler ====================
                Item {
                    anchors.fill: parent
                    focus: true

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Q &&
                            (event.modifiers & Qt.ControlModifier) &&
                            (event.modifiers & Qt.AltModifier)) {
                            sessionLock.locked = false
                            event.accepted = true
                            return
                        }

                        if (phase === "grace" && inputEnabled && !isTransitioning) {
                            root.dismiss()
                            event.accepted = true
                            return
                        }

                        if (phase === "locked") {
                            if (!passwordField.activeFocus) {
                                passwordField.forceActiveFocus()
                                if (event.text.length > 0 && !event.modifiers) {
                                    passwordField.text += event.text
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                        forceActiveFocus()
                    }
                }
            }
        }
    }

    function startAuth() {
        if (pamPassword.active) return

        if (pamFace.active) {
            pamFace.abort()
        }

        errorMessage = ""
        pendingPassword = ""
        authInProgress = true
        statusMessage = "正在进行人脸识别..."
        pamFace.start()
    }

    function startAuthWithPassword(password) {
        errorMessage = ""

        if (pamFace.active) {
            pamFace.abort()
        }

        if (pamPassword.responseRequired) {
            pamPassword.respond(password)
            return
        }

        if (pamPassword.active) {
            pendingPassword = password
            return
        }

        pendingPassword = password
        pamPassword.start()
    }
}
