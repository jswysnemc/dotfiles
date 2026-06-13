import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "./Theme.js" as Theme

ColumnLayout {
    id: worldClockPage

    // ============ 属性声明 ============
    required property var controller

    // ============ 基础排版 ============
    Layout.fillWidth: true
    spacing: Theme.spacingM
    visible: controller.activeRoute === "world-clock"

    // ------ 图层一：本地时间大 Bento 卡片（含模拟扫表） ------
    WorldClockLocalHeader {
        controller: worldClockPage.controller
    }

    // ------ 图层二：横向标题与刷新工具条 ------
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS

        Text {
            text: worldClockPage.controller.i18nContext.trLiteral("全球时间线")
            font.pixelSize: Theme.fontSizeL
            font.bold: true
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        // 刷新按钮卡片
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
                    text: worldClockPage.controller.i18nContext.trLiteral("刷新")
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
                // 1. 点击刷新，向 controller 请求触发异步同步
                onClicked: worldClockPage.controller.loadWorldClock()
            }
        }
    }

    // ------ 图层三：无数据 / 正在同步占位面板 ------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 232
        radius: Theme.radiusL
        color: Theme.alpha(Theme.surface, 0.48)
        border.color: Theme.alpha(Theme.outline, 0.5)
        border.width: 1
        visible: worldClockPage.controller.worldClockZoneCount === 0

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
                    running: worldClockPage.controller.worldClockLoading
                }
            }

            Text {
                text: worldClockPage.controller.worldClockLoading 
                    ? worldClockPage.controller.i18nContext.trLiteral("正在同步世界时钟...")
                    : worldClockPage.controller.i18nContext.trLiteral("世界时钟暂无数据")
                font.pixelSize: Theme.fontSizeM
                color: Theme.textMuted
            }
        }
    }

    // ------ 图层四：世界时区 Bento 网格 ------
    GridLayout {
        id: worldClockGrid
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Theme.spacingS
        columnSpacing: Theme.spacingS
        visible: worldClockPage.controller.worldClockZoneCount > 0

        // 2. 遍历已同步的各时区数据，实例化独立的 WorldClockZoneCard 卡片
        Repeater {
            model: worldClockPage.controller.worldClockZoneCount
            delegate: WorldClockZoneCard {
                // index 属性和 modelData 将自动由 Repeater 注入
                zoneData: worldClockPage.controller.worldClockZones[index] || ({})
                controller: worldClockPage.controller
            }
        }
    }

    // ------ 图层五：底部版权与同步说明 ------
    Text {
        Layout.fillWidth: true
        text: worldClockPage.controller.i18nContext.trLiteral("每 30 秒自动同步 | 夏令时来自系统 zoneinfo")
        font.pixelSize: Theme.fontSizeXS
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
    }
}
