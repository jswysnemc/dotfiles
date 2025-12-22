import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "colors.js" as Colors

PanelWindow {
    id: popup
    
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    visible: true
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "control-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    
    ControlCenterManager {
        id: ccManager
    }
    
    CalendarManager {
        id: calendarManager
    }
    
    Rectangle {
        id: background
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 40
        anchors.rightMargin: 10
        width: 380
        height: Math.min(contentColumn.implicitHeight + 32, popup.height - 80)
        color: Colors.base
        radius: 16
        border.color: Colors.surface1
        border.width: 1
        
        MouseArea {
            anchors.fill: parent
            onClicked: {}
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    scrollView.contentY = Math.max(0, scrollView.contentY - 60)
                } else {
                    scrollView.contentY = Math.min(scrollView.contentHeight - scrollView.height, scrollView.contentY + 60)
                }
            }
        }
        
        Flickable {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: contentColumn.implicitHeight
            clip: true
            
            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: 16
                
                // ========== 音量控制 ==========
                Rectangle {
                    Layout.fillWidth: true
                    height: 70
                    radius: 12
                    color: Colors.surface0
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text {
                                text: ccManager.muted ? "󰝟" : (ccManager.volume > 50 ? "󰕾" : "󰖀")
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 20
                                color: ccManager.muted ? Colors.red : Colors.primary
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ccManager.toggleMute()
                                }
                            }
                            
                            Text {
                                text: "音量"
                                font.pixelSize: 13
                                color: Colors.text
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Text {
                                text: ccManager.volume + "%"
                                font.pixelSize: 13
                                color: Colors.subtext
                            }
                        }
                        
                        Slider {
                            id: volumeSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: ccManager.volume
                            
                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: 6
                                radius: 3
                                color: Colors.surface1
                                
                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: ccManager.muted ? Colors.red : Colors.primary
                                }
                            }
                            
                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: volumeSlider.pressed ? Colors.text : Colors.subtext
                            }
                            
                            onMoved: ccManager.setVolume(Math.round(value))
                        }
                    }
                }
                
                // ========== 亮度控制 ==========
                Rectangle {
                    Layout.fillWidth: true
                    height: 70
                    radius: 12
                    color: Colors.surface0
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text {
                                text: ccManager.getBrightnessPercent() > 50 ? "󰃠" : "󰃞"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 20
                                color: Colors.yellow
                            }
                            
                            Text {
                                text: "亮度"
                                font.pixelSize: 13
                                color: Colors.text
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Text {
                                text: ccManager.getBrightnessPercent() + "%"
                                font.pixelSize: 13
                                color: Colors.subtext
                            }
                        }
                        
                        Slider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            from: 1
                            to: ccManager.maxBrightness
                            value: ccManager.brightness
                            
                            background: Rectangle {
                                x: brightnessSlider.leftPadding
                                y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                width: brightnessSlider.availableWidth
                                height: 6
                                radius: 3
                                color: Colors.surface1
                                
                                Rectangle {
                                    width: brightnessSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: Colors.yellow
                                }
                            }
                            
                            handle: Rectangle {
                                x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                                y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: brightnessSlider.pressed ? Colors.text : Colors.subtext
                            }
                            
                            onMoved: ccManager.setBrightness(Math.round(value))
                        }
                    }
                }
                
                // ========== 快捷开关 ==========
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 8
                    columnSpacing: 8
                    
                    // WiFi
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        radius: 12
                        color: ccManager.wifiConnected ? Colors.surface1 : Colors.surface0
                        border.color: ccManager.wifiConnected ? Colors.primary : "transparent"
                        border.width: ccManager.wifiConnected ? 1 : 0
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: ccManager.wifiConnected ? "󰤨" : "󰤭"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 22
                                color: ccManager.wifiConnected ? Colors.primary : Colors.subtext
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "WiFi"
                                font.pixelSize: 10
                                color: Colors.subtext
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Qt.quit()
                                Qt.callLater(() => {
                                    // 打开WiFi面板
                                })
                            }
                        }
                    }
                    
                    // 蓝牙
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        radius: 12
                        color: ccManager.bluetoothPowered ? Colors.surface1 : Colors.surface0
                        border.color: ccManager.bluetoothPowered ? Colors.primary : "transparent"
                        border.width: ccManager.bluetoothPowered ? 1 : 0
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: ccManager.bluetoothDevice ? "󰂱" : (ccManager.bluetoothPowered ? "󰂯" : "󰂲")
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 22
                                color: ccManager.bluetoothPowered ? Colors.primary : Colors.subtext
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "蓝牙"
                                font.pixelSize: 10
                                color: Colors.subtext
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    
                    // 勿扰
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        radius: 12
                        color: ccManager.dndEnabled ? Colors.surface1 : Colors.surface0
                        border.color: ccManager.dndEnabled ? Colors.yellow : "transparent"
                        border.width: ccManager.dndEnabled ? 1 : 0
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰂛"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 22
                                color: ccManager.dndEnabled ? Colors.yellow : Colors.subtext
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "勿扰"
                                font.pixelSize: 10
                                color: Colors.subtext
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ccManager.toggleDnd()
                        }
                    }
                    
                    // 通知
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        radius: 12
                        color: ccManager.notificationCount > 0 ? Colors.surface1 : Colors.surface0
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: ccManager.notificationCount > 0 ? "󰂚" : "󰂜"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 22
                                color: ccManager.notificationCount > 0 ? Colors.primary : Colors.subtext
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: ccManager.notificationCount > 0 ? ccManager.notificationCount.toString() : "通知"
                                font.pixelSize: 10
                                color: Colors.subtext
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
                
                // ========== 网络状态 ==========
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    radius: 12
                    color: Colors.surface0
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        
                        // WiFi 信息
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: ccManager.wifiConnected ? "󰤨" : "󰤭"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 18
                                color: ccManager.wifiConnected ? Colors.green : Colors.subtext
                            }
                            
                            ColumnLayout {
                                spacing: 2
                                
                                Text {
                                    text: ccManager.wifiConnected ? ccManager.wifiSsid : "未连接"
                                    font.pixelSize: 12
                                    color: Colors.text
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: "WiFi"
                                    font.pixelSize: 10
                                    color: Colors.overlay
                                }
                            }
                        }
                        
                        Rectangle {
                            width: 1
                            height: 30
                            color: Colors.surface1
                        }
                        
                        // 蓝牙信息
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: ccManager.bluetoothDevice ? "󰂱" : (ccManager.bluetoothPowered ? "󰂯" : "󰂲")
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 18
                                color: ccManager.bluetoothDevice ? Colors.green : (ccManager.bluetoothPowered ? Colors.primary : Colors.subtext)
                            }
                            
                            ColumnLayout {
                                spacing: 2
                                
                                Text {
                                    text: ccManager.bluetoothDevice || (ccManager.bluetoothPowered ? "已开启" : "已关闭")
                                    font.pixelSize: 12
                                    color: Colors.text
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: "蓝牙"
                                    font.pixelSize: 10
                                    color: Colors.overlay
                                }
                            }
                        }
                    }
                }
                
                // ========== 日历 ==========
                Rectangle {
                    Layout.fillWidth: true
                    height: calendarContent.implicitHeight + 24
                    radius: 12
                    color: Colors.surface0
                    
                    ColumnLayout {
                        id: calendarContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        
                        // 日历标题
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "󰃭"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: Colors.secondary
                            }
                            
                            Text {
                                text: calendarManager.currentYear + "年" + calendarManager.currentMonth + "月"
                                font.pixelSize: 13
                                font.bold: true
                                color: Colors.text
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Text {
                                text: "󰅁"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                color: Colors.subtext
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarManager.prevMonth()
                                }
                            }
                            
                            Text {
                                text: "󰅂"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                color: Colors.subtext
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarManager.nextMonth()
                                }
                            }
                        }
                        
                        // 星期标题
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            
                            Repeater {
                                model: ["日", "一", "二", "三", "四", "五", "六"]
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.pixelSize: 10
                                    color: index === 0 || index === 6 ? Colors.red : Colors.overlay
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // 日期网格
                        Grid {
                            Layout.fillWidth: true
                            columns: 7
                            spacing: 2
                            
                            Repeater {
                                model: calendarManager.datesModel
                                
                                Rectangle {
                                    width: (parent.width - 12) / 7
                                    height: 28
                                    radius: 4
                                    color: modelData.isToday ? Colors.primary : "transparent"
                                    opacity: modelData.isCurrentMonth ? 1 : 0.3
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 0
                                        
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.day
                                            font.pixelSize: 11
                                            font.bold: modelData.isToday
                                            color: modelData.isToday ? Colors.base : Colors.text
                                        }
                                        
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.lunarDay || ""
                                            font.pixelSize: 7
                                            color: modelData.isToday ? Colors.base : 
                                                   (modelData.holiday ? Colors.yellow : Colors.overlay)
                                            visible: text.length > 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
