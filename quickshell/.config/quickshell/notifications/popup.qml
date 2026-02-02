import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // ============ Animation State ============
    property real notifOpacity: 0
    property real notifX: 30
    property real notifScale: 0.98

    function getAppIcon(appName) {
        if (!appName) return "\uf0f3"
        var name = appName.toLowerCase()

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

        return "\uf0f3"
    }

    // State
    property var currentNotif: null
    property bool visible: false

    // Filter out "default" action for display
    property var displayActions: {
        if (!currentNotif || !currentNotif.actions) return []
        return currentNotif.actions.filter(a => a.id !== "default")
    }

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-notifications.sock"

    // Load notification from environment variable
    Component.onCompleted: {
        var data = Quickshell.env("QS_NOTIF_DATA")
        if (data) {
            try {
                root.currentNotif = JSON.parse(data)
                root.visible = true
                // 启动入场动画
                enterAnimation.start()
                hideTimer.start()
            } catch (e) {}
        } else {
            Qt.quit()
        }
    }

    // ============ 入场动画 (从右滑入，快速) ============
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "notifOpacity"
            from: 0; to: 1
            duration: 80
        }

        NumberAnimation {
            target: root
            property: "notifX"
            from: 30; to: 0
            duration: 100
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "notifScale"
            from: 0.98; to: 1.0
            duration: 80
        }
    }

    // ============ 退场动画 (滑出) ============
    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "notifOpacity"
            to: 0
            duration: 60
        }

        NumberAnimation {
            target: root
            property: "notifX"
            to: 20
            duration: 60
        }

        NumberAnimation {
            target: root
            property: "notifScale"
            to: 0.98
            duration: 60
        }

        onFinished: Qt.quit()
    }

    function dismissWithAnimation() {
        hideTimer.stop()
        exitAnimation.start()
    }

    Timer {
        id: hideTimer
        interval: 4000
        onTriggered: root.dismissWithAnimation()
    }

    function invokeAction(actionId) {
        sendCmd.command = ["bash", "-c",
            "echo '{\"cmd\":\"action\",\"id\":" + currentNotif.id + ",\"action\":\"" + actionId + "\"}' | nc -U -q0 '" + socketPath + "'"
        ]
        sendCmd.running = true
    }

    Process {
        id: sendCmd
        command: ["echo"]
        onExited: Qt.quit()
    }

    // UI
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData
            visible: root.visible && root.currentNotif

            color: "transparent"
            WlrLayershell.namespace: "qs-notification-popup"
            WlrLayershell.layer: WlrLayer.Overlay

            anchors.top: true
            anchors.right: true
            margins.top: 8
            margins.right: 8

            implicitWidth: 360
            implicitHeight: contentCol.implicitHeight + Theme.spacingL * 2

            Rectangle {
                id: contentContainer
                anchors.fill: parent
                color: Theme.surface
                radius: Theme.radiusL
                border.color: Theme.outline
                border.width: 1

                // 动画属性
                opacity: root.notifOpacity
                scale: root.notifScale
                transform: Translate { x: root.notifX }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: hideTimer.stop()
                    onExited: hideTimer.restart()
                    onClicked: {
                        var actions = root.currentNotif ? root.currentNotif.actions : []
                        if (actions && actions.length > 0) {
                            var defaultAction = actions.find(a => a.id === "default")
                            if (defaultAction) {
                                root.invokeAction("default")
                            } else {
                                root.invokeAction(actions[0].id)
                            }
                        } else {
                            root.dismissWithAnimation()
                        }
                    }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Main content row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        // App icon
                        Rectangle {
                            width: 44
                            height: 44
                            radius: Theme.radiusM
                            color: Theme.alpha(Theme.primary, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: root.currentNotif ? getAppIcon(root.currentNotif.app_name) : "\uf0f3"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 22
                                color: Theme.primary
                            }
                        }

                        // Text content
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            // Title row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text {
                                    Layout.fillWidth: true
                                    text: root.currentNotif ? (root.currentNotif.summary || root.currentNotif.app_name || "") : ""
                                    font.pixelSize: Theme.fontSizeL
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                // App name badge (if summary exists)
                                Rectangle {
                                    visible: root.currentNotif && root.currentNotif.summary && root.currentNotif.app_name
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: appNameText.implicitWidth + Theme.spacingS * 2
                                    radius: Theme.radiusS
                                    color: Theme.alpha(Theme.primary, 0.08)

                                    Text {
                                        id: appNameText
                                        anchors.centerIn: parent
                                        text: root.currentNotif ? root.currentNotif.app_name : ""
                                        font.pixelSize: Theme.fontSizeXS
                                        color: Theme.primary
                                    }
                                }
                            }

                            // Body
                            Text {
                                Layout.fillWidth: true
                                text: root.currentNotif ? (root.currentNotif.body || "") : ""
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textSecondary
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                elide: Text.ElideRight
                                maximumLineCount: 3
                                visible: text !== ""
                            }
                        }

                        // Close button
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            width: 24
                            height: 24
                            radius: 12
                            color: closeHover.hovered ? Theme.alpha(Theme.error, 0.1) : "transparent"
                            scale: closeTap.pressed ? 0.9 : (closeHover.hovered ? 1.1 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 12
                                color: closeHover.hovered ? Theme.error : Theme.textMuted

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            HoverHandler { id: closeHover }
                            TapHandler { id: closeTap; onTapped: root.dismissWithAnimation() }
                        }
                    }

                    // Action buttons row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS
                        visible: root.displayActions.length > 0

                        Repeater {
                            model: root.displayActions

                            Rectangle {
                                id: actionBtn
                                required property var modelData
                                required property int index

                                Layout.preferredHeight: 30
                                Layout.preferredWidth: Math.max(actionLabel.implicitWidth + Theme.spacingM * 2, 60)
                                radius: Theme.radiusS
                                color: actionBtnHover.hovered ? Theme.alpha(Theme.primary, 0.15) : Theme.alpha(Theme.primary, 0.08)
                                scale: actionBtnTap.pressed ? 0.95 : (actionBtnHover.hovered ? 1.03 : 1.0)

                                // 快速入场
                                opacity: 0
                                Component.onCompleted: actionEnterAnim.start()

                                SequentialAnimation {
                                    id: actionEnterAnim
                                    PauseAnimation { duration: 50 + actionBtn.index * 20 }
                                    NumberAnimation {
                                        target: actionBtn
                                        property: "opacity"
                                        to: 1
                                        duration: 60
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionBtn.modelData.label
                                    font.pixelSize: Theme.fontSizeS
                                    font.weight: Font.Medium
                                    color: Theme.primary
                                }

                                HoverHandler { id: actionBtnHover }
                                TapHandler {
                                    id: actionBtnTap
                                    onTapped: root.invokeAction(actionBtn.modelData.id)
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
