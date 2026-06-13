import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import "./BluetoothUtils.js" as BluetoothUtils
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

Item {
    required property var controller

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-bt-bg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }
        }
    }

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            readonly property int shadowPadding: 0
            screen: modelData

            color: "transparent"
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "quickshell-bt"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: controller.anchorTop && !controller.anchorVCenter
            anchors.bottom: controller.anchorBottom
            anchors.left: controller.anchorLeft
            anchors.right: controller.anchorRight
            margins.top: controller.anchorTop ? controller.marginT - shadowPadding : 0
            margins.bottom: controller.anchorBottom ? controller.marginB - shadowPadding : 0
            margins.left: controller.anchorLeft ? controller.marginL - shadowPadding : 0
            margins.right: controller.anchorRight ? controller.marginR - shadowPadding : 0
            implicitWidth: 380 + shadowPadding * 2
            implicitHeight: Math.min(720, panelRect.implicitHeight) + shadowPadding * 2
            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            Rectangle {
                id: panelRect
                anchors.fill: parent
                anchors.margins: panel.shadowPadding
                color: Theme.alpha(Theme.background, 0.42)
                radius: Theme.radiusXL
                border.color: Theme.glassBorder
                border.width: 1.5
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                // 玻璃内描边
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 10
                }

                opacity: controller.panelOpacity

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text { text: "\uf293"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: controller.btEnabled ? Theme.primary : Theme.textMuted }
                        Text { text: controller.i18nContext.trLiteral("蓝牙"); font.pixelSize: Theme.fontSizeL; font.weight: Font.Bold; color: Theme.textPrimary; Layout.fillWidth: true }

                        // Toggle
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: controller.btEnabled ? Theme.primary : Theme.surfaceVariant

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: controller.btEnabled ? parent.width - width - 3 : 3
                                color: Theme.textPrimary
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: controller.toggleBluetooth(!controller.btEnabled) }
                        }

                        // Discoverable
                        Rectangle {
                            width: 48; height: 28; radius: Theme.radiusS
                            color: controller.btDiscoverable ? Theme.alpha(Theme.primary, 0.2) : "transparent"
                            border.color: controller.btDiscoverable ? Theme.primary : Theme.outline
                            scale: discoverMa.pressed ? 0.95 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("可见"); font.pixelSize: Theme.fontSizeXS; color: controller.btDiscoverable ? Theme.primary : Theme.textSecondary }
                            MouseArea { id: discoverMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: controller.btEnabled; onClicked: controller.toggleDiscoverable(!controller.btDiscoverable) }
                        }

                        // Scan
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: scanMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: scanMa.pressed ? 0.9 : (scanMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent; text: "\uf021"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: Theme.textSecondary
                                RotationAnimation on rotation { running: controller.btScanning; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                            }
                            MouseArea { id: scanMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: controller.btEnabled; onClicked: controller.toggleScan() }
                        }

                        // Close
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: closeMa.pressed ? 0.9 : (closeMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: Theme.textSecondary }
                            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.closeWithAnimation() }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // Item height: ~70px per item (including spacing)
                    property int btItemHeight: 70
                    property int btMaxVisibleItems: 7

                    ScrollView {
                        id: btScroll
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(parent.btMaxVisibleItems * parent.btItemHeight, btContent.implicitHeight)
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        contentWidth: availableWidth

                        ColumnLayout {
                            id: btContent
                            width: btScroll.availableWidth
                            spacing: Theme.spacingM

                            // Disabled state
                            Rectangle {
                                visible: !controller.btEnabled
                                Layout.fillWidth: true; height: 120; color: "transparent"
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: Theme.spacingM
                                    Text { text: "\uf293"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 48; color: Theme.textMuted; opacity: 0.5; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: controller.i18nContext.trLiteral("蓝牙已关闭"); font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                                }
                            }

                            // Error banner
                            Rectangle {
                                visible: controller.lastError !== ""
                                Layout.fillWidth: true
                                radius: Theme.radiusM
                                color: Theme.alpha(Theme.error, 0.12)
                                border.color: Theme.error
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    Text {
                                        text: controller.lastError
                                        font.pixelSize: Theme.fontSizeS
                                        color: Theme.error
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        color: closeErrMa.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                        Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 10; color: Theme.error }
                                        MouseArea {
                                            id: closeErrMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: controller.lastError = ""
                                        }
                                    }
                                }
                            }

                            // Connected devices
                            ColumnLayout {
                                visible: controller.btEnabled && controller.btDevices.some(d => d.connected)
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: controller.i18nContext.trLiteral("已连接"); font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Repeater {
                                    model: controller.btDevices.filter(d => d.connected)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: connColumn.implicitHeight + Theme.spacingM * 2
                                        radius: Theme.radiusM
                                        color: connHover.hovered ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.primary
                                        border.width: 1
                                        readonly property bool isBusy: controller.isDeviceBusy(modelData)

                                        HoverHandler { id: connHover }

                                        ColumnLayout {
                                            id: connColumn
                                            width: parent.width - Theme.spacingM * 2
                                            x: Theme.spacingM
                                            y: Theme.spacingM
                                            spacing: Theme.spacingS

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingM

                                                Rectangle {
                                                    width: 36; height: 36; radius: Theme.radiusS
                                                    Layout.alignment: Qt.AlignVCenter
                                                    color: Theme.alpha(Theme.primary, 0.12)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: controller.deviceIconLabel(modelData)
                                                        font.pixelSize: Theme.fontSizeS
                                                        font.weight: Font.DemiBold
                                                        color: Theme.primary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: Theme.spacingS
                                                        Text {
                                                            Layout.fillWidth: true
                                                            Layout.minimumWidth: 0
                                                            text: controller.displayName(modelData)
                                                            font.pixelSize: Theme.fontSizeM
                                                            font.weight: Font.Bold
                                                            color: Theme.textPrimary
                                                            elide: Text.ElideRight
                                                        }
                                                        Rectangle {
                                                            width: 40; height: 16
                                                            radius: Theme.radiusPill
                                                            color: Theme.alpha(Theme.success, 0.2)
                                                            Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("已连接"); font.pixelSize: Theme.fontSizeXS; color: Theme.success }
                                                        }
                                                        Rectangle {
                                                            visible: isBusy
                                                            width: 50; height: 16
                                                            radius: Theme.radiusPill
                                                            color: Theme.alpha(Theme.warning, 0.2)
                                                            Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("处理中..."); font.pixelSize: Theme.fontSizeXS; color: Theme.warning }
                                                        }
                                                    }

                                                    Text { text: controller.deviceAddress(modelData) || ""; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: infoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                        border.color: Theme.primary; border.width: 1
                                                        Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                        MouseArea {
                                                            id: infoMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: controller.expandedMac = (controller.expandedMac === controller.deviceAddress(modelData)) ? "" : controller.deviceAddress(modelData)
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 70; height: 28
                                                        radius: Theme.radiusS
                                                        color: discMa.containsMouse ? Theme.alpha(Theme.error, 0.3) : Theme.alpha(Theme.error, 0.15)
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("断开"); font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: discMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.disconnectDevice(modelData) }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: forgetMa.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("忘记"); font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: forgetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.forgetDevice(modelData) }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: controller.expandedMac === controller.deviceAddress(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: infoCol.implicitHeight + Theme.spacingM * 2
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                border.color: Theme.outline
                                                border.width: 1

                                                ColumnLayout {
                                                    id: infoCol
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    spacing: Theme.spacingS

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("地址"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: controller.deviceAddress(modelData) || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("配对"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.paired ? controller.i18nContext.trLiteral("是") : controller.i18nContext.trLiteral("否"); font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("可信"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.trusted ? controller.i18nContext.trLiteral("是") : controller.i18nContext.trLiteral("否"); font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("信号"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var p = controller.getSignalPercent(modelData)
                                                                return p === null ? "-" : (p + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("电量"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var b = controller.getBatteryPercent(modelData)
                                                                return b === null ? "-" : (b + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Paired devices
                            ColumnLayout {
                                visible: controller.btEnabled && controller.btDevices.some(d => !d.connected && (d.paired || d.trusted))
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: controller.i18nContext.trLiteral("已配对"); font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Repeater {
                                    model: controller.btDevices.filter(d => !d.connected && (d.paired || d.trusted))

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: pairColumn.implicitHeight + Theme.spacingM * 2
                                        radius: Theme.radiusM
                                        color: pairHover.hovered ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.outline
                                        border.width: 1
                                        readonly property bool isBusy: controller.isDeviceBusy(modelData)

                                        HoverHandler { id: pairHover }

                                        ColumnLayout {
                                            id: pairColumn
                                            width: parent.width - Theme.spacingM * 2
                                            x: Theme.spacingM
                                            y: Theme.spacingM
                                            spacing: Theme.spacingS

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingM

                                                Rectangle {
                                                    width: 36; height: 36; radius: Theme.radiusS
                                                    Layout.alignment: Qt.AlignVCenter
                                                    color: Theme.surfaceVariant
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: controller.deviceIconLabel(modelData)
                                                        font.pixelSize: Theme.fontSizeS
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textSecondary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        text: controller.displayName(modelData)
                                                        font.pixelSize: Theme.fontSizeM
                                                        font.weight: Font.Medium
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }
                                                    Text { text: controller.deviceStatusLabel(modelData) + " · " + (controller.deviceAddress(modelData) || ""); font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: pairInfoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                        border.color: Theme.primary; border.width: 1
                                                        Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                        MouseArea {
                                                            id: pairInfoMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: controller.expandedMac = (controller.expandedMac === controller.deviceAddress(modelData)) ? "" : controller.deviceAddress(modelData)
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: connMa.containsMouse ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha(Theme.primary, 0.15)
                                                        border.color: Theme.primary
                                                        Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("连接"); font.pixelSize: Theme.fontSizeXS; color: Theme.primary }
                                                        MouseArea { id: connMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.connectDevice(modelData) }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: forget2Ma.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("忘记"); font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: forget2Ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.forgetDevice(modelData) }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: controller.expandedMac === controller.deviceAddress(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: infoColPaired.implicitHeight + Theme.spacingM * 2
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                border.color: Theme.outline
                                                border.width: 1

                                                ColumnLayout {
                                                    id: infoColPaired
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    spacing: Theme.spacingS

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("地址"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: controller.deviceAddress(modelData) || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("配对"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.paired ? controller.i18nContext.trLiteral("是") : controller.i18nContext.trLiteral("否"); font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("可信"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.trusted ? controller.i18nContext.trLiteral("是") : controller.i18nContext.trLiteral("否"); font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("信号"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var p2 = controller.getSignalPercent(modelData)
                                                                return p2 === null ? "-" : (p2 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("电量"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var b2 = controller.getBatteryPercent(modelData)
                                                                return b2 === null ? "-" : (b2 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Available devices
                            ColumnLayout {
                                visible: controller.btEnabled && controller.btDevices.some(d => !d.connected && !d.paired && !d.trusted)
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: controller.i18nContext.trLiteral("可用设备"); font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Repeater {
                                    model: controller.btDevices.filter(d => !d.connected && !d.paired && !d.trusted)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: availColumn.implicitHeight + Theme.spacingM * 2
                                        radius: Theme.radiusM
                                        color: availHover.hovered ? Theme.surfaceVariant : Theme.surface
                                        border.color: Theme.outline
                                        border.width: 1
                                        readonly property bool isBusy: controller.isDeviceBusy(modelData)

                                        HoverHandler { id: availHover }

                                        ColumnLayout {
                                            id: availColumn
                                            width: parent.width - Theme.spacingM * 2
                                            x: Theme.spacingM
                                            y: Theme.spacingM
                                            spacing: Theme.spacingS

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingM

                                                Rectangle {
                                                    width: 36; height: 36; radius: Theme.radiusS
                                                    Layout.alignment: Qt.AlignVCenter
                                                    color: Theme.surfaceVariant
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: controller.deviceIconLabel(modelData)
                                                        font.pixelSize: Theme.fontSizeS
                                                        font.weight: Font.DemiBold
                                                        color: Theme.textSecondary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        text: controller.displayName(modelData)
                                                        font.pixelSize: Theme.fontSizeM
                                                        font.weight: Font.Medium
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }
                                                    Text { text: controller.deviceAddress(modelData) || ""; font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: availInfoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                        border.color: Theme.primary; border.width: 1
                                                        Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                        MouseArea {
                                                            id: availInfoMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: controller.expandedMac = (controller.expandedMac === controller.deviceAddress(modelData)) ? "" : controller.deviceAddress(modelData)
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: pairMa.containsMouse ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha(Theme.primary, 0.15)
                                                        border.color: Theme.primary
                                                        Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("配对"); font.pixelSize: Theme.fontSizeXS; color: Theme.primary }
                                                        MouseArea { id: pairMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.pairDevice(modelData) }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: controller.expandedMac === controller.deviceAddress(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: infoColAvail.implicitHeight + Theme.spacingM * 2
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                border.color: Theme.outline
                                                border.width: 1

                                                ColumnLayout {
                                                    id: infoColAvail
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    spacing: Theme.spacingS

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("地址"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: controller.deviceAddress(modelData) || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("配对"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.paired ? controller.i18nContext.trLiteral("是") : controller.i18nContext.trLiteral("否"); font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("可信"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text { text: modelData.trusted ? controller.i18nContext.trLiteral("是") : controller.i18nContext.trLiteral("否"); font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("信号"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var p3 = controller.getSignalPercent(modelData)
                                                                return p3 === null ? "-" : (p3 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: controller.i18nContext.trLiteral("电量"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                                        Text {
                                                            text: {
                                                                var b3 = controller.getBatteryPercent(modelData)
                                                                return b3 === null ? "-" : (b3 + "%")
                                                            }
                                                            font.pixelSize: Theme.fontSizeS
                                                            color: Theme.textPrimary
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty state
                            Rectangle {
                                visible: controller.btEnabled && controller.btDevices.length === 0
                                Layout.fillWidth: true; height: 120; color: "transparent"
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: Theme.spacingM
                                    Text { text: "\uf293"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 36; color: Theme.textMuted; opacity: 0.5; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: controller.i18nContext.trLiteral("未发现设备"); font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                                    Text { text: controller.i18nContext.trLiteral("点击刷新开始扫描"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                                }
                            }

                            // Scanning indicator
                            Rectangle {
                                visible: controller.btEnabled && controller.btScanning && controller.btDevices.length === 0
                                Layout.fillWidth: true; height: 120; color: "transparent"
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: Theme.spacingM
                                    Text {
                                        text: "\uf110"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 24
                                        color: Theme.primary
                                        Layout.alignment: Qt.AlignHCenter
                                        RotationAnimation on rotation { running: true; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                                    }
                                    Text { text: controller.i18nContext.trLiteral("正在扫描..."); font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
                                }
                            }
                        }
                    }
                }
            }
        }
    }}
