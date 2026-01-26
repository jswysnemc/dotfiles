import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

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
    Process {
        id: loadClipboard
        command: ["cliphist", "list"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
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
                        // Skip file URI entries (from file manager copy operations)
                        if (!isImage && content.startsWith("file://")) continue
                        var preview = isImage ? "" : content.substring(0, 200).replace(/\n/g, " ").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                        // Deduplicate by content (keep first occurrence which is most recent)
                        var key = isImage ? ("img:" + content) : preview
                        if (seen[key]) continue
                        seen[key] = true
                        items.push({
                            id: id,
                            isImage: isImage,
                            imagePath: "",
                            preview: preview
                        })
                    }
                }
                root.clipboardItems = items
                root.filterItems()
                root.loading = false
                // Decode images in background
                if (items.some(i => i.isImage)) {
                    root.startImageDecode()
                }
            }
        }
        onExited: code => {
            root.loading = false
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
            filteredItems = clipboardItems
        } else {
            var results = []
            for (var i = 0; i < clipboardItems.length; i++) {
                var item = clipboardItems[i]
                if (item.isImage) continue
                var m = fuzzyMatch(searchText, item.preview)
                if (m.match) results.push({ item: item, score: m.score })
            }
            results.sort((a, b) => b.score - a.score)
            filteredItems = results.map(r => r.item)
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
        if (!item.isImage) {
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
        copyProcess.command = ["bash", "-c", "cliphist decode " + item.id + " | wl-copy"]
        copyProcess.running = true
        Qt.quit()
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


            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
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
                onClicked: Qt.quit()
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
                            TapHandler { onTapped: Qt.quit() }
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

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: modelData.isImage ? 100 : 56
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

                                            // Image preview
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

                                            // Text icon
                                            Rectangle {
                                                visible: !clipItem.modelData.isImage
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

                                            // Content
                                            Text {
                                                id: itemText
                                                visible: !clipItem.modelData.isImage
                                                Layout.fillWidth: true
                                                text: clipItem.modelData.preview
                                                font.pixelSize: Theme.fontSizeS
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                            }

                                            Text {
                                                visible: clipItem.modelData.isImage
                                                Layout.fillWidth: true
                                                text: "图片"
                                                font.pixelSize: Theme.fontSizeS
                                                color: Theme.textSecondary
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

                Rectangle {
                    anchors.centerIn: parent
                    width: root.previewItem && root.previewItem.isImage ? Math.min(parent.width - 60, 800) : Math.min(parent.width - 60, 700)
                    height: root.previewItem && root.previewItem.isImage ? Math.min(parent.height - 60, 650) : Math.min(parent.height - 60, 550)
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
                                text: root.previewItem && root.previewItem.isImage ? "\uf03e" : "\uf0f6"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 18
                                color: Theme.primary
                            }

                            Text {
                                text: root.previewItem && root.previewItem.isImage ? "图片预览" : "文本预览"
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
                                contentHeight: root.previewItem && root.previewItem.isImage ? previewImage.height : previewTextEdit.contentHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                // Image preview
                                Image {
                                    id: previewImage
                                    visible: root.previewItem && root.previewItem.isImage
                                    width: parent.width
                                    source: root.previewItem && root.imagePaths[root.previewItem.id]
                                        ? "file://" + root.imagePaths[root.previewItem.id] : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                // Text preview (selectable)
                                TextEdit {
                                    id: previewTextEdit
                                    visible: root.previewItem && !root.previewItem.isImage
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
