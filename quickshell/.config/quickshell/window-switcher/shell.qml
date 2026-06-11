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
        catalog: "window-switcher"
    }

    readonly property var i18nContext: i18n

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: true

    // Grid config
    readonly property int cardWidth: 280
    readonly property int cardHeight: 180
    readonly property int columns: 3

    // State
    property var allWindows: []
    property var filteredWindows: []
    property string searchText: ""
    property int selectedIndex: 0
    property bool showCloseAllConfirm: false

    // App icons mapping
    readonly property var appIcons: ({
        "firefox": "\uf269",
        "code": "󰨞",
        "kitty": "",
        "dolphin": "",
        "chrome": "",
        "chromium": "",
        "telegram": "",
        "discord": "󰙯",
        "spotify": "",
        "vlc": "󰕼",
        "mpv": "",
        "gimp": "",
        "inkscape": "",
        "blender": "󰂫",
        "steam": "",
        "obs": "󰑋",
        "thunar": "",
        "nautilus": "",
        "alacritty": "",
        "wezterm": "",
        "foot": "",
        "konsole": "",
        "gnome-terminal": "",
        "libreoffice": "󰏆",
        "evince": "",
        "zathura": "",
        "eog": "",
        "feh": "",
        "imv": "",
        "pavucontrol": "󰕾",
        "nm-connection-editor": "󰖩",
        "blueman": "",
        "default": ""
    })

    // App colors for visual distinction
    readonly property var appColors: ({
        "firefox": "#ff7139",
        "code": "#007acc",
        "kitty": "#f0a030",
        "dolphin": "#1d99f3",
        "chrome": "#4285f4",
        "telegram": "#0088cc",
        "discord": "#5865f2",
        "spotify": "#1db954",
        "steam": "#1b2838",
        "default": "#3b6ef5"
    })

    function getAppIcon(appId) {
        if (!appId) return appIcons["default"]
        var id = appId.toLowerCase()
        for (var key in appIcons) {
            if (id.indexOf(key) !== -1) return appIcons[key]
        }
        return appIcons["default"]
    }

    function getAppColor(appId) {
        if (!appId) return appColors["default"]
        var id = appId.toLowerCase()
        for (var key in appColors) {
            if (id.indexOf(key) !== -1) return appColors[key]
        }
        return appColors["default"]
    }

    // Fuzzy search
    function fuzzyMatch(pattern, str) {
        if (!pattern) return { match: true, score: 0 }
        var patternLower = pattern.toLowerCase()
        var strLower = str.toLowerCase()

        var pIdx = 0, sIdx = 0, score = 0, consecutive = 0, lastIdx = -1

        while (pIdx < patternLower.length && sIdx < strLower.length) {
            if (patternLower[pIdx] === strLower[sIdx]) {
                if (lastIdx === sIdx - 1) { consecutive++; score += consecutive * 2 }
                else consecutive = 0
                if (sIdx === 0 || " -_".includes(strLower[sIdx - 1])) score += 10
                lastIdx = sIdx
                pIdx++
            }
            sIdx++
        }

        if (pIdx === patternLower.length) {
            score += Math.max(0, 50 - strLower.length)
            return { match: true, score: score }
        }
        return { match: false, score: 0 }
    }

    function filterWindows() {
        var windows = allWindows

        if (searchText) {
            var results = []
            for (var i = 0; i < windows.length; i++) {
                var win = windows[i]
                var titleMatch = fuzzyMatch(searchText, win.title || "")
                var appMatch = fuzzyMatch(searchText, win.app_id || "")
                var best = titleMatch.score > appMatch.score ? titleMatch : appMatch
                if (best.match) {
                    results.push({ win: win, score: best.score })
                }
            }
            results.sort((a, b) => b.score - a.score)
            windows = results.map(r => r.win)
        }

        filteredWindows = windows
        if (selectedIndex >= filteredWindows.length) {
            selectedIndex = Math.max(0, filteredWindows.length - 1)
        }
    }

    Timer {
        id: searchDebounce
        interval: 50
        repeat: false
        onTriggered: root.filterWindows()
    }

    onSearchTextChanged: searchDebounce.restart()

    // Navigation
    function moveLeft() {
        if (selectedIndex > 0) selectedIndex--
    }
    function moveRight() {
        if (selectedIndex < filteredWindows.length - 1) selectedIndex++
    }
    function moveUp() {
        if (selectedIndex >= columns) selectedIndex -= columns
    }
    function moveDown() {
        if (selectedIndex + columns < filteredWindows.length) selectedIndex += columns
        else if (selectedIndex < filteredWindows.length - 1) selectedIndex = filteredWindows.length - 1
    }

    // Load windows
    Process {
        id: loadWindows
        command: ["niri", "msg", "--json", "windows"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var windows = JSON.parse(data)
                    // Sort by workspace, then by focus timestamp (most recent first)
                    windows.sort((a, b) => {
                        if (a.workspace_id !== b.workspace_id) {
                            return a.workspace_id - b.workspace_id
                        }
                        var aTime = a.focus_timestamp ? (a.focus_timestamp.secs * 1e9 + a.focus_timestamp.nanos) : 0
                        var bTime = b.focus_timestamp ? (b.focus_timestamp.secs * 1e9 + b.focus_timestamp.nanos) : 0
                        return bTime - aTime
                    })
                    root.allWindows = windows
                    root.filterWindows()
                } catch (e) {
                    console.log("Failed to parse windows:", e)
                }
            }
        }
    }

    // Focus window
    Process {
        id: focusProcess
        command: ["niri", "msg", "action", "focus-window", "--id", "0"]
    }

    Timer {
        id: quitTimer
        interval: 100
        onTriggered: Qt.quit()
    }

    function focusWindow(win) {
        if (!win) return
        focusProcess.command = ["niri", "msg", "action", "focus-window", "--id", String(win.id)]
        focusProcess.running = true
        quitTimer.start()
    }

    function focusSelected() {
        if (filteredWindows.length > 0 && selectedIndex < filteredWindows.length) {
            focusWindow(filteredWindows[selectedIndex])
        }
    }

    // Close window
    Process {
        id: closeProcess
        command: ["niri", "msg", "action", "close-window"]
        onExited: loadWindows.running = true
    }

    function closeWindow(win) {
        if (!win) return
        closeProcess.command = ["niri", "msg", "action", "close-window", "--id", String(win.id)]
        closeProcess.running = true
    }

    function closeSelected() {
        if (filteredWindows.length > 0 && selectedIndex < filteredWindows.length) {
            closeWindow(filteredWindows[selectedIndex])
        }
    }

    // Close all windows
    property int closeAllIndex: 0
    property var windowsToClose: []

    function closeAllWindows() {
        if (filteredWindows.length === 0) return
        showCloseAllConfirm = true
    }

    function confirmCloseAll() {
        windowsToClose = filteredWindows.slice()
        closeAllIndex = 0
        closeNextWindow()
    }

    function closeNextWindow() {
        if (closeAllIndex >= windowsToClose.length) {
            showCloseAllConfirm = false
            loadWindows.running = true
            return
        }
        closeAllProcess.command = ["niri", "msg", "action", "close-window", "--id", String(windowsToClose[closeAllIndex].id)]
        closeAllProcess.running = true
    }

    Process {
        id: closeAllProcess
        command: ["niri", "msg", "action", "close-window"]
        onExited: {
            root.closeAllIndex++
            root.closeNextWindow()
        }
    }

    Component.onCompleted: {
        loadWindows.running = true
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
     * 关闭窗口切换弹窗窗口。
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

    // UI
    // ============ UI ============
    WindowSwitcherView {
        controller: root
    }
}
