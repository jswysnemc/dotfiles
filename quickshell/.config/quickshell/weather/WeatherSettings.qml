import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

Rectangle {
    id: settingsRoot

    // ============ 属性声明 ============
    required property var controller

    // ============ 基础样式 ============
    visible: controller.showSettings
    anchors.fill: parent
    color: Theme.alpha(Theme.background, 0.42)
    radius: parent.radius
    z: 40

    // ============ 动画控制 ============
    opacity: controller.showSettings ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }

    // ============ 垂直布局 ============
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingL

        // ------------ 顶部标题栏 ------------
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: settingsRoot.controller.i18nContext.trLiteral("位置设置")
                font.pixelSize: Theme.fontSizeL
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
            
            // 关闭按钮
            Rectangle {
                width: 28; height: 28; radius: 14
                color: closeSetMa.containsMouse ? Theme.surfaceVariant : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 14
                    color: Theme.textSecondary
                }
                
                MouseArea {
                    id: closeSetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        settingsRoot.controller.showSettings = false
                        settingsRoot.controller.searchResults = []
                    }
                }
            }
        }

        // 分割线
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

        // ------------ 当前定位展示 ------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 16; color: Theme.primary }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: settingsRoot.controller.i18nContext.trLiteral("当前位置"); font.pixelSize: Theme.fontSizeXS; color: Theme.textMuted }
                Text { text: settingsRoot.controller.locationName; font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
            }
        }

        // ------------ 自动定位按钮卡片 ------------
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: Theme.radiusM
            color: autoLocMa.containsMouse ? Theme.surfaceVariant : Theme.surface
            border.color: Theme.outline
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                Text {
                    text: settingsRoot.controller.locating ? "" : ""
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 14
                    color: Theme.primary
                    
                    RotationAnimation on rotation {
                        running: settingsRoot.controller.locating
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
                Text {
                    text: settingsRoot.controller.locating ? settingsRoot.controller.i18nContext.trLiteral("定位中...") : settingsRoot.controller.i18nContext.trLiteral("自动定位")
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.textPrimary
                }
            }
            MouseArea {
                id: autoLocMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // 1. 触发自动定位脚本指令
                    if (!settingsRoot.controller.locating) settingsRoot.controller.geolocate()
                }
            }
        }

        // 分割线
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

        // ------------ 搜索城市排版 ------------
        Text { text: settingsRoot.controller.i18nContext.trLiteral("搜索城市"); font.pixelSize: Theme.fontSizeS; color: Theme.textMuted }

        // 输入框卡片
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: Theme.radiusM
            color: Theme.surface
            border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
            border.width: searchInput.activeFocus ? 2 : 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS
                Text {
                    text: settingsRoot.controller.searching ? "" : ""
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 14
                    color: Theme.textMuted
                    
                    RotationAnimation on rotation {
                        running: settingsRoot.controller.searching
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.textPrimary
                    clip: true
                    onTextChanged: {
                        // 2. 将输入的文本同步至 controller，并触发搜索防抖 Timer
                        settingsRoot.controller.searchQuery = text
                        searchTimer.restart()
                    }
                    Text {
                        anchors.fill: parent
                        text: settingsRoot.controller.i18nContext.trLiteral("输入城市名称...")
                        font.pixelSize: Theme.fontSizeM
                        color: Theme.textMuted
                        visible: !searchInput.text
                    }
                }
            }
        }

        // 搜索防抖定时器
        Timer {
            id: searchTimer
            interval: 500
            onTriggered: {
                // 3. 执行城市搜索 API
                settingsRoot.controller.searchLocation(settingsRoot.controller.searchQuery)
            }
        }

        // ------------ 城市搜索结果 Flickable 列表 ------------
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: resultsCol.implicitHeight
            clip: true

            ColumnLayout {
                id: resultsCol
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: settingsRoot.controller.searchResults

                    Rectangle {
                        Layout.fillWidth: true
                        height: 50
                        radius: Theme.radiusM
                        color: resultMa.containsMouse ? Theme.surfaceVariant : Theme.surface
                        border.color: Theme.outline
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM
                            Text { text: ""; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: Theme.textMuted }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: modelData.name; font.pixelSize: Theme.fontSizeM; color: Theme.textPrimary }
                                Text {
                                    text: (modelData.admin1 || "") + (modelData.country ? ", " + modelData.country : "")
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.textMuted
                                    visible: text !== ""
                                }
                            }
                        }
                        MouseArea {
                            id: resultMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // 4. 选择当前城市，更新位置并关闭设置栏
                                settingsRoot.controller.selectLocation(modelData)
                            }
                        }
                    }
                }

                Text {
                    visible: settingsRoot.controller.searchResults.length === 0 && settingsRoot.controller.searchQuery.length >= 2 && !settingsRoot.controller.searching
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.spacingL
                    text: settingsRoot.controller.i18nContext.trLiteral("未找到结果")
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.textMuted
                }
            }
        }
    }
}
