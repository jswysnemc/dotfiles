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
    WlrLayershell.namespace: "media-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    
    MediaManager {
        id: mediaManager
    }
    
    Rectangle {
        id: background
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 0
        anchors.leftMargin: 150
        width: 380
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
            
            // 专辑封面和信息
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                // 封面
                Rectangle {
                    width: 80
                    height: 80
                    radius: 12
                    color: Colors.surface0
                    clip: true
                    
                    Image {
                        anchors.fill: parent
                        source: mediaManager.artUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: mediaManager.artUrl.length > 0
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 32
                        color: Colors.overlay
                        visible: mediaManager.artUrl.length === 0
                    }
                }
                
                // 信息
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        Layout.fillWidth: true
                        text: mediaManager.title || "未在播放"
                        font.pixelSize: 16
                        font.bold: true
                        color: Colors.text
                        elide: Text.ElideRight
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: mediaManager.artist || "未知艺术家"
                        font.pixelSize: 13
                        color: Colors.subtext
                        elide: Text.ElideRight
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: mediaManager.album || ""
                        font.pixelSize: 11
                        color: Colors.overlay
                        elide: Text.ElideRight
                        visible: mediaManager.album.length > 0
                    }
                    
                    // 播放器名称
                    Rectangle {
                        width: playerNameText.implicitWidth + 12
                        height: 18
                        radius: 4
                        color: Colors.surface1
                        visible: mediaManager.playerName.length > 0
                        
                        Text {
                            id: playerNameText
                            anchors.centerIn: parent
                            text: mediaManager.playerName
                            font.pixelSize: 10
                            color: Colors.primary
                        }
                    }
                }
            }
            
            // 进度条
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: mediaManager.hasPlayer
                
                Slider {
                    id: progressSlider
                    Layout.fillWidth: true
                    from: 0
                    to: Math.max(1, mediaManager.length)
                    value: mediaManager.position
                    
                    background: Rectangle {
                        x: progressSlider.leftPadding
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: progressSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Colors.surface1
                        
                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Colors.primary
                        }
                    }
                    
                    handle: Rectangle {
                        x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: progressSlider.pressed ? Colors.primary : Colors.text
                        visible: progressSlider.hovered || progressSlider.pressed
                    }
                    
                    onPressedChanged: {
                        if (!pressed) {
                            mediaManager.seek(Math.floor(value))
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: mediaManager.formatTime(mediaManager.position)
                        font.pixelSize: 10
                        color: Colors.overlay
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: mediaManager.formatTime(mediaManager.length)
                        font.pixelSize: 10
                        color: Colors.overlay
                    }
                }
            }
            
            // 控制按钮
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                
                // 随机播放
                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: shuffleMouse.containsMouse ? Colors.surface1 : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒟"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 18
                        color: mediaManager.shuffle ? Colors.green : Colors.overlay
                    }
                    
                    MouseArea {
                        id: shuffleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaManager.toggleShuffle()
                    }
                }
                
                // 上一曲
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: prevMouse.containsMouse ? Colors.surface1 : Colors.surface0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 22
                        color: Colors.text
                    }
                    
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaManager.previous()
                    }
                }
                
                // 播放/暂停
                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    color: playMouse.containsMouse ? Colors.primary : Colors.primary
                    
                    Text {
                        anchors.centerIn: parent
                        text: mediaManager.status === "Playing" ? "󰏤" : "󰐊"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 28
                        color: Colors.base
                    }
                    
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaManager.playPause()
                    }
                }
                
                // 下一曲
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: nextMouse.containsMouse ? Colors.surface1 : Colors.surface0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 22
                        color: Colors.text
                    }
                    
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaManager.next()
                    }
                }
                
                // 循环模式
                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: loopMouse.containsMouse ? Colors.surface1 : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: mediaManager.loopStatus === "Track" ? "󰑘" : "󰑖"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 18
                        color: mediaManager.loopStatus !== "None" ? Colors.green : Colors.overlay
                    }
                    
                    MouseArea {
                        id: loopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaManager.cycleLoop()
                    }
                }
            }
            
            // 音量控制
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: mediaManager.hasPlayer
                
                Text {
                    text: mediaManager.volume < 0.01 ? "󰝟" : (mediaManager.volume < 0.5 ? "󰖀" : "󰕾")
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 18
                    color: Colors.subtext
                }
                
                Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    
                    // 只在不拖动时更新值
                    Binding {
                        target: volumeSlider
                        property: "value"
                        value: mediaManager.volume
                        when: !volumeSlider.pressed
                    }
                    
                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: volumeSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Colors.surface1
                        
                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Colors.subtext
                        }
                    }
                    
                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: volumeSlider.pressed ? Colors.text : Colors.subtext
                        visible: volumeSlider.hovered || volumeSlider.pressed
                    }
                    
                    onPressedChanged: {
                        if (!pressed) {
                            mediaManager.setVolume(value)
                        }
                    }
                }
                
                Text {
                    text: Math.round(mediaManager.volume * 100) + "%"
                    font.pixelSize: 11
                    color: Colors.overlay
                    Layout.preferredWidth: 35
                }
            }
            
            // 无播放器提示
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: 8
                color: Colors.surface0
                visible: !mediaManager.hasPlayer
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    
                    Text {
                        text: "󰝛"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 24
                        color: Colors.overlay
                    }
                    
                    Text {
                        text: "没有检测到播放器"
                        font.pixelSize: 13
                        color: Colors.overlay
                    }
                }
            }
        }
    }
}
