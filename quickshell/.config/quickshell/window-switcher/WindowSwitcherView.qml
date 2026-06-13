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

    Variants {
        model: ScreenModel.targetScreens(Quickshell.screens, Quickshell.env("QS_TARGET_OUTPUT"))

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-window-switcher-bg"
            WlrLayershell.layer: WlrLayer.Overlay
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
            WlrLayershell.namespace: "qs-window-switcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            implicitWidth: Math.min(controller.columns * (controller.cardWidth + Theme.spacingM) + Theme.spacingXL * 2, (modelData.width ? modelData.width : 1280) - 80) + shadowPadding * 2
            implicitHeight: Math.min(contentCol.implicitHeight + Theme.spacingXL * 2, (modelData.height ? modelData.height : 720) - 80) + shadowPadding * 2

            // Keyboard shortcuts
            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }
            Shortcut { sequence: "Return"; onActivated: controller.focusSelected() }
            Shortcut { sequence: "Enter"; onActivated: controller.focusSelected() }
            Shortcut { sequence: "Ctrl+D"; onActivated: controller.closeSelected() }
            Shortcut { sequence: "Ctrl+Shift+D"; onActivated: controller.closeAllWindows() }

            Shortcut { sequence: "Left"; onActivated: controller.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: controller.moveRight() }
            Shortcut { sequence: "Up"; onActivated: controller.moveUp() }
            Shortcut { sequence: "Down"; onActivated: controller.moveDown() }
            Shortcut { sequence: "h"; onActivated: controller.moveLeft() }
            Shortcut { sequence: "l"; onActivated: controller.moveRight() }
            Shortcut { sequence: "k"; onActivated: controller.moveUp() }
            Shortcut { sequence: "j"; onActivated: controller.moveDown() }
            Shortcut { sequence: "Ctrl+H"; onActivated: controller.moveLeft() }
            Shortcut { sequence: "Ctrl+L"; onActivated: controller.moveRight() }
            Shortcut { sequence: "Ctrl+K"; onActivated: controller.moveUp() }
            Shortcut { sequence: "Ctrl+J"; onActivated: controller.moveDown() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            // Main container
            Rectangle {
                id: mainContainer
                anchors.fill: parent
                anchors.margins: panel.shadowPadding
                color: Theme.alpha(Theme.background, 0.42)
                radius: Theme.radiusXL + 4
                border.color: Theme.glassBorder
                border.width: 1.5

                opacity: controller.panelOpacity

                // 玻璃内描边
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassHighlight
                    z: 10
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Search box (fzf style)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: Theme.radiusL
                        color: Theme.surface
                        border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
                        border.width: searchInput.activeFocus ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            Text {
                                text: "\uf002"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 18
                                color: Theme.primary
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                font.pixelSize: Theme.fontSizeL
                                font.family: "monospace"
                                color: Theme.textPrimary
                                clip: true
                                focus: true
                                activeFocusOnTab: true
                                onTextChanged: controller.searchText = text

                                Keys.onPressed: function(event) {
                                    switch (event.key) {
                                        case Qt.Key_Left:
                                            controller.moveLeft()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Right:
                                            controller.moveRight()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Up:
                                            controller.moveUp()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Down:
                                            controller.moveDown()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Return:
                                        case Qt.Key_Enter:
                                            controller.focusSelected()
                                            event.accepted = true
                                            break
                                        case Qt.Key_Escape:
                                            controller.closeWithAnimation()
                                            event.accepted = true
                                            break
                                    }
                                }

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 2
                                    verticalAlignment: Text.AlignVCenter
                                    text: controller.i18nContext.tr("searchPlaceholder")
                                    font.pixelSize: Theme.fontSizeL
                                    font.family: "monospace"
                                    color: Theme.textMuted
                                    visible: !searchInput.text
                                }
                            }

                            Rectangle {
                                width: countText.implicitWidth + Theme.spacingM * 2
                                height: 24
                                radius: 12
                                color: Theme.surfaceVariant

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: controller.filteredWindows.length + "/" + controller.allWindows.length
                                    font.pixelSize: Theme.fontSizeS
                                    font.family: "monospace"
                                    color: Theme.textMuted
                                }
                            }

                            // Close All Button
                            Rectangle {
                                visible: controller.filteredWindows.length > 0
                                width: closeAllText.implicitWidth + Theme.spacingM * 2
                                height: 24
                                radius: 12
                                color: closeAllHover.hovered ? Theme.error : Theme.alpha(Theme.error, 0.1)

                                Text {
                                    id: closeAllText
                                    anchors.centerIn: parent
                                    text: controller.i18nContext.trLiteral("关闭全部")
                                    font.pixelSize: Theme.fontSizeS
                                    color: closeAllHover.hovered ? "white" : Theme.error
                                }

                                HoverHandler { id: closeAllHover }
                                TapHandler { onTapped: controller.closeAllWindows() }
                            }
                        }
                    }

                    // Window grid
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: {
                            var rows = Math.ceil(controller.filteredWindows.length / controller.columns)
                            return Math.min(rows * (controller.cardHeight + Theme.spacingM), 500)
                        }
                        contentHeight: windowGrid.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        GridLayout {
                            id: windowGrid
                            width: parent.width
                            columns: controller.columns
                            rowSpacing: Theme.spacingM
                            columnSpacing: Theme.spacingM

                            Repeater {
                                model: controller.filteredWindows

                                Rectangle {
                                    id: winCard
                                    required property var modelData
                                    required property int index

                                    Layout.preferredWidth: controller.cardWidth
                                    Layout.preferredHeight: controller.cardHeight
                                    radius: Theme.radiusL
                                    color: Theme.surface
                                    border.color: index === controller.selectedIndex ? Theme.primary : Theme.outline
                                    border.width: index === controller.selectedIndex ? 2 : 1

                                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                    // Hover effect
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusL
                                        color: winHover.hovered ? Theme.alpha(Theme.textPrimary, 0.03) : "transparent"
                                    }

                                    HoverHandler { id: winHover }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingS

                                        // Preview area (simulated)
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: Theme.radiusM
                                            color: Theme.alpha(controller.getAppColor(winCard.modelData.app_id), 0.08)
                                            border.color: Theme.alpha(controller.getAppColor(winCard.modelData.app_id), 0.2)
                                            border.width: 1

                                            // App icon centered
                                            Text {
                                                anchors.centerIn: parent
                                                text: controller.getAppIcon(winCard.modelData.app_id)
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 48
                                                color: controller.getAppColor(winCard.modelData.app_id)
                                                opacity: 0.6
                                            }

                                            // Workspace badge
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.margins: Theme.spacingS
                                                width: wsText.implicitWidth + Theme.spacingS * 2
                                                height: 20
                                                radius: 10
                                                color: Theme.primary

                                                Text {
                                                    id: wsText
                                                    anchors.centerIn: parent
                                                    text: "WS " + winCard.modelData.workspace_id
                                                    font.pixelSize: Theme.fontSizeXS
                                                    font.bold: true
                                                    color: "white"
                                                }
                                            }

                                            // Status badges
                                            Row {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: Theme.spacingS
                                                spacing: Theme.spacingXS

                                                Rectangle {
                                                    visible: winCard.modelData.is_focused
                                                    width: 20
                                                    height: 20
                                                    radius: 10
                                                    color: Theme.success

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf00c"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 10
                                                        color: "white"
                                                    }
                                                }

                                                Rectangle {
                                                    visible: winCard.modelData.is_floating
                                                    width: 20
                                                    height: 20
                                                    radius: 10
                                                    color: Theme.warning

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf24d"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 10
                                                        color: "white"
                                                    }
                                                }
                                            }
                                        }

                                        // Window info
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingS

                                                Rectangle {
                                                    width: 20
                                                    height: 20
                                                    radius: Theme.radiusS
                                                    color: Theme.alpha(controller.getAppColor(winCard.modelData.app_id), 0.15)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: controller.getAppIcon(winCard.modelData.app_id)
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 11
                                                        color: controller.getAppColor(winCard.modelData.app_id)
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: winCard.modelData.title || "Untitled"
                                                    font.pixelSize: Theme.fontSizeM
                                                    font.bold: winCard.modelData.is_focused
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: winCard.modelData.app_id || "unknown"
                                                font.pixelSize: Theme.fontSizeS
                                                font.family: "monospace"
                                                color: Theme.textMuted
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    // Close button (top level for proper event handling)
                                    Rectangle {
                                        id: closeBtn
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: Theme.spacingM + 90  // Below preview area
                                        anchors.rightMargin: Theme.spacingM + Theme.spacingS
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: closeHover.hovered ? Theme.error : Theme.alpha(Theme.error, 0.1)
                                        visible: winHover.hovered || index === controller.selectedIndex
                                        z: 10

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00d"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 12
                                            color: closeHover.hovered ? "white" : Theme.error
                                        }

                                        HoverHandler { id: closeHover }
                                    }

                                    // Card click area (must be after close button to check it)
                                    MouseArea {
                                        anchors.fill: parent
                                        z: 5
                                        onClicked: function(mouse) {
                                            // Check if click is on close button
                                            var closeBtnPos = closeBtn.mapToItem(winCard, 0, 0)
                                            if (closeBtn.visible &&
                                                mouse.x >= closeBtnPos.x && mouse.x <= closeBtnPos.x + closeBtn.width &&
                                                mouse.y >= closeBtnPos.y && mouse.y <= closeBtnPos.y + closeBtn.height) {
                                                controller.closeWindow(winCard.modelData)
                                            } else {
                                                controller.focusWindow(winCard.modelData)
                                            }
                                        }
                                    }

                                    // Selection glow
                                    Rectangle {
                                        visible: index === controller.selectedIndex
                                        anchors.fill: parent
                                        anchors.margins: -2
                                        radius: Theme.radiusL + 2
                                        color: "transparent"
                                        border.color: Theme.alpha(Theme.primary, 0.3)
                                        border.width: 3
                                        z: -1
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Rectangle {
                        visible: controller.filteredWindows.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        color: "transparent"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: controller.searchText ? "\uf002" : "\uf2d2"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 48
                                color: Theme.textMuted
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: controller.searchText ? "No matching windows" : "No windows open"
                                font.pixelSize: Theme.fontSizeL
                                color: Theme.textMuted
                            }
                        }
                    }

                    // Hints
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.radiusM
                        color: Theme.surfaceVariant

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXL

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Enter"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Switch"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Ctrl+D"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Close"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Ctrl+Shift+D"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Close All"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "H/J/K/L"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Navigate"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }

                            RowLayout {
                                spacing: Theme.spacingXS
                                Text { text: "Esc"; font.pixelSize: Theme.fontSizeS; font.bold: true; color: Theme.textSecondary }
                                Text { text: "Cancel"; font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }
                            }
                        }
                    }
                }

                // Close All Confirmation Dialog
                Rectangle {
                    visible: controller.showCloseAllConfirm
                    anchors.fill: parent
                    color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.6)
                    radius: Theme.radiusXL

                    MouseArea {
                        anchors.fill: parent
                        onClicked: controller.showCloseAllConfirm = false
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 320
                        height: confirmContent.implicitHeight + Theme.spacingXL * 2
                        color: Theme.alpha(Theme.background, 0.42)
                        radius: Theme.radiusXL + 2
                        border.color: Theme.alpha(Theme.error, 0.4)
                        border.width: 1.5

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.alpha(Theme.error, 0.25)
                            shadowBlur: 1.0
                            shadowVerticalOffset: 16
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.glassHighlight
                            z: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: function(mouse) { mouse.accepted = true }
                        }

                        ColumnLayout {
                            id: confirmContent
                            anchors.centerIn: parent
                            anchors.margins: Theme.spacingXL
                            spacing: Theme.spacingL

                            // Warning Icon
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56
                                height: 56
                                radius: 28
                                color: Theme.alpha(Theme.error, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf071"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 26
                                    color: Theme.error
                                }
                            }

                            // Title
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: controller.i18nContext.trLiteral("关闭全部窗口")
                                font.pixelSize: Theme.fontSizeL
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            // Message
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: controller.i18nContext.trLiteral("确定要关闭全部 ") + controller.filteredWindows.length + controller.i18nContext.trLiteral(" 个窗口吗？")
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textSecondary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: controller.i18nContext.trLiteral("此操作不可撤销")
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.warning
                            }

                            // Buttons
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: Theme.spacingM

                                Rectangle {
                                    width: 100
                                    height: 36
                                    radius: Theme.radiusM
                                    color: cancelConfirmHover.hovered ? Theme.surfaceVariant : Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: controller.i18nContext.trLiteral("取消 (N)")
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textSecondary
                                    }

                                    HoverHandler { id: cancelConfirmHover }
                                    TapHandler { onTapped: controller.showCloseAllConfirm = false }
                                }

                                Rectangle {
                                    width: 120
                                    height: 36
                                    radius: Theme.radiusM
                                    color: confirmCloseHover.hovered ? Theme.alpha(Theme.error, 0.8) : Theme.error

                                    Text {
                                        anchors.centerIn: parent
                                        text: controller.i18nContext.trLiteral("全部关闭 (Y)")
                                        font.pixelSize: Theme.fontSizeM
                                        font.bold: true
                                        color: Theme.surface
                                    }

                                    HoverHandler { id: confirmCloseHover }
                                    TapHandler { onTapped: controller.confirmCloseAll() }
                                }
                            }
                        }

                        // Keyboard handling for confirm dialog
                        focus: controller.showCloseAllConfirm
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Y) {
                                controller.confirmCloseAll()
                                event.accepted = true
                            } else if (event.key === Qt.Key_N || event.key === Qt.Key_Escape) {
                                controller.showCloseAllConfirm = false
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }}
