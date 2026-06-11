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
        catalog: "close-confirm"
    }

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    property bool blurActive: true
    property var targetWindow: null
    property bool hasTargetWindow: targetWindow !== null && targetWindow !== undefined
    readonly property string targetTitle: hasTargetWindow && targetWindow.title ? targetWindow.title : i18n.tr("unknownTitle")
    readonly property string targetAppId: hasTargetWindow && targetWindow.app_id ? targetWindow.app_id : "unknown"
    readonly property string targetWorkspace: hasTargetWindow && targetWindow.workspace_id !== undefined ? String(targetWindow.workspace_id) : "-"
    readonly property string targetPid: hasTargetWindow && targetWindow.pid !== undefined ? String(targetWindow.pid) : "-"

    Process {
        id: closeProcess
        command: ["niri", "msg", "action", "close-window"]
        onExited: Qt.quit()
    }

    function confirmClose() {
        root.blurActive = false
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
        // 【Quickshell/CloseConfirm】【初始化】准备加载窗口配置
        // 1. 检查环境变量或从当前聚焦的窗口中加载
        if (!loadTargetWindowFromEnv()) {
            loadFocusedWindow.running = true
        }
        // 2. 执行淡入淡出动画
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
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "qs-close-confirm"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: root.blurActive && dialog.width > 0 && dialog.height > 0 ? dialog : null
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
            implicitWidth: 380
            implicitHeight: dialog.implicitHeight

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
                anchors.fill: parent
                implicitHeight: contentCol.implicitHeight + Theme.spacingXL * 2
                color: Theme.alpha(Theme.background, 0.28)
                radius: Theme.radiusXL + 4
                border.color: Theme.glassBorder
                border.width: 1.5

                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: root.panelOpacity

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
                        text: i18n.tr("title")
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Message
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.hasTargetWindow ? i18n.tr("messageWithTarget") : i18n.tr("messageCurrent")
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
                                        text: root.hasTargetWindow ? root.targetTitle : i18n.tr("noWindowInfo")
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.hasTargetWindow ? root.targetAppId : i18n.tr("runAsFocused")
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
                                    text: i18n.tr("workspace", { workspace: root.targetWorkspace })
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
                                    text: root.hasTargetWindow && root.targetWindow.id !== undefined ? "ID " + root.targetWindow.id : ""
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
                                text: i18n.tr("cancel")
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
                                text: i18n.tr("confirm")
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
                        text: i18n.tr("hint")
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
