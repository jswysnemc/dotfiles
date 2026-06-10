import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

ShellRoot {
    id: root

    I18nContext {
        id: i18n
        catalog: "media"
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

    // ============ State ============
    property int currentPlayerIndex: 0
    property var playersList: []
    property bool initialized: false  // Wait for data before rendering

    // Update players list when MPRIS changes
    function refreshPlayersList() {
        var list = []
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            list.push(players[i])
        }
        playersList = list
    }

    Connections {
        target: Mpris.players
        function onObjectInsertedPost() { root.refreshPlayersList() }
        function onObjectRemovedPost() { root.refreshPlayersList() }
    }

    Component.onCompleted: {
        refreshPlayersList()
        // Delay to ensure all data is ready before showing UI
        initTimer.start()
    }

    // Initialization timer - wait for MPRIS data to be ready
    Timer {
        id: initTimer
        interval: 50
        repeat: false
        onTriggered: {
            root.updatePlayingState()
            // Initialize track detection state
            if (root.activePlayer) {
                root.lastDetectedTitle = root.activePlayer.trackTitle || ""
                root.lastDetectedArtist = root.activePlayer.trackArtist || ""
            }
            root.onTrackChanged()
            root.initialized = true
            enterAnimation.start()
        }
    }

    // ============ Animations ============
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

    property var activePlayer: {
        if (playersList.length === 0) return null
        if (currentPlayerIndex >= playersList.length) currentPlayerIndex = 0
        return playersList[currentPlayerIndex]
    }

    property bool hasPlayer: activePlayer !== null
    property bool isPlaying: false

    // Update isPlaying state explicitly
    function updatePlayingState() {
        isPlaying = hasPlayer && activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    }

    // Watch playback state changes on active player
    Connections {
        target: root.activePlayer
        function onPlaybackStateChanged() { root.updatePlayingState() }
        function onTrackTitleChanged() { root.onTrackChanged() }
        function onTrackArtistChanged() { root.onTrackChanged() }
        function onTrackAlbumChanged() { root.onTrackChanged() }
        function onLengthChanged() { root.onTrackChanged() }
    }

    // Handle track change - refresh lyrics
    function onTrackChanged() {
        scheduleLyricsFetch()
    }

    onActivePlayerChanged: {
        updatePlayingState()
        // Also check for track change when switching players
        onTrackChanged()
    }
    property string trackTitle: hasPlayer && activePlayer.trackTitle ? activePlayer.trackTitle : ""
    property string trackArtist: hasPlayer && activePlayer.trackArtist ? activePlayer.trackArtist : ""
    property string trackAlbum: hasPlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
    property string artUrl: hasPlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
    property real position: hasPlayer && activePlayer.position !== undefined ? activePlayer.position : 0
    property real length: hasPlayer && activePlayer.length !== undefined ? activePlayer.length : 0
    property real volume: hasPlayer && activePlayer.volume !== undefined ? activePlayer.volume : 1.0

    // Get playerctl-compatible name from dbusName
    // dbusName format: "org.mpris.MediaPlayer2.musicfox" or "org.mpris.MediaPlayer2.chromium.instance123456"
    // playerctl needs: "musicfox" or "chromium.instance123456"
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

    // Lyrics state
    property var lyricsLines: []
    property bool lyricsLoaded: false
    property bool lyricsLoading: false
    property string lyricsError: ""
    property string currentLyric: ""
    property string nextLyric: ""
    property int currentLyricIndex: -1
    property bool showLyrics: true
    property string lastFetchedTrackKey: ""

    // Dragging state for progress bar
    property bool isDragging: false
    property real dragPosition: 0

    function resetLyricsState() {
        lyricsLoaded = false
        lyricsLines = []
        currentLyric = ""
        nextLyric = ""
        currentLyricIndex = -1
        lyricsError = ""
    }

    function shouldFetchLyrics() {
        return trackTitle && trackKey !== lastFetchedTrackKey
    }

    function scheduleLyricsFetch() {
        if (!shouldFetchLyrics()) return
        resetLyricsState()
        lyricsFetchTimer.restart()
    }

    // Position update timer - always run when player exists
    Timer {
        interval: 500
        running: root.hasPlayer && !root.isDragging
        repeat: true
        onTriggered: {
            if (root.activePlayer) {
                root.position = root.activePlayer.position
                if (root.isPlaying) {
                    updateCurrentLyric()
                }
            }
        }
    }

    // Fallback refresh timer - ensure UI stays responsive
    // Also detects track changes for players that don't emit signals
    property string lastDetectedTitle: ""
    property string lastDetectedArtist: ""

    Timer {
        interval: 500
        running: root.hasPlayer
        repeat: true
        onTriggered: {
            // Force refresh player list and playing state
            root.refreshPlayersList()
            root.updatePlayingState()
            if (root.activePlayer) {
                root.position = root.activePlayer.position
                // Detect track change by comparing title/artist
                var currentTitle = root.activePlayer.trackTitle || ""
                var currentArtist = root.activePlayer.trackArtist || ""
                if (currentTitle !== root.lastDetectedTitle || currentArtist !== root.lastDetectedArtist) {
                    root.lastDetectedTitle = currentTitle
                    root.lastDetectedArtist = currentArtist
                    root.onTrackChanged()
                }
            }
        }
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

    // Lyrics sync timer (more frequent for smooth lyrics)
    Timer {
        interval: 100
        running: root.isPlaying && root.lyricsLoaded && root.lyricsLines.length > 0 && !root.isDragging
        repeat: true
        onTriggered: updateCurrentLyric()
    }

    property string scriptPath: Qt.resolvedUrl("lyrics_fetcher.py").toString().replace("file://", "")
    property string uvPath: "/usr/bin/uv"
    property string rootDir: Quickshell.env("HOME") + "/.config/quickshell"

    Process {
        id: lyricsFetcher
        command: ["echo"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                root.lyricsLoading = false
                try {
                    let data = JSON.parse(text)
                    if (data.success) {
                        if (data.synced && data.lines) {
                            root.lyricsLines = data.lines
                            root.lyricsLoaded = true
                            root.lyricsError = ""
                            updateCurrentLyric()
                        } else if (data.text) {
                            root.lyricsLines = []
                            root.lyricsLoaded = true
                            root.lyricsError = ""
                            root.currentLyric = i18n.trLiteral("无同步歌词")
                        } else {
                            root.lyricsError = i18n.trLiteral("无歌词")
                            root.lyricsLoaded = false
                        }
                    } else {
                        root.lyricsError = data.error || i18n.trLiteral("获取失败")
                        root.lyricsLoaded = false
                    }
                } catch (e) {
                    root.lyricsError = i18n.trLiteral("解析失败")
                    root.lyricsLoaded = false
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    console.log("Lyrics fetch error:", text)
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.lyricsLoaded) {
                root.lyricsLoading = false
                root.lyricsError = i18n.trLiteral("获取失败")
            }
        }
    }

    function fetchLyrics() {
        if (!trackTitle) return

        lastFetchedTrackKey = trackKey
        resetLyricsState()
        lyricsLoading = true

        // Always pass all arguments with fixed positions
        // Python expects: fetch title artist album duration player
        let args = [uvPath, "run", "--directory", rootDir, scriptPath, "fetch",
            trackTitle,
            trackArtist || "",
            trackAlbum || "",
            length > 0 ? length.toString() : "0",
            playerctlName || ""
        ]

        lyricsFetcher.command = args
        lyricsFetcher.running = true
    }

    function updateCurrentLyric() {
        if (!lyricsLoaded || lyricsLines.length === 0) return

        let pos = isDragging ? dragPosition : position
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

    function formatTime(s) {
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function playPause() {
        if (hasPlayer) {
            activePlayer.togglePlaying()
            // Immediate UI feedback, then sync with actual state
            Qt.callLater(updatePlayingState)
        }
    }

    function next() {
        if (hasPlayer && activePlayer.canGoNext) activePlayer.next()
    }

    function previous() {
        if (hasPlayer && activePlayer.canGoPrevious) activePlayer.previous()
    }

    function seek(pos) {
        if (hasPlayer && activePlayer.canSeek) activePlayer.position = pos
    }

    function setVolume(v) {
        if (hasPlayer) activePlayer.volume = Math.max(0, Math.min(1, v))
    }

    function nextPlayer() {
        if (playersList.length > 1) {
            currentPlayerIndex = (currentPlayerIndex + 1) % playersList.length
        }
    }

    function prevPlayer() {
        if (playersList.length > 1) {
            currentPlayerIndex = (currentPlayerIndex - 1 + playersList.length) % playersList.length
        }
    }

    // ============ UI ============
    MediaView {
        controller: root
    }
}
