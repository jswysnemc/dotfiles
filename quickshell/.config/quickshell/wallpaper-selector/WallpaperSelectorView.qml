import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "qs-wallpaper-selector-bg"
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
            WlrLayershell.namespace: "qs-wallpaper-selector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            implicitWidth: Math.min(modelData.width ? modelData.width * 0.8 : 900, 900) + shadowPadding * 2
            implicitHeight: Math.min(modelData.height ? modelData.height * 0.9 : 730, 730) + shadowPadding * 2

            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }
            Shortcut { sequence: "Up"; onActivated: controller.moveUp() }
            Shortcut { sequence: "Down"; onActivated: controller.moveDown() }
            Shortcut { sequence: "Left"; onActivated: controller.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: controller.moveRight() }
            Shortcut { sequence: "k"; onActivated: controller.moveUp() }
            Shortcut { sequence: "j"; onActivated: controller.moveDown() }
            Shortcut { sequence: "h"; onActivated: controller.moveLeft() }
            Shortcut { sequence: "l"; onActivated: controller.moveRight() }
            Shortcut { sequence: "Return"; onActivated: if (wallpaperModel.count > 0) controller.applyWallpaper(wallpaperModel.get(controller.selectedIndex).path) }
            Shortcut { sequence: "Space"; onActivated: if (wallpaperModel.count > 0) controller.applyWallpaper(wallpaperModel.get(controller.selectedIndex).path) }
            Shortcut { sequence: "Tab"; onActivated: controller.currentTab = (controller.currentTab + 1) % 2 }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            Rectangle {
                id: mainContainer
                anchors.fill: parent
                anchors.margins: panel.shadowPadding
                color: Theme.alpha(Theme.background, 0.28)
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
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header with Tab bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf03e"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 20
                            color: Theme.primary
                        }

                        Text {
                            text: controller.i18nContext.trLiteral("壁纸与主题")
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        // Tab bar - 放在标题右侧
                        Rectangle {
                            Layout.preferredWidth: 240
                            Layout.preferredHeight: 32
                            radius: Theme.radiusM
                            color: Theme.surfaceVariant

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 3

                                Repeater {
                                    model: [{name: controller.i18nContext.trLiteral("壁纸"), icon: "\uf03e"}, {name: controller.i18nContext.trLiteral("主题设置"), icon: "\uf1fc"}]

                                    Rectangle {
                                        required property int index
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: Theme.radiusS
                                        color: controller.currentTab === index ? Theme.surface : "transparent"

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: modelData.icon
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: Theme.fontSizeS
                                                color: controller.currentTab === index ? Theme.primary : Theme.textMuted
                                            }

                                            Text {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeS
                                                font.bold: controller.currentTab === index
                                                color: controller.currentTab === index ? Theme.primary : Theme.textMuted
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: controller.currentTab = parent.index
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: controller.loading ? controller.i18nContext.trLiteral("加载中...") : controller.wallpaperCount + controller.i18nContext.trLiteral(" 张壁纸")
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.textMuted
                        }

                        Rectangle {
                            width: 32; height: 32; radius: Theme.radiusM
                            color: closeMa.containsMouse ? Theme.surfaceVariant : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Theme.iconSizeM
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controller.closeWithAnimation()
                            }
                        }
                    }

                    // Content
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: controller.currentTab

                        // ============ Wallpapers Tab ============
                        Item {
                            GridView {
                                id: gridView
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: scrollBar.left
                                anchors.rightMargin: 6
                                cellWidth: Math.floor(width / 3)
                                cellHeight: 160
                                model: wallpaperModel
                                currentIndex: controller.selectedIndex
                                cacheBuffer: 800
                                clip: true

                                delegate: Item {
                                    width: gridView.cellWidth
                                    height: gridView.cellHeight

                                    required property string path
                                    required property int index

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: Theme.radiusM
                                        color: Theme.surface
                                        border.color: controller.selectedIndex === parent.index ? Theme.primary : (controller.currentWallpaper === parent.path ? Theme.primary : Theme.outline)
                                        border.width: controller.selectedIndex === parent.index || controller.currentWallpaper === parent.path ? 2 : 1

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: "file://" + path
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            sourceSize.width: 280
                                            sourceSize.height: 180
                                            mipmap: true

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Theme.surfaceVariant
                                                visible: parent.status !== Image.Ready
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf03e"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 24
                                                    color: Theme.textMuted
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: controller.currentWallpaper === path
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 6
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: Theme.primary
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf00c"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 11
                                                color: "white"
                                            }
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 2
                                            height: 26
                                            color: Theme.alpha(Qt.rgba(0, 0, 0, 1), 0.6)
                                            radius: Theme.radiusM - 2
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: parent.radius
                                                color: parent.color
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                width: parent.width - 8
                                                text: path.split('/').pop()
                                                font.pixelSize: Theme.fontSizeS
                                                color: "white"
                                                elide: Text.ElideMiddle
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: controller.selectedIndex = index
                                            onClicked: controller.applyWallpaper(path)
                                        }
                                    }
                                }
                            }

                            ScrollBar {
                                id: scrollBar
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 6
                                policy: gridView.contentHeight > gridView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: scrollBar.pressed ? Theme.primary : (scrollBar.hovered ? Theme.textMuted : Theme.outline)
                                }
                            }

                            Binding {
                                target: scrollBar
                                property: "position"
                                value: gridView.visibleArea.yPosition
                                when: !scrollBar.pressed
                            }

                            Binding {
                                target: scrollBar
                                property: "size"
                                value: gridView.visibleArea.heightRatio
                            }

                            Connections {
                                target: scrollBar
                                function onPositionChanged() {
                                    if (scrollBar.pressed) {
                                        gridView.contentY = scrollBar.position * gridView.contentHeight
                                    }
                                }
                            }
                        }

                        // ============ Theme Settings Tab ============
                        Item {
                            id: themeSettingsTab

                            // 模式按钮组件
                            component ModeButton: Rectangle {
                                id: modeBtn
                                property string mode: ""
                                property string icon: ""
                                property string label: ""
                                property bool isActive: false
                                property color activeColor: Theme.primary
                                signal clicked()

                                width: 64
                                height: 30
                                radius: Theme.radiusS
                                color: isActive ? activeColor : (modeBtnMa.containsMouse ? Theme.surfaceVariant : "transparent")
                                border.color: isActive ? activeColor : Theme.outline
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: modeBtn.icon
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 11
                                        color: modeBtn.isActive ? "white" : Theme.textSecondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modeBtn.label
                                        font.pixelSize: 11
                                        color: modeBtn.isActive ? "white" : Theme.textSecondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: modeBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modeBtn.clicked()
                                }
                            }

                            Column {
                                anchors.fill: parent
                                spacing: Theme.spacingM

                                // Row 1: QuickShell Theme
                                Rectangle {
                                    width: parent.width
                                    height: 68
                                    radius: Theme.radiusL
                                    color: Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        spacing: 12

                                        // Icon
                                        Rectangle {
                                            width: 42
                                            height: 42
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: Theme.radiusM
                                            color: Theme.surfaceVariant
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf0e7"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 18
                                                color: Theme.primary
                                            }
                                        }

                                        // Text
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 42 - 210 - 36
                                            spacing: 2
                                            Text {
                                                text: controller.i18nContext.trLiteral("QuickShell 主题")
                                                font.pixelSize: Theme.fontSizeM
                                                font.bold: true
                                                color: Theme.textPrimary
                                            }
                                            Text {
                                                text: controller.i18nContext.trLiteral("控制 QuickShell 组件的颜色模式")
                                                font.pixelSize: Theme.fontSizeS
                                                color: Theme.textMuted
                                            }
                                        }

                                        // Buttons
                                        Row {
                                            width: 210
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6
                                            ModeButton {
                                                mode: "dark"; icon: "\uf186"; label: controller.i18nContext.trLiteral("深色")
                                                isActive: controller.qsMode === "dark"
                                                activeColor: Theme.primary
                                                onClicked: controller.setQsModeValue("dark")
                                            }
                                            ModeButton {
                                                mode: "light"; icon: "\uf185"; label: controller.i18nContext.trLiteral("浅色")
                                                isActive: controller.qsMode === "light"
                                                activeColor: Theme.primary
                                                onClicked: controller.setQsModeValue("light")
                                            }
                                            ModeButton {
                                                mode: "auto"; icon: "\uf021"; label: controller.i18nContext.trLiteral("自动")
                                                isActive: controller.qsMode === "auto"
                                                activeColor: Theme.primary
                                                onClicked: controller.setQsModeValue("auto")
                                            }
                                        }
                                    }
                                }

                                // Row 2: Waybar Theme
                                Rectangle {
                                    width: parent.width
                                    height: 68
                                    radius: Theme.radiusL
                                    color: Theme.surface
                                    border.color: Theme.outline
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        spacing: 12

                                        // Icon
                                        Rectangle {
                                            width: 42
                                            height: 42
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: Theme.radiusM
                                            color: Theme.surfaceVariant
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf0c9"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 18
                                                color: Theme.secondary
                                            }
                                        }

                                        // Text
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 42 - 210 - 36
                                            spacing: 2
                                            Text {
                                                text: controller.i18nContext.trLiteral("Waybar 主题")
                                                font.pixelSize: Theme.fontSizeM
                                                font.bold: true
                                                color: Theme.textPrimary
                                            }
                                            Text {
                                                text: controller.i18nContext.trLiteral("控制状态栏的颜色模式")
                                                font.pixelSize: Theme.fontSizeS
                                                color: Theme.textMuted
                                            }
                                        }

                                        // Buttons
                                        Row {
                                            width: 210
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6
                                            ModeButton {
                                                mode: "dark"; icon: "\uf186"; label: controller.i18nContext.trLiteral("深色")
                                                isActive: controller.waybarMode === "dark"
                                                activeColor: Theme.secondary
                                                onClicked: controller.setWaybarModeValue("dark")
                                            }
                                            ModeButton {
                                                mode: "light"; icon: "\uf185"; label: controller.i18nContext.trLiteral("浅色")
                                                isActive: controller.waybarMode === "light"
                                                activeColor: Theme.secondary
                                                onClicked: controller.setWaybarModeValue("light")
                                            }
                                            ModeButton {
                                                mode: "auto"; icon: "\uf021"; label: controller.i18nContext.trLiteral("自动")
                                                isActive: controller.waybarMode === "auto"
                                                activeColor: Theme.secondary
                                                onClicked: controller.setWaybarModeValue("auto")
                                            }
                                        }
                                    }
                                }

                                // Row 3: Info
                                Rectangle {
                                    width: parent.width
                                    height: 68
                                    radius: Theme.radiusL
                                    color: Theme.alpha(Theme.tertiary, 0.08)
                                    border.color: Theme.alpha(Theme.tertiary, 0.2)
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        spacing: 12

                                        // Icon
                                        Rectangle {
                                            width: 42
                                            height: 42
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: Theme.radiusM
                                            color: Theme.alpha(Theme.tertiary, 0.15)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf05a"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 18
                                                color: Theme.tertiary
                                            }
                                        }

                                        // Text
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 42 - 210 - 36
                                            spacing: 2
                                            Text {
                                                text: controller.i18nContext.trLiteral("模式在下次设置壁纸时生效")
                                                font.pixelSize: Theme.fontSizeM
                                                font.bold: true
                                                color: Theme.textPrimary
                                            }
                                            Text {
                                                text: controller.i18nContext.trLiteral("点击下方按钮可立刻刷新所有组件主题")
                                                font.pixelSize: Theme.fontSizeS
                                                color: Theme.textMuted
                                            }
                                        }

                                        // Placeholder for alignment
                                        Item {
                                            width: 210
                                            height: 1
                                        }
                                    }
                                }

                                // Row 4: Apply Button
                                Rectangle {
                                    width: parent.width
                                    height: 68
                                    radius: Theme.radiusL
                                    color: applyMa.containsMouse ? Theme.primary : Theme.alpha(Theme.primary, 0.08)
                                    border.color: Theme.primary
                                    border.width: applyMa.containsMouse ? 0 : 1

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        spacing: 12

                                        // Icon
                                        Rectangle {
                                            width: 42
                                            height: 42
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: Theme.radiusM
                                            color: applyMa.containsMouse ? Theme.alpha("white", 0.2) : Theme.alpha(Theme.primary, 0.15)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf021"
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 18
                                                color: applyMa.containsMouse ? "white" : Theme.primary
                                            }
                                        }

                                        // Text
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 42 - 210 - 36
                                            spacing: 2
                                            Text {
                                                text: controller.i18nContext.trLiteral("立即应用主题")
                                                font.pixelSize: Theme.fontSizeM
                                                font.bold: true
                                                color: applyMa.containsMouse ? "white" : Theme.primary
                                            }
                                            Text {
                                                text: controller.i18nContext.trLiteral("刷新 QuickShell 和 Waybar 的主题配色")
                                                font.pixelSize: Theme.fontSizeS
                                                color: applyMa.containsMouse ? Theme.alpha("white", 0.8) : Theme.textMuted
                                            }
                                        }

                                        // Placeholder for alignment
                                        Item {
                                            width: 210
                                            height: 1
                                        }
                                    }

                                    MouseArea {
                                        id: applyMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: applyTheme.running = true
                                    }
                                }
                            }
                        }
                    }

                    // Footer
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: controller.currentTab === 0 ? controller.i18nContext.trLiteral("方向键选择 | Enter 应用 | Tab 切换 | Esc 关闭") : controller.i18nContext.trLiteral("点击切换模式 | Tab 切换 | Esc 关闭")
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }}
