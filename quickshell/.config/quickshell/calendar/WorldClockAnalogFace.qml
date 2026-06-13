import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "./Theme.js" as Theme

Item {
    id: faceRoot

    // ============ 属性声明 ============
    required property var currentTime

    // ============ 物理尺寸 ============
    width: 72
    height: 72

    // ============ 表盘背景盘 ============
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.alpha(Theme.surface, 0.35)
        border.color: Theme.alpha(Theme.outline, 0.55)
        border.width: 1

        // 1. 12点钟方向极简刻度点
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.spacingXS
            width: 3; height: 3; radius: 1.5
            color: Theme.textMuted
        }

        // 2. 3点钟方向极简刻度点
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Theme.spacingXS
            width: 3; height: 3; radius: 1.5
            color: Theme.textMuted
        }

        // 3. 6点钟方向极简刻度点
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: Theme.spacingXS
            width: 3; height: 3; radius: 1.5
            color: Theme.textMuted
        }

        // 4. 9点钟方向极简刻度点
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingXS
            width: 3; height: 3; radius: 1.5
            color: Theme.textMuted
        }
    }

    // ============ 指针轴心 ============
    Rectangle {
        anchors.centerIn: parent
        width: 6; height: 6; radius: 3
        color: Theme.primary
        z: 10
    }

    // ============ 时针 ============
    Rectangle {
        id: hourHand
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: 3.5
        height: 18
        radius: 2
        color: Theme.textPrimary
        antialiasing: true
        
        // 5. 时针旋转，包含分钟偏移量的复合物理换算
        transform: Rotation {
            origin.x: hourHand.width / 2
            origin.y: hourHand.height
            angle: {
                var hours = faceRoot.currentTime.getHours()
                var mins = faceRoot.currentTime.getMinutes()
                return (hours % 12) * 30 + mins * 0.5
            }
        }
    }

    // ============ 分针 ============
    Rectangle {
        id: minuteHand
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: 2.2
        height: 25
        radius: 1.5
        color: Theme.textSecondary
        antialiasing: true

        // 6. 分针旋转，包含秒级偏移量的复合物理换算
        transform: Rotation {
            origin.x: minuteHand.width / 2
            origin.y: minuteHand.height
            angle: {
                var mins = faceRoot.currentTime.getMinutes()
                var secs = faceRoot.currentTime.getSeconds()
                return mins * 6 + secs * 0.1
            }
        }
    }

    // ============ 秒针 ============
    Rectangle {
        id: secondHand
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: -6 // 秒针尾部突出以平衡视觉重量
        width: 1.2
        height: 31
        color: Theme.tertiary
        antialiasing: true

        // 7. 秒针旋转，包含毫秒极高频更新以构建平滑扫针（Sweeping Hand）
        transform: Rotation {
            origin.x: secondHand.width / 2
            origin.y: secondHand.height - 6
            angle: {
                var secs = faceRoot.currentTime.getSeconds()
                var ms = faceRoot.currentTime.getMilliseconds()
                return secs * 6 + ms * 0.006
            }
        }
    }
}
