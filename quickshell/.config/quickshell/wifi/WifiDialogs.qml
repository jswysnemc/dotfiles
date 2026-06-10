import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme
import "./ScreenModel.js" as ScreenModel

Item {
    required property var controller

    // ===== Password Dialog =====
    Rectangle {
        visible: controller.showPasswordDialog
        anchors.fill: parent
        color: Theme.alpha(Theme.background, 0.38)
        radius: Theme.radiusL
        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function () {
                    passwordInput.forceActiveFocus();
                });
            }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 4
            spacing: Theme.spacingL

            Text {
                text: controller.i18nContext.trLiteral("连接到 ") + controller.passwordDialogSsid
                font.pixelSize: Theme.fontSizeL
                font.weight: Font.Bold
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: controller.i18nContext.trLiteral("请输入密码")
                font.pixelSize: Theme.fontSizeM
                color: Theme.textMuted
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: Theme.radiusM
                color: Theme.surface
                border.color: passwordInput.activeFocus ? Theme.primary : Theme.outline
                border.width: 1

                TextInput {
                    id: passwordInput
                    anchors.margins: Theme.spacingM
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.textPrimary
                    echoMode: controller.passwordVisible ? TextInput.Normal : TextInput.Password
                    clip: true
                    focus: controller.showPasswordDialog
                    onAccepted: {
                        if (text !== "") {
                            controller.showPasswordDialog = false
                            controller.passwordVisible = false
                            controller.connectToWifi(controller.passwordDialogSsid, text)
                            text = ""
                        }
                    }
                }

                Text {
                    visible: passwordInput.text === ""
                    text: controller.i18nContext.trLiteral("密码")
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.textMuted
                }

                // Eye toggle button
                Rectangle {
                    id: eyeBtn
                    width: 32; height: 32
                    radius: Theme.radiusS
                    color: eyeMa.containsMouse ? Theme.surfaceVariant : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: controller.passwordVisible ? "\uf06e" : "\uf070"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: Theme.iconSizeS
                        color: Theme.textMuted
                    }

                    MouseArea {
                        id: eyeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controller.passwordVisible = !controller.passwordVisible
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: passwordInput.forceActiveFocus()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: Theme.radiusM
                    color: cancelMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                    border.color: Theme.outline

                    Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("取消"); font.pixelSize: Theme.fontSizeM; color: Theme.textSecondary }
                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { controller.showPasswordDialog = false; controller.passwordVisible = false; passwordInput.text = "" }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: Theme.radiusM
                    color: confirmMa.containsMouse ? Theme.alpha(Theme.primary, 0.8) : Theme.primary

                    Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("连接"); font.pixelSize: Theme.fontSizeM; font.weight: Font.Bold; color: Theme.background }
                    MouseArea {
                        id: confirmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (passwordInput.text !== "") {
                                controller.showPasswordDialog = false
                                controller.passwordVisible = false
                                controller.connectToWifi(controller.passwordDialogSsid, passwordInput.text)
                                passwordInput.text = ""
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== Info Dialog =====
    Rectangle {
        visible: controller.showInfoDialog
        anchors.fill: parent
        color: Theme.alpha(Theme.background, 0.38)
        radius: Theme.radiusL

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 4
            spacing: Theme.spacingL

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: controller.infoDialogData ? controller.infoDialogData.ssid : ""
                    font.pixelSize: Theme.fontSizeL
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: closeInfoMa.containsMouse ? Theme.surfaceVariant : "transparent"
                    Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Theme.iconSizeS; color: Theme.textSecondary }
                    MouseArea { id: closeInfoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.showInfoDialog = false }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: infoCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.radiusM
                color: Theme.surface
                border.color: Theme.outline
                border.width: 1

                ColumnLayout {
                    id: infoCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: controller.i18nContext.trLiteral("安全性"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                        Text { text: controller.infoDialogData ? (controller.infoDialogData.security || controller.i18nContext.trLiteral("开放")) : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: controller.i18nContext.trLiteral("信号"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                        Text { text: controller.infoDialogData ? (controller.infoDialogData.signal + "% " + (controller.infoDialogData.signalDbm || "")) : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                    }
                    RowLayout {
                        visible: controller.infoDialogData && controller.infoDialogData.band !== undefined && controller.infoDialogData.band !== ""
                        Layout.fillWidth: true
                        Text { text: controller.i18nContext.trLiteral("频段"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                        Text { text: controller.infoDialogData ? (controller.infoDialogData.band || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                    }
                    RowLayout {
                        visible: controller.infoDialogData && controller.infoDialogData.speed !== undefined && controller.infoDialogData.speed !== ""
                        Layout.fillWidth: true
                        Text { text: controller.i18nContext.trLiteral("速率"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                        Text { text: controller.infoDialogData ? (controller.infoDialogData.speed || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: controller.i18nContext.trLiteral("IP 地址"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                        Text { text: controller.infoDialogData ? (controller.infoDialogData.ip || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: controller.i18nContext.trLiteral("网关"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                        Text { text: controller.infoDialogData ? (controller.infoDialogData.gateway || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "DNS"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted; Layout.preferredWidth: 80 }
                        Text { text: controller.infoDialogData ? (controller.infoDialogData.dns || "-") : "-"; font.pixelSize: Theme.fontSizeS; color: Theme.textPrimary }
                    }
                }
            }

            // Forget button
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: Theme.radiusM
                color: forgetInfoMa.containsMouse ? Theme.alpha(Theme.error, 0.3) : Theme.alpha(Theme.error, 0.15)
                border.color: Theme.error

                Text { anchors.centerIn: parent; text: controller.i18nContext.trLiteral("忘记此网络"); font.pixelSize: Theme.fontSizeM; color: Theme.error }
                MouseArea {
                    id: forgetInfoMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        controller.forgetWifi(controller.infoDialogData.ssid)
                        controller.showInfoDialog = false
                    }
                }
            }
        }
    }}
