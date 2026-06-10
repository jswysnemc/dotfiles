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

// Player content
ColumnLayout {
    required property var controller
    visible: controller.hasPlayer
    Layout.fillWidth: true
    spacing: Theme.spacingL
    opacity: controller.hasPlayer ? 1 : 0

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
                source: controller.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: controller.artUrl !== ""
                opacity: controller.artUrl !== "" ? 1 : 0

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
                            radius: Theme.radiusXL - 4
                        }
                    }
                }
            }

            // Cover Shadow
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.alpha(Theme.primary, 0.3)
                shadowBlur: 0.6
                shadowVerticalOffset: 4
            }

            Text {
                anchors.centerIn: parent
                visible: controller.artUrl === ""
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
                color: controller.isPlaying ? Theme.success : Theme.warning
                visible: controller.hasPlayer

                Text {
                    anchors.centerIn: parent
                    text: controller.isPlaying ? "\uf04b" : "\uf04c"
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
                text: controller.trackTitle || controller.i18nContext.trLiteral("未知曲目")
                font.pixelSize: Theme.fontSizeL
                font.weight: Font.Bold
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: controller.trackArtist !== ""
                text: controller.trackArtist
                font.pixelSize: Theme.fontSizeM
                color: Theme.primary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: controller.trackAlbum !== ""
                text: controller.trackAlbum
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
                    text: controller.activePlayer ? controller.activePlayer.identity : ""
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
                width: controller.length > 0 ? ((controller.isDragging ? controller.dragPosition : controller.position) / controller.length) * parent.width : 0
                height: parent.height
                radius: 3
                color: controller.isDragging ? Theme.secondary : Theme.primary

                Behavior on width { enabled: !controller.isDragging; NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Progress handle (always visible)
            Rectangle {
                id: progressHandle
                x: Math.max(0, Math.min(progressFill.width - width / 2, parent.width - width))
                y: -3
                width: 12; height: 12; radius: 6
                color: controller.isDragging ? Theme.secondary : Theme.primary
                border.color: Theme.surface
                border.width: 2
                visible: controller.length > 0
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
                    if (controller.length > 0) {
                        controller.isDragging = true
                        controller.dragPosition = Math.max(0, Math.min(1, mouse.x / progressBar.width)) * controller.length
                        updateCurrentLyric()
                    }
                }

                onPositionChanged: (mouse) => {
                    if (pressed && controller.length > 0) {
                        controller.dragPosition = Math.max(0, Math.min(1, mouse.x / progressBar.width)) * controller.length
                        updateCurrentLyric()
                    }
                }

                onReleased: {
                    if (controller.length > 0 && controller.isDragging) {
                        controller.seek(controller.dragPosition)
                        controller.position = controller.dragPosition
                    }
                    controller.isDragging = false
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: controller.formatTime(controller.isDragging ? controller.dragPosition : controller.position)
                font.pixelSize: Theme.fontSizeXS
                color: controller.isDragging ? Theme.secondary : Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            Text {
                text: controller.formatTime(controller.length)
                font.pixelSize: Theme.fontSizeXS
                color: Theme.textMuted
            }
        }
    }

    // Lyrics display
    Item {
        Layout.fillWidth: true
        height: lyricsCol.implicitHeight
        visible: controller.showLyrics

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
                        onClicked: controller.showLyrics = false
                    }
                }

                // Refresh button
                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: refreshLyricsMa.containsMouse ? Theme.surfaceVariant : "transparent"
                    visible: !controller.lyricsLoading

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
                            controller.lastFetchedTrackKey = ""
                            controller.fetchLyrics()
                        }
                    }
                }

                // Loading indicator
                Text {
                    visible: controller.lyricsLoading
                    text: "\uf110"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: Theme.iconSizeS
                    color: Theme.textMuted

                    RotationAnimator on rotation {
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: controller.lyricsLoading
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
                    text: controller.i18nContext.trLiteral("歌词")
                    font.pixelSize: Theme.fontSizeXS
                    font.bold: true
                    color: Theme.textMuted
                }
            }

            // Current lyric line (shifted up with less spacing)
            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingXS
                text: controller.lyricsLoading ? controller.i18nContext.trLiteral("正在获取歌词...") :
                      controller.lyricsError ? controller.lyricsError :
                      controller.currentLyric || (controller.lyricsLoaded ? "..." : controller.i18nContext.trLiteral("暂无歌词"))
                font.pixelSize: Theme.fontSizeM
                font.weight: Font.Medium
                color: controller.lyricsError ? Theme.error :
                       controller.currentLyric ? Theme.textPrimary : Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                opacity: controller.lyricsLoading ? 0.7 : 1

                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }

            // Next lyric line
            Text {
                Layout.fillWidth: true
                text: controller.nextLyric
                font.pixelSize: Theme.fontSizeS
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: controller.nextLyric !== "" && !controller.lyricsError && !controller.lyricsLoading
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
        visible: !controller.showLyrics

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
                text: controller.i18nContext.trLiteral("显示歌词")
                font.pixelSize: Theme.fontSizeXS
                color: Theme.textMuted
            }
        }

        MouseArea {
            id: showLyricsMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controller.showLyrics = true
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
            opacity: controller.activePlayer && controller.activePlayer.canGoPrevious ? 1 : 0.5

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
                onClicked: controller.previous()
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
                text: controller.isPlaying ? "\uf04c" : "\uf04b"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.iconSizeL
                color: Theme.surface
            }

            MouseArea {
                id: playMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.playPause()
            }
        }

        // Next
        Rectangle {
            width: 40; height: 40; radius: Theme.radiusM
            color: nextMa.containsMouse ? Theme.surfaceVariant : "transparent"
            scale: nextMa.containsMouse ? 1.1 : 1.0
            opacity: controller.activePlayer && controller.activePlayer.canGoNext ? 1 : 0.5

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
                onClicked: controller.next()
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
                text: controller.volume < 0.01 ? "\uf6a9" : controller.volume < 0.5 ? "\uf027" : "\uf028"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.iconSizeM
                color: Theme.textSecondary
            }

            MouseArea {
                id: volIconMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.setVolume(controller.volume < 0.01 ? 1.0 : 0)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Theme.surfaceVariant

            Rectangle {
                width: controller.volume * parent.width
                height: parent.height
                radius: 3
                color: Theme.secondary

                Behavior on width { NumberAnimation { duration: 50 } }
            }

            Rectangle {
                x: controller.volume * (parent.width - width)
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
                onClicked: controller.setVolume(Math.max(0, Math.min(1, mouseX / parent.width)))
                onPositionChanged: if (pressed) controller.setVolume(Math.max(0, Math.min(1, mouseX / parent.width)))
            }
        }

        Text {
            text: Math.round(controller.volume * 100) + "%"
            font.pixelSize: Theme.fontSizeXS
            color: Theme.textMuted
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }
}

