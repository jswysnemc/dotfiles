import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "colors.js" as Colors

PanelWindow {
    id: popup
    
    // 全屏覆盖用于点击外部关闭
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    visible: true
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bluetooth-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    // 点击外部关闭
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    
    // 主弹窗
    Rectangle {
        id: background
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 40
        anchors.rightMargin: 120  // 蓝牙图标位置略有不同
        width: 360
        height: contentColumn.implicitHeight + 32
        color: Colors.base
        radius: 16
        border.color: Colors.surface1
        border.width: 1
        
        // 阻止点击穿透
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            // 头部
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // 蓝牙图标
                Text {
                    text: btManager.powered ? "󰂯" : "󰂲"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 24
                    color: btManager.powered ? Colors.primary : Colors.overlay
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        text: btManager.connectedDevice || (btManager.powered ? "蓝牙" : "蓝牙已关闭")
                        font.pixelSize: 14
                        font.bold: true
                        color: Colors.text
                    }
                    
                    Text {
                        text: btManager.connectedDevice ? "已连接" : 
                              (btManager.powered ? "未连接设备" : "点击开启蓝牙")
                        font.pixelSize: 11
                        color: Colors.subtext
                    }
                }
                
                // 电源开关
                Rectangle {
                    width: 44
                    height: 24
                    radius: 12
                    color: btManager.powered ? Colors.primary : Colors.surface1
                    
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: Colors.text
                        x: btManager.powered ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Behavior on x {
                            NumberAnimation { duration: 150 }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btManager.setPower(!btManager.powered)
                    }
                }
                
                // 扫描按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: scanMouse.containsMouse ? Colors.surface1 : "transparent"
                    visible: btManager.powered
                    
                    Text {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "󰑓"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: Colors.primary
                        
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: btManager.scanning
                        }
                    }
                    
                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btManager.startScan()
                    }
                }
                
                // 关闭按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: closeMouse.containsMouse ? Colors.red : Colors.surface1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: closeMouse.containsMouse ? Colors.base : Colors.text
                    }
                    
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }
            }
            
            // 分割线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.surface1
                visible: btManager.powered
            }
            
            // 设备列表 (仅在蓝牙开启时显示)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: btManager.powered
                
                // 已配对设备标题
                Text {
                    text: "我的设备"
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.subtext
                    visible: btManager.pairedDevices.length > 0
                }
                
                // 已配对设备列表
                ListView {
                    id: pairedList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 180)
                    clip: true
                    spacing: 4
                    visible: btManager.pairedDevices.length > 0
                    
                    model: btManager.pairedDevices
                    
                    delegate: BluetoothListItem {
                        width: pairedList.width
                        name: modelData.name
                        mac: modelData.mac
                        paired: true
                        connected: modelData.mac === btManager.connectedDeviceMac
                        onConnectRequested: btManager.connectDevice(modelData.mac, modelData.name)
                        onDisconnectRequested: btManager.disconnectDevice(modelData.mac)
                        onRemoveRequested: btManager.removeDevice(modelData.mac)
                        onRightClicked: {
                            contextMenu.targetMac = modelData.mac
                            contextMenu.targetName = modelData.name
                            contextMenu.isPaired = true
                            contextMenu.isConnected = modelData.mac === btManager.connectedDeviceMac
                            contextMenu.visible = true
                        }
                    }
                }
                
                // 可用设备标题
                Text {
                    text: btManager.scanning ? "正在扫描..." : "可用设备"
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.subtext
                    Layout.topMargin: 8
                }
                
                // 可用设备列表 (排除已配对的)
                ListView {
                    id: availableList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 200)
                    clip: true
                    spacing: 4
                    
                    model: btManager.availableDevices.filter(d => !d.paired)
                    
                    delegate: BluetoothListItem {
                        width: availableList.width
                        name: modelData.name
                        mac: modelData.mac
                        paired: false
                        connected: false
                        onConnectRequested: {
                            btManager.trustDevice(modelData.mac)
                            btManager.pairDevice(modelData.mac)
                        }
                        onRightClicked: {
                            contextMenu.targetMac = modelData.mac
                            contextMenu.targetName = modelData.name
                            contextMenu.isPaired = false
                            contextMenu.isConnected = false
                            contextMenu.visible = true
                        }
                    }
                    
                    // 空状态
                    Text {
                        anchors.centerIn: parent
                        text: btManager.scanning ? "搜索中..." : "点击刷新按钮扫描设备"
                        font.pixelSize: 12
                        color: Colors.overlay
                        visible: availableList.count === 0
                    }
                }
            }
            
            // 蓝牙关闭时的提示
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                visible: !btManager.powered
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰂲"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 48
                    color: Colors.overlay
                }
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "蓝牙已关闭"
                    font.pixelSize: 14
                    color: Colors.subtext
                }
                
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 120
                    height: 36
                    radius: 8
                    color: powerOnMouse.containsMouse ? Colors.primary : Colors.primary
                    
                    Text {
                        anchors.centerIn: parent
                        text: "开启蓝牙"
                        font.pixelSize: 13
                        font.bold: true
                        color: Colors.base
                    }
                    
                    MouseArea {
                        id: powerOnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btManager.setPower(true)
                    }
                }
            }
        }
    }
    
    // 右键菜单
    Rectangle {
        id: contextMenu
        anchors.fill: parent
        color: "#80000000"
        visible: false
        radius: 16
        
        property string targetMac: ""
        property string targetName: ""
        property bool isPaired: false
        property bool isConnected: false
        
        MouseArea {
            anchors.fill: parent
            onClicked: contextMenu.visible = false
        }
        
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 40
            anchors.rightMargin: 120
            width: 280
            height: menuColumn.implicitHeight + 32
            color: Colors.base
            radius: 12
            border.color: Colors.surface1
            border.width: 1
            
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            
            ColumnLayout {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                // 头部
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "󰂯"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                        color: Colors.primary
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: contextMenu.targetName
                            font.pixelSize: 14
                            font.bold: true
                            color: Colors.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            text: contextMenu.targetMac
                            font.pixelSize: 10
                            color: Colors.overlay
                            font.family: "monospace"
                        }
                    }
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: menuCloseMouse.containsMouse ? Colors.surface1 : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 10
                            color: Colors.text
                        }
                        
                        MouseArea {
                            id: menuCloseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: contextMenu.visible = false
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.surface1
                }
                
                // 状态信息
                RowLayout {
                    spacing: 8
                    Text {
                        text: "状态:"
                        font.pixelSize: 12
                        color: Colors.subtext
                    }
                    Text {
                        text: contextMenu.isConnected ? "已连接" : 
                              contextMenu.isPaired ? "已配对" : "未配对"
                        font.pixelSize: 12
                        font.bold: true
                        color: contextMenu.isConnected ? Colors.green : 
                               contextMenu.isPaired ? Colors.primary : Colors.overlay
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.surface1
                }
                
                // 操作按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    // 连接/断开按钮
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: menuConnectMouse.containsMouse ? 
                               (contextMenu.isConnected ? Colors.red : Colors.primary) : 
                               (contextMenu.isConnected ? Colors.surface1 : Colors.primary)
                        
                        Text {
                            anchors.centerIn: parent
                            text: contextMenu.isConnected ? "断开" : 
                                  contextMenu.isPaired ? "连接" : "配对"
                            font.pixelSize: 13
                            font.bold: true
                            color: contextMenu.isConnected ? Colors.text : Colors.base
                        }
                        
                        MouseArea {
                            id: menuConnectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (contextMenu.isConnected) {
                                    btManager.disconnectDevice(contextMenu.targetMac)
                                } else if (contextMenu.isPaired) {
                                    btManager.connectDevice(contextMenu.targetMac, contextMenu.targetName)
                                } else {
                                    btManager.trustDevice(contextMenu.targetMac)
                                    btManager.pairDevice(contextMenu.targetMac)
                                }
                                contextMenu.visible = false
                            }
                        }
                    }
                    
                    // 移除按钮 (仅已配对)
                    Rectangle {
                        visible: contextMenu.isPaired
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: menuRemoveMouse.containsMouse ? Colors.tertiary : Colors.surface1
                        
                        Text {
                            anchors.centerIn: parent
                            text: "移除设备"
                            font.pixelSize: 13
                            color: menuRemoveMouse.containsMouse ? Colors.base : Colors.text
                        }
                        
                        MouseArea {
                            id: menuRemoveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                btManager.removeDevice(contextMenu.targetMac)
                                contextMenu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 蓝牙管理器
    BluetoothManager {
        id: btManager
    }
}
