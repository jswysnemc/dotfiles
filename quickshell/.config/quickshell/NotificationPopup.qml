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
    WlrLayershell.namespace: "notification-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    // 点击外部关闭
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    
    // 通知管理器
    NotificationManager {
        id: notificationManager
    }
    
    // 高亮链接和路径
    function highlightLinks(text) {
        if (!text) return ""
        // 转义 HTML 特殊字符
        var escaped = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        // 高亮 URL
        escaped = escaped.replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1" style="color: #89b4fa; text-decoration: underline;">$1</a>')
        // 高亮文件路径 (以 / 或 ~/ 开头)
        escaped = escaped.replace(/(^|[\s])([\/~][^\s<]+)/g, '$1<span style="color: #a6e3a1;">$2</span>')
        return escaped
    }
    
    // 主容器
    Rectangle {
        id: background
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 0
        anchors.rightMargin: 420
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
                // 滚轮滚动通知列表
                if (wheel.angleDelta.y > 0) {
                    notificationList.contentY = Math.max(0, notificationList.contentY - 60)
                } else {
                    notificationList.contentY = Math.min(notificationList.contentHeight - notificationList.height, notificationList.contentY + 60)
                }
            }
        }
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            // 标题栏
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                // 通知图标
                Text {
                    text: notificationManager.dndEnabled ? "󰂛" : 
                          (notificationManager.notificationCount > 0 ? "󰂚" : "󰂜")
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 24
                    color: notificationManager.dndEnabled ? Colors.yellow :
                           (notificationManager.notificationCount > 0 ? Colors.primary : Colors.subtext)
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        text: "通知中心"
                        font.pixelSize: 16
                        font.bold: true
                        color: Colors.text
                    }
                    
                    Text {
                        text: notificationManager.notificationCount > 0 ?
                              notificationManager.notificationCount + " 条通知" :
                              (notificationManager.dndEnabled ? "勿扰模式已开启" : "没有新通知")
                        font.pixelSize: 11
                        color: Colors.subtext
                    }
                }
                
                // 勿扰模式按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: notificationManager.dndEnabled ? Colors.surface1 : (dndMouse.containsMouse ? Colors.surface1 : "transparent")
                    border.color: notificationManager.dndEnabled ? Colors.yellow : "transparent"
                    border.width: notificationManager.dndEnabled ? 1 : 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰂛"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: notificationManager.dndEnabled ? Colors.yellow : Colors.text
                    }
                    
                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notificationManager.toggleDnd()
                    }
                }
                
                // 清除全部按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: clearMouse.containsMouse ? Colors.surface1 : "transparent"
                    opacity: notificationManager.notificationCount > 0 ? 1 : 0.5
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰎟"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: Colors.red
                    }
                    
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: notificationManager.notificationCount > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (notificationManager.notificationCount > 0) {
                                notificationManager.clearAll()
                            }
                        }
                    }
                }
            }
            
            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.surface1
            }
            
            // 通知列表
            ListView {
                id: notificationList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 400)
                Layout.minimumHeight: 60
                clip: true
                spacing: 8
                model: notificationManager.notifications
                
                // 无通知时的提示
                Text {
                    anchors.centerIn: parent
                    text: "暂无通知"
                    font.pixelSize: 13
                    color: Colors.overlay
                    visible: notificationManager.notificationCount === 0
                }
                
                delegate: Rectangle {
                    id: notificationItem
                    width: notificationList.width
                    height: notificationContent.implicitHeight + 16
                    radius: 10
                    color: notificationItemMouse.containsMouse ? Colors.surface1 : Colors.surface0
                    
                    property int itemIndex: index
                    
                    RowLayout {
                        id: notificationContent
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10
                        
                        // 应用图标
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: Colors.surface1
                            
                            Text {
                                anchors.centerIn: parent
                                text: {
                                    let app = (modelData.app || "").toLowerCase()
                                    if (app.includes("qq")) return "󰘅"
                                    if (app.includes("discord")) return "󰙯"
                                    if (app.includes("telegram")) return ""
                                    if (app.includes("firefox")) return "󰈹"
                                    if (app.includes("chrome")) return ""
                                    if (app.includes("spotify")) return "󰓇"
                                    if (app.includes("code") || app.includes("cursor")) return "󰨞"
                                    if (app.includes("slack")) return "󰒱"
                                    if (app.includes("steam")) return "󰓓"
                                    return "󰂜"
                                }
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 18
                                color: Colors.primary
                            }
                        }
                        
                        // 通知内容
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.summary || "通知"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Colors.text
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: modelData.time || ""
                                    font.pixelSize: 10
                                    color: Colors.overlay
                                }
                            }
                            
                            // 通知正文 - 可选择、支持链接高亮
                            TextEdit {
                                id: bodyText
                                Layout.fillWidth: true
                                text: highlightLinks(modelData.body || "")
                                font.pixelSize: 11
                                color: Colors.subtext
                                wrapMode: Text.WordWrap
                                readOnly: true
                                selectByMouse: true
                                selectionColor: Colors.primary
                                selectedTextColor: Colors.base
                                textFormat: Text.RichText
                                visible: (modelData.body || "").length > 0
                                
                                onLinkActivated: (link) => {
                                    Qt.openUrlExternally(link)
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    onClicked: {
                                        if (bodyText.selectedText) {
                                            notificationManager.copyToClipboard(bodyText.selectedText)
                                        }
                                    }
                                }
                            }
                            
                            Text {
                                text: modelData.app || ""
                                font.pixelSize: 10
                                color: Colors.overlay
                                visible: (modelData.app || "").length > 0
                            }
                        }
                        
                        // 操作按钮列
                        ColumnLayout {
                            spacing: 4
                            visible: notificationItemMouse.containsMouse
                            
                            // 激活按钮
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 4
                                color: activateBtnMouse.containsMouse ? Colors.primary : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰏌"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 12
                                    color: activateBtnMouse.containsMouse ? Colors.base : Colors.primary
                                }
                                
                                MouseArea {
                                    id: activateBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        notificationManager.activateNotification(modelData)
                                        Qt.quit()
                                    }
                                }
                            }
                            
                            // 复制按钮
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 4
                                color: copyBtnMouse.containsMouse ? Colors.green : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆏"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 12
                                    color: copyBtnMouse.containsMouse ? Colors.base : Colors.green
                                }
                                
                                MouseArea {
                                    id: copyBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var content = (modelData.summary || "") + "\n" + (modelData.body || "")
                                        notificationManager.copyToClipboard(content.trim())
                                    }
                                }
                            }
                            
                            // 删除按钮
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 4
                                color: deleteBtnMouse.containsMouse ? Colors.red : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 12
                                    color: deleteBtnMouse.containsMouse ? Colors.base : Colors.red
                                }
                                
                                MouseArea {
                                    id: deleteBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        notificationManager.removeNotification(notificationItem.itemIndex)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 整体悬停检测（不阻止子元素交互）
                    MouseArea {
                        id: notificationItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }
}
