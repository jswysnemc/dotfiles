import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

Item {
    id: overlayRoot

    // ============ 属性声明 ============
    required property bool confirmMode
    required property string confirmAction
    required property var actions
    required property string confirmTitleText
    required property string cancelBtnText
    required property string confirmBtnText

    // ============ 信号声明 ============
    signal cancel()
    signal confirmed(string actionId)

    // ============ 提取激活状态的动作数据 ============
    readonly property var activeAction: actions.find(a => a.id === confirmAction)

    anchors.fill: parent
    visible: confirmMode || opacity > 0
    opacity: confirmMode ? 1.0 : 0.0
    z: 30

    // 1. 全局渐入渐出动画
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }

    // 2. visionOS 风的横向微滑移动效：激活时向左滑入，隐藏时向右退回
    transform: Translate {
        x: overlayRoot.confirmMode ? 0 : 20
        Behavior on x {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    // ============ 背景遮罩 ============
    Rectangle {
        anchors.fill: parent
        radius: parent.parent ? parent.parent.radius : 0
        color: Theme.alpha(Theme.background, 0.72)
    }

    // ============ 横向两端对齐布局 ============
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXL + 8
        anchors.rightMargin: Theme.spacingXL + 8
        spacing: Theme.spacingL

        // ------------ 左侧部分：动作大图标 + 提示文字 ------------
        RowLayout {
            spacing: Theme.spacingM
            Layout.alignment: Qt.AlignVCenter

            // 图标容器
            Rectangle {
                width: 60
                height: 60
                radius: width / 2
                color: overlayRoot.activeAction ? Theme.alpha(overlayRoot.activeAction.color, 0.16) : Theme.alpha(Theme.error, 0.16)
                border.width: 1.5
                border.color: overlayRoot.activeAction ? overlayRoot.activeAction.color : Theme.error

                // 3. 苹果风彩色阴影渗透
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: overlayRoot.activeAction ? Theme.alpha(overlayRoot.activeAction.color, 0.5) : Theme.alpha(Theme.error, 0.5)
                    shadowBlur: 0.85
                    shadowVerticalOffset: 0
                    shadowOpacity: 0.7
                }

                Text {
                    anchors.centerIn: parent
                    text: overlayRoot.activeAction ? overlayRoot.activeAction.icon : ""
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 28
                    color: overlayRoot.activeAction ? overlayRoot.activeAction.color : Theme.error
                }
            }

            // 询问文本
            ColumnLayout {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: overlayRoot.confirmTitleText
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.textMuted
                }

                Text {
                    text: overlayRoot.activeAction ? overlayRoot.activeAction.name : ""
                    font.pixelSize: Theme.fontSizeXL
                    font.weight: Font.Black
                    color: overlayRoot.activeAction ? overlayRoot.activeAction.color : Theme.error
                }
            }
        }

        // ------------ 中间弹性缓冲区 ------------
        Item {
            Layout.fillWidth: true
        }

        // ------------ 右侧部分：取消与确定药丸按钮 ------------
        RowLayout {
            spacing: Theme.spacingM
            Layout.alignment: Qt.AlignVCenter

            // 取消按钮
            Rectangle {
                id: cancelBtn
                width: 100
                height: 42
                radius: Theme.radiusPill
                
                color: cancelHover.hovered ? Theme.alpha(Theme.surfaceVariant, 0.6) : Theme.alpha(Theme.surface, 0.45)
                border.color: Theme.alpha(Theme.outline, 0.6)
                border.width: 1
                
                scale: cancelTap.pressed ? 0.95 : (cancelHover.hovered ? 1.04 : 1.0)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: overlayRoot.cancelBtnText
                    font.pixelSize: Theme.fontSizeM
                    font.bold: true
                    color: Theme.textSecondary
                }

                HoverHandler { id: cancelHover }
                TapHandler { id: cancelTap; onTapped: overlayRoot.cancel() }
            }

            // 确定按钮
            Rectangle {
                id: confirmBtn
                width: 100
                height: 42
                radius: Theme.radiusPill
                
                color: overlayRoot.activeAction ? (confirmHover.hovered ? Theme.alpha(overlayRoot.activeAction.color, 0.85) : overlayRoot.activeAction.color) : Theme.error
                scale: confirmTap.pressed ? 0.95 : (confirmHover.hovered ? 1.04 : 1.0)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: overlayRoot.activeAction ? Theme.alpha(overlayRoot.activeAction.color, 0.5) : Theme.alpha(Theme.error, 0.5)
                    shadowBlur: 0.9
                    shadowVerticalOffset: 3
                    shadowOpacity: 0.75
                }

                Text {
                    anchors.centerIn: parent
                    text: overlayRoot.confirmBtnText
                    font.pixelSize: Theme.fontSizeM
                    font.bold: true
                    color: "#ffffff"
                }

                HoverHandler { id: confirmHover }
                TapHandler { id: confirmTap; onTapped: if (overlayRoot.activeAction) overlayRoot.confirmed(overlayRoot.activeAction.id) }
            }
        }
    }
}
