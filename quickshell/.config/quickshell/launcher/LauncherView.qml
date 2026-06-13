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
            id: clickCatcher
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-launcher-bg"
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
            screen: modelData

            color: "transparent"
            surfaceFormat.opaque: false
            WlrLayershell.namespace: "quickshell-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            BackgroundEffect.blurRegion: Region {
                id: blurRegion
                item: controller.blurActive && mainContainer.width > 0 && mainContainer.height > 0 ? mainContainer : null
                radius: Theme.radiusXL + 4
            }
            Connections {
                target: controller
                function onBlurActiveChanged() { blurRegion.changed() }
            }
            Connections {
                target: mainContainer
                function onXChanged() { blurRegion.changed() }
                function onYChanged() { blurRegion.changed() }
                function onWidthChanged() { blurRegion.changed() }
                function onHeightChanged() { blurRegion.changed() }
            }
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true


            // Keyboard
            Shortcut { sequence: "Escape"; onActivated: controller.closeWithAnimation() }
            Shortcut { sequence: "Return"; onActivated: controller.launchSelected() }
            Shortcut { sequence: "Enter"; onActivated: controller.launchSelected() }
            Shortcut { sequence: "Tab"; onActivated: controller.nextCategory() }
            Shortcut { sequence: "Shift+Tab"; onActivated: controller.prevCategory() }

            Shortcut { sequence: "Left"; onActivated: controller.moveLeft() }
            Shortcut { sequence: "Right"; onActivated: controller.moveRight() }
            Shortcut { sequence: "Up"; onActivated: controller.moveUp() }
            Shortcut { sequence: "Down"; onActivated: controller.moveDown() }

            MouseArea {
                anchors.fill: parent
                onClicked: controller.closeWithAnimation()
            }

            // Shadow container to provide margins for shadow rendering and prevent clipping artifacts
            Item {
                id: shadowContainer
                anchors.top: controller.anchorTop ? parent.top : undefined
                anchors.bottom: controller.anchorBottom ? parent.bottom : undefined
                anchors.left: controller.anchorLeft ? parent.left : undefined
                anchors.right: controller.anchorRight ? parent.right : undefined
                anchors.horizontalCenter: controller.anchorHCenter ? parent.horizontalCenter : undefined
                anchors.verticalCenter: controller.anchorVCenter ? parent.verticalCenter : undefined
                anchors.topMargin: controller.anchorTop ? controller.marginT - 40 : 0
                anchors.bottomMargin: controller.anchorBottom ? controller.marginB - 40 : 0
                anchors.leftMargin: controller.anchorLeft ? controller.marginL - 40 : 0
                anchors.rightMargin: controller.anchorRight ? controller.marginR - 40 : 0
                width: 720 + 80
                height: 660 + 80
                opacity: controller.containerOpacity

                // 高级光影
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 1.0
                    shadowVerticalOffset: 18
                }

                // Main container
                Rectangle {
                    id: mainContainer
                    anchors.centerIn: parent
                    width: 720
                    height: 660
                    color: Theme.alpha(Theme.background, 0.28)
                    radius: Theme.radiusXL + 4
                    border.color: Theme.glassBorder
                    border.width: 1.5

                    // 玻璃内描边
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.glassHighlight
                        z: 10
                    }

                    // Aurora 装饰球
                    AuroraBackground {
                        anchors.fill: parent
                        intensity: 0.28
                        orbScale: 1.6
                        z: 0
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

                    // Header row — Hero
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        // Hero search box
                        Rectangle {
                            id: searchBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            radius: 30
                            color: Theme.alpha(Theme.surface, 0.38)
                            border.color: searchInput.activeFocus ? Theme.primary : Theme.glassBorder
                            border.width: searchInput.activeFocus ? 2 : 1

                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.width { NumberAnimation { duration: Theme.animFast } }

                            // 聚焦发光
                            layer.enabled: searchInput.activeFocus && controller.searchText !== ""
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Theme.alpha(Theme.primary, 0.55)
                                shadowBlur: 1.0
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                                shadowOpacity: 0.75
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingL
                                anchors.rightMargin: Theme.spacingL
                                spacing: Theme.spacingM

                                Text {
                                    text: "\uf002"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 22
                                    color: searchInput.activeFocus ? Theme.primary : Theme.textMuted
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 20
                                    font.weight: Font.Medium
                                    color: Theme.textPrimary
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    focus: true
                                    activeFocusOnTab: true
                                    inputMethodHints: Qt.ImhNone
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
                                                controller.launchSelected()
                                                event.accepted = true
                                                break
                                            case Qt.Key_Escape:
                                                controller.closeWithAnimation()
                                                event.accepted = true
                                                break
                                            case Qt.Key_Tab:
                                                controller.nextCategory()
                                                event.accepted = true
                                                break
                                            case Qt.Key_Backtab:
                                                controller.prevCategory()
                                                event.accepted = true
                                                break
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: controller.i18nContext.trLiteral("搜索应用...")
                                        font.pixelSize: 20
                                        font.weight: Font.Medium
                                        color: Theme.textMuted
                                        visible: !searchInput.text
                                        opacity: 0.7
                                    }
                                }

                                Rectangle {
                                    visible: controller.searchText !== ""
                                    Layout.preferredWidth: countText.implicitWidth + Theme.spacingM
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: Theme.alpha(Theme.primary, 0.2)
                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: controller.filteredApps.length + controller.i18nContext.trLiteral(" 个")
                                        font.pixelSize: Theme.fontSizeS
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                    }
                                }
                            }
                        }

                    }

                    // Category bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Theme.radiusL
                        color: Theme.alpha(Theme.surface, 0.38)
                        border.color: Theme.outline
                        border.width: 1

                        Flickable {
                            id: categoryFlickable
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            clip: true
                            contentWidth: Math.max(width, categoryRow.implicitWidth)
                            contentHeight: height
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentWidth > width

                            ScrollBar.horizontal: ScrollBar {
                                policy: categoryFlickable.contentWidth > categoryFlickable.width
                                    ? ScrollBar.AsNeeded
                                    : ScrollBar.AlwaysOff
                                height: 4
                            }

                            RowLayout {
                                id: categoryRow
                                height: categoryFlickable.height
                                width: implicitWidth
                                spacing: Theme.spacingXS

                                Repeater {
                                    model: controller.categories

                                    Rectangle {
                                        id: catBtn
                                        required property var modelData
                                        required property int index

                                        Layout.fillHeight: true
                                        Layout.preferredWidth: catContent.implicitWidth + Theme.spacingS * 2
                                        radius: Theme.radiusM
                                        color: controller.selectedCategory === modelData.id
                                            ? Theme.primary
                                            : (catHover.hovered ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent")
                                        scale: catHover.hovered ? 1.05 : 1.0

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                        HoverHandler { id: catHover }
                                        TapHandler { onTapped: controller.selectedCategory = catBtn.modelData.id }

                                        RowLayout {
                                            id: catContent
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingXS

                                            Text {
                                                text: catBtn.modelData.icon
                                                font.family: "Symbols Nerd Font Mono"
                                                font.pixelSize: 12
                                                color: controller.selectedCategory === catBtn.modelData.id
                                                    ? "white" : Theme.textSecondary

                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            }

                                            Text {
                                                text: catBtn.modelData.name
                                                font.pixelSize: Theme.fontSizeS
                                                color: controller.selectedCategory === catBtn.modelData.id
                                                    ? "white" : Theme.textSecondary

                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // App grid
                    Flickable {
                        id: appFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: appFlow.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                        }

                        function ensureVisible() {
                            if (controller.filteredApps.length === 0) return
                            var row = Math.floor(controller.selectedIndex / controller.columnsPerRow)
                            var itemHeight = controller.itemSize + 24 + Theme.spacingS
                            var itemTop = row * itemHeight
                            var itemBottom = itemTop + itemHeight

                            if (itemTop < contentY) {
                                contentY = itemTop
                            } else if (itemBottom > contentY + height) {
                                contentY = itemBottom - height
                            }
                        }

                        Connections {
                            target: controller
                            function onSelectedIndexChanged() {
                                appFlickable.ensureVisible()
                            }
                        }

                        Flow {
                            id: appFlow
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: controller.columnsPerRow * controller.itemSize + (controller.columnsPerRow - 1) * spacing
                            spacing: Theme.spacingS

                            Binding {
                                target: controller
                                property: "columnsPerRow"
                                value: Math.max(1, Math.floor((appFlickable.width + appFlow.spacing) / (controller.itemSize + appFlow.spacing)))
                            }

                            Repeater {
                                model: controller.filteredApps

                                Rectangle {
                                    id: appItem
                                    required property var modelData
                                    required property int index

                                    width: controller.itemSize
                                    height: controller.itemSize + 24
                                    radius: Theme.radiusL
                                    color: index === controller.selectedIndex
                                        ? Theme.alpha(Theme.primary, 0.15)
                                        : (appHover.hovered ? Theme.alpha(Theme.textPrimary, 0.08) : "transparent")

                                    // 图标立即显示
                                    opacity: 1
                                    scale: 1.0

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    // 悬停缩放效果
                                    property real hoverScale: appHover.hovered && index !== controller.selectedIndex ? 1.05 : 1.0
                                    Behavior on hoverScale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                    HoverHandler { id: appHover }
                                    TapHandler {
                                        onTapped: {
                                            // 点击弹跳动画
                                            clickBounce.start()
                                            controller.launchApp(appItem.modelData)
                                        }
                                    }

                                    SequentialAnimation {
                                        id: clickBounce
                                        NumberAnimation { target: appItem; property: "scale"; to: 0.92; duration: 50; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: appItem; property: "scale"; to: 1.0; duration: 80; easing.type: Easing.OutCubic }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS
                                        spacing: Theme.spacingXS

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: controller.iconSize
                                            height: controller.iconSize
                                            scale: appItem.hoverScale

                                            Image {
                                                id: iconImg
                                                anchors.fill: parent
                                                source: appItem.modelData._iconSource || ""
                                                sourceSize: Qt.size(controller.iconSize, controller.iconSize)
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true
                                                visible: status === Image.Ready

                                                // 图标加载淡入
                                                opacity: status === Image.Ready ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                            }

                                            Rectangle {
                                                visible: iconImg.status !== Image.Ready
                                                anchors.fill: parent
                                                radius: Theme.radiusM
                                                color: Theme.surfaceVariant

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf135"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 28
                                                    color: Theme.textMuted
                                                }
                                            }

                                            Rectangle {
                                                id: wineBadge
                                                visible: appItem.modelData._isWine
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right
                                                anchors.bottomMargin: -5
                                                anchors.rightMargin: -12
                                                width: wineBadgeText.implicitWidth + 14
                                                height: 20
                                                radius: 10
                                                color: appHover.hovered ? Theme.warning : Theme.alpha(Theme.warning, 0.92)
                                                border.color: Theme.alpha(Theme.background, 0.95)
                                                border.width: 2
                                                scale: appHover.hovered ? 1.08 : 1.0
                                                z: 3

                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    shadowEnabled: true
                                                    shadowColor: Theme.alpha("#000000", 0.24)
                                                    shadowBlur: 0.55
                                                    shadowVerticalOffset: 2
                                                }

                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                                Text {
                                                    id: wineBadgeText
                                                    anchors.centerIn: parent
                                                    text: "WINE"
                                                    font.pixelSize: 9
                                                    font.weight: Font.Bold
                                                    color: "white"
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            text: appItem.modelData.name
                                            font.pixelSize: Theme.fontSizeS
                                            color: Theme.textPrimary
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignTop
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        }
                                    }

                                    // 选中边框
                                    Rectangle {
                                        visible: appItem.index === controller.selectedIndex
                                        anchors.fill: parent
                                        radius: Theme.radiusL
                                        color: "transparent"
                                        border.color: Theme.primary
                                        border.width: 2

                                        // 选中时的脉冲效果 (更快更微妙)
                                        opacity: 1
                                        SequentialAnimation on opacity {
                                            running: appItem.index === controller.selectedIndex
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.7; duration: 500; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    ToolTip {
                                        id: appDetailsToolTip
                                        visible: appHover.hovered
                                        delay: 1000
                                        timeout: -1
                                        padding: Theme.spacingM

                                        contentItem: ColumnLayout {
                                            spacing: Theme.spacingS

                                            RowLayout {
                                                Layout.preferredWidth: 300
                                                spacing: Theme.spacingS

                                                Rectangle {
                                                    Layout.preferredWidth: 3
                                                    Layout.preferredHeight: 26
                                                    radius: 2
                                                    color: appItem.modelData._isWine ? Theme.warning : Theme.primary
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: appItem.modelData.name || controller.i18nContext.trLiteral("未知应用")
                                                    font.pixelSize: Theme.fontSizeL
                                                    font.weight: Font.DemiBold
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    visible: appItem.modelData._isWine
                                                    Layout.preferredWidth: wineTooltipText.implicitWidth + 12
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: Theme.alpha(Theme.warning, 0.16)
                                                    border.color: Theme.alpha(Theme.warning, 0.45)
                                                    border.width: 1

                                                    Text {
                                                        id: wineTooltipText
                                                        anchors.centerIn: parent
                                                        text: "WINE"
                                                        font.pixelSize: Theme.fontSizeXS
                                                        font.weight: Font.Bold
                                                        color: Theme.warning
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 300
                                                Layout.preferredHeight: 1
                                                color: Theme.alpha(appItem.modelData._isWine ? Theme.warning : Theme.primary, 0.18)
                                            }

                                            Text {
                                                Layout.preferredWidth: 300
                                                text: controller.appDetailBodyText(appItem.modelData)
                                                font.pixelSize: Theme.fontSizeS
                                                color: Theme.textSecondary
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                lineHeight: 1.18
                                                lineHeightMode: Text.ProportionalHeight
                                            }
                                        }

                                        background: Rectangle {
                                            radius: Theme.radiusL
                                            color: Theme.alpha(Theme.surface, 0.74)
                                            border.color: Theme.alpha(appItem.modelData._isWine ? Theme.warning : Theme.primary, 0.32)
                                            border.width: 1

                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                shadowEnabled: true
                                                shadowColor: Theme.alpha("#000000", 0.24)
                                                shadowBlur: 0.85
                                                shadowVerticalOffset: 8
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // Hints
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: controller.i18nContext.trLiteral("Enter 启动 | Tab 切换分类 | 方向键 导航 | Esc 关闭")
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
}


