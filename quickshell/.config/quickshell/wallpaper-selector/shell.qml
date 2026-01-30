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
    property int currentTab: 0  // 0: wallpapers, 1: theme settings

    // Theme settings
    property string qsMode: "auto"
    property string waybarMode: "auto"

    // Wallpaper list model
    ListModel {
        id: wallpaperModel
    }

    readonly property string homeDir: Quickshell.env("HOME")

    Component.onCompleted: {
        loadWallpapers.running = true
        getCurrentWallpaper.running = true
        loadThemeStatus.running = true
    }

    // Load wallpapers using backend script
    Process {
        id: loadWallpapers
        command: ["wallpaper-manager", "list-simple"]
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
        command: ["wallpaper-manager", "current"]
        stdout: SplitParser {
            onRead: data => {
                root.currentWallpaper = data.trim()
            }
        }
    }

    Process {
        id: loadThemeStatus
        command: ["bash", "-c", "echo \"$(theme-gen --qs)|$(theme-gen --waybar)\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                if (parts.length >= 2) {
                    var qsPart = parts[0].split(":").pop().trim()
                    var wbPart = parts[1].split(":").pop().trim()
                    if (qsPart) root.qsMode = qsPart
                    if (wbPart) root.waybarMode = wbPart
                }
            }
        }
    }

    Process {
        id: setWallpaper
        command: ["wallpaper-manager", "set", ""]
        onExited: Qt.quit()
    }

    Process {
        id: setQsMode
        command: ["theme-gen", "--qs", ""]
        onExited: loadThemeStatus.running = true
    }

    Process {
        id: setWaybarMode
        command: ["theme-gen", "--waybar", ""]
        onExited: loadThemeStatus.running = true
    }

    Process {
        id: applyTheme
        command: ["theme-gen"]
        onExited: Qt.quit()
    }

    function applyWallpaper(path) {
        setWallpaper.command = ["wallpaper-manager", "set", path]
        setWallpaper.running = true
    }

    function setQsModeValue(mode) {
        setQsMode.command = ["theme-gen", "--qs", mode]
        setQsMode.running = true
        qsMode = mode
    }

    function setWaybarModeValue(mode) {
        setWaybarMode.command = ["theme-gen", "--waybar", mode]
        setWaybarMode.running = true
        waybarMode = mode
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
            Shortcut { sequence: "Tab"; onActivated: root.currentTab = (root.currentTab + 1) % 2 }

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

                    // Header
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
                            text: "壁纸与主题"
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

                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"

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

                    // Tab bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radiusM
                        color: Theme.surfaceVariant

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 3

                            Repeater {
                                model: [{name: "壁纸", icon: "\uf03e"}, {name: "主题设置", icon: "\uf1fc"}]

                                Rectangle {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusS
                                    color: root.currentTab === index ? Theme.surface : "transparent"

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: modelData.icon
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: Theme.fontSizeS
                                            color: root.currentTab === index ? Theme.primary : Theme.textMuted
                                        }

                                        Text {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeS
                                            font.bold: root.currentTab === index
                                            color: root.currentTab === index ? Theme.primary : Theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.currentTab = parent.index
                                    }
                                }
                            }
                        }
                    }

                    // Content
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.currentTab

                        // ============ Wallpapers Tab ============
                        Rectangle {
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

                        // ============ Theme Settings Tab ============
                        ColumnLayout {
                            spacing: Theme.spacingL

                            // 通用主题选择组件
                            component ThemeRow: Rectangle {
                                id: themeRow
                                property string title: ""
                                property string subtitle: ""
                                property string icon: ""
                                property color iconColor: Theme.primary
                                property color activeColor: Theme.primary
                                property string currentMode: ""
                                signal modeSelected(string mode)

                                Layout.fillWidth: true
                                height: 72
                                radius: Theme.radiusL
                                color: Theme.surface
                                border.color: Theme.outline
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingL
                                    anchors.rightMargin: Theme.spacingL
                                    spacing: Theme.spacingM

                                    // 左侧图标
                                    Rectangle {
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 44
                                        radius: Theme.radiusM
                                        color: Theme.surfaceVariant

                                        Text {
                                            anchors.centerIn: parent
                                            text: themeRow.icon
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 20
                                            color: themeRow.iconColor
                                        }
                                    }

                                    // 中间文字
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: themeRow.title
                                            font.pixelSize: Theme.fontSizeM
                                            font.bold: true
                                            color: Theme.textPrimary
                                        }

                                        Text {
                                            text: themeRow.subtitle
                                            font.pixelSize: Theme.fontSizeS
                                            color: Theme.textMuted
                                        }
                                    }

                                    // 右侧按钮组 - 固定宽度
                                    Row {
                                        Layout.preferredWidth: 200
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 6

                                        Repeater {
                                            model: [{mode: "dark", icon: "\uf186", label: "深色"},
                                                    {mode: "light", icon: "\uf185", label: "浅色"},
                                                    {mode: "auto", icon: "\uf021", label: "自动"}]

                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                width: 62; height: 32
                                                radius: Theme.radiusS
                                                color: themeRow.currentMode === modelData.mode ? themeRow.activeColor : (btnMa.containsMouse ? Theme.surfaceVariant : "transparent")
                                                border.color: themeRow.currentMode === modelData.mode ? themeRow.activeColor : Theme.outline
                                                border.width: 1

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Text {
                                                        text: modelData.icon
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 11
                                                        color: themeRow.currentMode === modelData.mode ? "white" : Theme.textSecondary
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        text: modelData.label
                                                        font.pixelSize: 11
                                                        color: themeRow.currentMode === modelData.mode ? "white" : Theme.textSecondary
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }

                                                MouseArea {
                                                    id: btnMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: themeRow.modeSelected(modelData.mode)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // QuickShell Theme
                            ThemeRow {
                                title: "QuickShell 主题"
                                subtitle: "控制 QuickShell 组件的颜色模式"
                                icon: "\uf0e7"
                                iconColor: Theme.primary
                                activeColor: Theme.primary
                                currentMode: root.qsMode
                                onModeSelected: mode => root.setQsModeValue(mode)
                            }

                            // Waybar Theme
                            ThemeRow {
                                title: "Waybar 主题"
                                subtitle: "控制状态栏的颜色模式"
                                icon: "\uf0c9"
                                iconColor: Theme.secondary
                                activeColor: Theme.secondary
                                currentMode: root.waybarMode
                                onModeSelected: mode => root.setWaybarModeValue(mode)
                            }

                            // Info box
                            Rectangle {
                                Layout.fillWidth: true
                                height: 70
                                radius: Theme.radiusL
                                color: Theme.alpha(Theme.tertiary, 0.1)
                                border.color: Theme.alpha(Theme.tertiary, 0.3)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Text {
                                        text: "\uf05a"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 20
                                        color: Theme.tertiary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "模式在下次设置壁纸时生效\n点击「立即应用」可立刻刷新所有组件主题"
                                        font.pixelSize: Theme.fontSizeS
                                        color: Theme.textSecondary
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            // Apply button
                            Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: Theme.radiusM
                                color: applyMa.containsMouse ? Theme.alpha(Theme.primary, 0.2) : Theme.alpha(Theme.primary, 0.1)
                                border.color: Theme.primary
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: "\uf021"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: Theme.fontSizeL
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: "立即应用主题"
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: applyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: applyTheme.running = true
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }

                    // Footer
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.currentTab === 0 ? "方向键选择 | Enter 应用 | Tab 切换 | Esc 关闭" : "点击切换模式 | Tab 切换 | Esc 关闭"
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
