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

// ============ Devices Tab ============
ColumnLayout {
    required property var controller
    Layout.fillWidth: true
    spacing: Theme.spacingL

    // Output Devices
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS

        RowLayout {
            spacing: Theme.spacingS

            Text {
                text: "\uf028"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.iconSizeS
                color: Theme.primary
            }

            Text {
                text: controller.i18nContext.trLiteral("输出设备")
                font.pixelSize: Theme.fontSizeM
                font.bold: true
                color: Theme.textPrimary
            }
        }

        Repeater {
            model: controller.sinks

            Rectangle {
                required property PwNode modelData
                Layout.fillWidth: true
                height: 40
                radius: Theme.radiusM
                color: modelData.id === controller.sink?.id ? Theme.alpha(Theme.primary, 0.1) :
                       sinkMa.containsMouse ? Theme.surfaceVariant : "transparent"
                border.color: modelData.id === controller.sink?.id ? Theme.primary : "transparent"
                border.width: modelData.id === controller.sink?.id ? 1 : 0

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    Text {
                        text: modelData.id === controller.sink?.id ? "\uf058" : "\uf111"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: modelData.id === controller.sink?.id ? Theme.iconSizeS : 8
                        color: modelData.id === controller.sink?.id ? Theme.primary : Theme.textMuted
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.description || modelData.name || "Unknown"
                        font.pixelSize: Theme.fontSizeS
                        color: modelData.id === controller.sink?.id ? Theme.textPrimary : Theme.textSecondary
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: sinkMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.setDefaultSink(modelData)
                }
            }
        }

        Text {
            visible: controller.sinks.length === 0
            text: controller.i18nContext.trLiteral("未检测到输出设备")
            font.pixelSize: Theme.fontSizeS
            color: Theme.textMuted
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.4 }

    // Input Devices
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS

        RowLayout {
            spacing: Theme.spacingS

            Text {
                text: "\uf130"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.iconSizeS
                color: Theme.secondary
            }

            Text {
                text: controller.i18nContext.trLiteral("输入设备")
                font.pixelSize: Theme.fontSizeM
                font.bold: true
                color: Theme.textPrimary
            }
        }

        Repeater {
            model: controller.sources

            Rectangle {
                required property PwNode modelData
                Layout.fillWidth: true
                height: 40
                radius: Theme.radiusM
                color: modelData.id === controller.source?.id ? Theme.alpha(Theme.secondary, 0.1) :
                       sourceMa.containsMouse ? Theme.surfaceVariant : "transparent"
                border.color: modelData.id === controller.source?.id ? Theme.secondary : "transparent"
                border.width: modelData.id === controller.source?.id ? 1 : 0

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    Text {
                        text: modelData.id === controller.source?.id ? "\uf058" : "\uf111"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: modelData.id === controller.source?.id ? Theme.iconSizeS : 8
                        color: modelData.id === controller.source?.id ? Theme.secondary : Theme.textMuted
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.description || modelData.name || "Unknown"
                        font.pixelSize: Theme.fontSizeS
                        color: modelData.id === controller.source?.id ? Theme.textPrimary : Theme.textSecondary
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: sourceMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.setDefaultSource(modelData)
                }
            }
        }

        Text {
            visible: controller.sources.length === 0
            text: controller.i18nContext.trLiteral("未检测到输入设备")
            font.pixelSize: Theme.fontSizeS
            color: Theme.textMuted
        }
    }
}

