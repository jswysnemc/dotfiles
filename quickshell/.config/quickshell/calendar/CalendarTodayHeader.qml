import QtQuick
import QtQuick.Layouts
import "./Theme.js" as Theme

Rectangle {
    required property var controller

    Layout.fillWidth: true
    implicitHeight: 124
    radius: Theme.radiusL
    clip: true
    color: Theme.alpha(Theme.surface, 0.65)
    border.color: Theme.alpha(Theme.primary, 0.32)
    border.width: 1.5

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // 巨型日期
        Text {
            text: controller.todayDay
            font.pixelSize: 76
            font.weight: Font.Black
            font.letterSpacing: -2
            color: Theme.primary
            Layout.preferredWidth: 92
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }

        // 垂直分隔
        Rectangle {
            Layout.preferredWidth: 2
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter
            radius: 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha(Theme.primary, 0.0) }
                GradientStop { position: 0.5; color: Theme.alpha(Theme.primary, 0.4) }
                GradientStop { position: 1.0; color: Theme.alpha(Theme.primary, 0.0) }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingS

            // 年月 + 星期标签
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Text {
                    text: controller.i18nContext.tr("todayDate", {
                        year: controller.todayYear,
                        month: controller.getMonthName()
                    })
                    font.pixelSize: Theme.fontSizeL
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: weekdayLabel.implicitWidth + Theme.spacingM
                    implicitHeight: 22
                    radius: 11
                    color: Theme.alpha(Theme.primary, 0.18)
                    Text {
                        id: weekdayLabel
                        anchors.centerIn: parent
                        text: controller.todayWeekday
                        font.pixelSize: Theme.fontSizeXS
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                }
            }

            // 农历 + 节日
            RowLayout {
                Layout.fillWidth: true
                visible: controller.todayLunar !== ""
                spacing: Theme.spacingS

                Text {
                    text: controller.todayLunar
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: controller.todayFestival !== ""
                    implicitWidth: festLabel.implicitWidth + Theme.spacingM
                    implicitHeight: 22
                    radius: 11
                    color: Theme.alpha(Theme.warning, 0.2)
                    border.color: Theme.alpha(Theme.warning, 0.4)
                    border.width: 1
                    Text {
                        id: festLabel
                        anchors.centerIn: parent
                        text: controller.todayFestival
                        font.pixelSize: Theme.fontSizeXS
                        font.weight: Font.Medium
                        color: Theme.warning
                    }
                }
            }
        }

        // 今天按钮
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: todayBtnLabel.implicitWidth + Theme.spacingM * 2 + 18
            implicitHeight: 32
            Layout.preferredWidth: implicitWidth
            Layout.minimumWidth: implicitWidth
            radius: 16
            color: todayMouse.containsMouse ? Theme.alpha(Theme.primary, 0.22) : Theme.alpha(Theme.primary, 0.12)
            border.color: Theme.alpha(Theme.primary, 0.4)
            border.width: 1
            visible: controller.currentYear !== controller.todayYear || controller.currentMonth !== controller.todayMonth
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: "\uf073"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 11
                    color: Theme.primary
                }
                Text {
                    id: todayBtnLabel
                    text: controller.i18nContext.trLiteral("今天")
                    font.pixelSize: Theme.fontSizeS
                    font.weight: Font.Medium
                    color: Theme.primary
                }
            }

            MouseArea {
                id: todayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.goToToday()
            }
        }
    }
}
