import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

Rectangle {
    id: headerRoot

    // ============ 属性声明 ============
    required property var controller

    // ============ 局部扫秒控制时钟 ============
    property var currentTime: new Date()

    // ============ 基础尺寸与样式 ============
    Layout.fillWidth: true
    implicitHeight: 118
    radius: Theme.radiusL
    color: Theme.alpha(Theme.surface, 0.66)
    border.color: Theme.alpha(Theme.tertiary, 0.32)
    border.width: 1.5

    // 1. 挂载高频平滑时钟，用 50ms (20fps) 的刷新率支持扫秒表盘的流体动态
    Timer {
        id: ticker
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            headerRoot.currentTime = new Date()
        }
    }

    // ============ 横向排版布局 ============
    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // ------------ 左侧部分：大图标装饰 + 三行折行信息栏 ------------
        RowLayout {
            spacing: Theme.spacingM
            Layout.alignment: Qt.AlignVCenter

            // 极简球体图标容器
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

            // 本地时间及多行折行详细元数据
            ColumnLayout {
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                // 2. 本地大数字时间，微调字号以在 380px 的宽度下呼吸舒展
                Text {
                    text: headerRoot.controller.worldClockLocal.time || "--:--"
                    font.pixelSize: 42
                    font.weight: Font.Black
                    font.letterSpacing: -1.5
                    color: Theme.textPrimary
                }

                // 3. 独立行：日期与星期
                Text {
                    text: headerRoot.controller.worldClockLocal.dateText || headerRoot.controller.i18nContext.trLiteral("等待同步")
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.textSecondary
                }

                // 4. 独立行：双药丸（时区标签 与 同步状态）并列，规避横向撑宽导致的组件出界
                RowLayout {
                    spacing: Theme.spacingXS

                    Rectangle {
                        implicitWidth: localZoneLabel.implicitWidth + Theme.spacingM
                        implicitHeight: 20
                        radius: 10
                        color: Theme.alpha(Theme.primary, 0.14)

                        Text {
                            id: localZoneLabel
                            anchors.centerIn: parent
                            text: headerRoot.controller.worldClockLocal.timezoneLabel || headerRoot.controller.i18nContext.trLiteral("本地")
                            font.pixelSize: Theme.fontSizeXS - 1
                            font.weight: Font.Medium
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        implicitWidth: syncLabel.implicitWidth + Theme.spacingM
                        implicitHeight: 20
                        radius: 10
                        color: Theme.alpha(headerRoot.controller.worldClockLoading ? Theme.warning : Theme.success, 0.14)
                        border.color: Theme.alpha(headerRoot.controller.worldClockLoading ? Theme.warning : Theme.success, 0.32)
                        border.width: 1

                        Text {
                            id: syncLabel
                            anchors.centerIn: parent
                            text: headerRoot.controller.worldClockLoading ? headerRoot.controller.i18nContext.trLiteral("同步中") : headerRoot.controller.i18nContext.trLiteral("已同步")
                            font.pixelSize: Theme.fontSizeXS - 1
                            font.weight: Font.Medium
                            color: headerRoot.controller.worldClockLoading ? Theme.warning : Theme.success
                        }
                    }
                }
            }
        }

        // ------------ 中间弹性缓冲栏 ------------
        Item {
            Layout.fillWidth: true
        }

        // ------------ 右侧部分：纯模拟扫秒时钟 ------------
        WorldClockAnalogFace {
            id: analogClock
            Layout.alignment: Qt.AlignVCenter
            currentTime: headerRoot.currentTime
        }
    }
}
