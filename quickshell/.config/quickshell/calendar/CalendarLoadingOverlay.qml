import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

// Loading overlay
Rectangle {
    required property var controller
    anchors.fill: parent
    color: Theme.alpha(Theme.background, 0.36)
    radius: Theme.radiusL
    visible: opacity > 0
    opacity: controller.activeRoute === "calendar" && controller.isLoading ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingM

        Text {
            id: loadingIcon
            text: "\uf110"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 24
            color: Theme.primary
            Layout.alignment: Qt.AlignHCenter

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: controller.activeRoute === "calendar" && controller.isLoading
            }
        }

        Text {
            text: controller.i18nContext.trLiteral("加载中...")
            font.pixelSize: Theme.fontSizeM
            color: Theme.textMuted
        }
    }
}
