import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

ColumnLayout {
    required property var controller
    id: worldClockPage
    Layout.fillWidth: true
    spacing: Theme.spacingM
    visible: controller.activeRoute === "world-clock"

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 118
        radius: Theme.radiusL
        color: Theme.alpha(Theme.surface, 0.66)
        border.color: Theme.alpha(Theme.tertiary, 0.32)
        border.width: 1.5

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 58
                height: 58
                radius: 29
                color: Theme.alpha(Theme.tertiary, 0.16)
                border.color: Theme.alpha(Theme.tertiary, 0.38)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\uf0ac"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 24
                    color: Theme.tertiary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: controller.worldClockLocal.time || "--:--"
                    font.pixelSize: 48
                    font.weight: Font.Black
                    font.letterSpacing: -2
                    color: Theme.textPrimary
                }

                RowLayout {
                    spacing: Theme.spacingS

                    Text {
                        text: controller.worldClockLocal.dateText || controller.i18nContext.trLiteral("等待同步")
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textSecondary
                    }

                    Rectangle {
                        implicitWidth: localZoneLabel.implicitWidth + Theme.spacingM
                        implicitHeight: 22
                        radius: 11
                        color: Theme.alpha(Theme.primary, 0.14)

                        Text {
                            id: localZoneLabel
                            anchors.centerIn: parent
                            text: controller.worldClockLocal.timezoneLabel || controller.i18nContext.trLiteral("本地")
                            font.pixelSize: Theme.fontSizeXS
                            font.weight: Font.Medium
                            color: Theme.primary
                        }
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: syncLabel.implicitWidth + Theme.spacingM
                implicitHeight: 24
                radius: 12
                color: Theme.alpha(controller.worldClockLoading ? Theme.warning : Theme.success, 0.14)
                border.color: Theme.alpha(controller.worldClockLoading ? Theme.warning : Theme.success, 0.32)
                border.width: 1

                Text {
                    id: syncLabel
                    anchors.centerIn: parent
                    text: controller.worldClockLoading ? controller.i18nContext.trLiteral("同步中") : controller.i18nContext.trLiteral("已同步")
                    font.pixelSize: Theme.fontSizeXS
                    font.weight: Font.Medium
                    color: controller.worldClockLoading ? Theme.warning : Theme.success
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS

        Text {
            text: controller.i18nContext.trLiteral("全球时间线")
            font.pixelSize: Theme.fontSizeL
            font.bold: true
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: refreshClockLabel.implicitWidth + Theme.spacingM * 2 + 14
            implicitHeight: 30
            radius: 15
            color: refreshClockMouse.containsMouse ? Theme.alpha(Theme.primary, 0.18) : Theme.alpha(Theme.primary, 0.1)
            border.color: Theme.alpha(Theme.primary, 0.28)
            border.width: 1
            scale: refreshClockMouse.containsMouse ? 1.04 : 1.0

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "\uf2f1"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 11
                    color: Theme.primary
                }

                Text {
                    id: refreshClockLabel
                    text: controller.i18nContext.trLiteral("刷新")
                    font.pixelSize: Theme.fontSizeS
                    font.weight: Font.Medium
                    color: Theme.primary
                }
            }

            MouseArea {
                id: refreshClockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.loadWorldClock()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 232
        radius: Theme.radiusL
        color: Theme.alpha(Theme.surface, 0.48)
        border.color: Theme.alpha(Theme.outline, 0.5)
        border.width: 1
        visible: controller.worldClockZoneCount === 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingM

            Text {
                text: "\uf110"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 22
                color: Theme.primary
                Layout.alignment: Qt.AlignHCenter

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: controller.worldClockLoading
                }
            }

            Text {
                text: controller.worldClockLoading ? controller.i18nContext.trLiteral("正在同步世界时钟...") : controller.i18nContext.trLiteral("世界时钟暂无数据")
                font.pixelSize: Theme.fontSizeM
                color: Theme.textMuted
            }
        }
    }

    GridLayout {
        id: worldClockGrid
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Theme.spacingS
        columnSpacing: Theme.spacingS
        visible: controller.worldClockZoneCount > 0

        Repeater {
            model: controller.worldClockZoneCount

            Rectangle {
                id: zoneCard
                property var zoneData: controller.worldClockZones[index] || ({})
                property int zoneDayDelta: zoneData.dayDelta || 0
                property real zoneDayProgress: zoneData.dayProgress || 0
                property bool isLocalZone: zoneData.isLocal || false

                Layout.fillWidth: true
                Layout.preferredHeight: 88
                radius: Theme.radiusL
                color: Theme.alpha(Theme.surface, isLocalZone ? 0.78 : 0.58)
                border.color: isLocalZone ? Theme.alpha(Theme.primary, 0.5) : Theme.alpha(Theme.outline, 0.52)
                border.width: isLocalZone ? 1.5 : 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Text {
                            Layout.fillWidth: true
                            text: zoneCard.zoneData.city || ""
                            font.pixelSize: Theme.fontSizeS
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            text: zoneCard.zoneData.offset || ""
                            font.pixelSize: 9
                            color: Theme.textMuted
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Text {
                            text: zoneCard.zoneData.time || "--:--"
                            font.pixelSize: 26
                            font.weight: Font.Black
                            font.letterSpacing: -1
                            color: isLocalZone ? Theme.primary : Theme.textPrimary
                        }

                        Rectangle {
                            visible: zoneCard.zoneDayDelta !== 0
                            implicitWidth: dayDeltaLabel.implicitWidth + Theme.spacingS
                            implicitHeight: 18
                            radius: 9
                            color: Theme.alpha(zoneCard.zoneDayDelta > 0 ? Theme.success : Theme.warning, 0.16)

                            Text {
                                id: dayDeltaLabel
                                anchors.centerIn: parent
                                text: zoneCard.zoneDayDelta > 0 ? controller.i18nContext.trLiteral("明天") : controller.i18nContext.trLiteral("昨天")
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: zoneCard.zoneDayDelta > 0 ? Theme.success : Theme.warning
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: (zoneCard.zoneData.country || "") + " · " + (zoneCard.zoneData.dateText || "")
                        font.pixelSize: 9
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width * zoneCard.zoneDayProgress
                    height: 3
                    radius: 2
                    color: isLocalZone ? Theme.primary : Theme.tertiary
                    opacity: 0.72

                    Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: controller.i18nContext.trLiteral("每 30 秒自动同步 | 夏令时来自系统 zoneinfo")
        font.pixelSize: Theme.fontSizeXS
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
    }
}
