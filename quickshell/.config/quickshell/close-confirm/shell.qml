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

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property var targetWindow: null
    property bool hasTargetWindow: targetWindow !== null && targetWindow !== undefined
    readonly property string targetTitle: hasTargetWindow && targetWindow.title ? targetWindow.title : "未知标题"
    readonly property string targetAppId: hasTargetWindow && targetWindow.app_id ? targetWindow.app_id : "unknown"
    readonly property string targetWorkspace: hasTargetWindow && targetWindow.workspace_id !== undefined ? String(targetWindow.workspace_id) : "-"
    readonly property string targetPid: hasTargetWindow && targetWindow.pid !== undefined ? String(targetWindow.pid) : "-"

    Process {
        id: closeProcess
        command: ["niri", "msg", "action", "close-window"]
        onExited: Qt.quit()
    }

    function confirmClose() {
        closeProcess.running = true
    }

    function setTargetWindow(win) {
        if (win && typeof win === "object" && win.id !== undefined && win.id !== null) {
            targetWindow = win
            closeProcess.command = ["niri", "msg", "action", "close-window", "--id", String(win.id)]
        } else {
            targetWindow = null
            closeProcess.command = ["niri", "msg", "action", "close-window"]
        }
    }

    function loadTargetWindowFromEnv() {
        var data = Quickshell.env("QS_TARGET_WINDOW_JSON")
        if (!data) return false

        try {
            var win = JSON.parse(data)
            setTargetWindow(win)
            return hasTargetWindow
        } catch (e) {
            console.log("Failed to parse target window:", e)
            return false
        }
    }

    Process {
        id: loadFocusedWindow
        command: ["niri", "msg", "--json", "focused-window"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.setTargetWindow(JSON.parse(data))
                } catch (e) {
                    console.log("Failed to load focused window:", e)
                }
            }
        }
    }

    Component.onCompleted: {
        if (!loadTargetWindowFromEnv()) {
            loadFocusedWindow.running = true
        }
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

    // Background overlay
    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData

            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.3)
            WlrLayershell.namespace: "qs-close-confirm-bg"
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

    // Main dialog
    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-close-confirm"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.closeWithAnimation() }
            Shortcut { sequence: "Return"; onActivated: root.confirmClose() }
            Shortcut { sequence: "y"; onActivated: root.confirmClose() }
            Shortcut { sequence: "n"; onActivated: root.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: 380
                height: contentCol.implicitHeight + Theme.spacingXL * 2
                color: Theme.alpha(Theme.background, 0.9)
                radius: Theme.radiusXL + 4
                border.color: Theme.glassBorder
                border.width: 1.5

                opacity: root.panelOpacity
                scale: root.panelScale
                transform: Translate { y: root.panelY }

                // 高级光影
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.alpha(Theme.error, 0.2)
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

                // 顶部错误色脉冲条
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 3
                    radius: 1.5
                    z: 11
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.error, 0.0) }
                        GradientStop { position: 0.5; color: Theme.error }
                        GradientStop { position: 1.0; color: Theme.alpha(Theme.error, 0.0) }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingXL * 2
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Icon
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 56
                        height: 56
                        radius: 28
                        color: Theme.alpha(Theme.error, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 26
                            color: Theme.error
                        }
                    }

                    // Title
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "关闭窗口"
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Message
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.hasTargetWindow ? "确定要关闭以下窗口吗？" : "确定要关闭当前窗口吗？"
                        font.pixelSize: Theme.fontSizeM
                        color: Theme.textSecondary
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: windowInfoCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.radiusL
                        color: Theme.surface
                        border.color: root.hasTargetWindow ? Theme.alpha(Theme.error, 0.25) : Theme.outline
                        border.width: 1

                        ColumnLayout {
                            id: windowInfoCol
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Theme.radiusS
                                    color: Theme.alpha(Theme.error, 0.1)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf2d2"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 14
                                        color: Theme.error
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.hasTargetWindow ? root.targetTitle : "未获取到窗口信息"
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.hasTargetWindow ? root.targetAppId : "将按 niri 当前聚焦窗口执行"
                                        font.pixelSize: Theme.fontSizeS
                                        font.family: "monospace"
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text {
                                    text: "工作区 " + root.targetWorkspace
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textSecondary
                                }

                                Text {
                                    text: "PID " + root.targetPid
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textSecondary
                                }

                                Text {
                                    visible: root.hasTargetWindow && root.targetWindow.id !== undefined
                                    text: "ID " + root.targetWindow.id
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }

                    // Buttons
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 100
                            height: 36
                            radius: Theme.radiusM
                            color: cancelHover.hovered ? Theme.surfaceVariant : Theme.surface
                            border.color: Theme.outline
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "取消 (N)"
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textSecondary
                            }

                            HoverHandler { id: cancelHover }
                            TapHandler { onTapped: root.closeWithAnimation() }
                        }

                        Rectangle {
                            width: 100
                            height: 36
                            radius: Theme.radiusM
                            color: confirmHover.hovered ? Theme.alpha(Theme.error, 0.8) : Theme.error

                            Text {
                                anchors.centerIn: parent
                                text: "关闭 (Y)"
                                font.pixelSize: Theme.fontSizeM
                                font.bold: true
                                color: Theme.surface
                            }

                            HoverHandler { id: confirmHover }
                            TapHandler { onTapped: root.confirmClose() }
                        }
                    }

                    // Hint
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Y 确认 | N/Esc 取消"
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
