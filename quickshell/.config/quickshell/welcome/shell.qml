import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    property string markerFile: Quickshell.env("HOME") + "/.config/quickshell/.welcome-shown"
    property bool shouldShow: false
    property bool initialized: false

    // Check if welcome was already shown
    Component.onCompleted: {
        checkMarker.running = true
    }

    Process {
        id: checkMarker
        command: ["test", "-f", root.markerFile]
        onExited: (code, status) => {
            // code 0 means file exists, skip welcome
            root.shouldShow = (code !== 0)
            root.initialized = true
        }
    }

    Process {
        id: createMarker
        command: ["touch", root.markerFile]
    }

    function dismiss() {
        createMarker.running = true
        Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-welcome"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            visible: root.initialized && root.shouldShow

            Shortcut { sequence: "Escape"; onActivated: root.dismiss() }
            Shortcut { sequence: "Return"; onActivated: root.dismiss() }
            Shortcut { sequence: "Space"; onActivated: root.dismiss() }

            // Background overlay
            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.background, 0.85)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismiss()
                }
            }

            // Main card
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(560, parent.width - 40)
                height: mainCol.implicitHeight + Theme.spacingXL * 2
                color: Theme.background
                radius: Theme.radiusXL
                border.color: Theme.outline
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf005"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 24
                            color: Theme.primary
                        }

                        Text {
                            text: "欢迎使用"
                            font.pixelSize: Theme.fontSizeHuge
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"

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
                                onClicked: root.dismiss()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.6
                    }

                    // Intro text
                    Text {
                        Layout.fillWidth: true
                        text: "niri + QuickShell"
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.primary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "滚动平铺式 Wayland 混成器，配合自定义 Shell 组件。"
                        font.pixelSize: Theme.fontSizeM
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.3
                    }

                    // Quick tips section
                    Text {
                        Layout.fillWidth: true
                        text: "常用快捷键"
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingM

                        // Keybindings help
                        HelpItem {
                            keys: "Super + Shift + /"
                            desc: "显示快捷键帮助"
                            icon: "\uf11c"
                        }

                        // Launcher
                        HelpItem {
                            keys: "Alt + Space"
                            desc: "应用启动器"
                            icon: "\uf002"
                        }

                        // Terminal
                        HelpItem {
                            keys: "Super + Return"
                            desc: "打开终端"
                            icon: "\uf120"
                        }

                        // Close window
                        HelpItem {
                            keys: "Super + C"
                            desc: "关闭窗口"
                            icon: "\uf00d"
                        }

                        // Screenshot
                        HelpItem {
                            keys: "Super + Shift + S"
                            desc: "区域截屏"
                            icon: "\uf030"
                        }

                        // Overview
                        HelpItem {
                            keys: "Super + O"
                            desc: "概览视图"
                            icon: "\uf0c9"
                        }

                        // Clipboard
                        HelpItem {
                            keys: "Alt + V"
                            desc: "剪贴板历史"
                            icon: "\uf328"
                        }

                        // Power menu
                        HelpItem {
                            keys: "电源键"
                            desc: "电源菜单"
                            icon: "\uf011"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.3
                    }

                    // Window tips
                    Text {
                        Layout.fillWidth: true
                        text: "窗口操作"
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingM

                        HelpItem {
                            keys: "Super + H/J/K/L"
                            desc: "移动焦点"
                            icon: "\uf0b2"
                        }

                        HelpItem {
                            keys: "Super + Ctrl + H/L"
                            desc: "移动窗口"
                            icon: "\uf047"
                        }

                        HelpItem {
                            keys: "Super + F"
                            desc: "最大化列"
                            icon: "\uf065"
                        }

                        HelpItem {
                            keys: "Super + V"
                            desc: "浮动/平铺切换"
                            icon: "\uf24d"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.3
                    }

                    // Resources
                    Text {
                        Layout.fillWidth: true
                        text: "帮助资源"
                        font.pixelSize: Theme.fontSizeL
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        LinkButton {
                            text: "\uf059  niri 文档"
                            onClicked: Qt.openUrlExternally("https://yalter.github.io/niri/")
                        }

                        LinkButton {
                            text: "\uf02d  QuickShell"
                            onClicked: Qt.openUrlExternally("https://deepwiki.com/quickshell-mirror/quickshell/2-getting-started")
                        }

                        LinkButton {
                            text: "\uf09b  配置仓库"
                            onClicked: Qt.openUrlExternally("https://github.com/jswysnemc/dotfiles")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.3
                    }

                    // Footer
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "按任意键或点击外部区域继续"
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: startBtn.implicitWidth + Theme.spacingL * 2
                            height: 36
                            radius: Theme.radiusPill
                            color: startMa.containsMouse ? Theme.alpha(Theme.primary, 0.9) : Theme.primary

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: startBtn
                                anchors.centerIn: parent
                                text: "开始使用"
                                font.pixelSize: Theme.fontSizeM
                                font.bold: true
                                color: Theme.surface
                            }

                            MouseArea {
                                id: startMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    // Helper component for keybinding tips
    component HelpItem: RowLayout {
        property string keys: ""
        property string desc: ""
        property string icon: ""

        Layout.fillWidth: true
        spacing: Theme.spacingS

        Text {
            text: icon
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.iconSizeS
            color: Theme.primary
            Layout.preferredWidth: 20
        }

        Rectangle {
            Layout.preferredWidth: kbdText.implicitWidth + Theme.spacingM
            height: 22
            radius: Theme.radiusS
            color: Theme.surfaceVariant
            border.color: Theme.outline
            border.width: 1

            Text {
                id: kbdText
                anchors.centerIn: parent
                text: keys
                font.pixelSize: Theme.fontSizeXS
                font.family: "monospace"
                color: Theme.textPrimary
            }
        }

        Text {
            text: desc
            font.pixelSize: Theme.fontSizeS
            color: Theme.textSecondary
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    // Helper component for link buttons
    component LinkButton: Rectangle {
        property alias text: linkText.text
        signal clicked()

        width: linkText.implicitWidth + Theme.spacingM * 2
        height: 28
        radius: Theme.radiusM
        color: linkMa.containsMouse ? Theme.surfaceVariant : "transparent"
        border.color: linkMa.containsMouse ? Theme.outline : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        Text {
            id: linkText
            anchors.centerIn: parent
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.fontSizeS
            color: linkMa.containsMouse ? Theme.primary : Theme.textSecondary
        }

        MouseArea {
            id: linkMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
