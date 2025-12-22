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
    WlrLayershell.namespace: "weather-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    
    WeatherManager {
        id: weatherManager
    }
    
    Rectangle {
        id: background
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 0
        anchors.leftMargin: 0
        width: 340
        height: contentColumn.implicitHeight + 32
        color: Colors.base
        radius: 16
        border.color: Colors.surface1
        border.width: 1
        
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            
            // 加载/错误状态
            Text {
                Layout.fillWidth: true
                text: weatherManager.loading ? "加载中..." : weatherManager.error
                font.pixelSize: 13
                color: Colors.red
                horizontalAlignment: Text.AlignHCenter
                visible: weatherManager.loading || weatherManager.error.length > 0
            }
            
            // 主要天气信息
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: !weatherManager.loading && weatherManager.error.length === 0
                
                // 天气图标和温度
                ColumnLayout {
                    spacing: 4
                    
                    Text {
                        text: weatherManager.icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 56
                        color: Colors.primary
                    }
                    
                    Text {
                        text: weatherManager.weatherDesc
                        font.pixelSize: 14
                        color: Colors.subtext
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // 温度和位置
                ColumnLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4
                    
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: weatherManager.temp + "°"
                        font.pixelSize: 48
                        font.bold: true
                        color: Colors.text
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "体感 " + weatherManager.feelsLike + "°"
                        font.pixelSize: 12
                        color: Colors.subtext
                    }
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 4
                        
                        Text {
                            text: "󰍎"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: Colors.yellow
                        }
                        
                        Text {
                            text: weatherManager.city || weatherManager.area
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                    }
                }
            }
            
            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.surface1
                visible: !weatherManager.loading && weatherManager.error.length === 0
            }
            
            // 详细信息
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 12
                columnSpacing: 8
                visible: !weatherManager.loading && weatherManager.error.length === 0
                
                // 湿度
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰖎"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                        color: Colors.primary
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: weatherManager.humidity + "%"
                        font.pixelSize: 13
                        color: Colors.text
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "湿度"
                        font.pixelSize: 10
                        color: Colors.overlay
                    }
                }
                
                // 风速
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰖝"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                        color: Colors.secondary
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: weatherManager.windSpeed + "km/h"
                        font.pixelSize: 13
                        color: Colors.text
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: weatherManager.windDir + "风"
                        font.pixelSize: 10
                        color: Colors.overlay
                    }
                }
                
                // 能见度
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰈈"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                        color: Colors.primary
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: weatherManager.visibility + "km"
                        font.pixelSize: 13
                        color: Colors.text
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "能见度"
                        font.pixelSize: 10
                        color: Colors.overlay
                    }
                }
                
                // UV指数
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰖙"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                        color: Colors.yellow
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: weatherManager.uvIndex
                        font.pixelSize: 13
                        color: Colors.text
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "紫外线"
                        font.pixelSize: 10
                        color: Colors.overlay
                    }
                }
            }
            
            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.surface1
                visible: !weatherManager.loading && weatherManager.forecast.length > 0
            }
            
            // 未来天气预报
            Text {
                text: "未来预报"
                font.pixelSize: 13
                font.bold: true
                color: Colors.text
                visible: !weatherManager.loading && weatherManager.forecast.length > 0
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !weatherManager.loading && weatherManager.forecast.length > 0
                
                Repeater {
                    model: weatherManager.forecast
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: index === 0 ? Colors.surface1 : Colors.surface0
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: weatherManager.getDayOfWeek(modelData.date)
                                font.pixelSize: 11
                                color: Colors.subtext
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 22
                                color: Colors.primary
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.maxTemp + "° / " + modelData.minTemp + "°"
                                font.pixelSize: 11
                                color: Colors.text
                            }
                        }
                    }
                }
            }
            
            // 刷新按钮和更新时间
            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: weatherManager.observationTime ? "观测: " + weatherManager.observationTime : ""
                    font.pixelSize: 10
                    color: Colors.overlay
                }
                
                Text {
                    text: "·"
                    font.pixelSize: 10
                    color: Colors.overlay
                    visible: weatherManager.lastUpdateTime && weatherManager.observationTime
                }
                
                Text {
                    text: weatherManager.lastUpdateTime ? "刷新: " + weatherManager.lastUpdateTime : ""
                    font.pixelSize: 10
                    color: Colors.overlay
                }
                
                // 刷新中指示器
                Text {
                    text: "刷新中..."
                    font.pixelSize: 10
                    color: Colors.primary
                    visible: weatherManager.refreshing
                }
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: refreshMouse.containsMouse ? Colors.surface1 : "transparent"
                    opacity: weatherManager.refreshing ? 0.5 : 1.0
                    
                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "󰑓"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: weatherManager.refreshing ? Colors.green : Colors.primary
                        
                        RotationAnimation on rotation {
                            running: weatherManager.loading || weatherManager.refreshing
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                        }
                    }
                    
                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: weatherManager.refreshing ? Qt.BusyCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!weatherManager.refreshing) {
                                weatherManager.refresh()
                            }
                        }
                    }
                }
            }
        }
    }
}
