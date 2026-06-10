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
        catalog: "welcome"
    }

    property string markerFile: Quickshell.env("HOME") + "/.config/quickshell/.welcome-shown"
    property bool shouldShow: false
    property bool initialized: false

    // ============ Animation State ============
    property real heroOpacity: 0
    property real heroY: 40
    property real bgOpacity: 0

    Component.onCompleted: {
        // 【Quickshell/Welcome】【初始化】检查启动标记文件是否已存在
        checkMarker.running = true
    }

    onShouldShowChanged: {
        if (shouldShow) enterAnimation.start()
    }

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation { target: root; property: "bgOpacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "heroOpacity"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "heroY"; from: 40; to: 0; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
    }

    Process {
        id: checkMarker
        command: ["test", "-f", root.markerFile]
        onExited: (code, status) => {
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
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

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

            // 全屏渐变背景
            Rectangle {
                anchors.fill: parent
                opacity: root.bgOpacity
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.background, 0.34) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.surfaceVariant, 0.92) }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismiss()
                }
            }

            // 漂浮的 aurora 装饰球
            AuroraBackground {
                anchors.fill: parent
                intensity: 0.35 * root.bgOpacity
                orbScale: 1.8
            }

            // Hero 内容
            Item {
                anchors.centerIn: parent
                width: Math.min(820, parent.width - 80)
                height: heroCol.implicitHeight
                opacity: root.heroOpacity
                transform: Translate { y: root.heroY }

                ColumnLayout {
                    id: heroCol
                    anchors.fill: parent
                    spacing: Theme.spacingXL

                    // Logo / 图标
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 96; height: 96
                        radius: 48
                        color: "transparent"
                        border.color: Theme.alpha(Theme.primary, 0.35)
                        border.width: 1.5

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.alpha(Theme.primary, 0.7)
                            shadowBlur: 1.0
                            shadowVerticalOffset: 0
                            shadowOpacity: 0.7
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 44
                            color: Theme.primary
                        }
                    }

                    // 巨型标题
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18n.tr("title")
                        font.pixelSize: 72
                        font.weight: Font.Black
                        font.letterSpacing: -1
                        color: Theme.textPrimary
                    }

                    // 副标题
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "niri · QuickShell"
                        font.pixelSize: Theme.fontSizeL
                        font.letterSpacing: 6
                        color: Theme.textMuted
                    }

                    // 一行的关键描述
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 580
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: i18n.tr("description")
                        font.pixelSize: Theme.fontSizeM
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                    }

                    // 关键快捷键 chips
                    Flow {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 720
                        Layout.maximumWidth: 720
                        spacing: Theme.spacingM
                        Layout.topMargin: Theme.spacingL

                        ShortcutChip { icon: ""; keys: "Alt + Space"; desc: i18n.tr("launcher") }
                        ShortcutChip { icon: ""; keys: "Super + Return"; desc: i18n.tr("terminal") }
                        ShortcutChip { icon: ""; keys: "Alt + V"; desc: i18n.tr("clipboard") }
                        ShortcutChip { icon: ""; keys: "Super + Shift + S"; desc: i18n.tr("screenshot") }
                        ShortcutChip { icon: ""; keys: "Super + O"; desc: i18n.tr("overview") }
                        ShortcutChip { icon: ""; keys: "Super + Shift + /"; desc: i18n.tr("allShortcuts") }
                    }

                    // 资源链接
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spacingL
                        Layout.topMargin: Theme.spacingL

                        LinkChip {
                            text: i18n.tr("docsNiri")
                            onClicked: Qt.openUrlExternally("https://yalter.github.io/niri/")
                        }
                        LinkChip {
                            text: i18n.tr("docsQuickshell")
                            onClicked: Qt.openUrlExternally("https://deepwiki.com/quickshell-mirror/quickshell/2-getting-started")
                        }
                        LinkChip {
                            text: i18n.tr("configRepo")
                            onClicked: Qt.openUrlExternally("https://github.com/jswysnemc/dotfiles")
                        }
                    }

                    // 大号开始按钮
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.spacingXL
                        width: 220
                        height: 52
                        radius: Theme.radiusPill
                        scale: startMa.containsMouse ? 1.05 : 1.0
                        opacity: startMa.containsMouse ? 1.0 : 0.94

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.primary }
                            GradientStop { position: 0.5; color: Theme.secondary }
                            GradientStop { position: 1.0; color: Theme.tertiary }
                        }

                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.alpha(Theme.primary, 0.55)
                            shadowBlur: 1.0
                            shadowVerticalOffset: 8
                        }

                        Text {
                            anchors.centerIn: parent
                            text: i18n.tr("startButton")
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: startMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismiss()
                        }
                    }

                    // 提示
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.spacingS
                        text: i18n.tr("hint")
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                        opacity: 0.7
                    }
                }
            }
        }
    }

    // 快捷键 chip
    component ShortcutChip: Rectangle {
        property string icon: ""
        property string keys: ""
        property string desc: ""

        implicitWidth: chipRow.implicitWidth + Theme.spacingL * 2
        implicitHeight: 38
        radius: Theme.radiusPill
        color: Theme.alpha(Theme.background, 0.55)
        border.color: Theme.glassBorder
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadowColor
            shadowBlur: 0.6
            shadowVerticalOffset: 4
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Text {
                text: icon
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.iconSizeS
                color: Theme.primary
            }

            Text {
                text: keys
                font.pixelSize: Theme.fontSizeXS
                font.family: "monospace"
                color: Theme.textPrimary
            }

            Rectangle {
                width: 1; height: 14
                color: Theme.outline
                opacity: 0.5
            }

            Text {
                text: desc
                font.pixelSize: Theme.fontSizeS
                color: Theme.textSecondary
            }
        }
    }

    // 链接 chip
    component LinkChip: Rectangle {
        property alias text: linkText.text
        signal clicked()

        implicitWidth: linkText.implicitWidth + Theme.spacingL * 2
        implicitHeight: 32
        radius: Theme.radiusPill
        color: linkMa.containsMouse ? Theme.alpha(Theme.primary, 0.15) : "transparent"
        border.color: linkMa.containsMouse ? Theme.primary : Theme.alpha(Theme.outline, 0.6)
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
