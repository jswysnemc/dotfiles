import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
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

    // ============ State ============
    property int currentPlayerIndex: 0
    property var playersList: {
        var list = []
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            list.push(players[i])
        }
        return list
    }

    property var activePlayer: {
        if (playersList.length === 0) return null
        if (currentPlayerIndex >= playersList.length) currentPlayerIndex = 0
        return playersList[currentPlayerIndex]
    }

    property bool hasPlayer: activePlayer !== null
    property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    property string trackTitle: hasPlayer && activePlayer.trackTitle ? activePlayer.trackTitle : ""
    property string trackArtist: hasPlayer && activePlayer.trackArtist ? activePlayer.trackArtist : ""
    property string trackAlbum: hasPlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
    property string artUrl: hasPlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
    property real position: hasPlayer && activePlayer.position !== undefined ? activePlayer.position : 0
    property real length: hasPlayer && activePlayer.length !== undefined ? activePlayer.length : 0
    property real volume: hasPlayer && activePlayer.volume !== undefined ? activePlayer.volume : 1.0

    // Lyrics state
    property var lyricsLines: []
    property bool lyricsLoaded: false
    property bool lyricsLoading: false
    property string lyricsError: ""
    property string currentLyric: ""
    property string nextLyric: ""
    property int currentLyricIndex: -1
    property bool showLyrics: true
    property string lastFetchedTrack: ""

    // Dragging state for progress bar
    property bool isDragging: false
    property real dragPosition: 0

    // Position update timer
    Timer {
        interval: 500
        running: root.isPlaying && !root.isDragging
        repeat: true
        onTriggered: {
            root.position = root.activePlayer ? root.activePlayer.position : 0
            updateCurrentLyric()
        }
    }

    // Lyrics sync timer (more frequent for smooth lyrics)
    Timer {
        interval: 100
        running: root.isPlaying && root.lyricsLoaded && root.lyricsLines.length > 0 && !root.isDragging
        repeat: true
        onTriggered: updateCurrentLyric()
    }

    // Track change watcher
    onTrackTitleChanged: {
        if (trackTitle && trackTitle !== lastFetchedTrack) {
            fetchLyrics()
        }
    }

    property string scriptPath: Qt.resolvedUrl("lyrics_fetcher.py").toString().replace("file://", "")
    property string uvPath: "/usr/bin/uv"
    property string rootDir: "/home/snemc/.config/quickshell"

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
                            root.currentLyric = "无同步歌词"
                        } else {
                            root.lyricsError = "无歌词"
                            root.lyricsLoaded = false
                        }
                    } else {
                        root.lyricsError = data.error || "获取失败"
                        root.lyricsLoaded = false
                    }
                } catch (e) {
                    root.lyricsError = "解析失败"
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
                root.lyricsError = "获取失败"
            }
        }
    }

    function fetchLyrics() {
        if (!trackTitle) return

        lastFetchedTrack = trackTitle
        lyricsLoading = true
        lyricsLoaded = false
        lyricsLines = []
        currentLyric = ""
        nextLyric = ""
        lyricsError = ""

        let args = [uvPath, "run", "--directory", rootDir, scriptPath, "fetch", trackTitle]
        if (trackArtist) args.push(trackArtist)
        if (trackAlbum) args.push(trackAlbum)
        if (length > 0) args.push(length.toString())

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
        if (hasPlayer) activePlayer.togglePlaying()
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
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-media"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true


            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
            Shortcut { sequence: "Space"; onActivated: root.playPause() }
            Shortcut { sequence: "Left"; onActivated: root.previous() }
            Shortcut { sequence: "Right"; onActivated: root.next() }

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
                width: 380
                height: panelRect.implicitHeight
                color: Theme.background
                radius: Theme.radiusL
                border.color: Theme.outline
                border.width: 1
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                // Background art blur effect
                Item {
                    anchors.fill: parent
                    clip: true
                    visible: root.artUrl !== ""
                    opacity: 0.15

                    Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: -40
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: 64
                            blur: 1.0
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.background
                    opacity: 0.85
                    radius: Theme.radiusL
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    // Header with player selector
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf001"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: Theme.iconSizeM
                            color: Theme.primary
                        }

                        Text {
                            text: "媒体播放"
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        // Player switcher (if multiple players)
                        Rectangle {
                            visible: root.playersList.length > 1
                            width: playerSwitchRow.implicitWidth + Theme.spacingM * 2
                            height: 28
                            radius: Theme.radiusPill
                            color: Theme.surfaceVariant
                            border.color: Theme.outline
                            border.width: 1

                            RowLayout {
                                id: playerSwitchRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: 20; height: 20; radius: 10
                                    color: prevPlayerMa.containsMouse ? Theme.surface : "transparent"
                                    scale: prevPlayerMa.containsMouse ? 1.1 : 1.0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf104"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 10
                                        color: Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: prevPlayerMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.prevPlayer()
                                    }
                                }

                                Text {
                                    text: (root.currentPlayerIndex + 1) + "/" + root.playersList.length
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.textMuted
                                }

                                Rectangle {
                                    width: 20; height: 20; radius: 10
                                    color: nextPlayerMa.containsMouse ? Theme.surface : "transparent"
                                    scale: nextPlayerMa.containsMouse ? 1.1 : 1.0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf105"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 10
                                        color: Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: nextPlayerMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.nextPlayer()
                                    }
                                }
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: closeMa.containsMouse ? 1.1 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeM
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // No player state
                    Rectangle {
                        visible: !root.hasPlayer
                        Layout.fillWidth: true
                        height: 180
                        color: "transparent"
                        opacity: !root.hasPlayer ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingL

                            Text {
                                text: "\uf001"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 48
                                color: Theme.textMuted
                                opacity: 0.5
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "没有正在播放的媒体"
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textMuted
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "播放音乐或视频后在此控制"
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                                opacity: 0.7
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Player content
                    ColumnLayout {
                        visible: root.hasPlayer
                        Layout.fillWidth: true
                        spacing: Theme.spacingL
                        opacity: root.hasPlayer ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        // Album art and track info
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingL

                            // Album art
                            Rectangle {
                                width: 100
                                height: 100
                                radius: Theme.radiusM
                                color: Theme.surfaceVariant
                                border.color: Theme.outline
                                border.width: 1

                                Image {
                                    id: albumArt
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: root.artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: root.artUrl !== ""
                                    opacity: root.artUrl !== "" ? 1 : 0

                                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                        maskSource: ShaderEffectSource {
                                            sourceItem: Rectangle {
                                                width: 98
                                                height: 98
                                                radius: Theme.radiusM - 1
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.artUrl === ""
                                    text: "\uf001"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 36
                                    color: Theme.textMuted
                                    opacity: 0.5
                                }

                                // Playing indicator
                                Rectangle {
                                    anchors.margins: 6
                                    width: 24; height: 24; radius: 12
                                    color: root.isPlaying ? Theme.success : Theme.warning
                                    visible: root.hasPlayer

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isPlaying ? "\uf04b" : "\uf04c"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 10
                                        color: Theme.surface
                                    }
                                }
                            }

                            // Track info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text {
                                    text: root.trackTitle || "未知曲目"
                                    font.pixelSize: Theme.fontSizeL
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: root.trackArtist !== ""
                                    text: root.trackArtist
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.primary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: root.trackAlbum !== ""
                                    text: root.trackAlbum
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        color: Theme.surfaceVariant

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf144"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 8
                                            color: Theme.textMuted
                                        }
                                    }

                                    Text {
                                        text: root.activePlayer ? root.activePlayer.identity : ""
                                        font.pixelSize: Theme.fontSizeXS
                                        color: Theme.textMuted
                                    }
                                }
                            }
                        }

                        // Progress bar
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            Rectangle {
                                id: progressBar
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Theme.surfaceVariant

                                Rectangle {
                                    id: progressFill
                                    width: root.length > 0 ? ((root.isDragging ? root.dragPosition : root.position) / root.length) * parent.width : 0
                                    height: parent.height
                                    radius: 3
                                    color: root.isDragging ? Theme.secondary : Theme.primary

                                    Behavior on width { enabled: !root.isDragging; NumberAnimation { duration: 100 } }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                // Progress handle (always visible)
                                Rectangle {
                                    id: progressHandle
                                    x: Math.max(0, Math.min(progressFill.width - width / 2, parent.width - width))
                                    y: -3
                                    width: 12; height: 12; radius: 6
                                    color: root.isDragging ? Theme.secondary : Theme.primary
                                    border.color: Theme.surface
                                    border.width: 2
                                    visible: root.length > 0
                                    scale: progressMa.pressed ? 1.2 : (progressMa.containsMouse ? 1.1 : 1.0)

                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                MouseArea {
                                    id: progressMa
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onPressed: (mouse) => {
                                        if (root.length > 0) {
                                            root.isDragging = true
                                            root.dragPosition = Math.max(0, Math.min(1, mouse.x / progressBar.width)) * root.length
                                            updateCurrentLyric()
                                        }
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (pressed && root.length > 0) {
                                            root.dragPosition = Math.max(0, Math.min(1, mouse.x / progressBar.width)) * root.length
                                            updateCurrentLyric()
                                        }
                                    }

                                    onReleased: {
                                        if (root.length > 0 && root.isDragging) {
                                            root.seek(root.dragPosition)
                                            root.position = root.dragPosition
                                        }
                                        root.isDragging = false
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: root.formatTime(root.isDragging ? root.dragPosition : root.position)
                                    font.pixelSize: Theme.fontSizeXS
                                    color: root.isDragging ? Theme.secondary : Theme.textMuted
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.formatTime(root.length)
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.textMuted
                                }
                            }
                        }

                        // Lyrics display
                        Item {
                            Layout.fillWidth: true
                            height: lyricsCol.implicitHeight
                            visible: root.showLyrics

                            ColumnLayout {
                                id: lyricsCol
                                anchors.fill: parent
                                spacing: Theme.spacingXS

                                // Lyrics header with buttons on left
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    // Toggle lyrics (hide)
                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        color: toggleLyricsMa.containsMouse ? Theme.surfaceVariant : "transparent"

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf068"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 10
                                            color: Theme.textMuted
                                        }

                                        MouseArea {
                                            id: toggleLyricsMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.showLyrics = false
                                        }
                                    }

                                    // Refresh button
                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        color: refreshLyricsMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                        visible: !root.lyricsLoading

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf021"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 10
                                            color: Theme.textMuted
                                        }

                                        MouseArea {
                                            id: refreshLyricsMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.lastFetchedTrack = ""
                                                root.fetchLyrics()
                                            }
                                        }
                                    }

                                    // Loading indicator
                                    Text {
                                        visible: root.lyricsLoading
                                        text: "\uf110"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: Theme.iconSizeS
                                        color: Theme.textMuted

                                        RotationAnimator on rotation {
                                            from: 0; to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: root.lyricsLoading
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "\uf130"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: Theme.iconSizeS
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: "歌词"
                                        font.pixelSize: Theme.fontSizeXS
                                        font.bold: true
                                        color: Theme.textMuted
                                    }
                                }

                                // Current lyric line (shifted up with less spacing)
                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: Theme.spacingXS
                                    text: root.lyricsLoading ? "正在获取歌词..." :
                                          root.lyricsError ? root.lyricsError :
                                          root.currentLyric || (root.lyricsLoaded ? "..." : "暂无歌词")
                                    font.pixelSize: Theme.fontSizeM
                                    font.weight: Font.Medium
                                    color: root.lyricsError ? Theme.error :
                                           root.currentLyric ? Theme.textPrimary : Theme.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    opacity: root.lyricsLoading ? 0.7 : 1

                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }

                                // Next lyric line
                                Text {
                                    Layout.fillWidth: true
                                    text: root.nextLyric
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    visible: root.nextLyric !== "" && !root.lyricsError && !root.lyricsLoading
                                    opacity: 0.5
                                }
                            }
                        }

                        // Show lyrics button (when hidden)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: Theme.radiusM
                            color: showLyricsMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            visible: !root.showLyrics

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Text {
                                    text: "\uf130"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: Theme.textMuted
                                }

                                Text {
                                    text: "显示歌词"
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.textMuted
                                }
                            }

                            MouseArea {
                                id: showLyricsMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showLyrics = true
                            }
                        }

                        // Playback controls
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacingL

                            // Shuffle (placeholder)
                            Rectangle {
                                width: 36; height: 36; radius: Theme.radiusM
                                color: shuffleMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                scale: shuffleMa.containsMouse ? 1.1 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf074"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeM
                                    color: Theme.textMuted
                                }

                                MouseArea {
                                    id: shuffleMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }

                            // Previous
                            Rectangle {
                                width: 40; height: 40; radius: Theme.radiusM
                                color: prevMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                scale: prevMa.containsMouse ? 1.1 : 1.0
                                opacity: root.activePlayer && root.activePlayer.canGoPrevious ? 1 : 0.5

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf048"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeL
                                    color: Theme.textSecondary
                                }

                                MouseArea {
                                    id: prevMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.previous()
                                }
                            }

                            // Play/Pause
                            Rectangle {
                                width: 56; height: 56; radius: 28
                                color: playMa.containsMouse ? Theme.alpha(Theme.primary, 0.8) : Theme.primary
                                scale: playMa.containsMouse ? 1.05 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.isPlaying ? "\uf04c" : "\uf04b"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeL
                                    color: Theme.surface
                                }

                                MouseArea {
                                    id: playMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playPause()
                                }
                            }

                            // Next
                            Rectangle {
                                width: 40; height: 40; radius: Theme.radiusM
                                color: nextMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                scale: nextMa.containsMouse ? 1.1 : 1.0
                                opacity: root.activePlayer && root.activePlayer.canGoNext ? 1 : 0.5

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf051"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeL
                                    color: Theme.textSecondary
                                }

                                MouseArea {
                                    id: nextMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.next()
                                }
                            }

                            // Repeat (placeholder)
                            Rectangle {
                                width: 36; height: 36; radius: Theme.radiusM
                                color: repeatMa.containsMouse ? Theme.surfaceVariant : "transparent"
                                scale: repeatMa.containsMouse ? 1.1 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf01e"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeM
                                    color: Theme.textMuted
                                }

                                MouseArea {
                                    id: repeatMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }

                        // Volume control
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 28; height: 28; radius: Theme.radiusM
                                color: volIconMa.containsMouse ? Theme.surfaceVariant : "transparent"

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.volume < 0.01 ? "\uf6a9" : root.volume < 0.5 ? "\uf027" : "\uf028"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeM
                                    color: Theme.textSecondary
                                }

                                MouseArea {
                                    id: volIconMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setVolume(root.volume < 0.01 ? 1.0 : 0)
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Theme.surfaceVariant

                                Rectangle {
                                    width: root.volume * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: Theme.secondary

                                    Behavior on width { NumberAnimation { duration: 50 } }
                                }

                                Rectangle {
                                    x: root.volume * (parent.width - width)
                                    y: -3
                                    width: 12; height: 12; radius: 6
                                    color: Theme.secondary
                                    border.color: Theme.surface
                                    border.width: 2
                                    visible: volMa.containsMouse || volMa.pressed
                                    scale: volMa.pressed ? 1.2 : 1.0

                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    id: volMa
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setVolume(Math.max(0, Math.min(1, mouseX / parent.width)))
                                    onPositionChanged: if (pressed) root.setVolume(Math.max(0, Math.min(1, mouseX / parent.width)))
                                }
                            }

                            Text {
                                text: Math.round(root.volume * 100) + "%"
                                font.pixelSize: Theme.fontSizeXS
                                color: Theme.textMuted
                                Layout.preferredWidth: 36
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // Keyboard hints
                    Text {
                        Layout.fillWidth: true
                        text: "Space 播放/暂停 | Left/Right 上/下一曲"
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.hasPlayer
                    }
                }
            }
        }
    }
}
