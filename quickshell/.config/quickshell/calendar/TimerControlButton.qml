import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./Theme.js" as Theme

Rectangle {
    id: controlButton

    // ============ 属性声明 ============
    required property string label
    required property string icon
    property bool highlighted: false

    // ============ 信号声明 ============
    signal clicked()

    implicitHeight: 42
    radius: Theme.radiusPill
    color: highlighted
        ? (buttonMouse.containsMouse ? Theme.alpha(Theme.primary, 0.9) : Theme.primary)
        : (buttonMouse.containsMouse ? Theme.alpha(Theme.surfaceVariant, 0.72) : Theme.alpha(Theme.surface, 0.54))
    border.color: highlighted ? Theme.alpha(Theme.primary, 0.6) : Theme.alpha(Theme.outline, 0.5)
    border.width: 1
    scale: buttonMouse.pressed ? 0.96 : (buttonMouse.containsMouse ? 1.03 : 1.0)

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    RowLayout {
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: controlButton.icon
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
            color: controlButton.highlighted ? "#ffffff" : Theme.textSecondary
        }

        Text {
            text: controlButton.label
            font.pixelSize: Theme.fontSizeM
            font.bold: true
            color: controlButton.highlighted ? "#ffffff" : Theme.textSecondary
        }
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: controlButton.clicked()
    }
}
