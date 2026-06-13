import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

ColumnLayout {
    id: heroRoot

    // ============ 属性声明 ============
    required property var controller

    Layout.fillWidth: true
    spacing: Theme.spacingM

    // ------------ Hero 大温度及天气大图表示层 ------------
    Item {
        Layout.fillWidth: true
        implicitHeight: 140

        // 1. 半透明天气大图标：位于背景层，带极慢的微悬浮呼吸动效
        Text {
            id: bgWeatherIcon
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: -6
            text: heroRoot.controller.weatherData ? heroRoot.controller.getWeatherIcon(heroRoot.controller.weatherData.current.weather_code) : ""
            font.family: "Weather Icons"
            font.pixelSize: 136
            color: Theme.alpha(Theme.primary, 0.55)

            // 呼吸参数
            property real pulse: 1.0
            scale: pulse
            SequentialAnimation on pulse {
                loops: Animation.Infinite
                NumberAnimation { to: 1.06; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: 1800; easing.type: Easing.InOutSine }
            }
        }

        // 2. 左侧大温度数字与中文描述
        ColumnLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: -10

            RowLayout {
                spacing: 4
                Text {
                    text: heroRoot.controller.weatherData ? Math.round(heroRoot.controller.useCelsius ? heroRoot.controller.weatherData.current.temperature_2m : heroRoot.controller.weatherData.current.temperature_2m * 9 / 5 + 32) : ""
                    font.pixelSize: 96
                    font.weight: Font.Black
                    font.letterSpacing: -5
                    color: Theme.textPrimary
                }
                Text {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 16
                    text: "°" + (heroRoot.controller.useCelsius ? "C" : "F")
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: Theme.primary
                }
            }

            Text {
                text: heroRoot.controller.weatherData ? heroRoot.controller.getWeatherDesc(heroRoot.controller.weatherData.current.weather_code) : ""
                font.pixelSize: Theme.fontSizeL
                font.weight: Font.Medium
                color: Theme.textSecondary
            }
        }
    }

    // ------------ 位置芯片与刷新按钮工具条 ------------
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS

        // 位置芯片卡片 (整合设置)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: Theme.radiusPill
            color: Theme.alpha(Theme.surface, 0.38)
            border.color: locChipMa.containsMouse ? Theme.primary : Theme.glassBorder
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS
                Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                Text {
                    Layout.fillWidth: true
                    text: heroRoot.controller.locationName
                    font.pixelSize: Theme.fontSizeS
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }
                Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 11; color: Theme.textMuted }
            }
            MouseArea {
                id: locChipMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // 3. 点击拉起设置叠加遮罩
                    heroRoot.controller.showSettings = true
                }
            }
        }

        // 刷新按钮卡片
        Rectangle {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34
            radius: 17
            color: refreshMa.containsMouse ? Theme.alpha(Theme.primary, 0.2) : Theme.alpha(Theme.surface, 0.38)
            border.color: Theme.glassBorder
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text: ""
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
                color: heroRoot.controller.refreshing ? Theme.primary : Theme.textSecondary
                
                RotationAnimation on rotation {
                    running: heroRoot.controller.refreshing
                    from: 0; to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }
            MouseArea {
                id: refreshMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // 4. 重置缓存时间并触发数据获取
                    heroRoot.controller.cachedTime = 0
                    heroRoot.controller.fetchWeather()
                }
            }
        }
    }
}
