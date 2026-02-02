import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15

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

    function closeWithAnimation() {
        exitAnimation.start()
    }

    // UI
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData

            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.5)
            WlrLayershell.namespace: "qs-window-switcher-bg"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-window-switcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // Keyboard shortcuts
            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }
            Shortcut { sequence: "Return"; onActivated: root.focusSelected() }
            Shortcut { sequence: "Enter"; onActivated: root.focusSelected() }
            Shortcut { sequence: "Ctrl+D"; onActivated: root.closeSelected() }
            Shortcut { sequence: "Ctrl+Shift+D"; onActivated: root.closeAllWindows() }

            Shortcut { sequence: "Left"; onActivated: root.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: root.moveRight() }
            Shortcut { sequence: "Up"; onActivated: root.moveUp() }
            Shortcut { sequence: "Down"; onActivated: root.moveDown() }
            Shortcut { sequence: "h"; onActivated: root.moveLeft() }
            Shortcut { sequence: "l"; onActivated: root.moveRight() }
            Shortcut { sequence: "k"; onActivated: root.moveUp() }
            Shortcut { sequence: "j"; onActivated: root.moveDown() }
            Shortcut { sequence: "Ctrl+H"; onActivated: root.moveLeft() }
            Shortcut { sequence: "Ctrl+L"; onActivated: root.moveRight() }
            Shortcut { sequence: "Ctrl+K"; onActivated: root.moveUp() }
            Shortcut { sequence: "Ctrl+J"; onActivated: root.moveDown() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            // Main container
            Rectangle {
                id: mainContainer
                anchors.centerIn: parent
                width: Math.min(root.columns * (root.cardWidth + Theme.spacingM) + Theme.spacingXL * 2, parent.width - 80)
                height: Math.min(contentCol.implicitHeight + Theme.spacingXL * 2, parent.height - 80)
                color: Theme.background
                radius: Theme.radiusXL
                border.color: Theme.outline
                border.width: 1

                opacity: root.panelOpacity
                scale: root.panelScale
                transform: Translate { y: root.panelY }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Search box (fzf style)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: Theme.radiusL
                        color: Theme.surface
                        border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
                        border.width: searchInput.activeFocus ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            Text {
                                text: "\uf002"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 18
                                color: Theme.primary
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                font.pixelSize: Theme.fontSizeL
                                font.family: "monospace"
                                color: Theme.textPrimary
                                clip: true
                                focus: true
                                activeFocusOnTab: true
                                onTextChanged: root.searchText = text

                                Keys.onPressed: function(event) {
                                    switch (event.key) {
                                        case Qt.Key_Left:
                                            root.moveLeft()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Right:
                                            root.moveRight()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Up:
                                            root.moveUp()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Down:
                                            root.moveDown()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Return:
                                        case Qt.Key_Enter:
                                            root.focusSelected()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Escape:
                                            root.closeWithAnimation()
                                            event.accepted = true
                                            break
                                    }
                                }

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 2
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Type to filter windows..."
                                    font.pixelSize: Theme.fontSizeL
                                    font.family: "monospace"
                                    color: Theme.textMuted
                                    visible: !searchInput.text
                                }
                            }

                            Rectangle {
                                width: countText.implicitWidth + Theme.spacingM * 2
                                height: 24
                                radius: 12
                                color: Theme.surfaceVariant

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: root.filteredWindows.length + "/" + root.allWindows.length
                                    font.pixelSize: Theme.fontSizeS
                                    font.family: "monospace"
                                    color: Theme.textMuted
                                }
                            }

                            // Close All Button
                            Rectangle {
                                visible: root.filteredWindows.length > 0
                                width: closeAllText.implicitWidth + Theme.spacingM * 2
                                height: 24
                                radius: 12
                                color: closeAllHover.hovered ? Theme.error : Theme.alpha(Theme.error, 0.1)

                                Text {
                                    id: closeAllText
                                    anchors.centerIn: parent
                                    text: "关闭全部"
                                    font.pixelSize: Theme.fontSizeS
                                    color: closeAllHover.hovered ? "white" : Theme.error
                                }

                                HoverHandler { id: closeAllHover }
                                TapHandler { onTapped: root.closeAllWindows() }
                            }
                        }
                    }

                    // Window grid
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: {
                            var rows = Math.ceil(root.filteredWindows.length / root.columns)
                            return Math.min(rows * (root.cardHeight + Theme.spacingM), 500)
                        }
                        contentHeight: windowGrid.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        GridLayout {
                            id: windowGrid
                            width: parent.width
                            columns: root.columns
                            rowSpacing: Theme.spacingM
                            columnSpacing: Theme.spacingM

                            Repeater {
                                model: root.filteredWindows

                                Rectangle {
                                    id: winCard
                                    required property var modelData
                                    required property int index

                                    Layout.preferredWidth: root.cardWidth
                                    Layout.preferredHeight: root.cardHeight
                                    radius: Theme.radiusL
                                    color: Theme.surface
                                    border.color: index === root.selectedIndex ? Theme.primary : Theme.outline
                                    border.width: index === root.selectedIndex ? 2 : 1

                                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                    // Hover effect
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusL
                                        color: winHover.hovered ? Theme.alpha(Theme.textPrimary, 0.03) : "transparent"
                                    }

                                    HoverHandler { id: winHover }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingS

                                        // Preview area (simulated)
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: Theme.radiusM
                                            color: Theme.alpha(root.getAppColor(winCard.modelData.app_id), 0.08)
                                            border.color: Theme.alpha(root.getAppColor(winCard.modelData.app_id), 0.2)
                                            border.width: 1

                                            // App icon centered
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.getAppIcon(winCard.modelData.app_id)
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 48
                                                color: root.getAppColor(winCard.modelData.app_id)
                                                opacity: 0.6
                                            }

                                            // Workspace badge
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.margins: Theme.spacingS
                                                width: wsText.implicitWidth + Theme.spacingS * 2
                                                height: 20
                                                radius: 10
                                                color: Theme.primary

                                                Text {
                                                    id: wsText
                                                    anchors.centerIn: parent
                                                    text: "WS " + winCard.modelData.workspace_id
                                                    font.pixelSize: Theme.fontSizeXS
                                                    font.bold: true
                                                    color: "white"
                                                }
                                            }

                                            // Status badges
                                            Row {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: Theme.spacingS
                                                spacing: Theme.spacingXS

                                                Rectangle {
                                                    visible: winCard.modelData.is_focused
                                                    width: 20
                                                    height: 20
                                                    radius: 10
                                                    color: Theme.success

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf00c"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 10
                                                        color: "white"
                                                    }
                                                }

                                                Rectangle {
                                                    visible: winCard.modelData.is_floating
                                                    width: 20
                                                    height: 20
                                                    radius: 10
                                                    color: Theme.warning

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf24d"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 10
                                                        color: "white"
                                                    }
                                                }
                                            }
                                        }

                                        // Window info
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingS

                                                Rectangle {
                                                    width: 20
                                                    height: 20
                                                    radius: Theme.radiusS
                                                    color: Theme.alpha(root.getAppColor(winCard.modelData.app_id), 0.15)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root.getAppIcon(winCard.modelData.app_id)
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 11
                                                        color: root.getAppColor(winCard.modelData.app_id)
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: winCard.modelData.title || "Untitled"
                                                    font.pixelSize: Theme.fontSizeM
                                                    font.bold: winCard.modelData.is_focused
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: winCard.modelData.app_id || "unknown"
                                                font.pixelSize: Theme.fontSizeS
                                                font.family: "monospace"
                                                color: Theme.textMuted
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    // Close button (top level for proper event handling)
                                    Rectangle {
                                        id: closeBtn
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: Theme.spacingM + 90  // Below preview area
                                        anchors.rightMargin: Theme.spacingM + Theme.spacingS
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: closeHover.hovered ? Theme.error : Theme.alpha(Theme.error, 0.1)
                                        visible: winHover.hovered || index === root.selectedIndex
                                        z: 10

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00d"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 12
                                            color: closeHover.hovered ? "white" : Theme.error
                                        }

                                        HoverHandler { id: closeHover }
                                    }

                                    // Card click area (must be after close button to check it)
                                    MouseArea {
                                        anchors.fill: parent
                                        z: 5
                                        onClicked: function(mouse) {
                                            // Check if click is on close button
                                            var closeBtnPos = closeBtn.mapToItem(winCard, 0, 0)
                                            if (closeBtn.visible &&
                                                mouse.x >= closeBtnPos.x && mouse.x <= closeBtnPos.x + closeBtn.width &&
                                                mouse.y >= closeBtnPos.y && mouse.y <= closeBtnPos.y + closeBtn.height) {
                                                root.closeWindow(winCard.modelData)
                                            } else {
                                                root.focusWindow(winCard.modelData)
                                            }
                                        }
                                    }

                                    // Selection glow
                                    Rectangle {
                                        visible: index === root.selectedIndex
                                        anchors.fill: parent
                                        anchors.margins: -2
                                        radius: Theme.radiusL + 2
                                        color: "transparent"
                                        border.color: Theme.alpha(Theme.primary, 0.3)
                                        border.width: 3
                                        z: -1
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Rectangle {
                        visible: root.filteredWindows.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        color: "transparent"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.searchText ? "\uf002" : "\uf2d2"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 48
                                color: Theme.textMuted
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.searchText ? "No matching windows" : "No windows open"
                                font.pixelSize: Theme.fontSizeL
                                color: Theme.textMuted
                            }
                        }
                    }

                    // Hints
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.radiusM
                        color: Theme.surfaceVariant

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXL

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Enter"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Switch"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Ctrl+D"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Close"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Ctrl+Shift+D"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Close All"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "H/J/K/L"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Navigate"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Esc"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Cancel"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }
                        }
                    }
                }

                // Close All Confirmation Dialog
                Rectangle {
                    visible: root.showCloseAllConfirm
                    anchors.fill: parent
                    color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.6)
                    radius: Theme.radiusXL

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.showCloseAllConfirm = false
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 320
                        height: confirmContent.implicitHeight + Theme.spacingXL * 2
                        color: Theme.background
                        radius: Theme.radiusXL
                        border.color: Theme.outline
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: function(mouse) { mouse.accepted = true }
                        }

                        ColumnLayout {
                            id: confirmContent
                            anchors.centerIn: parent
                            anchors.margins: Theme.spacingXL
                            spacing: Theme.spacingL

                            // Warning Icon
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56
                                height: 56
                                radius: 28
                                color: Theme.alpha(Theme.error, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf071"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 26
                                    color: Theme.error
                                }
                            }

                            // Title
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "关闭全部窗口"
                                font.pixelSize: Theme.fontSizeL
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            // Message
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "确定要关闭全部 " + root.filteredWindows.length + " 个窗口吗？"
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textSecondary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "此操作不可撤销"
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.warning
                            }

                            // Buttons
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: Theme.spacingM

                                Rectangle {
                                    width: 100
                                    height: 36
                                    radius: Theme.radiusM
                                    color: cancelConfirmHover.hovered ? Theme.surfaceVariant : Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "取消 (N)"
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textSecondary
                                    }

                                    HoverHandler { id: cancelConfirmHover }
                                    TapHandler { onTapped: root.showCloseAllConfirm = false }
                                }

                                Rectangle {
                                    width: 120
                                    height: 36
                                    radius: Theme.radiusM
                                    color: confirmCloseHover.hovered ? Theme.alpha(Theme.error, 0.8) : Theme.error

                                    Text {
                                        anchors.centerIn: parent
                                        text: "全部关闭 (Y)"
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.surface
                                    }

                                    HoverHandler { id: confirmCloseHover }
                                    TapHandler { onTapped: root.confirmCloseAll() }
                                }
                            }
                        }

                        // Keyboard handling for confirm dialog
                        focus: root.showCloseAllConfirm
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Y) {
                                root.confirmCloseAll()
                                event.accepted = true
                            } else if (event.key === Qt.Key_N || event.key === Qt.Key_Escape) {
                                root.showCloseAllConfirm = false
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
