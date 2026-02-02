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
    property bool animationReady: false
    property real containerOpacity: 0
    property real containerScale: 0.92
    property real containerY: 20

    // ============ Position from environment ============
    property string posEnv: Quickshell.env("QS_POS") || "center"
    property int marginT: parseInt(Quickshell.env("QS_MARGIN_T")) || 0
    property int marginR: parseInt(Quickshell.env("QS_MARGIN_R")) || 0
    property int marginB: parseInt(Quickshell.env("QS_MARGIN_B")) || 0
    property int marginL: parseInt(Quickshell.env("QS_MARGIN_L")) || 0
    property bool anchorTop: posEnv.indexOf("top") !== -1
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    // ============ State ============
    property var allApps: []
    property var filteredApps: []
    property string searchText: ""
    property int selectedIndex: 0
    property bool isFullscreen: false
    property string selectedCategory: "all"
    property int selectedCategoryIndex: 0

    readonly property int itemSize: 90
    readonly property int iconSize: 48
    property int columnsPerRow: 7  // Will be updated based on container width

    function moveLeft() {
        if (selectedIndex > 0) selectedIndex--
    }

    function moveRight() {
        if (selectedIndex < filteredApps.length - 1) selectedIndex++
    }

    function moveUp() {
        if (selectedIndex >= columnsPerRow) {
            selectedIndex -= columnsPerRow
        }
    }

    function moveDown() {
        if (selectedIndex + columnsPerRow < filteredApps.length) {
            selectedIndex += columnsPerRow
        } else if (selectedIndex < filteredApps.length - 1) {
            selectedIndex = filteredApps.length - 1
        }
    }

    function nextCategory() {
        selectedCategoryIndex = (selectedCategoryIndex + 1) % categories.length
        selectedCategory = categories[selectedCategoryIndex].id
    }

    function prevCategory() {
        selectedCategoryIndex = (selectedCategoryIndex - 1 + categories.length) % categories.length
        selectedCategory = categories[selectedCategoryIndex].id
    }

    // ============ Categories ============
    readonly property var categories: [
        { id: "all", name: "全部", icon: "\uf0c9" },
        { id: "dev", name: "开发", icon: "\uf121" },
        { id: "internet", name: "网络", icon: "\uf0ac" },
        { id: "media", name: "媒体", icon: "\uf001" },
        { id: "graphics", name: "图形", icon: "\uf03e" },
        { id: "office", name: "办公", icon: "\uf15c" },
        { id: "game", name: "游戏", icon: "\uf11b" },
        { id: "system", name: "系统", icon: "\uf085" },
        { id: "utility", name: "工具", icon: "\uf0ad" }
    ]

    function prepareApps(apps) {
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i]
            var name = app.name || ""
            var generic = app.genericName || ""
            var exec = app.exec || ""
            var keywords = (app.keywords || []).join(" ")

            app._nameLower = name.toLowerCase()
            app._genericLower = generic.toLowerCase()
            app._execLower = exec.toLowerCase()
            app._keywordsLower = keywords.toLowerCase()

            var categoryName = app._nameLower + " " + app._genericLower + " " + app._keywordsLower
            app._category = getCategoryForAppLower(categoryName, app._execLower)

            if (app.icon) {
                app._iconSource = app.icon.startsWith("/")
                    ? "file://" + app.icon
                    : "image://icon/" + app.icon
            } else {
                app._iconSource = ""
            }
        }
        return apps
    }

    function getCategoryForAppLower(nameLower, execLower) {
        if (nameLower.match(/code|ide|editor|develop|程序|编程|terminal|konsole|kitty|alacritty|vim|emacs|git/)) return "dev"
        if (nameLower.match(/browser|firefox|chrome|telegram|discord|mail|网络|浏览|qq|wechat|slack/) || execLower.match(/firefox|chrome|telegram/)) return "internet"
        if (nameLower.match(/music|video|player|spotify|vlc|mpv|音乐|视频|media|audio/)) return "media"
        if (nameLower.match(/image|photo|gimp|inkscape|blender|图片|图像|draw|paint/)) return "graphics"
        if (nameLower.match(/office|writer|calc|impress|word|excel|文档|办公|libreoffice|wps/)) return "office"
        if (nameLower.match(/game|steam|游戏|play|lutris|wine/)) return "game"
        if (nameLower.match(/setting|config|system|monitor|系统|设置|管理|htop|task/)) return "system"
        return "utility"
    }

    function getCategoryForApp(app) {
        var name = ((app.name || "") + " " + (app.genericName || "") + " " + (app.keywords || []).join(" ")).toLowerCase()
        var exec = (app.exec || "").toLowerCase()

        return getCategoryForAppLower(name, exec)
    }

    // ============ Fuzzy Search ============
    function fuzzyMatchLower(patternLower, strLower) {
        if (!patternLower) return { match: true, score: 0 }

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

    function filterApps() {
        var apps = allApps

        // Filter by category
        if (selectedCategory !== "all") {
            apps = apps.filter(app => (app._category || getCategoryForApp(app)) === selectedCategory)
        }

        // Filter by search
        if (searchText) {
            var searchLower = searchText.toLowerCase()
            var results = []
            for (var i = 0; i < apps.length; i++) {
                var app = apps[i]
                var nameLower = app._nameLower || (app.name || "").toLowerCase()
                var genericLower = app._genericLower || (app.genericName || "").toLowerCase()
                var execLower = app._execLower || (app.exec || "").toLowerCase()
                var keywordsLower = app._keywordsLower || (app.keywords || []).join(" ").toLowerCase()

                var m1 = fuzzyMatchLower(searchLower, nameLower)
                var m2 = fuzzyMatchLower(searchLower, genericLower)
                var m3 = fuzzyMatchLower(searchLower, execLower)
                var m4 = fuzzyMatchLower(searchLower, keywordsLower)
                var best = m1
                if (m2.score > best.score) best = m2
                if (m3.score > best.score) best = m3
                if (m4.score > best.score) best = m4
                if (best.match) results.push({ app: app, score: best.score })
            }
            results.sort((a, b) => b.score - a.score)
            apps = results.map(r => r.app)
        }

        filteredApps = apps
        selectedIndex = 0
    }

    Timer {
        id: searchDebounce
        interval: 100
        repeat: false
        onTriggered: root.filterApps()
    }

    onSearchTextChanged: searchDebounce.restart()
    onSelectedCategoryChanged: filterApps()

    // ============ App Loading (cached JSON) ============
    readonly property string cacheFile: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/qs-launcher-apps.json"

    Process {
        id: loadCache
        command: ["cat", root.cacheFile]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.allApps = root.prepareApps(JSON.parse(data))
                    root.filterApps()
                } catch (e) {}
                // Refresh cache in background
                refreshCache.running = true
            }
        }
        onExited: code => {
            if (code !== 0) refreshCache.running = true
        }
    }

    Process {
        id: refreshCache
        command: ["bash", "-c", `
            apps='[]'
            for f in /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop; do
                [ -f "$f" ] || continue
                name=$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2-)
                [ -z "$name" ] && continue
                nodisplay=$(grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)
                hidden=$(grep -m1 '^Hidden=' "$f" 2>/dev/null | cut -d= -f2-)
                [ "$nodisplay" = "true" ] || [ "$hidden" = "true" ] && continue
                generic=$(grep -m1 '^GenericName=' "$f" 2>/dev/null | cut -d= -f2-)
                icon=$(grep -m1 '^Icon=' "$f" 2>/dev/null | cut -d= -f2-)
                # Resolve icon path if not absolute
                if [ -n "$icon" ] && ! echo "$icon" | grep -q '^/'; then
                    for ext in png svg; do
                        for dir in ~/.local/share/icons /usr/share/pixmaps; do
                            if [ -f "$dir/$icon.$ext" ]; then
                                icon="$dir/$icon.$ext"
                                break 2
                            fi
                        done
                    done
                fi
                exec=$(grep -m1 '^Exec=' "$f" 2>/dev/null | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g')
                keywords=$(grep -m1 '^Keywords=' "$f" 2>/dev/null | cut -d= -f2-)
                terminal=$(grep -m1 '^Terminal=' "$f" 2>/dev/null | cut -d= -f2-)
                [ "$terminal" = "true" ] && term="true" || term="false"
                apps=$(echo "$apps" | jq --arg n "$name" --arg g "$generic" --arg i "$icon" --arg e "$exec" --arg k "$keywords" --argjson t "$term" '. + [{"name":$n,"genericName":$g,"icon":$i,"exec":$e,"keywords":($k|split(";")|map(select(.!=""))),"terminal":$t}]')
            done
            echo "$apps" | jq -c 'unique_by(.name)|sort_by(.name|ascii_downcase)' > ` + root.cacheFile + `
            cat ` + root.cacheFile
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.allApps = root.prepareApps(JSON.parse(data))
                    root.filterApps()
                } catch (e) {}
            }
        }
    }

    // Launch app
    Process {
        id: launchProcess
        command: ["bash", "-c", "echo"]
    }

    Timer {
        id: quitTimer
        interval: 100
        onTriggered: Qt.quit()
    }

    function launchApp(app) {
        if (!app || !app.exec) return
        var cmd = app.exec
        if (app.terminal) {
            cmd = "kitty -e " + cmd
        }
        launchProcess.command = ["bash", "-c", "nohup " + cmd + " >/dev/null 2>&1 &"]
        launchProcess.running = true
        quitTimer.start()
    }

    function launchSelected() {
        if (filteredApps.length > 0 && selectedIndex < filteredApps.length) {
            launchApp(filteredApps[selectedIndex])
        }
    }

    Component.onCompleted: {
        loadCache.running = true
        enterAnimation.start()
    }

    // ============ 入场动画 ============
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "containerOpacity"
            from: 0; to: 1
            duration: 20
        }

        NumberAnimation {
            target: root
            property: "containerScale"
            from: 0.98; to: 1.0
            duration: 20
        }

        NumberAnimation {
            target: root
            property: "containerY"
            from: 4; to: 0
            duration: 20
        }

        onFinished: root.animationReady = true
    }

    // ============ 退场动画 ============
    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "containerOpacity"
            to: 0
            duration: 20
        }

        NumberAnimation {
            target: root
            property: "containerScale"
            to: 0.98
            duration: 20
        }

        NumberAnimation {
            target: root
            property: "containerY"
            to: -4
            duration: 20
        }

        onFinished: Qt.quit()
    }

    function closeWithAnimation() {
        exitAnimation.start()
    }

    // ============ UI ============
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true


            // Keyboard
            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }
            Shortcut { sequence: "Return"; onActivated: root.launchSelected() }
            Shortcut { sequence: "Enter"; onActivated: root.launchSelected() }
            Shortcut { sequence: "Tab"; onActivated: root.nextCategory() }
            Shortcut { sequence: "Shift+Tab"; onActivated: root.prevCategory() }
            Shortcut { sequence: "F11"; onActivated: root.isFullscreen = !root.isFullscreen }

            Shortcut { sequence: "Left"; onActivated: root.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: root.moveRight() }
            Shortcut { sequence: "Up"; onActivated: root.moveUp() }
            Shortcut { sequence: "Down"; onActivated: root.moveDown() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            // Main container
            Rectangle {
                id: mainContainer
                anchors.top: root.isFullscreen ? undefined : (root.anchorTop ? parent.top : undefined)
                anchors.bottom: root.isFullscreen ? undefined : (root.anchorBottom ? parent.bottom : undefined)
                anchors.left: root.isFullscreen ? undefined : (root.anchorLeft ? parent.left : undefined)
                anchors.right: root.isFullscreen ? undefined : (root.anchorRight ? parent.right : undefined)
                anchors.horizontalCenter: root.isFullscreen ? parent.horizontalCenter : (root.anchorHCenter ? parent.horizontalCenter : undefined)
                anchors.verticalCenter: root.isFullscreen ? parent.verticalCenter : (root.anchorVCenter ? parent.verticalCenter : undefined)
                anchors.topMargin: root.isFullscreen ? 0 : (root.anchorTop ? root.marginT : 0)
                anchors.bottomMargin: root.isFullscreen ? 0 : (root.anchorBottom ? root.marginB : 0)
                anchors.leftMargin: root.isFullscreen ? 0 : (root.anchorLeft ? root.marginL : 0)
                anchors.rightMargin: root.isFullscreen ? 0 : (root.anchorRight ? root.marginR : 0)
                width: root.isFullscreen ? parent.width - 40 : 720
                height: root.isFullscreen ? parent.height - 40 : 660
                color: Theme.background
                radius: Theme.radiusXL
                border.color: Theme.outline
                border.width: 1

                // 动画属性
                opacity: root.containerOpacity
                scale: root.containerScale
                transform: Translate { y: root.containerY }

                Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        // Search box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Theme.radiusXL
                            color: Theme.surface
                            border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
                            border.width: searchInput.activeFocus ? 2 : 1

                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.width { NumberAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Text {
                                    text: "\uf002"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 16
                                    color: Theme.textMuted
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: Theme.fontSizeL
                                    color: Theme.textPrimary
                                    clip: true
                                    focus: true
                                    activeFocusOnTab: true
                                    inputMethodHints: Qt.ImhNone
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
                                                root.launchSelected()
                                                event.accepted = true
                                                break
                                            case Qt.Key_Escape:
                                                root.closeWithAnimation()
                                                event.accepted = true
                                                break
                                            case Qt.Key_Tab:
                                                root.nextCategory()
                                                event.accepted = true
                                                break
                                            case Qt.Key_Backtab:
                                                root.prevCategory()
                                                event.accepted = true
                                                break
                                        }
                                    }

                                    Text {
                                        anchors.fill: parent
                                        text: "搜索应用..."
                                        font.pixelSize: Theme.fontSizeL
                                        color: Theme.textMuted
                                        visible: !searchInput.text
                                    }
                                }

                                Text {
                                    visible: root.searchText !== ""
                                    text: root.filteredApps.length + " 个"
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textMuted
                                }
                            }
                        }

                        // Size toggle button
                        Rectangle {
                            width: 44; height: 44
                            radius: Theme.radiusL
                            color: sizeHover.hovered ? Theme.alpha(Theme.textPrimary, 0.08) : Theme.surface
                            border.color: Theme.outline
                            border.width: 1
                            scale: sizeHover.hovered ? 1.05 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: root.isFullscreen ? "\uf066" : "\uf065"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 16
                                color: Theme.textSecondary

                                // 图标切换动画
                                Behavior on text {
                                    SequentialAnimation {
                                        NumberAnimation { target: parent; property: "scale"; to: 0.8; duration: 80 }
                                        PropertyAction { }
                                        NumberAnimation { target: parent; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack }
                                    }
                                }
                            }

                            HoverHandler { id: sizeHover }
                            TapHandler { onTapped: root.isFullscreen = !root.isFullscreen }
                        }
                    }

                    // Category bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Theme.radiusL
                        color: Theme.surface
                        border.color: Theme.outline
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.categories

                                Rectangle {
                                    id: catBtn
                                    required property var modelData
                                    required property int index

                                    Layout.fillHeight: true
                                    Layout.preferredWidth: catRow.implicitWidth + Theme.spacingM * 2
                                    radius: Theme.radiusM
                                    color: root.selectedCategory === modelData.id
                                        ? Theme.primary
                                        : (catHover.hovered ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent")
                                    scale: catHover.hovered ? 1.05 : 1.0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                    HoverHandler { id: catHover }
                                    TapHandler { onTapped: root.selectedCategory = catBtn.modelData.id }

                                    RowLayout {
                                        id: catRow
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS

                                        Text {
                                            text: catBtn.modelData.icon
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 12
                                            color: root.selectedCategory === catBtn.modelData.id
                                                ? "white" : Theme.textSecondary

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }

                                        Text {
                                            text: catBtn.modelData.name
                                            font.pixelSize: Theme.fontSizeS
                                            color: root.selectedCategory === catBtn.modelData.id
                                                ? "white" : Theme.textSecondary

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // App grid
                    Flickable {
                        id: appFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: appFlow.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                        }

                        function ensureVisible() {
                            if (root.filteredApps.length === 0) return
                            var row = Math.floor(root.selectedIndex / root.columnsPerRow)
                            var itemHeight = root.itemSize + 24 + Theme.spacingS
                            var itemTop = row * itemHeight
                            var itemBottom = itemTop + itemHeight

                            if (itemTop < contentY) {
                                contentY = itemTop
                            } else if (itemBottom > contentY + height) {
                                contentY = itemBottom - height
                            }
                        }

                        Connections {
                            target: root
                            function onSelectedIndexChanged() {
                                appFlickable.ensureVisible()
                            }
                        }

                        Flow {
                            id: appFlow
                            width: parent.width
                            spacing: Theme.spacingS

                            onWidthChanged: {
                                root.columnsPerRow = Math.max(1, Math.floor((width + Theme.spacingS) / (root.itemSize + Theme.spacingS)))
                            }

                            Repeater {
                                model: root.filteredApps

                                Rectangle {
                                    id: appItem
                                    required property var modelData
                                    required property int index

                                    width: root.itemSize
                                    height: root.itemSize + 24
                                    radius: Theme.radiusL
                                    color: index === root.selectedIndex
                                        ? Theme.alpha(Theme.primary, 0.15)
                                        : (appHover.hovered ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent")

                                    // 图标立即显示
                                    opacity: 1
                                    scale: 1.0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    // 悬停缩放效果
                                    property real hoverScale: appHover.hovered && index !== root.selectedIndex ? 1.05 : 1.0
                                    Behavior on hoverScale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                    HoverHandler { id: appHover }
                                    TapHandler {
                                        onTapped: {
                                            // 点击弹跳动画
                                            clickBounce.start()
                                            root.launchApp(appItem.modelData)
                                        }
                                    }

                                    SequentialAnimation {
                                        id: clickBounce
                                        NumberAnimation { target: appItem; property: "scale"; to: 0.92; duration: 50; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: appItem; property: "scale"; to: 1.0; duration: 80; easing.type: Easing.OutCubic }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS
                                        spacing: Theme.spacingXS

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: root.iconSize
                                            height: root.iconSize
                                            scale: appItem.hoverScale

                                            Image {
                                                id: iconImg
                                                anchors.fill: parent
                                                source: appItem.modelData._iconSource || ""
                                                sourceSize: Qt.size(root.iconSize, root.iconSize)
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true
                                                visible: status === Image.Ready

                                                // 图标加载淡入
                                                opacity: status === Image.Ready ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                            }

                                            Rectangle {
                                                visible: iconImg.status !== Image.Ready
                                                anchors.fill: parent
                                                radius: Theme.radiusM
                                                color: Theme.surfaceVariant

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf135"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 28
                                                    color: Theme.textMuted
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: appItem.modelData.name
                                            font.pixelSize: Theme.fontSizeS
                                            color: Theme.textPrimary
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        }
                                    }

                                    // 选中边框
                                    Rectangle {
                                        visible: appItem.index === root.selectedIndex
                                        anchors.fill: parent
                                        radius: Theme.radiusL
                                        color: "transparent"
                                        border.color: Theme.primary
                                        border.width: 2

                                        // 选中时的脉冲效果 (更快更微妙)
                                        opacity: 1
                                        SequentialAnimation on opacity {
                                            running: appItem.index === root.selectedIndex
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.7; duration: 500; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // Hints
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Enter 启动 | Tab 切换分类 | F11 全屏 | 方向键 导航 | Esc 关闭"
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
