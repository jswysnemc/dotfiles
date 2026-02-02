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

    property string dataFile: Quickshell.env("HOME") + "/.local/share/quickshell/notes.json"
    property var todos: []
    property var notes: []
    property int activeTab: 0  // 0: todos, 1: notes
    property int editingNoteId: -1

    Component.onCompleted: {
        loadData()
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

    FileView {
        id: fileView
        path: root.dataFile
        onTextChanged: {
            if (text && text.length > 0) {
                try {
                    var data = JSON.parse(text)
                    root.todos = data.todos || []
                    root.notes = data.notes || []
                } catch (e) {
                    root.todos = []
                    root.notes = []
                }
            }
        }
    }

    function loadData() {
        if (fileView.text && fileView.text.length > 0) {
            try {
                var data = JSON.parse(fileView.text)
                todos = data.todos || []
                notes = data.notes || []
            } catch (e) {
                todos = []
                notes = []
            }
        }
    }

    function saveData() {
        saveProcess.running = true
    }

    Process {
        id: saveProcess
        command: ["bash", "-c", "mkdir -p ~/.local/share/quickshell && cat > " + root.dataFile]
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify({todos: root.todos, notes: root.notes}, null, 2))
            closeStdin()
        }
    }

    // Todo functions
    function addTodo(text) {
        if (text.trim() === "") return
        var newTodo = {
            id: Date.now(),
            text: text.trim(),
            done: false,
            createdAt: new Date().toISOString()
        }
        var newList = todos.slice()
        newList.push(newTodo)
        todos = newList
        saveData()
    }

    function toggleTodo(id) {
        todos = todos.map(function(t) {
            if (t.id === id) {
                return {id: t.id, text: t.text, done: !t.done, createdAt: t.createdAt}
            }
            return t
        })
        saveData()
    }

    function deleteTodo(id) {
        todos = todos.filter(function(t) { return t.id !== id })
        saveData()
    }

    function clearCompleted() {
        todos = todos.filter(function(t) { return !t.done })
        saveData()
    }

    // Note functions
    property var noteColors: ["#fef3c7", "#dbeafe", "#dcfce7", "#fce7f3", "#e0e7ff"]

    function addNote() {
        var newNote = {
            id: Date.now(),
            title: "新便签",
            content: "",
            color: noteColors[notes.length % noteColors.length],
            createdAt: new Date().toISOString()
        }
        var newList = notes.slice()
        newList.push(newNote)
        notes = newList
        editingNoteId = newNote.id
        saveData()
    }

    function updateNote(id, title, content) {
        notes = notes.map(function(n) {
            if (n.id === id) {
                return {id: n.id, title: title, content: content, color: n.color, createdAt: n.createdAt}
            }
            return n
        })
        saveData()
    }

    function deleteNote(id) {
        notes = notes.filter(function(n) { return n.id !== id })
        if (editingNoteId === id) editingNoteId = -1
        saveData()
    }

    function cycleNoteColor(id) {
        notes = notes.map(function(n) {
            if (n.id === id) {
                var idx = noteColors.indexOf(n.color)
                var newColor = noteColors[(idx + 1) % noteColors.length]
                return {id: n.id, title: n.title, content: n.content, color: newColor, createdAt: n.createdAt}
            }
            return n
        })
        saveData()
    }

    // Background overlay
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData

            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.3)
            WlrLayershell.namespace: "qs-todo-bg"
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

    // Main panel
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-todo"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }
            Shortcut { sequence: "Ctrl+1"; onActivated: root.activeTab = 0 }
            Shortcut { sequence: "Ctrl+2"; onActivated: root.activeTab = 1 }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: 450
                height: 520
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

                    // Tab bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                {icon: "\uf0ae", label: "待办", idx: 0},
                                {icon: "\uf249", label: "便签", idx: 1}
                            ]

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 40
                                radius: Theme.radiusM
                                color: root.activeTab === modelData.idx ? Theme.primary : (tabHover.hovered ? Theme.surfaceVariant : Theme.surface)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS

                                    Text {
                                        text: modelData.icon
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 16
                                        color: root.activeTab === modelData.idx ? "#ffffff" : Theme.textSecondary
                                    }

                                    Text {
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: root.activeTab === modelData.idx
                                        color: root.activeTab === modelData.idx ? "#ffffff" : Theme.textSecondary
                                    }
                                }

                                HoverHandler { id: tabHover }
                                TapHandler { onTapped: root.activeTab = modelData.idx }
                            }
                        }
                    }

                    // Content area
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.activeTab

                        // Tab 0: Todos
                        ColumnLayout {
                            spacing: Theme.spacingM

                            // Input field
                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                color: Theme.surface
                                radius: Theme.radiusM
                                border.color: inputField.activeFocus ? Theme.primary : Theme.outline
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS

                                    TextInput {
                                        id: inputField
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textPrimary
                                        clip: true
                                        selectByMouse: true

                                        property string placeholderText: "添加新任务..."
                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: inputField.placeholderText
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fontSizeM
                                            visible: !inputField.text && !inputField.activeFocus
                                        }

                                        Keys.onReturnPressed: {
                                            root.addTodo(text)
                                            text = ""
                                        }
                                    }

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: Theme.radiusS
                                        color: addBtnHover.hovered ? Theme.primary : Theme.alpha(Theme.primary, 0.8)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf067"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 14
                                            color: "#ffffff"
                                        }

                                        HoverHandler { id: addBtnHover }
                                        TapHandler {
                                            onTapped: {
                                                root.addTodo(inputField.text)
                                                inputField.text = ""
                                            }
                                        }
                                    }
                                }
                            }

                            // Stats
                            Text {
                                text: root.todos.filter(function(t) { return !t.done }).length + " 个待完成 / " + root.todos.length + " 个任务"
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                            }

                            // Todo list
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "transparent"

                                ListView {
                                    id: todoList
                                    anchors.fill: parent
                                    clip: true
                                    spacing: Theme.spacingS
                                    model: root.todos

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: todoList.width
                                        height: 44
                                        color: itemHover.hovered ? Theme.surfaceVariant : Theme.surface
                                        radius: Theme.radiusM

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM

                                            Rectangle {
                                                width: 22
                                                height: 22
                                                radius: Theme.radiusS
                                                color: modelData.done ? Theme.success : "transparent"
                                                border.color: modelData.done ? Theme.success : Theme.outline
                                                border.width: 2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf00c"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 12
                                                    color: "#ffffff"
                                                    visible: modelData.done
                                                }

                                                TapHandler {
                                                    onTapped: root.toggleTodo(modelData.id)
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.text
                                                font.pixelSize: Theme.fontSizeM
                                                color: modelData.done ? Theme.textMuted : Theme.textPrimary
                                                font.strikeout: modelData.done
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: Theme.radiusS
                                                color: deleteHover.hovered ? Theme.alpha(Theme.error, 0.1) : "transparent"
                                                visible: itemHover.hovered

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf1f8"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 12
                                                    color: deleteHover.hovered ? Theme.error : Theme.textMuted
                                                }

                                                HoverHandler { id: deleteHover }
                                                TapHandler {
                                                    onTapped: root.deleteTodo(modelData.id)
                                                }
                                            }
                                        }

                                        HoverHandler { id: itemHover }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "没有待办事项\n按 Enter 添加"
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textMuted
                                        horizontalAlignment: Text.AlignHCenter
                                        visible: root.todos.length === 0
                                    }
                                }
                            }

                            // Clear button
                            Rectangle {
                                visible: root.todos.some(function(t) { return t.done })
                                Layout.alignment: Qt.AlignRight
                                width: clearLabel.implicitWidth + Theme.spacingL * 2
                                height: 28
                                radius: Theme.radiusS
                                color: clearHover.hovered ? Theme.surfaceVariant : "transparent"
                                border.color: Theme.outline
                                border.width: 1

                                Text {
                                    id: clearLabel
                                    anchors.centerIn: parent
                                    text: "清除已完成"
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textSecondary
                                }

                                HoverHandler { id: clearHover }
                                TapHandler { onTapped: root.clearCompleted() }
                            }
                        }

                        // Tab 1: Notes
                        ColumnLayout {
                            spacing: Theme.spacingM

                            // Add note button
                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: Theme.radiusM
                                color: addNoteHover.hovered ? Theme.alpha(Theme.primary, 0.1) : Theme.surface
                                border.color: Theme.primary
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS

                                    Text {
                                        text: "\uf067"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 14
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: "新建便签"
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.primary
                                    }
                                }

                                HoverHandler { id: addNoteHover }
                                TapHandler { onTapped: root.addNote() }
                            }

                            // Notes grid
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "transparent"

                                GridView {
                                    id: notesGrid
                                    anchors.fill: parent
                                    clip: true
                                    cellWidth: (width - Theme.spacingS) / 2
                                    cellHeight: 140
                                    model: root.notes

                                    delegate: Item {
                                        required property var modelData
                                        required property int index
                                        width: notesGrid.cellWidth
                                        height: notesGrid.cellHeight

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingXS
                                            radius: Theme.radiusM
                                            color: modelData.color
                                            border.color: root.editingNoteId === modelData.id ? Theme.primary : "transparent"
                                            border.width: 2

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingS
                                                spacing: Theme.spacingXS

                                                // Header
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: Theme.spacingXS

                                                    TextInput {
                                                        id: noteTitleInput
                                                        Layout.fillWidth: true
                                                        text: modelData.title
                                                        font.pixelSize: Theme.fontSizeM
                                                        font.bold: true
                                                        color: "#374151"
                                                        selectByMouse: true
                                                        onTextChanged: {
                                                            if (activeFocus) {
                                                                root.updateNote(modelData.id, text, modelData.content)
                                                            }
                                                        }
                                                        onActiveFocusChanged: {
                                                            if (activeFocus) root.editingNoteId = modelData.id
                                                        }
                                                    }

                                                    // Color cycle
                                                    Rectangle {
                                                        width: 20
                                                        height: 20
                                                        radius: 10
                                                        color: colorHover.hovered ? "#00000020" : "transparent"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf53f"
                                                            font.family: "Symbols Nerd Font Mono"
                                                            font.pixelSize: 10
                                                            color: "#6b7280"
                                                        }

                                                        HoverHandler { id: colorHover }
                                                        TapHandler { onTapped: root.cycleNoteColor(modelData.id) }
                                                    }

                                                    // Delete
                                                    Rectangle {
                                                        width: 20
                                                        height: 20
                                                        radius: 10
                                                        color: noteDelHover.hovered ? "#fee2e2" : "transparent"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf00d"
                                                            font.family: "Symbols Nerd Font Mono"
                                                            font.pixelSize: 10
                                                            color: noteDelHover.hovered ? Theme.error : "#6b7280"
                                                        }

                                                        HoverHandler { id: noteDelHover }
                                                        TapHandler { onTapped: root.deleteNote(modelData.id) }
                                                    }
                                                }

                                                // Content
                                                ScrollView {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    clip: true

                                                    TextArea {
                                                        id: noteContentArea
                                                        text: modelData.content
                                                        font.pixelSize: Theme.fontSizeS
                                                        color: "#4b5563"
                                                        wrapMode: Text.Wrap
                                                        background: null
                                                        placeholderText: "写点什么..."

                                                        onTextChanged: {
                                                            if (activeFocus) {
                                                                root.updateNote(modelData.id, modelData.title, text)
                                                            }
                                                        }
                                                        onActiveFocusChanged: {
                                                            if (activeFocus) root.editingNoteId = modelData.id
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "没有便签\n点击上方按钮创建"
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textMuted
                                        horizontalAlignment: Text.AlignHCenter
                                        visible: root.notes.length === 0
                                    }
                                }
                            }
                        }
                    }

                    // Footer
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Esc 关闭 | Ctrl+1 待办 | Ctrl+2 便签"
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
