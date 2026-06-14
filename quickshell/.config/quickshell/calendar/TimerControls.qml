import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./Theme.js" as Theme

RowLayout {
    id: controls

    // ============ 属性声明 ============
    required property bool active
    required property bool running
    required property var controller

    // ============ 信号声明 ============
    signal startRequested()
    signal pauseRequested()
    signal resumeRequested()
    signal stopRequested()

    Layout.fillWidth: true
    spacing: Theme.spacingS

    TimerControlButton {
        Layout.fillWidth: true
        visible: !controls.active
        label: controls.controller.i18nContext.trLiteral("开始")
        icon: "\uf04b"
        highlighted: true
        onClicked: controls.startRequested()
    }

    TimerControlButton {
        Layout.fillWidth: true
        visible: controls.active && controls.running
        label: controls.controller.i18nContext.trLiteral("暂停")
        icon: "\uf04c"
        highlighted: true
        onClicked: controls.pauseRequested()
    }

    TimerControlButton {
        Layout.fillWidth: true
        visible: controls.active && !controls.running
        label: controls.controller.i18nContext.trLiteral("继续")
        icon: "\uf04b"
        highlighted: true
        onClicked: controls.resumeRequested()
    }

    TimerControlButton {
        Layout.fillWidth: true
        visible: controls.active
        label: controls.controller.i18nContext.trLiteral("停止")
        icon: "\uf04d"
        highlighted: false
        onClicked: controls.stopRequested()
    }
}
