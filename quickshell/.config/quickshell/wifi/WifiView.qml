import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

Item {
    id: wifiView

    required property var controller

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-wifi-bg"
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
            readonly property int contentWidth: 400
            screen: modelData

            color: "transparent"
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "quickshell-wifi"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: controller.showPasswordDialog ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors.top: controller.anchorTop && !controller.anchorVCenter
            anchors.bottom: controller.anchorBottom
            anchors.left: controller.anchorLeft
            anchors.right: controller.anchorRight
            margins.top: controller.anchorTop ? controller.marginT - shadowPadding : 0
            margins.bottom: controller.anchorBottom ? controller.marginB - shadowPadding : 0
            margins.left: controller.anchorLeft ? controller.marginL - shadowPadding : 0
            margins.right: controller.anchorRight ? controller.marginR - shadowPadding : 0
            implicitWidth: contentWidth + shadowPadding * 2
            implicitHeight: Math.min(720, panelRect.implicitHeight) + shadowPadding * 2


            Shortcut { sequence: "Escape"; onActivated: { controller.showPasswordDialog = false; controller.showInfoDialog = false; controller.closeWithAnimation() } }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

             Rectangle {
                id: panelRect
                anchors.fill: parent
                anchors.margins: panel.shadowPadding
                color: Theme.alpha(Theme.background, 0.28)
                radius: Theme.radiusXL
                border.color: Theme.glassBorder
                border.width: 1.5
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                // 顶部内发光高光
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

                        Text { text: "\uf1eb"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeL; color: controller.wifiEnabled ? Theme.primary : Theme.textMuted }
                        Text { text: "Wi-Fi"; font.pixelSize: Theme.fontSizeL; font.weight: Font.Bold; color: Theme.textPrimary; Layout.fillWidth: true }

                        // Toggle
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: controller.wifiEnabled ? Theme.primary : Theme.surfaceVariant

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: controller.wifiEnabled ? parent.width - width - 3 : 3
                                color: Theme.textPrimary
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: controller.toggleWifi(!controller.wifiEnabled) }
                        }

                        // Refresh
                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: refreshMa.containsMouse ? Theme.surfaceVariant : "transparent"
                            scale: refreshMa.pressed ? 0.9 : (refreshMa.containsMouse ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent; text: "\uf021"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeM; color: Theme.textSecondary
                                RotationAnimation on rotation { running: controller.wifiScanning; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                            }
                            MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: controller.wifiEnabled && !controller.wifiScanning; onClicked: scanWifi.running = true }
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

                    // Tab bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Repeater {
                            model: [{ icon: "\uf1eb", label: "Wi-Fi", idx: 0 }, { icon: "\uf6ff", label: controller.i18nContext.trLiteral("以太网"), idx: 1 }]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: Theme.radiusM
                                color: controller.currentTab === modelData.idx ? Theme.primary : Theme.surface
                                border.color: controller.currentTab === modelData.idx ? Theme.primary : Theme.outline
                                scale: tabMa.pressed ? 0.97 : 1.0

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeM
                                    font.weight: controller.currentTab === modelData.idx ? Font.Bold : Font.Medium
                                    color: controller.currentTab === modelData.idx ? Theme.background : Theme.textSecondary

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea { id: tabMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: controller.currentTab = modelData.idx }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // Content
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: controller.currentTab

                        // ===== WiFi Tab =====
                        // Item height: 56px + spacing 10px = 66px per item
                        property int itemHeight: 66
                        property int maxVisibleItems: 7

                        ScrollView {
                            id: wifiScroll
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(parent.maxVisibleItems * parent.itemHeight, wifiContent.implicitHeight)
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            contentWidth: availableWidth

                            ColumnLayout {
                                id: wifiContent
                                width: wifiScroll.availableWidth
                                spacing: Theme.spacingM

                                // Disabled state
                                Rectangle {
                                    visible: !controller.wifiEnabled
                                    Layout.fillWidth: true; height: 120; color: "transparent"
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: Theme.spacingM
                                        Text { text: "\uf1eb"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 48; color: Theme.textMuted; opacity: 0.5; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: controller.i18nContext.trLiteral("Wi-Fi 已关闭"); font.pixelSize: Theme.fontSizeM; color: Theme.textMuted }
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

                                // Known Networks Section
                                ColumnLayout {
                                    visible: controller.wifiEnabled && controller.wifiNetworks.some(n => n.known)
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    Text { text: controller.i18nContext.trLiteral("已知网络"); font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                    Repeater {
                                        model: controller.wifiEnabled ? controller.wifiNetworks.filter(n => n.known) : []

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 56
                                            radius: Theme.radiusM
                                            color: knownHover.hovered ? Theme.surfaceVariant : Theme.surface
                                            border.color: modelData.connected ? Theme.primary : Theme.outline
                                            border.width: 1

                                            HoverHandler {
                                                id: knownHover
                                            }

                                            ColumnLayout {
                                                id: knownColumn
                                                width: parent.width - Theme.spacingM * 2
                                                x: Theme.spacingM
                                                y: Theme.spacingM
                                                spacing: Theme.spacingS

                                                RowLayout {
                                                    id: knownRow
                                                    Layout.fillWidth: true
                                                    spacing: Theme.spacingM

                                                    // WiFi icon - left side
                                                    Rectangle {
                                                        id: knownIconBg
                                                        width: 36; height: 36; radius: Theme.radiusS
                                                        Layout.alignment: Qt.AlignVCenter
                                                        color: modelData.connected ? Theme.alpha(Theme.primary, 0.15) : Theme.surfaceVariant
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf1eb"
                                                            font.family: "Symbols Nerd Font Mono"
                                                            font.pixelSize: Theme.iconSizeM
                                                            color: modelData.connected ? Theme.primary : Theme.textSecondary
                                                        }
                                                    }

                                                    // Network info
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
                                                                text: modelData.ssid
                                                                font.pixelSize: Theme.fontSizeM
                                                                font.weight: modelData.connected ? Font.Bold : Font.Medium
                                                                color: Theme.textPrimary
                                                                elide: Text.ElideRight
                                                            }
                                                            Rectangle {
                                                                visible: modelData.connected
                                                                width: 40; height: 16
                                                                radius: Theme.radiusPill
                                                                color: Theme.alpha(Theme.success, 0.2)
                                                                Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("已连接"); font.pixelSize: Theme.fontSizeXS; color: Theme.success }
                                                            }
                                                            Rectangle {
                                                                visible: controller.connectingTo === modelData.ssid
                                                                width: 50; height: 16
                                                                radius: Theme.radiusPill
                                                                color: Theme.alpha(Theme.warning, 0.2)
                                                                Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("连接中..."); font.pixelSize: Theme.fontSizeXS; color: Theme.warning }
                                                            }
                                                        }

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: Theme.spacingXS
                                                            Text {
                                                                visible: modelData.security && modelData.security !== ""
                                                                text: "\uf023"
                                                                font.family: "Symbols Nerd Font Mono"
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                Layout.minimumWidth: 0
                                                                text: modelData.security || controller.i18nContext.trLiteral("开放")
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }

                                                    // Buttons - right side
                                                    RowLayout {
                                                        id: knownBtnRow
                                                        Layout.alignment: Qt.AlignVCenter
                                                        spacing: Theme.spacingS

                                                        // Info button (connected only)
                                                        Rectangle {
                                                            visible: modelData.connected
                                                            width: 28; height: 28; radius: 14
                                                            color: knInfoMa.containsMouse ? Theme.surfaceVariant : Theme.alpha(Theme.primary, 0.1)
                                                            border.color: Theme.primary; border.width: 1
                                                            Text { anchors.centerIn: parent; text: "\uf129"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12; color: Theme.primary }
                                                            MouseArea { id: knInfoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.showNetworkInfo(modelData.ssid) }
                                                        }

                                                    // Connect button (not connected, known, on hover)
                                                    Rectangle {
                                                        visible: !modelData.connected && controller.connectingTo !== modelData.ssid && knownHover.hovered
                                                        width: 28; height: 28; radius: Theme.radiusS
                                                        color: knConnMa.containsMouse ? Theme.alpha(Theme.primary, 0.8) : Theme.primary
                                                        Text { anchors.centerIn: parent; text: "\uf061"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeS; color: Theme.background }
                                                        MouseArea { id: knConnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.connectToWifi(modelData.ssid, "") }
                                                    }

                                                    // Forget button (known, not connected, on hover)
                                                    Rectangle {
                                                        visible: !modelData.connected && controller.connectingTo !== modelData.ssid && knownHover.hovered
                                                        width: 44; height: 28; radius: Theme.radiusS
                                                        color: knForgetMa.containsMouse ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                        border.color: Theme.error
                                                        Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("忘记"); font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                        MouseArea { id: knForgetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.forgetWifi(modelData.ssid) }
                                                    }

                                                    // Disconnect button (connected only)
                                                    Rectangle {
                                                        visible: modelData.connected
                                                        width: 70; height: 28
                                                        radius: Theme.radiusS
                                                            color: knDiscMa.containsMouse ? Theme.alpha(Theme.error, 0.3) : Theme.alpha(Theme.error, 0.15)
                                                            border.color: Theme.error
                                                            Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("断开连接"); font.pixelSize: Theme.fontSizeXS; color: Theme.error }
                                                            MouseArea { id: knDiscMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.disconnectWifi(modelData.ssid) }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Available Networks Section
                                ColumnLayout {
                                    visible: controller.wifiEnabled && controller.wifiNetworks.some(n => !n.known)
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    Text { text: controller.i18nContext.trLiteral("可用网络"); font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                    Repeater {
                                        model: controller.wifiEnabled ? controller.wifiNetworks.filter(n => !n.known) : []

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 56
                                            radius: Theme.radiusM
                                            color: availHover.hovered ? Theme.surfaceVariant : Theme.surface
                                            border.color: controller.connectingTo === modelData.ssid ? Theme.warning : Theme.outline
                                            border.width: 1

                                            HoverHandler {
                                                id: availHover
                                            }

                                            ColumnLayout {
                                                id: availColumn
                                                width: parent.width - Theme.spacingM * 2
                                                x: Theme.spacingM
                                                y: Theme.spacingM
                                                spacing: Theme.spacingS

                                                RowLayout {
                                                    id: availRow
                                                    Layout.fillWidth: true
                                                    spacing: Theme.spacingM

                                                    // WiFi icon - left side
                                                    Rectangle {
                                                        id: availIconBg
                                                        width: 36; height: 36; radius: Theme.radiusS
                                                        Layout.alignment: Qt.AlignVCenter
                                                        color: Theme.surfaceVariant
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf1eb"
                                                            font.family: "Symbols Nerd Font Mono"
                                                            font.pixelSize: Theme.iconSizeM
                                                            color: Theme.textSecondary
                                                            opacity: Math.max(0.5, modelData.signal / 100)
                                                        }
                                                    }

                                                    // Network info
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
                                                                text: modelData.ssid
                                                                font.pixelSize: Theme.fontSizeM
                                                                font.weight: Font.Medium
                                                                color: Theme.textPrimary
                                                                elide: Text.ElideRight
                                                            }
                                                            Rectangle {
                                                                visible: controller.connectingTo === modelData.ssid
                                                                width: 50; height: 16
                                                                radius: Theme.radiusPill
                                                                color: Theme.alpha(Theme.warning, 0.2)
                                                                Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("连接中..."); font.pixelSize: Theme.fontSizeXS; color: Theme.warning }
                                                            }
                                                        }

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: Theme.spacingXS
                                                            Text {
                                                                visible: modelData.security && modelData.security !== ""
                                                                text: "\uf023"
                                                                font.family: "Symbols Nerd Font Mono"
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                Layout.minimumWidth: 0
                                                                text: modelData.security || controller.i18nContext.trLiteral("开放")
                                                                font.pixelSize: Theme.fontSizeXS
                                                                color: Theme.textMuted
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }

                                                    // Button - right side
                                                    Rectangle {
                                                        id: availBtn
                                                        visible: controller.connectingTo !== modelData.ssid
                                                        Layout.alignment: Qt.AlignVCenter
                                                        width: 44; height: 28
                                                        radius: Theme.radiusS
                                                        color: avPwdMa.containsMouse ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha(Theme.primary, 0.15)
                                                        border.color: Theme.primary
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: controller.i18nContext.trLiteral("连接")
                                                            font.pixelSize: Theme.fontSizeXS
                                                            color: Theme.primary
                                                        }
                                                        MouseArea {
                                                            id: avPwdMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (modelData.security && modelData.security !== "") {
                                                                    controller.passwordDialogSsid = modelData.ssid
                                                                    controller.passwordDialogSecurity = modelData.security
                                                                    controller.showPasswordDialog = true
                                                                } else {
                                                                    controller.connectToWifi(modelData.ssid, "")
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Scanning indicator
                                Rectangle {
                                    visible: controller.wifiEnabled && controller.wifiScanning && controller.wifiNetworks.length === 0
                                    Layout.fillWidth: true; height: 80; color: "transparent"
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

                        // ===== Ethernet Tab =====
                        ColumnLayout {
                            spacing: Theme.spacingM

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: ethContent.implicitHeight + Theme.spacingM * 2
                                radius: Theme.radiusM
                                color: Theme.surface
                                border.color: controller.ethernetConnected ? Theme.primary : Theme.outline
                                border.width: 1

                                RowLayout {
                                    id: ethContent
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 36; height: 36; radius: Theme.radiusS
                                        color: Theme.surfaceVariant
                                        border.color: controller.ethernetConnected ? Theme.primary : Theme.outline
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: "ETH"
                                            font.pixelSize: Theme.fontSizeS
                                            font.weight: Font.DemiBold
                                            color: controller.ethernetConnected ? Theme.primary : Theme.textMuted
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            spacing: Theme.spacingS
                                            Text {
                                                text: controller.ethernetDetails.name || controller.i18nContext.trLiteral("以太网")
                                                font.pixelSize: Theme.fontSizeM
                                                font.weight: Font.Medium
                                                color: Theme.textPrimary
                                            }
                                            Rectangle {
                                                visible: controller.ethernetConnected
                                                width: ethConnLabel.implicitWidth + 8
                                                height: ethConnLabel.implicitHeight + 4
                                                radius: Theme.radiusPill
                                                color: Theme.alpha(Theme.success, 0.2)
                                                Text { id: ethConnLabel; anchors.centerIn: parent; text: controller.i18nContext.trLiteral("已连接"); font.pixelSize: Theme.fontSizeXS; color: Theme.success }
                                            }
                                        }

                                        Text {
                                            text: controller.ethernetConnected ? (controller.ethernetDetails.ifname || "") : controller.i18nContext.trLiteral("未连接")
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.textMuted
                                        }
                                    }
                                }
                            }

                            // Ethernet details
                            ColumnLayout {
                                visible: controller.ethernetConnected
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Text { text: controller.i18nContext.trLiteral("连接详情"); font.pixelSize: Theme.fontSizeS; font.weight: Font.DemiBold; color: Theme.textMuted }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: ethDetailsCol.implicitHeight + Theme.spacingM * 2
                                    radius: Theme.radiusM
                                    color: Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    ColumnLayout {
                                        id: ethDetailsCol
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingS

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: controller.i18nContext.trLiteral("IP 地址"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                            Text { text: controller.ethernetDetails.ip || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: controller.i18nContext.trLiteral("网关"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                            Text { text: controller.ethernetDetails.gateway || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "DNS"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                                            Text { text: controller.ethernetDetails.dns || "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                WifiDialogs {
                    anchors.fill: parent
                    controller: wifiView.controller
                }

            }
        }
    }}
