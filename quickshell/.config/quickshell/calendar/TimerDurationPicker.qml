import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./Theme.js" as Theme

ColumnLayout {
    id: durationPicker

    // ============ 属性声明 ============
    required property int selectedMinutes
    required property var controller

    // ============ 信号声明 ============
    signal durationSelected(int minutes)

    Layout.fillWidth: true
    spacing: Theme.spacingS

    Text {
        text: controller.i18nContext.trLiteral("选择时长")
        font.pixelSize: Theme.fontSizeS
        font.bold: true
        color: Theme.textSecondary
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 4
        rowSpacing: Theme.spacingS
        columnSpacing: Theme.spacingS

        Repeater {
            model: [5, 10, 15, 25, 45, 60, 90, 120]

            Rectangle {
                id: durationButton

                property int minutes: modelData
                property bool selected: durationPicker.selectedMinutes === minutes

                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.radiusM
                color: selected ? Theme.alpha(Theme.primary, 0.18) : (durationMouse.containsMouse ? Theme.alpha(Theme.surface, 0.62) : Theme.alpha(Theme.surface, 0.38))
                border.color: selected ? Theme.alpha(Theme.primary, 0.5) : Theme.alpha(Theme.outline, 0.45)
                border.width: selected ? 1.5 : 1
                scale: durationMouse.containsMouse ? 1.04 : 1.0

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: controller.i18nContext.trLiteral("%1 分钟").arg(durationButton.minutes)
                    font.pixelSize: Theme.fontSizeS
                    font.bold: durationButton.selected
                    color: durationButton.selected ? Theme.primary : Theme.textSecondary
                }

                MouseArea {
                    id: durationMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: durationPicker.durationSelected(durationButton.minutes)
                }
            }
        }
    }
}
