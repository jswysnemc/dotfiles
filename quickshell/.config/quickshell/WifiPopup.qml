import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "colors.js" as Colors

PanelWindow {
    id: popup
    
    // Cover full screen for click-outside detection
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    visible: true
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wifi-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    
    // Dark background with rounded corners - positioned near waybar wifi icon
    Rectangle {
        id: background
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 0
        anchors.rightMargin: 430
        width: 360
        height: contentColumn.implicitHeight + 32
        color: Colors.base
        radius: 16
        border.color: Colors.surface1
        border.width: 1
        
        // Prevent clicks on popup from closing
        MouseArea {
            anchors.fill: parent
            onClicked: {} // consume click
        }
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            // Header with current connection and close button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // WiFi icon
                Text {
                    text: wifiManager.isConnected ? "󰤨" : "󰤭"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 24
                    color: wifiManager.isConnected ? Colors.green : Colors.red
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        text: wifiManager.isConnected ? wifiManager.currentSsid : "未连接"
                        font.pixelSize: 14
                        font.bold: true
                        color: Colors.text
                    }
                    
                    Text {
                        text: wifiManager.isConnected ? "已连接" : "WiFi 已断开"
                        font.pixelSize: 11
                        color: Colors.subtext
                        visible: true
                    }
                }
                
                // Disconnect button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: disconnectMouse.containsMouse ? Colors.surface1 : "transparent"
                    visible: wifiManager.isConnected
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰖪"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: Colors.red
                    }
                    
                    MouseArea {
                        id: disconnectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiManager.disconnect()
                    }
                }
                
                // Refresh button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: refreshMouse.containsMouse ? Colors.surface1 : "transparent"
                    
                    Text {
                        id: refreshIcon
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
                            running: wifiManager.isScanning
                        }
                    }
                    
                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiManager.scanNetworks()
                    }
                }
                
                // Close button
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
            
            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.surface1
            }
            
            // Network list header
            Text {
                text: "可用网络"
                font.pixelSize: 12
                font.bold: true
                color: Colors.subtext
            }
            
            // WiFi list
            ListView {
                id: wifiList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 300)
                clip: true
                spacing: 4
                
                model: wifiManager.networkList
                
                delegate: WifiListItem {
                    width: wifiList.width
                    ssid: modelData.ssid
                    signal: modelData.signal
                    security: modelData.security
                    isConnected: modelData.ssid === wifiManager.currentSsid
                    isSaved: wifiManager.isSavedNetwork(modelData.ssid)
                    onConnectRequested: {
                        // 已保存的网络直接连接，无需密码
                        if (wifiManager.isSavedNetwork(modelData.ssid)) {
                            wifiManager.connectTo(modelData.ssid, "")
                        } else if (security !== "" && security !== "--") {
                            // 新的加密网络需要密码
                            passwordDialog.targetSsid = modelData.ssid
                            passwordDialog.visible = true
                            passwordInput.forceActiveFocus()
                        } else {
                            // 开放网络直接连接
                            wifiManager.connectTo(modelData.ssid, "")
                        }
                    }
                    onDisconnectRequested: wifiManager.disconnect()
                    onForgetRequested: wifiManager.forgetNetwork(modelData.ssid)
                    onRightClicked: {
                        contextMenu.targetSsid = modelData.ssid
                        contextMenu.targetSecurity = modelData.security
                        contextMenu.targetSignal = modelData.signal
                        contextMenu.isSaved = wifiManager.isSavedNetwork(modelData.ssid)
                        contextMenu.isConnected = modelData.ssid === wifiManager.currentSsid
                        contextMenu.visible = true
                    }
                }
                
                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: wifiManager.isScanning ? "正在扫描..." : "未找到网络"
                    font.pixelSize: 13
                    color: Colors.overlay
                    visible: wifiList.count === 0
                }
            }
        }
    }
    
    // Password Dialog Overlay
    Rectangle {
        id: passwordDialog
        anchors.fill: parent
        color: "#80000000"
        visible: false
        radius: 16
        
        property string targetSsid: ""
        
        // Block clicks from going through
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
        
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 40
            anchors.rightMargin: 200
            width: 300
            height: dialogColumn.implicitHeight + 32
            color: Colors.base
            radius: 12
            border.color: Colors.surface1
            border.width: 1
            
            ColumnLayout {
                id: dialogColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                // Dialog title
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "󰌾"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                        color: Colors.yellow
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: "连接到 " + passwordDialog.targetSsid
                        font.pixelSize: 14
                        font.bold: true
                        color: Colors.text
                        elide: Text.ElideRight
                    }
                }
                
                // Password input
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: Colors.surface0
                    border.color: passwordInput.activeFocus ? Colors.primary : Colors.surface1
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8
                        
                        TextInput {
                            id: passwordInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.text
                            selectionColor: Colors.primary
                            selectedTextColor: Colors.base
                            echoMode: showPasswordBtn.checked ? TextInput.Normal : TextInput.Password
                            font.pixelSize: 13
                            clip: true
                            
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "输入密码..."
                                color: Colors.overlay
                                font.pixelSize: 13
                                visible: !passwordInput.text && !passwordInput.activeFocus
                            }
                            
                            Keys.onReturnPressed: {
                                if (passwordInput.text.length > 0) {
                                    wifiManager.connectWithPassword(passwordDialog.targetSsid, passwordInput.text)
                                    passwordInput.text = ""
                                    passwordDialog.visible = false
                                }
                            }
                            
                            Keys.onEscapePressed: {
                                passwordInput.text = ""
                                passwordDialog.visible = false
                            }
                        }
                        
                        // Show/hide password button
                        Rectangle {
                            id: showPasswordBtn
                            width: 28
                            height: 28
                            radius: 6
                            color: showPwdMouse.containsMouse ? Colors.surface1 : "transparent"
                            property bool checked: false
                            
                            Text {
                                anchors.centerIn: parent
                                text: showPasswordBtn.checked ? "󰈈" : "󰈉"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                color: Colors.subtext
                            }
                            
                            MouseArea {
                                id: showPwdMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: showPasswordBtn.checked = !showPasswordBtn.checked
                            }
                        }
                    }
                }
                
                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    // Cancel button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: cancelBtnMouse.containsMouse ? Colors.surface1 : Colors.surface0
                        
                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            font.pixelSize: 13
                            color: Colors.text
                        }
                        
                        MouseArea {
                            id: cancelBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                passwordInput.text = ""
                                passwordDialog.visible = false
                            }
                        }
                    }
                    
                    // Connect button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: connectBtnMouse.containsMouse ? Colors.primary : Colors.primary
                        opacity: passwordInput.text.length >= 8 ? 1.0 : 0.5
                        
                        Text {
                            anchors.centerIn: parent
                            text: "连接"
                            font.pixelSize: 13
                            font.bold: true
                            color: Colors.base
                        }
                        
                        MouseArea {
                            id: connectBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: passwordInput.text.length >= 8 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (passwordInput.text.length >= 8) {
                                    wifiManager.connectWithPassword(passwordDialog.targetSsid, passwordInput.text)
                                    passwordInput.text = ""
                                    passwordDialog.visible = false
                                }
                            }
                        }
                    }
                }
                
                // Hint text
                Text {
                    Layout.fillWidth: true
                    text: "密码长度至少8位"
                    font.pixelSize: 10
                    color: Colors.overlay
                    visible: passwordInput.text.length > 0 && passwordInput.text.length < 8
                }
            }
        }
    }
    
    // Context Menu for right-click
    Rectangle {
        id: contextMenu
        anchors.fill: parent
        color: "#80000000"
        visible: false
        radius: 16
        
        property string targetSsid: ""
        property string targetSecurity: ""
        property int targetSignal: 0
        property bool isSaved: false
        property bool isConnected: false
        property bool showPassword: false
        
        // Block clicks
        MouseArea {
            anchors.fill: parent
            onClicked: contextMenu.visible = false
        }
        
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 40
            anchors.rightMargin: 200
            width: 320
            height: menuColumn.implicitHeight + 32
            color: Colors.base
            radius: 12
            border.color: Colors.surface1
            border.width: 1
            
            // Prevent close when clicking menu
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            
            ColumnLayout {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "󰤨"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 24
                        color: Colors.primary
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: contextMenu.targetSsid
                        font.pixelSize: 16
                        font.bold: true
                        color: Colors.text
                        elide: Text.ElideRight
                    }
                    
                    // Close button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: menuCloseMouse.containsMouse ? Colors.surface1 : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
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
                
                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.surface1
                }
                
                // Details
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    // Signal strength
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "信号强度:"
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                        Text {
                            text: contextMenu.targetSignal + "%"
                            font.pixelSize: 12
                            font.bold: true
                            color: contextMenu.targetSignal >= 70 ? Colors.green : 
                                   contextMenu.targetSignal >= 50 ? Colors.yellow : Colors.red
                        }
                    }
                    
                    // Security type
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "加密方式:"
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                        Text {
                            text: contextMenu.targetSecurity || "开放网络"
                            font.pixelSize: 12
                            font.bold: true
                            color: Colors.text
                        }
                    }
                    
                    // Status
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "状态:"
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                        Text {
                            text: contextMenu.isConnected ? "已连接" : 
                                  contextMenu.isSaved ? "已保存" : "未保存"
                            font.pixelSize: 12
                            font.bold: true
                            color: contextMenu.isConnected ? Colors.green : 
                                   contextMenu.isSaved ? Colors.primary : Colors.overlay
                        }
                    }
                    
                    // Password (if saved)
                    RowLayout {
                        visible: contextMenu.isSaved
                        spacing: 8
                        
                        Text {
                            text: "密码:"
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                        
                        Text {
                            text: contextMenu.showPassword ? 
                                  (wifiManager.queriedPassword || "无密码/获取失败") : "••••••••"
                            font.pixelSize: 12
                            font.bold: true
                            color: Colors.text
                        }
                        
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 4
                            color: showPwMouse.containsMouse ? Colors.surface1 : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: contextMenu.showPassword ? "󰈈" : "󰈉"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: Colors.subtext
                            }
                            
                            MouseArea {
                                id: showPwMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!contextMenu.showPassword) {
                                        wifiManager.queryPassword(contextMenu.targetSsid)
                                    }
                                    contextMenu.showPassword = !contextMenu.showPassword
                                }
                            }
                        }
                    }
                }
                
                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.surface1
                }
                
                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    // Connect/Disconnect button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: connectMenuMouse.containsMouse ? 
                               (contextMenu.isConnected ? Colors.red : Colors.primary) : 
                               (contextMenu.isConnected ? Colors.surface1 : Colors.primary)
                        
                        Text {
                            anchors.centerIn: parent
                            text: contextMenu.isConnected ? "断开连接" : "连接"
                            font.pixelSize: 13
                            font.bold: true
                            color: contextMenu.isConnected ? Colors.text : Colors.base
                        }
                        
                        MouseArea {
                            id: connectMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (contextMenu.isConnected) {
                                    wifiManager.disconnect()
                                } else if (contextMenu.isSaved) {
                                    wifiManager.connectTo(contextMenu.targetSsid, "")
                                } else if (contextMenu.targetSecurity) {
                                    passwordDialog.targetSsid = contextMenu.targetSsid
                                    passwordDialog.visible = true
                                    passwordInput.forceActiveFocus()
                                } else {
                                    wifiManager.connectTo(contextMenu.targetSsid, "")
                                }
                                contextMenu.visible = false
                            }
                        }
                    }
                    
                    // Forget button (only for saved networks)
                    Rectangle {
                        visible: contextMenu.isSaved
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: forgetMenuMouse.containsMouse ? Colors.tertiary : Colors.surface1
                        
                        Text {
                            anchors.centerIn: parent
                            text: "忘记网络"
                            font.pixelSize: 13
                            color: forgetMenuMouse.containsMouse ? Colors.base : Colors.text
                        }
                        
                        MouseArea {
                            id: forgetMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wifiManager.forgetNetwork(contextMenu.targetSsid)
                                contextMenu.visible = false
                            }
                        }
                    }
                }
            }
        }
        
        onVisibleChanged: {
            if (!visible) {
                showPassword = false
                wifiManager.queriedPassword = ""
            }
        }
    }
    
    // WiFi Manager instance
    WifiManager {
        id: wifiManager
    }
}
