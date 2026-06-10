import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

Item {
    required property var controller

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "quickshell-screenshot-toolbox"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: controller.blurActive ? card : null
                radius: Theme.radiusXL + 4
            }
            Connections {
                target: root
                function onBlurActiveChanged() { blurRegion.changed() }
                function onPanelScaleChanged() { blurRegion.changed() }
                function onPanelYChanged() { blurRegion.changed() }
            }
            Connections {
                target: card
                function onXChanged() { blurRegion.changed() }
                function onYChanged() { blurRegion.changed() }
                function onWidthChanged() { blurRegion.changed() }
                function onHeightChanged() { blurRegion.changed() }
            }
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: controller.activePage !== "main" ? controller.activePage = "main" : controller.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            Rectangle {
                id: card
                anchors.top: controller.anchorTop ? parent.top : undefined
                anchors.bottom: controller.anchorBottom ? parent.bottom : undefined
                anchors.left: controller.anchorLeft ? parent.left : undefined
                anchors.right: controller.anchorRight ? parent.right : undefined
                anchors.horizontalCenter: controller.anchorHCenter ? parent.horizontalCenter : undefined
                anchors.verticalCenter: controller.anchorVCenter ? parent.verticalCenter : undefined
                anchors.topMargin: controller.anchorTop ? controller.marginT : 0
                anchors.bottomMargin: controller.anchorBottom ? controller.marginB : 0
                anchors.leftMargin: controller.anchorLeft ? controller.marginL : 0
                anchors.rightMargin: controller.anchorRight ? controller.marginR : 0
                width: 420
                height: content.implicitHeight + Theme.spacingXL * 2
                radius: Theme.radiusXL + 4
                color: Theme.alpha(Theme.background, 0.28)
                border.color: Theme.glassBorder
                border.width: 1.5
                // BackgroundEffect uses item geometry, so avoid transforms on the blur-bound item.
                opacity: controller.panelOpacity

                // 高级光影
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
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
                            visible: controller.activePage !== "main"
                            width: 30
                            height: 30
                            radius: Theme.radiusS
                            color: backArea.containsMouse ? Theme.surfaceVariant : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf060"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeS
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: backArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controller.activePage = "main"
                            }
                        }

                        Rectangle {
                            width: 42
                            height: 42
                            radius: Theme.radiusM
                            color: controller.activePage === "color" && controller.pickedColor ? controller.pickedColor : Theme.alpha(Theme.primary, 0.16)
                            border.color: controller.activePage === "color" ? Theme.outline : "transparent"
                            border.width: controller.activePage === "color" ? 1 : 0

                            Text {
                                visible: controller.activePage !== "color"
                                anchors.centerIn: parent
                                text: "\uf030"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeL
                                color: Theme.primary
                            }
                        }

                        ColumnLayout {
                            spacing: 2

                            Text {
                                text: controller.activePage === "color" ? controller.i18nContext.trLiteral("颜色详情") : (controller.activePage === "screen-select" ? controller.i18nContext.trLiteral("选择截图屏幕") : controller.i18nContext.trLiteral("截图工具箱"))
                                font.pixelSize: Theme.fontSizeXL
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: controller.activePage === "color" ? controller.i18nContext.trLiteral("点击任意写法复制") : (controller.activePage === "screen-select" ? controller.i18nContext.trLiteral("单屏截图或多屏逻辑拼接") : controller.i18nContext.trLiteral("选框、窗口、长截图、贴图和编辑"))
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
                                onClicked: controller.closeWithAnimation()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.55 }

                    GridLayout {
                        visible: controller.activePage === "main"
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Theme.spacingM
                        columnSpacing: Theme.spacingM

                        Repeater {
                            model: controller.actions

                            Rectangle {
                                id: actionTile
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 82
                                radius: Theme.radiusL
                                color: tileArea.containsMouse ? Theme.alpha(modelData.color, 0.14) : Theme.surface
                                border.color: tileArea.containsMouse ? modelData.color : Theme.outline
                                border.width: 1
                                scale: tileArea.pressed ? 0.98 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 42
                                        height: 42
                                        radius: Theme.radiusM
                                        color: Theme.alpha(actionTile.modelData.color, 0.14)

                                        Text {
                                            anchors.centerIn: parent
                                            text: actionTile.modelData.icon
                                            font.family: "monospace"
                                            font.pixelSize: actionTile.modelData.icon.length > 3 ? Theme.fontSizeS : Theme.fontSizeL
                                            font.weight: Font.Bold
                                            color: actionTile.modelData.color
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: actionTile.modelData.title
                                            font.pixelSize: Theme.fontSizeM
                                            font.weight: Font.DemiBold
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: actionTile.modelData.desc
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.textMuted
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.runAction(actionTile.modelData.mode)
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: controller.activePage === "main"
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: Theme.radiusM
                            color: Theme.surfaceVariant

                            Text {
                                anchors.centerIn: parent
                                text: controller.i18nContext.trLiteral("后续功能可继续追加到 actions 和脚本 mode")
                                font.pixelSize: Theme.fontSizeXS
                                color: Theme.textMuted
                            }
                        }

                        Rectangle {
                            width: 104
                            height: 36
                            radius: Theme.radiusM
                            color: dirArea.containsMouse ? Theme.alpha(Theme.primary, 0.14) : Theme.surface
                            border.color: dirArea.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Text {
                                    text: "\uf07b"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: Theme.iconSizeS
                                    color: Theme.primary
                                }

                                Text {
                                    text: controller.i18nContext.trLiteral("截图目录")
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: dirArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controller.runAction("open-dir")
                            }
                        }
                    }

                    ColumnLayout {
                        visible: controller.activePage === "screen-select"
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            visible: controller.previewLoading
                            Layout.fillWidth: true
                            height: 38
                            radius: Theme.radiusM
                            color: Theme.surfaceVariant

                            Text {
                                anchors.centerIn: parent
                                text: controller.i18nContext.trLiteral("正在生成屏幕预览...")
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.textMuted
                            }
                        }

                        Repeater {
                            model: controller.screenOptions()

                            Rectangle {
                                id: screenRow
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                height: 94
                                radius: Theme.radiusL
                                color: screenArea.containsMouse ? Theme.alpha(Theme.primary, 0.12) : Theme.surface
                                border.color: screenArea.containsMouse ? Theme.primary : Theme.outline
                                border.width: 1
                                scale: screenArea.pressed ? 0.98 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 112
                                        height: 64
                                        radius: Theme.radiusM
                                        color: Theme.alpha(Theme.primary, 0.14)
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: screenRow.modelData.preview ? "file://" + screenRow.modelData.preview : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            visible: source !== ""
                                        }

                                        Text {
                                            visible: !screenRow.modelData.preview
                                            anchors.centerIn: parent
                                            text: screenRow.modelData.icon
                                            font.family: "monospace"
                                            font.pixelSize: Theme.fontSizeS
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: screenRow.modelData.title
                                            font.pixelSize: Theme.fontSizeM
                                            font.weight: Font.DemiBold
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: screenRow.modelData.desc
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.textMuted
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: screenArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (screenRow.modelData.mode === "fullscreen") {
                                            controller.runAction("fullscreen")
                                        } else {
                                            controller.runActionWithArg(screenRow.modelData.mode, screenRow.modelData.output)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: controller.activePage === "color"
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Rectangle {
                            Layout.fillWidth: true
                            height: 96
                            radius: Theme.radiusL
                            color: controller.pickedColor || Theme.surface
                            border.color: Theme.outline
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: controller.pickedColor
                                font.pixelSize: Theme.fontSizeXL
                                font.weight: Font.Bold
                                color: {
                                    var c = controller.colorChannels(controller.pickedColor)
                                    return ((c.r * 299 + c.g * 587 + c.b * 114) / 1000) > 150 ? "#111111" : "#ffffff"
                                }
                            }
                        }

                        Repeater {
                            model: controller.colorFormats()

                            Rectangle {
                                id: formatRow
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                height: 42
                                radius: Theme.radiusM
                                color: formatArea.containsMouse ? Theme.alpha(Theme.primary, 0.12) : Theme.surface
                                border.color: formatArea.containsMouse ? Theme.primary : Theme.outline
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Text {
                                        text: formatRow.modelData.label
                                        font.pixelSize: Theme.fontSizeS
                                        font.weight: Font.DemiBold
                                        color: Theme.textSecondary
                                        Layout.preferredWidth: 76
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: formatRow.modelData.value
                                        font.pixelSize: Theme.fontSizeS
                                        font.family: "monospace"
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "\uf0c5"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: Theme.iconSizeS
                                        color: formatArea.containsMouse ? Theme.primary : Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: formatArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.copyValue(formatRow.modelData.value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }}
