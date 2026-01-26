import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // State
    property string currentWallpaper: ""
    property int selectedIndex: 0
    property bool loading: true
    property int wallpaperCount: 0

    // Wallpaper list model
    ListModel {
        id: wallpaperModel
    }

    readonly property string homeDir: Quickshell.env("HOME")

    Component.onCompleted: {
        loadWallpapers.running = true
        getCurrentWallpaper.running = true
    }

    // Load all wallpapers at once
    Process {
        id: loadWallpapers
        command: ["bash", "-c", "find ~/Pictures/Wallpapers ~/Pictures/wallpapers ~/Downloads/Wallpapers -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | head -100 | sort"]
        property string output: ""
        stdout: SplitParser {
            onRead: data => {
                if (data.trim()) {
                    loadWallpapers.output += data.trim() + "\n"
                }
            }
        }
        onExited: {
            var lines = output.trim().split("\n")
            for (var i = 0; i < lines.length; i++) {
                if (lines[i]) {
                    wallpaperModel.append({ "path": lines[i] })
                }
            }
            root.wallpaperCount = wallpaperModel.count
            root.loading = false
        }
    }

    Process {
        id: getCurrentWallpaper
        command: ["readlink", "-f", homeDir + "/.cache/current_wallpaper"]
        stdout: SplitParser {
            onRead: data => {
                root.currentWallpaper = data.trim()
            }
        }
    }

    Process {
        id: setWallpaper
        command: ["bash", "-c", ""]
        onExited: Qt.quit()
    }

    function applyWallpaper(path) {
        var linkPath = homeDir + "/.cache/current_wallpaper"
        var cmd = "rm -f '" + linkPath + "' && ln -sf '" + path + "' '" + linkPath + "' && " +
                  "(pgrep -x swww-daemon || swww-daemon &) && sleep 0.2 && " +
                  "swww img '" + path + "' --transition-type grow --transition-pos 0.5,0.5 --transition-step 90 --transition-fps 60 && " +
                  "matugen image '" + linkPath + "'"
        setWallpaper.command = ["bash", "-c", cmd]
        setWallpaper.running = true
    }

    function moveUp() { if (selectedIndex >= 3) selectedIndex -= 3 }
    function moveDown() { if (selectedIndex + 3 < wallpaperModel.count) selectedIndex += 3 }
    function moveLeft() { if (selectedIndex > 0) selectedIndex-- }
    function moveRight() { if (selectedIndex < wallpaperModel.count - 1) selectedIndex++ }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-wallpaper-selector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
            Shortcut { sequence: "Up"; onActivated: root.moveUp() }
            Shortcut { sequence: "Down"; onActivated: root.moveDown() }
            Shortcut { sequence: "Left"; onActivated: root.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: root.moveRight() }
            Shortcut { sequence: "k"; onActivated: root.moveUp() }
            Shortcut { sequence: "j"; onActivated: root.moveDown() }
            Shortcut { sequence: "h"; onActivated: root.moveLeft() }
            Shortcut { sequence: "l"; onActivated: root.moveRight() }
            Shortcut { sequence: "Return"; onActivated: if (wallpaperModel.count > 0) root.applyWallpaper(wallpaperModel.get(root.selectedIndex).path) }
            Shortcut { sequence: "Space"; onActivated: if (wallpaperModel.count > 0) root.applyWallpaper(wallpaperModel.get(root.selectedIndex).path) }

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: mainContainer
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.8, 900)
                height: Math.min(parent.height * 0.8, 700)
                color: Theme.background
                radius: Theme.radiusXL
                border.color: Theme.outline
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf03e"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 20
                            color: Theme.primary
                        }

                        Text {
                            text: "壁纸选择"
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.loading ? "加载中..." : root.wallpaperCount + " 张壁纸"
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.textMuted
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.surfaceVariant
                        radius: Theme.radiusL
                        clip: true

                        GridView {
                            id: gridView
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM + 8
                            cellWidth: Math.floor((width - Theme.spacingM - 8) / 3)
                            cellHeight: 160
                            model: wallpaperModel
                            currentIndex: root.selectedIndex
                            cacheBuffer: 800
                            ScrollBar.vertical: ScrollBar {
                                id: scrollBar
                                anchors.right: parent.right
                                anchors.rightMargin: -Theme.spacingM - 4
                                width: 6
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: scrollBar.pressed ? Theme.primary : (scrollBar.hovered ? Theme.textMuted : Theme.outline)
                                }
                            }

                            delegate: Item {
                                width: gridView.cellWidth
                                height: gridView.cellHeight

                                required property string path
                                required property int index

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    radius: Theme.radiusM
                                    color: Theme.surface
                                    border.color: root.selectedIndex === parent.index ? Theme.primary : (root.currentWallpaper === parent.path ? Theme.primary : Theme.outline)
                                    border.width: root.selectedIndex === parent.index || root.currentWallpaper === parent.path ? 2 : 1

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: "file://" + path
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 280
                                        sourceSize.height: 180
                                        mipmap: true

                                        Rectangle {
                                            anchors.fill: parent
                                            color: Theme.surfaceVariant
                                            visible: parent.status !== Image.Ready
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf03e"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 24
                                                color: Theme.textMuted
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.currentWallpaper === path
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Theme.primary
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00c"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 11
                                            color: "white"
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 2
                                        height: 26
                                        color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.6)
                                        radius: Theme.radiusM - 2
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: parent.radius
                                            color: parent.color
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            width: parent.width - 8
                                            text: path.split('/').pop()
                                            font.pixelSize: Theme.fontSizeS
                                            color: "white"
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: root.selectedIndex = index
                                        onClicked: root.applyWallpaper(path)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "方向键选择 | Enter 应用 | Esc 取消"
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
