import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

// ============ Applications Tab ============
ColumnLayout {
    required property var controller
    Layout.fillWidth: true
    spacing: Theme.spacingM

    RowLayout {
        spacing: Theme.spacingS

        Text {
            text: "\uf259"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.iconSizeS
            color: Theme.tertiary
        }

        Text {
            text: controller.i18nContext.trLiteral("应用程序音量")
            font.pixelSize: Theme.fontSizeM
            font.bold: true
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        Text {
            text: controller.appStreams.length + controller.i18nContext.trLiteral(" 个应用")
            font.pixelSize: Theme.fontSizeXS
            color: Theme.textMuted
        }
    }

    // App streams list
    Repeater {
        model: controller.appStreams

        Rectangle {
            id: appBox
            required property PwNode modelData
            Layout.fillWidth: true
            height: appRow.implicitHeight + Theme.spacingM * 2
            radius: Theme.radiusM
            color: Theme.surface
            border.color: Theme.outline
            border.width: 1

            // Track this node
            PwObjectTracker {
                objects: modelData ? [modelData] : []
            }

            property PwNodeAudio nodeAudio: modelData?.audio ?? null
            property real appVolume: nodeAudio?.volume ?? 0
            property bool appMuted: nodeAudio?.muted ?? false

            // Get app name
            readonly property string appName: {
                if (!modelData) return "Unknown"
                var props = modelData.properties || {}
                var name = props["application.name"] ||
                           props["media.name"] ||
                           modelData.description ||
                           modelData.name || "Unknown"
                return name
            }

            // Get app icon name for lookup
            readonly property string appIconName: {
                if (!modelData) return ""
                var props = modelData.properties || {}
                return props["application.icon-name"] ||
                       props["application.name"]?.toLowerCase() ||
                       modelData.name?.split("-")[0]?.toLowerCase() || ""
            }

            // Get Nerd Font icon based on app name
            readonly property string appNerdIcon: {
                var name = appIconName.toLowerCase()
                if (name.includes("firefox") || name.includes("floorp")) return "\uf269"
                if (name.includes("chrome") || name.includes("chromium")) return "\uf268"
                if (name.includes("brave")) return "\uf38a"
                if (name.includes("edge")) return "\uf282"
                if (name.includes("spotify")) return "\uf1bc"
                if (name.includes("discord")) return "\uf392"
                if (name.includes("telegram")) return "\uf2c6"
                if (name.includes("slack")) return "\uf198"
                if (name.includes("teams")) return "\uf871"
                if (name.includes("zoom")) return "\uf03d"
                if (name.includes("vlc")) return "\uf03d"
                if (name.includes("mpv")) return "\uf03d"
                if (name.includes("obs")) return "\uf03d"
                if (name.includes("steam")) return "\uf1b6"
                if (name.includes("lutris")) return "\uf11b"
                if (name.includes("wine") || name.includes(".exe")) return "\uf17a"
                if (name.includes("code") || name.includes("vscode")) return "\ue70c"
                if (name.includes("terminal") || name.includes("konsole") || name.includes("kitty") || name.includes("alacritty")) return "\uf120"
                if (name.includes("music") || name.includes("rhythmbox") || name.includes("clementine")) return "\uf001"
                if (name.includes("video") || name.includes("totem")) return "\uf03d"
                if (name.includes("pipewire") || name.includes("pulse") || name.includes("audio")) return "\uf028"
                if (name.includes("speech")) return "\uf130"
                if (name.includes("game") || name.includes("yuanshen") || name.includes("genshin")) return "\uf11b"
                return "\uf013"  // Default gear icon
            }

            RowLayout {
                id: appRow
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // App icon using Nerd Font
                Rectangle {
                    width: 32; height: 32; radius: Theme.radiusS
                    color: Theme.surfaceVariant

                    Text {
                        anchors.centerIn: parent
                        text: appBox.appNerdIcon
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: Theme.iconSizeM
                        color: Theme.tertiary
                    }
                }

                // App name and volume slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    Text {
                        text: appBox.appName
                        font.pixelSize: Theme.fontSizeS
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Rectangle {
                            id: appSlider
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Theme.surfaceVariant

                            Rectangle {
                                id: appFill
                                width: Math.min(1, appBox.appVolume) * parent.width
                                height: parent.height
                                radius: 3
                                color: appBox.appMuted ? Theme.error : Theme.tertiary

                                Behavior on width { NumberAnimation { duration: 50 } }
                            }

                            Rectangle {
                                x: Math.max(0, Math.min(appFill.width - width / 2, parent.width - width))
                                y: -3
                                width: 12; height: 12; radius: 6
                                color: appBox.appMuted ? Theme.error : Theme.tertiary
                                border.color: Theme.surface
                                border.width: 2
                                scale: appMa.pressed ? 1.2 : (appMa.containsMouse ? 1.1 : 1.0)

                                Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                            }

                            MouseArea {
                                id: appMa
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onPressed: (mouse) => {
                                    if (appBox.nodeAudio) {
                                        appBox.nodeAudio.volume = Math.max(0, Math.min(1, mouse.x / appSlider.width))
                                    }
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed && appBox.nodeAudio) {
                                        appBox.nodeAudio.volume = Math.max(0, Math.min(1, mouse.x / appSlider.width))
                                    }
                                }
                                onWheel: (wheel) => {
                                    if (appBox.nodeAudio) {
                                        let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                        appBox.nodeAudio.volume = Math.max(0, Math.min(1, appBox.appVolume + delta))
                                    }
                                }
                            }
                        }

                        Text {
                            text: Math.round(appBox.appVolume * 100) + "%"
                            font.pixelSize: Theme.fontSizeXS
                            color: appBox.appMuted ? Theme.error : Theme.textMuted
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Mute button
                Rectangle {
                    width: 28; height: 28; radius: Theme.radiusM
                    color: appMuteMa.containsMouse ? Theme.surfaceVariant : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: appBox.appMuted ? "\uf026" : "\uf028"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: Theme.iconSizeS
                        color: appBox.appMuted ? Theme.error : Theme.textMuted
                    }

                    MouseArea {
                        id: appMuteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (appBox.nodeAudio) {
                                appBox.nodeAudio.muted = !appBox.appMuted
                            }
                        }
                    }
                }
            }
        }
    }

    // Empty state
    Text {
        visible: controller.appStreams.length === 0
        text: controller.i18nContext.trLiteral("没有正在播放音频的应用")
        font.pixelSize: Theme.fontSizeS
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacingL
    }
}

