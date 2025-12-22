import QtQuick
import QtQuick.Layouts
import "colors.js" as Colors

Rectangle {
    id: item
    
    property string name: ""
    property string mac: ""
    property bool paired: false
    property bool connected: false
    
    signal connectRequested()
    signal disconnectRequested()
    signal removeRequested()
    signal rightClicked()
    
    height: 52
    radius: 10
    color: itemMouse.containsMouse ? Colors.surface0 : (connected ? Colors.surface0 : "transparent")
    border.color: connected ? Colors.primary : "transparent"
    border.width: connected ? 1 : 0
    
    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        
        // 蓝牙设备图标
        Rectangle {
            width: 36
            height: 36
            radius: 8
            color: item.connected ? Colors.primary : Colors.surface1
            
            Text {
                anchors.centerIn: parent
                text: getDeviceIcon(item.name)
                font.family: "Symbols Nerd Font"
                font.pixelSize: 18
                color: item.connected ? Colors.base : Colors.text
            }
        }
        
        // 设备名称和MAC
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            
            Text {
                text: item.name || "未知设备"
                font.pixelSize: 13
                font.bold: item.connected
                color: Colors.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            
            RowLayout {
                spacing: 8
                
                Text {
                    text: item.mac
                    font.pixelSize: 10
                    color: Colors.overlay
                    font.family: "monospace"
                }
                
                // 已配对标签
                Rectangle {
                    visible: item.paired && !item.connected
                    width: pairedText.implicitWidth + 8
                    height: 16
                    radius: 4
                    color: Colors.surface0
                    
                    Text {
                        id: pairedText
                        anchors.centerIn: parent
                        text: "已配对"
                        font.pixelSize: 9
                        color: Colors.subtext
                    }
                }
                
                // 已连接标签
                Rectangle {
                    visible: item.connected
                    width: connectedText.implicitWidth + 8
                    height: 16
                    radius: 4
                    color: Colors.primary
                    
                    Text {
                        id: connectedText
                        anchors.centerIn: parent
                        text: "已连接"
                        font.pixelSize: 9
                        color: Colors.base
                    }
                }
            }
        }
        
        // 移除按钮 (仅已配对但未连接)
        Rectangle {
            visible: item.paired && !item.connected
            width: 28
            height: 28
            radius: 6
            color: removeBtnMouse.containsMouse ? Colors.tertiary : Colors.surface1
            
            Text {
                anchors.centerIn: parent
                text: "󰆴"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: removeBtnMouse.containsMouse ? Colors.base : Colors.text
            }
            
            MouseArea {
                id: removeBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: item.removeRequested()
            }
        }
        
        // 断开按钮 (仅已连接)
        Rectangle {
            visible: item.connected
            width: 28
            height: 28
            radius: 6
            color: disconnectBtnMouse.containsMouse ? Colors.red : Colors.surface1
            
            Text {
                anchors.centerIn: parent
                text: "󰂲"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: disconnectBtnMouse.containsMouse ? Colors.base : Colors.text
            }
            
            MouseArea {
                id: disconnectBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: item.disconnectRequested()
            }
        }
    }
    
    MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: item.connected ? Qt.ArrowCursor : Qt.PointingHandCursor
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                item.rightClicked()
            } else if (!item.connected) {
                item.connectRequested()
            }
        }
    }
    
    // 根据设备名猜测图标
    function getDeviceIcon(deviceName) {
        let name = deviceName.toLowerCase()
        if (name.includes("airpods") || name.includes("buds") || name.includes("earphone") || name.includes("headphone") || name.includes("earbuds")) {
            return "󰋋"  // 耳机
        }
        if (name.includes("headset") || name.includes("speaker") || name.includes("soundbar") || name.includes("audio")) {
            return "󰓃"  // 音箱
        }
        if (name.includes("keyboard") || name.includes("k380") || name.includes("k580")) {
            return "󰌌"  // 键盘
        }
        if (name.includes("mouse") || name.includes("mx master") || name.includes("m720")) {
            return "󰍽"  // 鼠标
        }
        if (name.includes("controller") || name.includes("gamepad") || name.includes("xbox") || name.includes("playstation") || name.includes("dualsense")) {
            return "󰖺"  // 游戏手柄
        }
        if (name.includes("phone") || name.includes("iphone") || name.includes("galaxy") || name.includes("pixel") || name.includes("xiaomi") || name.includes("redmi")) {
            return "󰏲"  // 手机
        }
        if (name.includes("watch") || name.includes("band") || name.includes("miband")) {
            return "󰖉"  // 手表
        }
        if (name.includes("tablet") || name.includes("ipad")) {
            return "󰓶"  // 平板
        }
        return "󰂯"  // 默认蓝牙图标
    }
}
