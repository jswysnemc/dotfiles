import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./Theme.js" as Theme

RowLayout {
    id: modeSelector

    // ============ 属性声明 ============
    required property string selectedMode
    required property var controller

    // ============ 信号声明 ============
    signal modeSelected(string mode)

    Layout.fillWidth: true
    spacing: Theme.spacingS

    Repeater {
        model: [
            { key: "stopwatch", label: controller.i18nContext.trLiteral("正计时"), icon: "\uf2f2" },
            { key: "countdown", label: controller.i18nContext.trLiteral("倒计时"), icon: "\uf252" },
            { key: "pomodoro", label: controller.i18nContext.trLiteral("番茄时钟"), icon: "\ue003" }
        ]

        Rectangle {
            id: modeButton

            property string modeKey: modelData.key
            property bool selected: modeSelector.selectedMode === modeKey

            Layout.fillWidth: true
            implicitHeight: 42
            radius: Theme.radiusM
            color: selected ? Theme.alpha(Theme.primary, 0.18) : (modeMouse.containsMouse ? Theme.alpha(Theme.surface, 0.62) : Theme.alpha(Theme.surface, 0.42))
            border.color: selected ? Theme.alpha(Theme.primary, 0.55) : Theme.alpha(Theme.outline, 0.5)
            border.width: selected ? 1.5 : 1
            scale: modeMouse.containsMouse ? 1.03 : 1.0

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: modelData.icon
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 13
                    color: modeButton.selected ? Theme.primary : Theme.textSecondary
                }

                Text {
                    text: modelData.label
                    font.pixelSize: Theme.fontSizeS
                    font.bold: modeButton.selected
                    color: modeButton.selected ? Theme.primary : Theme.textSecondary
                }
            }

            MouseArea {
                id: modeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: modeSelector.modeSelected(modeButton.modeKey)
            }
        }
    }
}
