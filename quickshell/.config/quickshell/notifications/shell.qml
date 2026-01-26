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
    property string posEnv: Quickshell.env("QS_POS") || "top-right"
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

    // State
    property var notifications: []
    property bool dndMode: false
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-notifications.sock"

    // Load history on start
    Component.onCompleted: loadHistory()

    Process {
        id: cmdProcess
        command: ["echo"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var resp = JSON.parse(data)
                    if (resp.history) {
                        root.notifications = resp.history.reverse()
                        root.dndMode = resp.dnd
                    }
                } catch (e) {}
            }
        }
    }

    function sendCmd(cmd) {
        cmdProcess.command = ["bash", "-c",
            "echo '" + JSON.stringify(cmd) + "' | nc -U -q0 '" + socketPath + "'"
        ]
        cmdProcess.running = true
    }

    function loadHistory() {
        sendCmd({cmd: "get_history"})
    }

    function toggleDnd() {
        dndMode = !dndMode
        sendCmd({cmd: "set_dnd", value: dndMode})
    }

    function clearAll() {
        notifications = []
        sendCmd({cmd: "clear_history"})
    }

    function deleteNotif(id) {
        notifications = notifications.filter(n => n.id !== id)
        sendCmd({cmd: "delete", id: id})
    }

    function invokeAction(id, action) {
        sendCmd({cmd: "action", id: id, action: action})
        // Close the notification panel after action
        Qt.quit()
    }

    // Invoke default action (click on notification)
    function invokeDefault(notif) {
        // Try default action first, then first available action
        if (notif.actions && notif.actions.length > 0) {
            var defaultAction = notif.actions.find(a => a.id === "default")
            if (defaultAction) {
                invokeAction(notif.id, "default")
            } else {
                invokeAction(notif.id, notif.actions[0].id)
            }
        }
    }

    // UI
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-notifications-bg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
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
            WlrLayershell.namespace: "qs-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: root.anchorTop && !root.anchorVCenter
            anchors.bottom: root.anchorBottom
            anchors.left: root.anchorLeft
            anchors.right: root.anchorRight
            margins.top: root.anchorTop ? root.marginT : 0
            margins.bottom: root.anchorBottom ? root.marginB : 0
            margins.left: root.anchorLeft ? root.marginL : 0
            margins.right: root.anchorRight ? root.marginR : 0
            implicitWidth: 420
            implicitHeight: 550


            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

            Rectangle {
                id: mainContainer
                anchors.fill: parent
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
                            text: "\uf0f3"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 20
                            color: Theme.primary
                        }

                        Text {
                            text: "通知中心"
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.notifications.length + " 条"
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.textMuted
                        }

                        // DND toggle
                        Rectangle {
                            width: 28; height: 28
                            radius: Theme.radiusM
                            color: root.dndMode ? Theme.alpha(Theme.error, 0.1) : (dndHover.hovered ? Theme.surfaceVariant : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: root.dndMode ? "\uf1f6" : "\uf0f3"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 14
                                color: root.dndMode ? Theme.error : Theme.textMuted
                            }

                            HoverHandler { id: dndHover }
                            TapHandler { onTapped: root.toggleDnd() }
                        }

                        // Clear all
                        Rectangle {
                            width: 28; height: 28
                            radius: Theme.radiusM
                            color: clearHover.hovered ? Theme.alpha(Theme.error, 0.1) : "transparent"
                            visible: root.notifications.length > 0

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

                        // Close
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

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // Notification list
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: notifCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: notifCol
                            width: parent.width
                            spacing: Theme.spacingS

                            // Empty state
                            ColumnLayout {
                                visible: root.notifications.length === 0
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.spacingXL * 2
                                spacing: Theme.spacingM

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "\uf0f3"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 48
                                    color: Theme.outline
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "暂无通知"
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textMuted
                                }
                            }

                            // Notification items
                            Repeater {
                                model: root.notifications

                                Rectangle {
                                    id: notifItem
                                    required property var modelData
                                    required property int index

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: notifContent.implicitHeight + Theme.spacingL * 2
                                    radius: Theme.radiusM
                                    color: itemHover.hovered ? Theme.surfaceVariant : Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    HoverHandler { id: itemHover }

                                    // Click to invoke default action
                                    TapHandler {
                                        onTapped: root.invokeDefault(notifItem.modelData)
                                    }

                                    RowLayout {
                                        id: notifContent
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingL
                                        spacing: Theme.spacingM

                                        // App icon
                                        Rectangle {
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 40
                                            Layout.alignment: Qt.AlignTop
                                            radius: Theme.radiusM
                                            color: Theme.alpha(Theme.primary, 0.1)

                                            Text {
                                                anchors.centerIn: parent
                                                text: getAppIcon(notifItem.modelData.app_name)
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 18
                                                color: Theme.primary
                                            }
                                        }

                                        // Content
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingXS

                                            // Header row
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingS

                                                Text {
                                                    text: notifItem.modelData.summary || notifItem.modelData.app_name || "Unknown"
                                                    font.pixelSize: Theme.fontSizeM
                                                    font.bold: true
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: formatTime(notifItem.modelData.timestamp)
                                                    font.pixelSize: Theme.fontSizeXS
                                                    color: Theme.textMuted
                                                }
                                            }

                                            // App name (if summary exists)
                                            Text {
                                                visible: notifItem.modelData.summary && notifItem.modelData.app_name
                                                text: notifItem.modelData.app_name || ""
                                                font.pixelSize: Theme.fontSizeXS
                                                color: Theme.textMuted
                                            }

                                            // Body
                                            Text {
                                                Layout.fillWidth: true
                                                text: notifItem.modelData.body || ""
                                                font.pixelSize: Theme.fontSizeS
                                                color: Theme.textSecondary
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                                visible: text !== ""
                                            }

                                            // Actions
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.topMargin: Theme.spacingXS
                                                spacing: Theme.spacingS
                                                visible: notifItem.modelData.actions && notifItem.modelData.actions.length > 0

                                                Repeater {
                                                    model: {
                                                        // Filter out "default" action from display
                                                        var actions = notifItem.modelData.actions || []
                                                        return actions.filter(a => a.id !== "default")
                                                    }

                                                    Rectangle {
                                                        required property var modelData

                                                        Layout.preferredHeight: 26
                                                        Layout.preferredWidth: actionText.implicitWidth + Theme.spacingM * 2
                                                        radius: Theme.radiusS
                                                        color: actionHover.hovered ? Theme.alpha(Theme.primary, 0.2) : Theme.alpha(Theme.primary, 0.1)

                                                        Text {
                                                            id: actionText
                                                            anchors.centerIn: parent
                                                            text: parent.modelData.label
                                                            font.pixelSize: Theme.fontSizeXS
                                                            color: Theme.primary
                                                        }

                                                        HoverHandler { id: actionHover }
                                                        TapHandler {
                                                            onTapped: root.invokeAction(notifItem.modelData.id, parent.modelData.id)
                                                        }
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }
                                            }
                                        }

                                        // Delete button
                                        Rectangle {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignTop
                                            radius: 12
                                            color: delHover.hovered ? Theme.alpha(Theme.error, 0.15) : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf00d"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 12
                                                color: delHover.hovered ? Theme.error : Theme.textMuted
                                            }

                                            HoverHandler { id: delHover }
                                            TapHandler { onTapped: root.deleteNotif(notifItem.modelData.id) }
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

    function formatTime(timestamp) {
        if (!timestamp) return ""
        var date = new Date(timestamp)
        var now = new Date()
        var diff = now - date

        if (diff < 60000) return "刚刚"
        if (diff < 3600000) return Math.floor(diff / 60000) + " 分钟前"
        if (diff < 86400000) return Math.floor(diff / 3600000) + " 小时前"
        return date.toLocaleDateString()
    }

    function getAppIcon(appName) {
        if (!appName) return "\uf0f3"
        var name = appName.toLowerCase()

        // Common apps
        if (name.includes("qq") || name.includes("tencent")) return "\uf1d6"
        if (name.includes("wechat") || name.includes("weixin") || name.includes("微信")) return "\uf1d7"
        if (name.includes("telegram")) return "\uf2c6"
        if (name.includes("discord")) return "\uf392"
        if (name.includes("slack")) return "\uf198"
        if (name.includes("firefox")) return "\uf269"
        if (name.includes("chrome") || name.includes("chromium")) return "\uf268"
        if (name.includes("code") || name.includes("vscode")) return "\ue70c"
        if (name.includes("spotify")) return "\uf1bc"
        if (name.includes("steam")) return "\uf1b6"
        if (name.includes("mail") || name.includes("thunderbird")) return "\uf0e0"
        if (name.includes("terminal") || name.includes("konsole") || name.includes("alacritty")) return "\uf120"
        if (name.includes("file") || name.includes("nautilus") || name.includes("dolphin")) return "\uf07b"
        if (name.includes("setting") || name.includes("config")) return "\uf013"
        if (name.includes("update") || name.includes("package")) return "\uf019"
        if (name.includes("screenshot") || name.includes("flameshot")) return "\uf030"
        if (name.includes("music") || name.includes("player")) return "\uf001"
        if (name.includes("video") || name.includes("mpv") || name.includes("vlc")) return "\uf03d"

        return "\uf0f3"  // Default bell icon
    }
}
