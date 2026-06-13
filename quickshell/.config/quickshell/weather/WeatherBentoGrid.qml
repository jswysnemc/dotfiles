import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

GridLayout {
    id: gridRoot

    // ============ 属性声明 ============
    required property var controller

    Layout.fillWidth: true
    columns: 3
    rowSpacing: Theme.spacingS
    columnSpacing: Theme.spacingS

    // ============ Bento 指标单元子组件 (可复用内部声明) ============
    component BentoTile: Rectangle {
        id: tileRoot
        property string icon: ""
        property string label: ""
        property string value: ""
        property color tone: Theme.primary

        Layout.fillWidth: true
        implicitHeight: 58
        radius: Theme.radiusM
        
        // 1. 卡片背景与边框：自适应 Matugen 并配有 Hover 交互加深
        color: tileMouse.containsMouse ? Theme.alpha(Theme.surface, 0.8) : Theme.alpha(Theme.surface, 0.65)
        border.color: tileMouse.containsMouse ? Theme.alpha(tone, 0.6) : Theme.alpha(tone, 0.3)
        border.width: tileMouse.containsMouse ? 1.5 : 1

        // 2. 悬停时的苹果风微放大动效
        scale: tileMouse.containsMouse ? 1.04 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutCubic
            }
        }

        // 3. 文字及图标水平垂直排版 (去掉了左边小竖线，左侧内边距扩充为 Theme.spacingL，提升呼吸感与极简度)
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingS
            spacing: 0

            RowLayout {
                spacing: 4
                Text {
                    text: tileRoot.icon
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 10
                    color: tileRoot.tone
                }
                Text {
                    text: tileRoot.label
                    font.pixelSize: 9
                    color: Theme.textMuted
                    font.letterSpacing: 0.5
                }
            }
            Text {
                text: tileRoot.value
                font.pixelSize: Theme.fontSizeM
                font.weight: Font.Bold
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    // ============ 6 个指标卡片平铺 ============

    BentoTile {
        icon: ""
        label: gridRoot.controller.i18nContext.trLiteral("体感")
        value: gridRoot.controller.weatherData ? gridRoot.controller.formatTemp(gridRoot.controller.weatherData.current.apparent_temperature) : "-"
        tone: Theme.warning
    }

    BentoTile {
        icon: ""
        label: gridRoot.controller.i18nContext.trLiteral("湿度")
        value: gridRoot.controller.weatherData ? gridRoot.controller.weatherData.current.relative_humidity_2m + "%" : "-"
        tone: Theme.tertiary
    }

    BentoTile {
        icon: "\ue314"
        label: gridRoot.controller.i18nContext.trLiteral("风速")
        value: gridRoot.controller.weatherData ? Math.round(gridRoot.controller.weatherData.current.wind_speed_10m) + " km/h" : "-"
        tone: Theme.secondary
    }

    BentoTile {
        icon: ""
        label: gridRoot.controller.i18nContext.trLiteral("日出")
        value: gridRoot.controller.weatherData && gridRoot.controller.weatherData.daily ? gridRoot.controller.weatherData.daily.sunrise[0].split("T")[1] : "-"
        tone: Theme.primary
    }

    BentoTile {
        icon: ""
        label: gridRoot.controller.i18nContext.trLiteral("日落")
        value: gridRoot.controller.weatherData && gridRoot.controller.weatherData.daily ? gridRoot.controller.weatherData.daily.sunset[0].split("T")[1] : "-"
        tone: Theme.alpha(Theme.primary, 0.7)
    }

    BentoTile {
        icon: ""
        label: gridRoot.controller.i18nContext.trLiteral("高/低")
        value: gridRoot.controller.weatherData && gridRoot.controller.weatherData.daily ? Math.round(gridRoot.controller.weatherData.daily.temperature_2m_max[0]) + "°/" + Math.round(gridRoot.controller.weatherData.daily.temperature_2m_min[0]) + "°" : "-"
        tone: Theme.error
    }
}
