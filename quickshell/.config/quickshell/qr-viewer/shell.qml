import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15
    readonly property string qrText: Quickshell.env("QS_QR_TEXT") || ""
    readonly property string qrUrl: normalizeUrl(qrText)

    Component.onCompleted: {
        if (!root.qrText) Qt.quit()
        enterAnimation.start()
    }

    function copyValue() {
        copyProc.command = ["bash", "-c", "printf '%s' \"$1\" | wl-copy && notify-send 'QR 扫码' '识别内容已复制'", "qs-copy-qr", root.qrText]
        copyProc.running = true
    }

    function normalizeUrl(value) {
        var text = (value || "").trim()
        if (/^https?:\/\/[^\s<>"']+$/i.test(text)) return text
        if (/^www\.[^\s<>"']+$/i.test(text)) return "https://" + text
        return ""
    }

    function openUrl() {
        if (!root.qrUrl) return
        openProc.command = ["bash", "-c", "xdg-open \"$1\" >/dev/null 2>&1", "qs-open-qr", root.qrUrl]
        openProc.running = true
    }

    function closeWithAnimation() {
        exitAnimation.start()
    }

    Process {
        id: copyProc
        command: ["true"]
        onExited: root.closeWithAnimation()
    }

    Process {
        id: openProc
        command: ["true"]
        onExited: root.closeWithAnimation()
    }

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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.3)
            WlrLayershell.namespace: "qs-qr-viewer-bg"
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "qs-qr-viewer"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
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
                width: 460
                height: content.implicitHeight + Theme.spacingXL * 2
                radius: Theme.radiusXL
                color: Theme.background
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
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 42
                            height: 42
                            radius: Theme.radiusM
                            color: Theme.alpha(Theme.primary, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: "QR"
                                font.family: "monospace"
                                font.pixelSize: Theme.fontSizeL
                                font.weight: Font.Bold
                                color: Theme.primary
                            }
                        }

                        ColumnLayout {
                            spacing: 2

                            Text {
                                text: "QR 识别结果"
                                font.pixelSize: Theme.fontSizeXL
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: root.qrUrl ? "内容可选择，也可直接访问链接" : "内容可选择，点击按钮复制全部"
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 32
                            height: 32
                            radius: Theme.radiusM
                            Layout.alignment: Qt.AlignVCenter
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: closeMa.containsMouse ? 1.1 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeM
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeWithAnimation()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 190
                        radius: Theme.radiusL
                        color: Theme.surface
                        border.color: Theme.outline
                        border.width: 1

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            clip: true

                            TextArea {
                                text: root.qrText
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAnywhere
                                textFormat: TextEdit.PlainText
                                color: Theme.textPrimary
                                selectedTextColor: "#ffffff"
                                selectionColor: Theme.primary
                                font.family: "monospace"
                                font.pixelSize: Theme.fontSizeS
                                background: Rectangle { color: "transparent" }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: Theme.radiusM
                            color: copyArea.containsMouse ? Theme.alpha(Theme.primary, 0.14) : Theme.surface
                            border.color: copyArea.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Text {
                                    text: "\uf0c5"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: copyArea.containsMouse ? Theme.primary : Theme.textMuted
                                }

                                Text {
                                    text: "复制全部"
                                    font.pixelSize: Theme.fontSizeS
                                    font.weight: Font.DemiBold
                                    color: copyArea.containsMouse ? Theme.primary : Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: copyArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyValue()
                            }
                        }

                        Rectangle {
                            visible: !!root.qrUrl
                            Layout.fillWidth: true
                            height: 42
                            radius: Theme.radiusM
                            color: openArea.containsMouse ? Theme.alpha(Theme.primary, 0.14) : Theme.surface
                            border.color: openArea.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Text {
                                    text: "\uf0c1"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: openArea.containsMouse ? Theme.primary : Theme.textMuted
                                }

                                Text {
                                    text: "访问链接"
                                    font.pixelSize: Theme.fontSizeS
                                    font.weight: Font.DemiBold
                                    color: openArea.containsMouse ? Theme.primary : Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: openArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openUrl()
                            }
                        }
                    }
                }
            }
        }
    }
}
