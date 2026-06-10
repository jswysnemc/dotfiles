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

// ============ Display Tab ============
ColumnLayout {
    required property var controller
    Layout.fillWidth: true
    spacing: Theme.spacingM

    // Header with refresh button
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS

        Text {
            text: "\uf108"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.iconSizeS
            color: Theme.tertiary
        }

        Text {
            text: controller.i18nContext.trLiteral("显示器")
            font.pixelSize: Theme.fontSizeM
            font.bold: true
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            width: 28; height: 28; radius: Theme.radiusM
            color: refreshMa.containsMouse ? Theme.surfaceVariant : "transparent"

            Text {
                anchors.centerIn: parent
                text: "\uf021"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.iconSizeS
                color: Theme.textMuted
                rotation: controller.displayLoading ? 360 : 0

                Behavior on rotation {
                    RotationAnimation {
                        duration: 500
                        loops: Animation.Infinite
                    }
                }
            }

            MouseArea {
                id: refreshMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.refreshDisplays()
            }
        }

        Rectangle {
            width: 28; height: 28; radius: Theme.radiusM
            color: saveMa.containsMouse ? Theme.surfaceVariant : "transparent"

            Text {
                anchors.centerIn: parent
                text: "\uf0c7"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.iconSizeS
                color: Theme.textMuted
            }

            MouseArea {
                id: saveMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.saveDisplayConfig()
            }

            ToolTip {
                visible: saveMa.containsMouse
                text: controller.i18nContext.trLiteral("保存配置")
                delay: 500
            }
        }
    }

    // Display list
    Repeater {
        model: controller.displayOutputs

        Rectangle {
            id: displayBox
            required property var modelData
            required property int index
            Layout.fillWidth: true
            height: displayCol.implicitHeight + Theme.spacingM * 2
            radius: Theme.radiusM
            color: Theme.surface
            border.color: Theme.outline
            border.width: 1

            ColumnLayout {
                id: displayCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                // Display info
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusS
                        color: Theme.surfaceVariant

                        Text {
                            anchors.centerIn: parent
                            text: "\uf108"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: Theme.iconSizeM
                            color: Theme.tertiary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: displayBox.modelData.name
                            font.pixelSize: Theme.fontSizeM
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: displayBox.modelData.make + " " + displayBox.modelData.model
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: displayBox.modelData.width + "x" + displayBox.modelData.height + "@" + displayBox.modelData.refresh + "Hz"
                        font.pixelSize: Theme.fontSizeS
                        font.family: "JetBrainsMono Nerd Font"
                        color: Theme.primary
                    }
                }

                // Mode selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Text {
                        text: controller.i18nContext.trLiteral("分辨率:")
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: Theme.radiusS
                        color: Theme.surfaceVariant

                        ComboBox {
                            id: modeCombo
                            anchors.fill: parent
                            anchors.margins: 2

                            model: {
                                let modes = displayBox.modelData.modes || []
                                let items = []
                                let seen = {}
                                for (let i = 0; i < modes.length; i++) {
                                    let m = modes[i]
                                    let key = m.width + "x" + m.height + "@" + m.refresh
                                    if (!seen[key]) {
                                        seen[key] = true
                                        items.push({
                                            text: m.width + "x" + m.height + " @ " + m.refresh + "Hz",
                                            mode: m.width + "x" + m.height + "@" + m.refresh + ".000",
                                            width: m.width,
                                            height: m.height,
                                            refresh: m.refresh
                                        })
                                    }
                                }
                                return items
                            }

                            textRole: "text"
                            currentIndex: {
                                let modes = model || []
                                for (let i = 0; i < modes.length; i++) {
                                    let m = modes[i]
                                    if (m.width === displayBox.modelData.width &&
                                        m.height === displayBox.modelData.height &&
                                        m.refresh === displayBox.modelData.refresh) {
                                        return i
                                    }
                                }
                                return 0
                            }

                            onActivated: (idx) => {
                                let m = model[idx]
                                if (m) {
                                    controller.setDisplayMode(displayBox.modelData.name, m.mode)
                                }
                            }

                            background: Rectangle {
                                color: modeCombo.hovered ? Theme.alpha(Theme.primary, 0.08) : "transparent"
                                radius: Theme.radiusS
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            contentItem: Text {
                                text: modeCombo.displayText
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacingS
                                rightPadding: Theme.spacingXL
                                elide: Text.ElideRight
                            }

                            indicator: Text {
                                x: modeCombo.width - width - Theme.spacingS
                                y: (modeCombo.height - height) / 2
                                text: modeCombo.popup.visible ? "\ue5c7" : "\ue5c5"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: Theme.iconSizeS
                                color: Theme.textMuted
                            }

                            popup: Popup {
                                y: modeCombo.height + 4
                                width: Math.max(modeCombo.width, 180)
                                padding: Theme.spacingXS

                                contentItem: ListView {
                                    id: popupListView
                                    implicitHeight: Math.min(contentHeight, 240)
                                    model: modeCombo.popup.visible ? modeCombo.delegateModel : null
                                    clip: true
                                    currentIndex: modeCombo.highlightedIndex
                                    ScrollBar.vertical: ScrollBar {
                                        active: true
                                        policy: popupListView.contentHeight > popupListView.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                                    }
                                }

                                background: Rectangle {
                                    color: Theme.surface
                                    radius: Theme.radiusM
                                    border.width: 1
                                    border.color: Theme.outline
                                }

                                enter: Transition {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animFast }
                                    NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Theme.animFast }
                                }
                                exit: Transition {
                                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
                                }
                            }

                            delegate: ItemDelegate {
                                width: modeCombo.popup.width - Theme.spacingS
                                height: 32
                                highlighted: modeCombo.highlightedIndex === index

                                contentItem: Text {
                                    text: modelData.text
                                    font.pixelSize: Theme.fontSizeS
                                    font.weight: modeCombo.currentIndex === index ? Font.Medium : Font.Normal
                                    color: modeCombo.currentIndex === index ? Theme.primary : Theme.textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: Theme.spacingS
                                }

                                background: Rectangle {
                                    color: highlighted ? Theme.alpha(Theme.primary, 0.12) :
                                           (modeCombo.currentIndex === index ? Theme.alpha(Theme.primary, 0.06) : "transparent")
                                    radius: Theme.radiusS
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                            }
                        }
                    }
                }

                // Scale and VRR
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Text {
                        text: controller.i18nContext.trLiteral("缩放: ") + displayBox.modelData.scale.toFixed(1)
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                    }

                    Rectangle {
                        width: 1; height: 12
                        color: Theme.outline
                    }

                    Text {
                        text: "VRR: " + (displayBox.modelData.vrr ? controller.i18nContext.trLiteral("开") : controller.i18nContext.trLiteral("关"))
                        font.pixelSize: Theme.fontSizeXS
                        color: displayBox.modelData.vrr ? Theme.success : Theme.textMuted
                    }
                }
            }
        }
    }

    // Empty state
    Text {
        visible: controller.displayOutputs.length === 0
        text: controller.displayLoading ? controller.i18nContext.trLiteral("加载中...") : controller.i18nContext.trLiteral("未检测到显示器")
        font.pixelSize: Theme.fontSizeS
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacingL
    }
}
