import QtQuick
import QtQuick.Layouts
import "./Theme.js" as Theme

RowLayout {
    required property var controller

    Layout.fillWidth: true
    spacing: Theme.spacingS

    // 上一年
    Rectangle {
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Theme.radiusM
        color: prevYearMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: "\uf100"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.iconSizeS
            color: Theme.primary
        }

        MouseArea {
            id: prevYearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (controller.yearSelectMode) controller.yearSelectBase -= 12
                else controller.prevYear()
            }
        }
    }

    // 上个月
    Rectangle {
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Theme.radiusM
        color: prevMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
        visible: !controller.yearSelectMode

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: "\uf104"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.iconSizeM
            color: Theme.textSecondary
        }

        MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controller.prevMonth()
        }
    }

    // 当前年月
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: Theme.radiusM
        color: yearMonthMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"

        Text {
            anchors.fill: parent
            text: controller.yearSelectMode
                ? controller.i18nContext.tr("yearRange", {
                    start: controller.yearSelectBase,
                    end: controller.yearSelectBase + 11
                })
                : controller.i18nContext.tr("yearMonth", {
                    year: controller.currentYear,
                    month: controller.getMonthName()
                })
            font.pixelSize: Theme.fontSizeL
            font.bold: true
            color: controller.yearSelectMode ? Theme.primary : Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight

            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }

        MouseArea {
            id: yearMonthMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                controller.yearSelectMode = !controller.yearSelectMode
                if (controller.yearSelectMode) {
                    controller.yearSelectBase = controller.currentYear - 6
                }
            }
        }
    }

    // 下个月
    Rectangle {
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Theme.radiusM
        color: nextMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"
        visible: !controller.yearSelectMode

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: "\uf105"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.iconSizeM
            color: Theme.textSecondary
        }

        MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controller.nextMonth()
        }
    }

    // 下一年
    Rectangle {
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Theme.radiusM
        color: nextYearMouse.containsMouse ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: "\uf101"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Theme.iconSizeS
            color: Theme.primary
        }

        MouseArea {
            id: nextYearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (controller.yearSelectMode) controller.yearSelectBase += 12
                else controller.nextYear()
            }
        }
    }
}
