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
        catalog: "launcher"
    }

    readonly property var i18nContext: i18n

    // ============ Animation State ============
    property real containerOpacity: 1
    property bool blurActive: false

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
        { id: "all", name: i18n.trLiteral("全部"), icon: "\uf0c9" },
        { id: "dev", name: i18n.trLiteral("开发"), icon: "\uf121" },
        { id: "internet", name: i18n.trLiteral("网络"), icon: "\uf0ac" },
        { id: "media", name: i18n.trLiteral("媒体"), icon: "\uf001" },
        { id: "graphics", name: i18n.trLiteral("图形"), icon: "\uf03e" },
        { id: "office", name: i18n.trLiteral("办公"), icon: "\uf15c" },
        { id: "game", name: i18n.trLiteral("游戏"), icon: "\uf11b" },
        { id: "system", name: i18n.trLiteral("系统"), icon: "\uf085" },
        { id: "utility", name: i18n.trLiteral("工具"), icon: "\uf0ad" }
    ]

    function prepareApps(apps) {
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i]
            var name = app.name || ""
            var generic = app.genericName || ""
            var exec = app.exec || ""
            var icon = app.icon || ""
            var desktop = app.desktopFile || ""
            var keywords = (app.keywords || []).join(" ")

            app._nameLower = name.toLowerCase()
            app._genericLower = generic.toLowerCase()
            app._execLower = exec.toLowerCase()
            app._iconLower = icon.toLowerCase()
            app._desktopLower = desktop.toLowerCase()
            app._isWine = app.isWine === true || app.isWine === "true" || looksLikeWineApp(app)
            app._keywordsLower = (keywords + (app._isWine ? " wine windows" : "")).toLowerCase()

            var categoryName = app._nameLower + " " + app._genericLower + " " + app._keywordsLower + " " + app._desktopLower
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

    function looksLikeWineApp(app) {
        if (!app) return false

        var probe = [
            app._nameLower || (app.name || "").toLowerCase(),
            app._genericLower || (app.genericName || "").toLowerCase(),
            app._execLower || (app.exec || "").toLowerCase(),
            app._iconLower || (app.icon || "").toLowerCase(),
            app._desktopLower || (app.desktopFile || "").toLowerCase()
        ].join(" ")

        return probe.match(/(^|[\s\/\\;:=])wine(64|browser|cfg|server|tricks)?([\s\/\\;:._-]|$)|wineprefix|drive_c|dosdevices|\/\.wine|\/wine\/|proton/) !== null
    }

    function categoryNameForId(categoryId) {
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].id === categoryId) return categories[i].name
        }
        return categoryId || i18n.trLiteral("未知")
    }

    function compactDetailValue(value, maxLength) {
        if (!value) return ""
        var text = String(value)
        if (text.length <= maxLength) return text
        return text.slice(0, Math.max(0, maxLength - 3)) + "..."
    }

    function formatPathForDetail(path) {
        if (!path) return ""
        var text = String(path)
        var home = Quickshell.env("HOME") || ""
        if (home && text.indexOf(home) === 0) return "~" + text.slice(home.length)
        return text
    }

    function appDetailText(app) {
        if (!app) return ""

        var body = appDetailBodyText(app)
        return body ? (app.name || i18n.trLiteral("未知应用")) + "\n" + body : (app.name || i18n.trLiteral("未知应用"))
    }

    function appDetailBodyText(app) {
        if (!app) return ""

        var lines = []
        if (app.genericName) lines.push(i18n.trLiteral("描述: ") + compactDetailValue(app.genericName, 80))
        lines.push(i18n.trLiteral("分类: ") + categoryNameForId(app._category || getCategoryForApp(app)))
        if (app._isWine) lines.push(i18n.trLiteral("来源: Wine / Windows 应用"))
        if (app.terminal) lines.push(i18n.trLiteral("终端: 是"))
        if (app.exec) lines.push(i18n.trLiteral("命令: ") + compactDetailValue(app.exec, 120))
        if (app.icon) lines.push(i18n.trLiteral("图标: ") + compactDetailValue(formatPathForDetail(app.icon), 96))
        if (app.desktopFile) lines.push(i18n.trLiteral("桌面文件: ") + compactDetailValue(formatPathForDetail(app.desktopFile), 96))
        return lines.length > 0 ? lines.join("\n") : i18n.trLiteral("暂无更多详情")
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
    readonly property string cacheFile: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
        + "/qs-launcher-apps-" + i18n.normalizedLanguage + ".json"

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
            cache_file="$1"
            locale_code="$2"
            locale_short=$(printf '%s' "$locale_code" | cut -d_ -f1)
            apps='[]'

            desktop_value() {
                key="$1"
                file="$2"
                value=$(grep -F -m1 "$key[$locale_code]=" "$file" 2>/dev/null | cut -d= -f2-)
                if [ -z "$value" ] && [ "$locale_short" != "$locale_code" ]; then
                    value=$(grep -F -m1 "$key[$locale_short]=" "$file" 2>/dev/null | cut -d= -f2-)
                fi
                if [ -z "$value" ]; then
                    value=$(grep -m1 "^$key=" "$file" 2>/dev/null | cut -d= -f2-)
                fi
                printf '%s' "$value"
            }

            scan_desktop_dir() {
                [ -d "$1" ] || return
                find "$1" -type f -name '*.desktop' -print0
            }

            while IFS= read -r -d '' f; do
                [ -f "$f" ] || continue
                name=$(desktop_value "Name" "$f")
                [ -z "$name" ] && continue
                nodisplay=$(grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)
                hidden=$(grep -m1 '^Hidden=' "$f" 2>/dev/null | cut -d= -f2-)
                [ "$nodisplay" = "true" ] || [ "$hidden" = "true" ] && continue
                generic=$(desktop_value "GenericName" "$f")
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
                keywords=$(desktop_value "Keywords" "$f")
                terminal=$(grep -m1 '^Terminal=' "$f" 2>/dev/null | cut -d= -f2-)
                [ "$terminal" = "true" ] && term="true" || term="false"

                wine_probe=$(printf '%s\n%s\n%s\n%s' "$f" "$exec" "$name" "$icon" | tr '[:upper:]' '[:lower:]')
                if echo "$wine_probe" | grep -Eq '(^|[[:space:]/\\;:=])wine(64|browser|cfg|server|tricks)?([[:space:]/\\;:._-]|$)|wineprefix|drive_c|dosdevices|/\.wine|/wine/|proton'; then
                    is_wine=true
                else
                    is_wine=false
                fi

                apps=$(echo "$apps" | jq --arg n "$name" --arg g "$generic" --arg i "$icon" --arg e "$exec" --arg k "$keywords" --arg d "$f" --argjson t "$term" --argjson w "$is_wine" '. + [{"name":$n,"genericName":$g,"icon":$i,"exec":$e,"keywords":($k|split(";")|map(select(.!=""))),"terminal":$t,"desktopFile":$d,"isWine":$w}]')
            done < <(
                xdg_data_home="$XDG_DATA_HOME"
                [ -z "$xdg_data_home" ] && xdg_data_home="$HOME/.local/share"
                scan_desktop_dir "$xdg_data_home/applications"
                [ "$xdg_data_home" = "$HOME/.local/share" ] || scan_desktop_dir "$HOME/.local/share/applications"

                xdg_data_dirs="$XDG_DATA_DIRS"
                [ -z "$xdg_data_dirs" ] && xdg_data_dirs="/usr/local/share:/usr/share"
                old_ifs=$IFS
                IFS=:
                for data_dir in $xdg_data_dirs; do
                    scan_desktop_dir "$data_dir/applications"
                done
                IFS=$old_ifs
            )

            mkdir -p "$(dirname "$cache_file")"
            echo "$apps" | jq -c 'unique_by([.name, .exec])|sort_by(.name|ascii_downcase)' > "$cache_file"
            cat "$cache_file"
        `, "qs-launcher-refresh", root.cacheFile, i18n.normalizedLanguage]
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
    }

    /**
     * 关闭启动器窗口。
     *
     * @param 无
     * @returns 无
     */
    function closeWithAnimation() {
        // 1. 先关闭模糊区域，避免退出前全屏 layer 参与模糊
        root.blurActive = false
        // 2. 隐藏卡片后立即退出，保持与剪贴板一致
        root.containerOpacity = 0
        Qt.quit()
    }

    // ============ UI ============
    LauncherView {
        controller: root
    }
}
