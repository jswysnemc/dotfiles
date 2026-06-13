import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

ColumnLayout {
    id: forecastRoot

    // ============ 属性声明 ============
    required property var controller

    Layout.fillWidth: true
    spacing: Theme.spacingM

    // ============ 内部辅助：整周极限温差计算 ============
    readonly property var minMaxOfWeek: {
        if (!controller.weatherData || !controller.weatherData.daily) return { min: 0.0, max: 40.0 }
        var mins = controller.weatherData.daily.temperature_2m_min
        var maxs = controller.weatherData.daily.temperature_2m_max
        
        // 1. 获取本周内的绝对最低温
        var minVal = mins[0]
        for (var i = 1; i < mins.length; i++) {
            if (mins[i] < minVal) minVal = mins[i]
        }
        
        // 2. 获取本周内的绝对最高温
        var maxVal = maxs[0]
        for (var j = 1; j < maxs.length; j++) {
            if (maxs[j] > maxVal) maxVal = maxs[j]
        }
        
        return { min: minVal, max: maxVal }
    }

    // ------------ 顶部小标题 ------------
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: forecastRoot.controller.i18nContext.trLiteral("7 天预报")
            font.pixelSize: Theme.fontSizeM
            font.weight: Font.DemiBold
            color: Theme.textPrimary
        }
        Item { Layout.fillWidth: true }
        
        // 装饰渐变条
        Rectangle {
            width: 36; height: 4
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.tertiary }
            }
        }
    }

    // ------------ 7天垂直预报列表 ------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS

        Repeater {
            model: forecastRoot.controller.weatherData && forecastRoot.controller.weatherData.daily 
                ? Math.min(7, forecastRoot.controller.weatherData.daily.time.length) 
                : 0

            // 每一个单日预报行
            RowLayout {
                id: forecastRow
                Layout.fillWidth: true
                spacing: Theme.spacingS
                implicitHeight: 32

                // 提取单日极限温度
                readonly property real dayMin: forecastRoot.controller.weatherData.daily.temperature_2m_min[index]
                readonly property real dayMax: forecastRoot.controller.weatherData.daily.temperature_2m_max[index]

                // 3. 星期标签 (固定宽度)
                Text {
                    text: forecastRoot.controller.getDayName(forecastRoot.controller.weatherData.daily.time[index], index)
                    font.pixelSize: Theme.fontSizeS
                    font.weight: index === 0 ? Font.Bold : Font.Normal
                    color: index === 0 ? Theme.primary : Theme.textPrimary
                    Layout.preferredWidth: 44
                }

                // 4. 天气小图标 (居中对齐，固定宽度)
                Text {
                    text: forecastRoot.controller.getWeatherIcon(forecastRoot.controller.weatherData.daily.weather_code[index])
                    font.family: "Weather Icons"
                    font.pixelSize: 18
                    color: index === 0 ? Theme.primary : Theme.textSecondary
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                }

                // 5. 日温最小值
                Text {
                    text: Math.round(forecastRow.dayMin) + "°"
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.textMuted
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignRight
                }

                // 6. 手绘温度区间范围条 (Temperature Range Bar)
                Item {
                    id: rangeBarContainer
                    Layout.fillWidth: true
                    implicitHeight: 6

                    // 跑道底图
                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Theme.alpha(Theme.outline, 0.22)
                    }

                    // 渐变激活温差条：指示今日温区在整周温区中的分布段
                    Rectangle {
                        id: rangeBarFill
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // 基于比例分配横向起点与宽度
                        x: {
                            var range = forecastRoot.minMaxOfWeek.max - forecastRoot.minMaxOfWeek.min
                            if (range === 0) return 0
                            return parent.width * ((forecastRow.dayMin - forecastRoot.minMaxOfWeek.min) / range)
                        }
                        width: {
                            var range = forecastRoot.minMaxOfWeek.max - forecastRoot.minMaxOfWeek.min
                            if (range === 0) return parent.width
                            return parent.width * ((forecastRow.dayMax - forecastRow.dayMin) / range)
                        }
                        
                        height: 4
                        radius: 2
                        
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.alpha(Theme.primary, 0.85) }
                            GradientStop { position: 1.0; color: Theme.alpha(Theme.warning, 0.85) }
                        }
                    }
                }

                // 7. 日温最大值
                Text {
                    text: Math.round(forecastRow.dayMax) + "°"
                    font.pixelSize: Theme.fontSizeS
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }
}
