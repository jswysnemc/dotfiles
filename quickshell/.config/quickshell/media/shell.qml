import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
    property bool blurActive: false
    property bool closing: false

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
        root.mediaStateLoadPending = true
        ensureMediaStateDaemon()
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
            root.requestMediaStateSnapshot(true)
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

    /**
     * 关闭媒体弹窗窗口。
     *
     * @param 无
     * @returns 无
     */
    function closeWithAnimation() {
        if (root.closing) return
        root.closing = true
        // 1. 先关闭模糊区域，避免退出前全屏 layer 参与模糊
        root.blurActive = false
        // 2. 停止入场动画，避免退出前继续补帧
        enterAnimation.stop()
        exitAnimation.stop()
        // 3. 立即隐藏卡片并退出，保持与剪贴板一致
        root.panelOpacity = 0
        root.panelScale = 1.0
        root.panelY = 0
        Qt.quit()
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
    property bool mediaStateLoadPending: false

    // Dragging state for progress bar
    property bool isDragging: false
    property real dragPosition: 0

    /**
     * 重置歌词展示状态。
     *
     * @param 无
     * @returns 无
     */
    function resetLyricsState() {
        lyricsLoaded = false
        lyricsLines = []
        currentLyric = ""
        nextLyric = ""
        currentLyricIndex = -1
        lyricsError = ""
    }

    /**
     * 判断当前曲目是否需要由组件发起歌词请求。
     *
     * @param 无
     * @returns {bool} 需要请求时返回 true。
     */
    function shouldFetchLyrics() {
        return !mediaStateLoadPending && !lyricsLoading && trackTitle && trackKey !== lastFetchedTrackKey
    }

    /**
     * 延迟调度歌词请求。
     *
     * @param 无
     * @returns 无
     */
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

    // 【媒体组件】【后台状态】后台脚本请求歌词时，组件只轮询快照，不重复请求接口
    Timer {
        interval: 1000
        running: root.hasPlayer && root.lyricsLoading && !root.mediaStateLoadPending
        repeat: true
        onTriggered: root.requestMediaStateSnapshot(false)
    }

    property string scriptPath: Qt.resolvedUrl("lyrics_fetcher.py").toString().replace("file://", "")
    property string mediaStateScriptPath: Qt.resolvedUrl("media_state.py").toString().replace("file://", "")
    property string uvPath: "/usr/bin/uv"
    property string rootDir: Quickshell.env("HOME") + "/.config/quickshell"

    Process {
        id: mediaStateDaemon
        command: ["echo"]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    console.log("【媒体组件】【状态脚本】后台脚本启动失败:", text)
                }
            }
        }
    }

    Process {
        id: mediaStateSnapshot
        command: ["echo"]
        stdout: StdioCollector {
            onStreamFinished: root.applyMediaStateSnapshot(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    console.log("【媒体组件】【状态脚本】读取状态失败:", text)
                }
            }
        }
        onExited: (code, status) => {
            if (root.mediaStateLoadPending) {
                root.finishMediaStateSnapshotLoad(false)
            }
        }
    }

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

    /**
     * 启动媒体后台状态脚本。
     *
     * @param 无
     * @returns 无
     */
    function ensureMediaStateDaemon() {
        // 【媒体组件】【后台状态】1. 后台脚本自行检查 PID，避免重复启动
        mediaStateDaemon.command = [uvPath, "run", "--directory", rootDir, mediaStateScriptPath, "ensure-daemon"]
        mediaStateDaemon.running = true
    }

    /**
     * 请求媒体状态快照。
     *
     * @param {bool} blockFetch - 是否在快照返回前阻止组件自身歌词请求。
     * @returns 无
     */
    function requestMediaStateSnapshot(blockFetch) {
        if (mediaStateSnapshot.running) return
        if (blockFetch) {
            mediaStateLoadPending = true
        }

        // 【媒体组件】【后台状态】1. 优先读取后台快照，减少组件重新请求歌词
        mediaStateSnapshot.command = [uvPath, "run", "--directory", rootDir, mediaStateScriptPath, "snapshot"]
        mediaStateSnapshot.running = true
    }

    /**
     * 完成媒体状态快照读取。
     *
     * @param {bool} applied - 是否已成功应用当前曲目的快照。
     * @returns 无
     */
    function finishMediaStateSnapshotLoad(applied) {
        mediaStateLoadPending = false
        if (!applied) {
            scheduleLyricsFetch()
        } else if (lyricsLoaded) {
            updateCurrentLyric()
        }
    }

    /**
     * 应用后台状态中的歌词数据。
     *
     * @param {var} lyrics - 后台状态脚本输出的歌词对象。
     * @returns {bool} 成功应用时返回 true。
     */
    function applyLyricsFromMediaState(lyrics) {
        if (!lyrics) return false

        lastFetchedTrackKey = trackKey
        lyricsLoading = lyrics.loading || false
        lyricsError = lyrics.error || ""

        if (lyrics.loaded && lyrics.synced && lyrics.lines) {
            lyricsLines = lyrics.lines
            lyricsLoaded = true
            currentLyricIndex = lyrics.current_index !== undefined ? lyrics.current_index : -1
            currentLyric = lyrics.current_text || ""
            nextLyric = lyrics.next_text || ""
            if (!currentLyric && lyricsLines.length > 0) {
                updateCurrentLyric()
            }
            return true
        }

        if (lyrics.loaded) {
            lyricsLines = []
            lyricsLoaded = true
            currentLyricIndex = -1
            currentLyric = lyrics.current_text || i18n.trLiteral("无同步歌词")
            nextLyric = ""
            return true
        }

        if (lyrics.loading) {
            lyricsLoaded = false
            lyricsLines = []
            currentLyric = ""
            nextLyric = ""
            currentLyricIndex = -1
            return true
        }

        return false
    }

    /**
     * 应用媒体后台状态快照。
     *
     * @param {string} text - 后台状态脚本输出的 JSON 文本。
     * @returns 无
     */
    function applyMediaStateSnapshot(text) {
        let applied = false
        try {
            let data = JSON.parse(text || "{}")
            let track = data.track || {}
            let playback = data.playback || {}
            let snapshotTrackKey = track.key || ""
            let updatedAt = data.updated_at || 0
            let stale = updatedAt > 0 && (Date.now() / 1000 - updatedAt > 20)

            if (data.success && data.active && snapshotTrackKey === trackKey && !stale) {
                if (playback.position !== undefined) {
                    position = playback.position
                }
                applied = applyLyricsFromMediaState(data.lyrics || {})
            }

            if (!applied && !mediaStateLoadPending && stale && snapshotTrackKey === trackKey && lyricsLoading) {
                lyricsLoading = false
                lastFetchedTrackKey = ""
                scheduleLyricsFetch()
            }
        } catch (e) {
            console.log("【媒体组件】【状态脚本】解析状态失败:", e)
        }

        if (mediaStateLoadPending) {
            finishMediaStateSnapshotLoad(applied)
        }
    }

    /**
     * 请求当前曲目的歌词。
     *
     * @param 无
     * @returns 无
     */
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

    /**
     * 根据当前播放进度更新歌词行。
     *
     * @param 无
     * @returns 无
     */
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
