import QtQuick
import QtQuick.Layouts
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
        catalog: "todo"
    }

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: true

    property string storeScript: Qt.resolvedUrl("todo_store.py").toString().replace("file://", "")
    property var todos: []
    property bool saveQueued: false

    Component.onCompleted: {
        loadProcess.running = true
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
        root.blurActive = false
        exitAnimation.start()
    }

    function normalizeTodo(todo) {
        if (!todo || typeof todo !== "object") return null

        var todoText = String(todo.text || "").trim()
        if (todoText === "") return null

        return {
            id: todo.id !== undefined ? todo.id : Date.now(),
            text: todoText,
            done: Boolean(todo.done),
            createdAt: todo.createdAt || new Date().toISOString(),
            completedAt: todo.completedAt || ""
        }
    }

    function loadTodosFromText(text) {
        try {
            var data = JSON.parse(text || "{}")
            var list = data.todos || []
            var normalized = []

            for (var i = 0; i < list.length; i++) {
                var todo = normalizeTodo(list[i])
                if (todo) normalized.push(todo)
            }

            root.todos = normalized
        } catch (e) {
            console.log("Failed to load todos:", e)
            root.todos = []
        }
    }

    function serializeTodos() {
        return JSON.stringify({todos: root.todos}, null, 2)
    }

    function doneCount() {
        var count = 0
        for (var i = 0; i < root.todos.length; i++) {
            if (root.todos[i].done) count += 1
        }
        return count
    }

    function pendingCount() {
        return root.todos.length - doneCount()
    }

    function saveData() {
        if (saveProcess.running) {
            root.saveQueued = true
            return
        }

        saveProcess.command = ["python3", root.storeScript, "save-json", root.serializeTodos()]
        saveProcess.running = true
    }

    Timer {
        id: queuedSaveTimer
        interval: 0
        repeat: false
        onTriggered: root.saveData()
    }

    Process {
        id: loadProcess
        command: ["python3", root.storeScript, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.loadTodosFromText(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) console.log("Todo load process failed:", exitCode)
        }
    }

    Process {
        id: saveProcess
        command: ["true"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) console.log("Todo save process failed:", exitCode)
            if (root.saveQueued) {
                root.saveQueued = false
                queuedSaveTimer.restart()
            }
        }
    }

    // Todo functions
    function addTodo(text) {
        var todoText = String(text || "").trim()
        if (todoText === "") return

        var newList = root.todos.slice()
        newList.push({
            id: Date.now(),
            text: todoText,
            done: false,
            createdAt: new Date().toISOString(),
            completedAt: ""
        })
        root.todos = newList
        saveData()
    }

    function toggleTodo(id) {
        var now = new Date().toISOString()
        root.todos = root.todos.map(function(t) {
            if (t.id === id) {
                var nextDone = !t.done
                return {
                    id: t.id,
                    text: t.text,
                    done: nextDone,
                    createdAt: t.createdAt,
                    completedAt: nextDone ? now : ""
                }
            }
            return t
        })
        saveData()
    }

    function deleteTodo(id) {
        root.todos = root.todos.filter(function(t) { return t.id !== id })
        saveData()
    }

    function clearCompleted() {
        root.todos = root.todos.filter(function(t) { return !t.done })
        saveData()
    }

    // Background overlay
    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

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
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-todo"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: root.blurActive ? dialog : null
                radius: Theme.radiusXL + 4
            }
            Connections {
                target: root
                function onBlurActiveChanged() { blurRegion.changed() }
                function onPanelScaleChanged() { blurRegion.changed() }
                function onPanelYChanged() { blurRegion.changed() }
            }
            Connections {
                target: dialog
                function onXChanged() { blurRegion.changed() }
                function onYChanged() { blurRegion.changed() }
                function onWidthChanged() { blurRegion.changed() }
                function onHeightChanged() { blurRegion.changed() }
            }
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: 430
                height: 480
                color: Theme.alpha(Theme.background, 0.28)
                radius: Theme.radiusXL + 4
                border.color: Theme.glassBorder
                border.width: 1.5

                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: root.panelOpacity

                // 高级光影
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 1.0
                    shadowVerticalOffset: 16
                }

                // 玻璃内描边
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 10
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 44
                            height: 44
                            radius: Theme.radiusM
                            color: Theme.alpha(Theme.primary, 0.14)
                            border.color: Theme.alpha(Theme.primary, 0.3)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\uf0ae"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 20
                                color: Theme.primary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: i18n.trLiteral("待办")
                                font.pixelSize: Theme.fontSizeXL
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Text {
                                text: root.pendingCount() + i18n.trLiteral(" 未完成 / ") + root.doneCount() + i18n.trLiteral(" 已完成")
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                            }
                        }
                    }

                    // Input field
                    Rectangle {
                        Layout.fillWidth: true
                        height: 42
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

                                property string placeholderText: i18n.trLiteral("添加新任务...")
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
                                width: 30
                                height: 30
                                radius: Theme.radiusS
                                color: addBtnHover.hovered ? Theme.primary : Theme.alpha(Theme.primary, 0.82)

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
                                text: i18n.tr("empty")
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                                visible: root.todos.length === 0
                            }
                        }
                    }

                    // Footer
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            Layout.fillWidth: true
                            text: i18n.trLiteral("Esc 关闭 | Enter 添加 | 点击复选框切换状态")
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: root.doneCount() > 0
                            width: clearLabel.implicitWidth + Theme.spacingL * 2
                            height: 28
                            radius: Theme.radiusS
                            color: clearHover.hovered ? Theme.surfaceVariant : "transparent"
                            border.color: Theme.outline
                            border.width: 1

                            Text {
                                id: clearLabel
                                anchors.centerIn: parent
                                text: i18n.trLiteral("清除已完成")
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textSecondary
                            }

                            HoverHandler { id: clearHover }
                            TapHandler { onTapped: root.clearCompleted() }
                        }
                    }
                }
            }
        }
    }
}
