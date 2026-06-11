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
        catalog: "wallpaper-selector"
    }

    readonly property var i18nContext: i18n

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: true

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
        enterAnimation.start()
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
     * 关闭壁纸选择弹窗窗口。
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
        onExited: root.closeWithAnimation()
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
        onExited: root.closeWithAnimation()
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

    // ============ UI ============
    WallpaperSelectorView {
        controller: root
    }
}
