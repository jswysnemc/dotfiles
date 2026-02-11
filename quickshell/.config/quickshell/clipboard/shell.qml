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

    // ============ Position from environment ============
    property string posEnv: Quickshell.env("QS_POS") || "center"
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
    property var clipboardItems: []
    property var filteredItems: []
    property string searchText: ""
    property int selectedIndex: 0
    property bool loading: false
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-clipboard"

    // Preview state
    property bool previewVisible: false
    property var previewItem: null
    property string previewFullText: ""

    // ============ Clipboard Loading ============
    property string clipboardBuffer: ""
    
    Process {
        id: loadClipboard
        command: ["cliphist", "list"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                // 累积数据到缓冲区
                root.clipboardBuffer += data
            }
        }
        onExited: code => {
            // 进程结束后一次性解析所有数据
            if (code === 0) {
                root.parseClipboardData(root.clipboardBuffer)
            }
            root.clipboardBuffer = ""
            root.loading = false
        }
    }
    
    // File type classification by extension
    readonly property var imageExts: ["png", "jpg", "jpeg", "webp", "bmp", "tiff", "tif", "ico", "svg"]
    readonly property var gifExts: ["gif"]
    readonly property var videoExts: ["mp4", "mkv", "webm", "avi", "mov", "flv", "wmv", "m4v", "ts", "mpg", "mpeg"]

    function classifyFile(path) {
        var ext = path.split(".").pop().toLowerCase()
        if (gifExts.indexOf(ext) !== -1) return "gif"
        if (imageExts.indexOf(ext) !== -1) return "image"
        if (videoExts.indexOf(ext) !== -1) return "video"
        return "other"
    }

    function extractFilePaths(content) {
        // file URIs can be multi-line (multiple files copied)
        var lines = content.trim().split("\n")
        var paths = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.startsWith("file://")) {
                paths.push(decodeURIComponent(line.substring(7)))
            }
        }
        return paths
    }

    function parseClipboardData(data) {
        var lines = data.trim().split("\n")
        var seen = {}
        var items = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line) continue
            var tabIdx = line.indexOf("\t")
            if (tabIdx > 0) {
                var id = line.substring(0, tabIdx)
                var content = line.substring(tabIdx + 1)
                var isImage = content.startsWith("[[ binary data")
                var isFile = !isImage && content.indexOf("file://") !== -1

                var filePaths = []
                var fileType = ""
                if (isFile) {
                    filePaths = extractFilePaths(content)
                    if (filePaths.length === 0) { isFile = false }
                    else { fileType = classifyFile(filePaths[0]) }
                }

                var preview = ""
                if (isImage) {
                    preview = ""
                } else if (isFile) {
                    // Show file name(s) as preview
                    preview = filePaths.map(function(p) {
                        return p.split("/").pop()
                    }).join(", ")
                } else {
                    preview = content.substring(0, 200).replace(/\n/g, " ").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                }

                // Deduplicate
                var key = isImage ? ("img:" + content) : (isFile ? ("file:" + filePaths.join("|")) : preview)
                if (seen[key]) continue
                seen[key] = true

                items.push({
                    id: id,
                    isImage: isImage,
                    isFile: isFile,
                    fileType: fileType,
                    filePaths: filePaths,
                    rawContent: isFile ? content.trim() : "",
                    imagePath: "",
                    preview: preview
                })
            }
        }
        root.clipboardItems = items
        root.filterItems()
        // Decode binary images in background
        if (items.some(function(i) { return i.isImage })) {
            root.startImageDecode()
        }
        // Generate video thumbnails
        if (items.some(function(i) { return i.isFile && i.fileType === "video" })) {
            root.startVideoThumbGen()
        }
    }

    property var imageQueue: []
    property int imageIndex: 0
    property var imagePaths: ({})  // Map of id -> path

    Process {
        id: decodeImage
        property string currentId: ""
        command: ["bash", "-c", "echo"]
        onExited: code => {
            if (code === 0 && decodeImage.currentId) {
                var newPaths = Object.assign({}, root.imagePaths)
                newPaths[decodeImage.currentId] = root.cacheDir + "/" + decodeImage.currentId + ".png"
                root.imagePaths = newPaths
            }
            root.imageIndex++
            root.decodeNextImage()
        }
    }

    function startImageDecode() {
        imageQueue = clipboardItems.filter(i => i.isImage).map(i => i.id)
        imageIndex = 0
        if (imageQueue.length > 0) {
            mkCacheDir.running = true
        }
    }

    Process {
        id: mkCacheDir
        command: ["mkdir", "-p", cacheDir]
        onExited: root.decodeNextImage()
    }

    function decodeNextImage() {
        if (imageIndex >= imageQueue.length) return
        var id = imageQueue[imageIndex]
        decodeImage.currentId = id
        decodeImage.command = ["bash", "-c",
            "cliphist decode '" + id + "' > '" + cacheDir + "/" + id + ".png' 2>/dev/null && echo ok"
        ]
        decodeImage.running = true
    }

    // ============ Video Thumbnail Generation ============
    property var videoQueue: []
    property int videoIndex: 0
    property var videoThumbPaths: ({})  // Map of filePath -> thumb path

    Process {
        id: genVideoThumb
        property string currentPath: ""
        command: ["bash", "-c", "echo"]
        onExited: code => {
            if (code === 0 && genVideoThumb.currentPath) {
                var thumbFile = root.cacheDir + "/vthumb_" + Qt.md5(genVideoThumb.currentPath) + ".png"
                var newPaths = Object.assign({}, root.videoThumbPaths)
                newPaths[genVideoThumb.currentPath] = thumbFile
                root.videoThumbPaths = newPaths
            }
            root.videoIndex++
            root.genNextVideoThumb()
        }
    }

    function startVideoThumbGen() {
        var paths = []
        for (var i = 0; i < clipboardItems.length; i++) {
            var item = clipboardItems[i]
            if (item.isFile && item.fileType === "video" && item.filePaths.length > 0) {
                paths.push(item.filePaths[0])
            }
        }
        videoQueue = paths
        videoIndex = 0
        if (paths.length > 0) {
            mkCacheDir2.running = true
        }
    }

    Process {
        id: mkCacheDir2
        command: ["mkdir", "-p", cacheDir]
        onExited: root.genNextVideoThumb()
    }

    function genNextVideoThumb() {
        if (videoIndex >= videoQueue.length) return
        var filePath = videoQueue[videoIndex]
        genVideoThumb.currentPath = filePath
        var thumbFile = cacheDir + "/vthumb_" + Qt.md5(filePath) + ".png"
        genVideoThumb.command = ["ffmpegthumbnailer", "-i", filePath, "-o", thumbFile, "-s", "256", "-q", "8"]
        genVideoThumb.running = true
    }

    // ============ Fuzzy Search ============
    function fuzzyMatch(pattern, str) {
        if (!pattern) return { match: true, score: 0 }
        pattern = pattern.toLowerCase()
        str = str.toLowerCase()

        var pIdx = 0, sIdx = 0, score = 0, consecutive = 0, lastIdx = -1

        while (pIdx < pattern.length && sIdx < str.length) {
            if (pattern[pIdx] === str[sIdx]) {
                if (lastIdx === sIdx - 1) { consecutive++; score += consecutive * 2 }
                else consecutive = 0
                if (sIdx === 0 || " -_".includes(str[sIdx - 1])) score += 10
                lastIdx = sIdx
                pIdx++
            }
            sIdx++
        }

        if (pIdx === pattern.length) {
            score += Math.max(0, 50 - str.length)
            return { match: true, score: score }
        }
        return { match: false, score: 0 }
    }

    function filterItems() {
        if (!searchText) {
            filteredItems = clipboardItems.slice()
        } else {
            var results = []
            for (var i = 0; i < clipboardItems.length; i++) {
                var item = clipboardItems[i]
                if (item.isImage) continue
                // File entries: search against file names
                var searchTarget = item.isFile ? item.preview : item.preview
                var m = fuzzyMatch(searchText, searchTarget)
                if (m.match) results.push({ item: item, score: m.score, originalIndex: i })
            }
            results.sort(function(a, b) {
                if (b.score !== a.score) return b.score - a.score
                return a.originalIndex - b.originalIndex
            })
            filteredItems = results.map(function(r) { return r.item })
        }
        selectedIndex = 0
    }

    onSearchTextChanged: filterItems()

    // ============ Actions ============
    Process {
        id: copyProcess
        command: ["echo"]
    }

    Process {
        id: deleteProcess
        command: ["echo"]
    }

    Process {
        id: clearProcess
        command: ["bash", "-c", "cliphist wipe && rm -rf '" + cacheDir + "'"]
    }

    Process {
        id: getFullText
        property string targetId: ""
        command: ["bash", "-c", "echo"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root.previewFullText = data
            }
        }
    }

    function showPreview(item) {
        previewItem = item
        previewVisible = true
        if (item.isFile) {
            // For file entries, decode the raw content for preview
            getFullText.targetId = item.id
            getFullText.command = ["bash", "-c", "cliphist decode '" + item.id + "'"]
            getFullText.running = true
        } else if (!item.isImage) {
            getFullText.targetId = item.id
            getFullText.command = ["bash", "-c", "cliphist decode '" + item.id + "'"]
            getFullText.running = true
        }
    }

    function hidePreview() {
        previewVisible = false
        previewItem = null
        previewFullText = ""
    }

    function selectItem(item) {
        if (item.isFile) {
            // Restore file URIs with correct MIME type so file managers recognize it
            copyProcess.command = ["bash", "-c", "cliphist decode " + item.id + " | wl-copy --type text/uri-list"]
        } else {
            copyProcess.command = ["bash", "-c", "cliphist decode " + item.id + " | wl-copy"]
        }
        copyProcess.running = true
        root.closeWithAnimation()
    }

    function deleteItem(item) {
        deleteProcess.command = ["bash", "-c", "cliphist list | grep -m1 '^" + item.id + "\t' | cliphist delete"]
        deleteProcess.running = true
        clipboardItems = clipboardItems.filter(i => i.id !== item.id)
        filterItems()
    }

    function clearAll() {
        clearProcess.running = true
        clipboardItems = []
        filteredItems = []
    }

    function selectCurrent() {
        if (filteredItems.length > 0 && selectedIndex < filteredItems.length) {
            selectItem(filteredItems[selectedIndex])
        }
    }

    Component.onCompleted: {
        loading = true
        loadClipboard.running = true
        enterAnimation.start()
    }

    // ============ Animations ============
    ParallelAnimation {
        id: enterAnimation
        NumberAnimation { target: root; property: "panelOpacity"; from: 0; to: 1; duration: 20 }
        NumberAnimation { target: root; property: "panelScale"; from: 0.98; to: 1.0; duration: 20 }
        NumberAnimation { target: root; property: "panelY"; from: 4; to: 0; duration: 20 }
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation { target: root; property: "panelOpacity"; to: 0; duration: 20 }
        NumberAnimation { target: root; property: "panelScale"; to: 0.98; duration: 20 }
        NumberAnimation { target: root; property: "panelY"; to: -4; duration: 20 }
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
            WlrLayershell.namespace: "quickshell-clipboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true


            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }
            Shortcut { sequence: "Return"; onActivated: root.selectCurrent() }
            Shortcut { sequence: "Enter"; onActivated: root.selectCurrent() }
            Shortcut {
                sequence: "Up"
                onActivated: { if (root.selectedIndex > 0) root.selectedIndex-- }
            }
            Shortcut {
                sequence: "Down"
                onActivated: {
                    if (root.selectedIndex < root.filteredItems.length - 1) root.selectedIndex++
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: mainContainer
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
                width: 650
                height: 550
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
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf0ea"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 20
                            color: Theme.primary
                        }

                        Text {
                            text: "剪贴板"
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.filteredItems.length + " 条记录"
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.textMuted
                        }

                        Rectangle {
                            width: 28; height: 28
                            radius: Theme.radiusM
                            color: clearHover.hovered ? Theme.alpha(Theme.error, 0.1) : "transparent"
                            visible: root.clipboardItems.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 14
                                color: clearHover.hovered ? Theme.error : Theme.textMuted
                            }

                            HoverHandler { id: clearHover }
                            TapHandler { onTapped: root.clearAll() }
                        }

                        Rectangle {
                            width: 28; height: 28
                            radius: Theme.radiusM
                            color: closeHover.hovered ? Theme.surfaceVariant : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 16
                                color: Theme.textSecondary
                            }

                            HoverHandler { id: closeHover }
                            TapHandler { onTapped: root.closeWithAnimation() }
                        }
                    }

                    // Search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
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
                                font.pixelSize: 14
                                color: Theme.textMuted
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textPrimary
                                clip: true
                                focus: true
                                onTextChanged: root.searchText = text

                                Text {
                                    anchors.fill: parent
                                    text: "搜索文本..."
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textMuted
                                    visible: !searchInput.text
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // List
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: listFlickable
                            anchors.fill: parent
                            anchors.rightMargin: listScrollbar.visible ? 10 : 0
                            contentHeight: itemsCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: itemsCol
                                width: parent.width
                                spacing: Theme.spacingS

                                // Empty
                                ColumnLayout {
                                    visible: root.filteredItems.length === 0 && !root.loading
                                    Layout.fillWidth: true
                                    Layout.topMargin: Theme.spacingXL * 2
                                    spacing: Theme.spacingM

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "\uf0ea"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 48
                                        color: Theme.outline
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.searchText ? "没有匹配" : "剪贴板为空"
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textMuted
                                    }
                                }

                                // Loading
                                Text {
                                    visible: root.loading
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Theme.spacingXL * 2
                                    text: "加载中..."
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textMuted
                                }

                                // Items
                                Repeater {
                                    model: root.filteredItems

                                    Rectangle {
                                        id: clipItem
                                        required property var modelData
                                        required property int index

                                        // Helper properties
                                        property bool hasVisualPreview: modelData.isImage
                                            || (modelData.isFile && (modelData.fileType === "image" || modelData.fileType === "gif" || modelData.fileType === "video"))

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: hasVisualPreview ? 100 : 56
                                        radius: Theme.radiusM
                                        color: index === root.selectedIndex
                                            ? Theme.alpha(Theme.primary, 0.1)
                                            : (itemHover.hovered ? Theme.surfaceVariant : Theme.surface)
                                        border.color: index === root.selectedIndex ? Theme.primary : Theme.outline
                                        border.width: index === root.selectedIndex ? 2 : 1

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        HoverHandler { id: itemHover }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.RightButton) {
                                                    root.showPreview(clipItem.modelData)
                                                } else {
                                                    root.selectItem(clipItem.modelData)
                                                }
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM

                                            // Binary image preview (from cliphist decode)
                                            Rectangle {
                                                visible: clipItem.modelData.isImage
                                                Layout.preferredWidth: 84
                                                Layout.preferredHeight: 84
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    source: root.imagePaths[clipItem.modelData.id] ? "file://" + root.imagePaths[clipItem.modelData.id] : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true

                                                    Text {
                                                        visible: parent.status !== Image.Ready
                                                        anchors.centerIn: parent
                                                        text: "\uf03e"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 24
                                                        color: Theme.textMuted
                                                    }
                                                }
                                            }

                                            // File image/gif preview (direct from file path)
                                            Rectangle {
                                                visible: clipItem.modelData.isFile && (clipItem.modelData.fileType === "image" || clipItem.modelData.fileType === "gif")
                                                Layout.preferredWidth: 84
                                                Layout.preferredHeight: 84
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                clip: true

                                                // Static image
                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    visible: clipItem.modelData.isFile && clipItem.modelData.fileType === "image"
                                                    source: (clipItem.modelData.isFile && clipItem.modelData.fileType === "image" && clipItem.modelData.filePaths.length > 0)
                                                        ? "file://" + clipItem.modelData.filePaths[0] : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }

                                                // GIF preview
                                                AnimatedImage {
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    visible: clipItem.modelData.isFile && clipItem.modelData.fileType === "gif"
                                                    source: (clipItem.modelData.isFile && clipItem.modelData.fileType === "gif" && clipItem.modelData.filePaths.length > 0)
                                                        ? "file://" + clipItem.modelData.filePaths[0] : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    playing: true
                                                    asynchronous: true
                                                }

                                                Rectangle {
                                                    visible: clipItem.modelData.isFile && clipItem.modelData.fileType === "gif"
                                                    anchors.bottom: parent.bottom
                                                    anchors.right: parent.right
                                                    anchors.margins: 4
                                                    width: gifBadgeText.implicitWidth + 8
                                                    height: gifBadgeText.implicitHeight + 4
                                                    radius: 3
                                                    color: Theme.alpha(Qt.black, 0.6)

                                                    Text {
                                                        id: gifBadgeText
                                                        anchors.centerIn: parent
                                                        text: "GIF"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        color: "white"
                                                    }
                                                }
                                            }

                                            // File video thumbnail
                                            Rectangle {
                                                visible: clipItem.modelData.isFile && clipItem.modelData.fileType === "video"
                                                Layout.preferredWidth: 84
                                                Layout.preferredHeight: 84
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    source: (clipItem.modelData.isFile && clipItem.modelData.fileType === "video" && clipItem.modelData.filePaths.length > 0)
                                                        ? (root.videoThumbPaths[clipItem.modelData.filePaths[0]]
                                                            ? "file://" + root.videoThumbPaths[clipItem.modelData.filePaths[0]] : "")
                                                        : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true

                                                    Text {
                                                        visible: parent.status !== Image.Ready
                                                        anchors.centerIn: parent
                                                        text: "\uf03d"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 24
                                                        color: Theme.textMuted
                                                    }
                                                }

                                                // Play icon overlay
                                                Rectangle {
                                                    visible: parent.children[0].status === Image.Ready
                                                    anchors.centerIn: parent
                                                    width: 24; height: 24
                                                    radius: 12
                                                    color: Theme.alpha(Qt.black, 0.5)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf04b"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 10
                                                        color: "white"
                                                    }
                                                }
                                            }

                                            // File icon for non-previewable files
                                            Rectangle {
                                                visible: clipItem.modelData.isFile && clipItem.modelData.fileType === "other"
                                                width: 32; height: 32
                                                radius: Theme.radiusS
                                                color: Theme.alpha(Theme.tertiary, 0.1)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf15b"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 14
                                                    color: Theme.tertiary
                                                }
                                            }

                                            // Text icon (plain text entries)
                                            Rectangle {
                                                visible: !clipItem.modelData.isImage && !clipItem.modelData.isFile
                                                width: 32; height: 32
                                                radius: Theme.radiusS
                                                color: Theme.alpha(Theme.primary, 0.1)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf0f6"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 14
                                                    color: Theme.primary
                                                }
                                            }

                                            // Content column
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                // File entry: show file badge + path info
                                                RowLayout {
                                                    visible: clipItem.modelData.isFile
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        width: fileLabel.implicitWidth + 8
                                                        height: fileLabel.implicitHeight + 4
                                                        radius: 3
                                                        color: Theme.alpha(Theme.tertiary, 0.15)

                                                        Text {
                                                            id: fileLabel
                                                            anchors.centerIn: parent
                                                            text: clipItem.modelData.fileType === "gif" ? "GIF"
                                                                : clipItem.modelData.fileType === "image" ? "IMG"
                                                                : clipItem.modelData.fileType === "video" ? "VID"
                                                                : "FILE"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: Theme.tertiary
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: clipItem.modelData.preview
                                                        font.pixelSize: Theme.fontSizeS
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideMiddle
                                                        maximumLineCount: 1
                                                    }
                                                }

                                                // File path (secondary line)
                                                Text {
                                                    visible: clipItem.modelData.isFile && clipItem.modelData.filePaths.length > 0
                                                    Layout.fillWidth: true
                                                    text: {
                                                        if (!clipItem.modelData.isFile || clipItem.modelData.filePaths.length === 0) return ""
                                                        var p = clipItem.modelData.filePaths[0]
                                                        var dir = p.substring(0, p.lastIndexOf("/"))
                                                        var suffix = clipItem.modelData.filePaths.length > 1
                                                            ? "  (+" + (clipItem.modelData.filePaths.length - 1) + ")" : ""
                                                        return dir + suffix
                                                    }
                                                    font.pixelSize: Theme.fontSizeXS
                                                    color: Theme.textMuted
                                                    elide: Text.ElideMiddle
                                                    maximumLineCount: 1
                                                }

                                                // Plain text content
                                                Text {
                                                    visible: !clipItem.modelData.isImage && !clipItem.modelData.isFile
                                                    Layout.fillWidth: true
                                                    text: clipItem.modelData.preview
                                                    font.pixelSize: Theme.fontSizeS
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                }

                                                // Binary image label
                                                Text {
                                                    visible: clipItem.modelData.isImage
                                                    text: "图片"
                                                    font.pixelSize: Theme.fontSizeS
                                                    color: Theme.textSecondary
                                                }
                                            }

                                            // Delete
                                            Rectangle {
                                                width: 24; height: 24
                                                radius: 12
                                                color: delHover.hovered ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                visible: itemHover.hovered || delHover.hovered

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf00d"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 10
                                                    color: delHover.hovered ? Theme.error : Theme.textMuted
                                                }

                                                HoverHandler { id: delHover }
                                                TapHandler { onTapped: root.deleteItem(clipItem.modelData) }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Scrollbar
                        Rectangle {
                            id: listScrollbar
                            visible: listFlickable.contentHeight > listFlickable.height
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 6
                            color: "transparent"

                            Rectangle {
                                id: scrollHandle
                                anchors.right: parent.right
                                width: 6
                                height: Math.max(30, parent.height * listFlickable.height / listFlickable.contentHeight)
                                radius: 3
                                color: scrollHandleArea.containsMouse || scrollHandleArea.pressed
                                    ? Theme.textMuted : Theme.alpha(Theme.textMuted, 0.4)
                                y: listFlickable.contentHeight > listFlickable.height
                                    ? listFlickable.contentY / (listFlickable.contentHeight - listFlickable.height) * (parent.height - height)
                                    : 0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                MouseArea {
                                    id: scrollHandleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    drag.target: parent
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: listScrollbar.height - scrollHandle.height

                                    onPositionChanged: {
                                        if (drag.active && listFlickable.contentHeight > listFlickable.height) {
                                            var ratio = scrollHandle.y / (listScrollbar.height - scrollHandle.height)
                                            listFlickable.contentY = ratio * (listFlickable.contentHeight - listFlickable.height)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Enter 粘贴 | 右键 预览 | 方向键 导航 | Esc 关闭"
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                    }
                }
            }

            // Preview overlay
            Rectangle {
                visible: root.previewVisible
                anchors.fill: parent
                color: Theme.alpha(Qt.black, 0.5)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.hidePreview()
                }

                // Helper properties for preview sizing
                property bool isVisualPreview: root.previewItem && (root.previewItem.isImage
                    || (root.previewItem.isFile && root.previewItem.fileType !== "other"))

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.isVisualPreview ? Math.min(parent.width - 60, 800) : Math.min(parent.width - 60, 700)
                    height: parent.isVisualPreview ? Math.min(parent.height - 60, 650) : Math.min(parent.height - 60, 550)
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
                                text: {
                                    if (!root.previewItem) return "\uf0f6"
                                    if (root.previewItem.isImage) return "\uf03e"
                                    if (root.previewItem.isFile) {
                                        if (root.previewItem.fileType === "gif") return "\uf03e"
                                        if (root.previewItem.fileType === "image") return "\uf03e"
                                        if (root.previewItem.fileType === "video") return "\uf03d"
                                        return "\uf15b"
                                    }
                                    return "\uf0f6"
                                }
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 18
                                color: Theme.primary
                            }

                            Text {
                                text: {
                                    if (!root.previewItem) return ""
                                    if (root.previewItem.isImage) return "图片预览"
                                    if (root.previewItem.isFile) {
                                        if (root.previewItem.fileType === "gif") return "GIF 预览"
                                        if (root.previewItem.fileType === "image") return "图片预览"
                                        if (root.previewItem.fileType === "video") return "视频预览"
                                        return "文件信息"
                                    }
                                    return "文本预览"
                                }
                                font.pixelSize: Theme.fontSizeL
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 28; height: 28
                                radius: Theme.radiusM
                                color: previewCloseHover.hovered ? Theme.surfaceVariant : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 16
                                    color: Theme.textSecondary
                                }

                                HoverHandler { id: previewCloseHover }
                                TapHandler { onTapped: root.hidePreview() }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        // Content
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                id: previewFlickable
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: {
                                    if (!root.previewItem) return 0
                                    if (root.previewItem.isImage) return previewImage.height
                                    if (root.previewItem.isFile) {
                                        if (root.previewItem.fileType === "gif") return previewGif.height
                                        if (root.previewItem.fileType === "image") return previewFileImage.height
                                        if (root.previewItem.fileType === "video") return previewVideoThumb.height
                                        return previewFileInfo.implicitHeight
                                    }
                                    return previewTextEdit.contentHeight
                                }
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                // Binary image preview
                                Image {
                                    id: previewImage
                                    visible: root.previewItem && root.previewItem.isImage
                                    width: parent.width
                                    source: root.previewItem && root.previewItem.isImage && root.imagePaths[root.previewItem.id]
                                        ? "file://" + root.imagePaths[root.previewItem.id] : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                // File image preview
                                Image {
                                    id: previewFileImage
                                    visible: root.previewItem && root.previewItem.isFile && root.previewItem.fileType === "image"
                                    width: parent.width
                                    source: (root.previewItem && root.previewItem.isFile && root.previewItem.fileType === "image" && root.previewItem.filePaths.length > 0)
                                        ? "file://" + root.previewItem.filePaths[0] : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                // GIF preview
                                AnimatedImage {
                                    id: previewGif
                                    visible: root.previewItem && root.previewItem.isFile && root.previewItem.fileType === "gif"
                                    width: parent.width
                                    source: (root.previewItem && root.previewItem.isFile && root.previewItem.fileType === "gif" && root.previewItem.filePaths.length > 0)
                                        ? "file://" + root.previewItem.filePaths[0] : ""
                                    fillMode: Image.PreserveAspectFit
                                    playing: true
                                    asynchronous: true
                                }

                                // Video thumbnail preview
                                Image {
                                    id: previewVideoThumb
                                    visible: root.previewItem && root.previewItem.isFile && root.previewItem.fileType === "video"
                                    width: parent.width
                                    source: {
                                        if (!root.previewItem || !root.previewItem.isFile || root.previewItem.fileType !== "video" || root.previewItem.filePaths.length === 0) return ""
                                        var thumb = root.videoThumbPaths[root.previewItem.filePaths[0]]
                                        return thumb ? "file://" + thumb : ""
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true

                                    // Play icon overlay
                                    Rectangle {
                                        visible: previewVideoThumb.status === Image.Ready
                                        anchors.centerIn: parent
                                        width: 48; height: 48
                                        radius: 24
                                        color: Theme.alpha(Qt.black, 0.5)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf04b"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 20
                                            color: "white"
                                        }
                                    }
                                }

                                // File info for non-previewable files
                                ColumnLayout {
                                    id: previewFileInfo
                                    visible: root.previewItem && root.previewItem.isFile && root.previewItem.fileType === "other"
                                    width: parent.width
                                    spacing: Theme.spacingL

                                    // File icon
                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.topMargin: Theme.spacingXL
                                        width: 64; height: 64
                                        radius: Theme.radiusL
                                        color: Theme.alpha(Theme.tertiary, 0.1)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf15b"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 32
                                            color: Theme.tertiary
                                        }
                                    }

                                    // File list
                                    Repeater {
                                        model: root.previewItem && root.previewItem.isFile ? root.previewItem.filePaths : []

                                        ColumnLayout {
                                            required property string modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.split("/").pop()
                                                font.pixelSize: Theme.fontSizeM
                                                font.bold: true
                                                color: Theme.textPrimary
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData
                                                font.pixelSize: Theme.fontSizeS
                                                font.family: "monospace"
                                                color: Theme.textMuted
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WrapAnywhere
                                            }

                                            Rectangle {
                                                visible: index < (root.previewItem ? root.previewItem.filePaths.length - 1 : 0)
                                                Layout.fillWidth: true
                                                Layout.topMargin: Theme.spacingS
                                                Layout.bottomMargin: Theme.spacingS
                                                height: 1
                                                color: Theme.outline
                                                opacity: 0.4
                                            }
                                        }
                                    }
                                }

                                // Text preview (selectable)
                                TextEdit {
                                    id: previewTextEdit
                                    visible: root.previewItem && !root.previewItem.isImage && !root.previewItem.isFile
                                    width: parent.width
                                    text: root.previewFullText
                                    font.pixelSize: Theme.fontSizeM
                                    font.family: "monospace"
                                    color: Theme.textPrimary
                                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                    readOnly: true
                                    selectByMouse: true
                                    selectionColor: Theme.primary
                                    selectedTextColor: "white"
                                }
                            }

                            // Scrollbar (outside Flickable)
                            Rectangle {
                                visible: previewFlickable.contentHeight > previewFlickable.height
                                y: (previewFlickable.contentHeight > previewFlickable.height)
                                    ? previewFlickable.contentY / (previewFlickable.contentHeight - previewFlickable.height) * (parent.height - height)
                                    : 0
                                width: 6
                                height: Math.max(30, parent.height * parent.height / previewFlickable.contentHeight)
                                radius: 3
                                color: scrollbarArea.pressed ? Theme.textMuted : Theme.alpha(Theme.textMuted, 0.5)

                                MouseArea {
                                    id: scrollbarArea
                                    anchors.fill: parent
                                    drag.target: parent
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: previewFlickable.height - parent.height

                                    onPositionChanged: {
                                        if (drag.active) {
                                            var ratio = parent.y / (previewFlickable.height - parent.height)
                                            previewFlickable.contentY = ratio * (previewFlickable.contentHeight - previewFlickable.height)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
