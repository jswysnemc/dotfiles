import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

Item {
    id: cardRoot

    // ============ 属性声明 ============
    required property var modelData
    required property int index
    required property int selectedIndex

    // ============ 状态计算 ============
    readonly property bool isSelected: selectedIndex === index

    // ============ 信号声明 ============
    signal tapped(string actionId)
    signal hovered(int idx)

    // ============ 基础物理尺寸 ============
    readonly property int cardWidth: 88
    readonly property int cardHeight: 96
    readonly property int cardRadius: 16

    width: cardWidth
    height: cardHeight

    // 1. 3D 浮动偏移量计算：选中时向上抬升 6px，悬浮时抬升 3px
    readonly property real yOffset: isSelected ? -6 : (cardHover.hovered ? -3 : 0)

    // ============ 交错滑入动画组件 ============
    opacity: 0
    transform: Translate {
        id: enterTranslate
        x: -18
    }

    Component.onCompleted: {
        // 2. 挂载完成后延迟播放横向交错弹性滑入
        enterAnim.start()
    }

    SequentialAnimation {
        id: enterAnim
        // 3. 根据卡片索引产生时间差，形成多米诺骨牌式的扫掠感
        PauseAnimation { duration: 60 + index * 55 }
        ParallelAnimation {
            NumberAnimation { target: cardRoot; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: enterTranslate; property: "x"; to: 0; duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    // ============ 内部核心内容卡片 ============
    Rectangle {
        id: innerCard
        width: parent.width
        height: parent.height
        y: cardRoot.yOffset
        radius: cardRoot.cardRadius

        // 4. 内容区背景色：选中时与主题色微微浸润，非选中时呈现磨砂玻璃感
        color: isSelected ? Theme.alpha(modelData.color, 0.22) : Theme.alpha(Theme.surface, 0.35)
        border.color: isSelected ? modelData.color : Theme.alpha(Theme.outline, 0.4)
        border.width: isSelected ? 2 : 1

        Behavior on y {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.width { NumberAnimation { duration: Theme.animFast } }

        // ============ 苹果风 3D 阴影及色彩渗透效果 ============
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            // 5. 选中时发光投影变为卡片自身主题色，非选中时为常规暗色阴影
            shadowColor: cardRoot.isSelected ? Theme.alpha(modelData.color, 0.55) : Theme.shadowColor
            shadowBlur: cardRoot.isSelected ? 0.95 : 0.45
            shadowVerticalOffset: cardRoot.isSelected ? 6 : 2
            shadowOpacity: cardRoot.isSelected ? 0.85 : 0.3
            
            Behavior on shadowColor { ColorAnimation { duration: Theme.animFast } }
        }

        // ============ 垂直排版 ============
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            // ------------ Nerd Font 图标 ------------
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: modelData.icon
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 28
                color: cardRoot.isSelected ? "#ffffff" : modelData.color
                scale: cardRoot.isSelected ? 1.08 : 1.0

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            }

            // ------------ 动作文本标签 ------------
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: modelData.name
                font.pixelSize: Theme.fontSizeS
                font.weight: cardRoot.isSelected ? Font.Bold : Font.Normal
                color: cardRoot.isSelected ? "#ffffff" : Theme.textSecondary

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }
    }

    // ============ 交互事件捕获 ============
    HoverHandler {
        id: cardHover
        onHoveredChanged: {
            // 6. 悬浮时向主容器广播焦点卡片索引，实现平滑同步
            if (hovered) {
                cardRoot.hovered(index)
            }
        }
    }

    TapHandler {
        // 7. 触发点击反馈
        onTapped: cardRoot.tapped(modelData.id)
    }
}
