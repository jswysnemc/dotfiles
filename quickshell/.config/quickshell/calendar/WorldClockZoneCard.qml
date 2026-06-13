import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

Rectangle {
    id: zoneCard

    // ============ 属性声明 ============
    required property var zoneData
    required property int index
    required property var controller

    // ============ 计算状态 ============
    readonly property int zoneDayDelta: zoneData.dayDelta || 0
    readonly property real zoneDayProgress: zoneData.dayProgress || 0.0
    readonly property bool isLocalZone: zoneData.isLocal || false

    // ============ 基础尺寸与自适应悬停 ============
    Layout.fillWidth: true
    Layout.preferredHeight: 96
    radius: Theme.radiusL
    clip: true

    // 1. 材质与边框配色完全依托 Matugen 变量，自适应壁纸色彩
    color: cardMouse.containsMouse 
        ? Theme.alpha(Theme.surface, isLocalZone ? 0.88 : 0.68)
        : Theme.alpha(Theme.surface, isLocalZone ? 0.78 : 0.58)
    border.color: isLocalZone ? Theme.alpha(Theme.primary, 0.5) : Theme.alpha(Theme.outline, 0.52)
    border.width: isLocalZone ? 1.5 : 1

    // 2. 悬停时的 3D 缩放微动效
    scale: cardMouse.containsMouse ? 1.025 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.OutCubic
        }
    }

    // ============ 内部布局 ============
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: 2

        // ------------ 第一栏：城市名 + 时区差 (基于 Anchors 强制锚定限制宽度，防止长英文如 Singapore 挤出卡片) ------------
        Item {
            Layout.fillWidth: true
            implicitHeight: cityLabel.implicitHeight

            Text {
                id: cityLabel
                anchors.left: parent.left
                anchors.right: offsetLabel.left
                anchors.rightMargin: Theme.spacingS
                text: zoneCard.zoneData.city || ""
                font.pixelSize: Theme.fontSizeM
                font.weight: Font.Bold
                color: Theme.textPrimary
                elide: Text.ElideRight // 在固定边界内，长城市拼写能被完美物理截断加省略号
            }

            Text {
                id: offsetLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: zoneCard.zoneData.offset || ""
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Theme.textMuted
            }
        }

        // ------------ 第二栏：大数字时间 + 日期偏差 (使用 Anchors 物理布局) ------------
        Item {
            Layout.fillWidth: true
            implicitHeight: timeLabel.implicitHeight

            Text {
                id: timeLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: zoneCard.zoneData.time || "--:--"
                font.pixelSize: 28
                font.weight: Font.Black
                font.letterSpacing: -1
                color: isLocalZone ? Theme.primary : Theme.textPrimary
            }

            Rectangle {
                id: deltaLabel
                anchors.left: timeLabel.right
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                visible: zoneCard.zoneDayDelta !== 0
                implicitWidth: dayDeltaLabel.implicitWidth + Theme.spacingS
                implicitHeight: 18
                radius: 9
                color: Theme.alpha(zoneCard.zoneDayDelta > 0 ? Theme.success : Theme.warning, 0.16)

                Text {
                    id: dayDeltaLabel
                    anchors.centerIn: parent
                    text: zoneCard.zoneDayDelta > 0 ? zoneCard.controller.i18nContext.trLiteral("明天") : zoneCard.controller.i18nContext.trLiteral("昨天")
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: zoneCard.zoneDayDelta > 0 ? Theme.success : Theme.warning
                }
            }
        }

        // ------------ 第三栏：国家地区 + 星期日期 ------------
        Text {
            Layout.fillWidth: true
            text: (zoneCard.zoneData.country || "") + " · " + (zoneCard.zoneData.dateText || "")
            font.pixelSize: 10
            color: Theme.textMuted
            elide: Text.ElideRight
        }

        // ------------ 弹性撑开，将进度轴固定在底部 ------------
        Item {
            Layout.fillHeight: true
        }

        // ------------ 第四栏：昼夜进程线性指示器 (直接去掉太阳和月亮图标，仅保留高适应性的自适应进度跑轨) ------------
        Item {
            id: timelineContainer
            Layout.fillWidth: true
            implicitHeight: 6

            // 3. 跑轨背景
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                color: Theme.alpha(Theme.outline, 0.35)
            }

            // 4. 进度填充
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * zoneCard.zoneDayProgress
                height: 2
                radius: 1
                color: zoneCard.isLocalZone ? Theme.primary : Theme.tertiary
                opacity: 0.8

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // 5. 物理进度滑块点
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - width) * zoneCard.zoneDayProgress
                width: 6
                height: 6
                radius: 3
                color: zoneCard.isLocalZone ? Theme.primary : Theme.tertiary

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // ============ 事件交互 ============
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
    }
}
