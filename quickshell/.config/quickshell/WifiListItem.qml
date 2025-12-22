import QtQuick
import QtQuick.Layouts
import "colors.js" as Colors

Rectangle {
    id: item
    
    property string ssid: ""
    property int signal: 0
    property string security: ""
    property bool isConnected: false
    property bool isSaved: false
    
    signal connectRequested()
    signal disconnectRequested()
    signal forgetRequested()
    signal rightClicked()
    
    // Check if this network is secured
    readonly property bool isSecured: security !== "" && security !== "--"
    
    height: 48
    radius: 10
    color: itemMouse.containsMouse ? Colors.surface0 : (isConnected ? Colors.surface0 : "transparent")
    border.color: isConnected ? Colors.primary : "transparent"
    border.width: isConnected ? 1 : 0
    
    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        
        // Signal strength icon with lock overlay
        Item {
            width: 24
            height: 24
            
            Text {
                anchors.centerIn: parent
                text: getSignalIcon(item.signal)
                font.family: "Symbols Nerd Font"
                font.pixelSize: 20
                color: getSignalColor(item.signal)
            }
            
            // Lock icon for secured networks
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -2
                anchors.bottomMargin: -2
                visible: item.isSecured
                text: "󰌾"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 10
                color: Colors.yellow
            }
        }
        
        // SSID and security info
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            
            Text {
                text: item.ssid
                font.pixelSize: 13
                font.bold: item.isConnected
                color: Colors.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            
            RowLayout {
                spacing: 8
                
                // Security badge
                Rectangle {
                    visible: item.security !== "" && item.security !== "--"
                    width: securityText.implicitWidth + 8
                    height: 16
                    radius: 4
                    color: Colors.surface1
                    
                    Text {
                        id: securityText
                        anchors.centerIn: parent
                        text: getSecurityLabel(item.security)
                        font.pixelSize: 9
                        color: Colors.yellow
                    }
                }
                
                // Open network badge
                Rectangle {
                    visible: item.security === "" || item.security === "--"
                    width: openText.implicitWidth + 8
                    height: 16
                    radius: 4
                    color: Colors.surface0
                    
                    Text {
                        id: openText
                        anchors.centerIn: parent
                        text: "开放"
                        font.pixelSize: 9
                        color: Colors.green
                    }
                }
                
                // Connected badge
                Rectangle {
                    visible: item.isConnected
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
                
                // Saved badge (only show if saved but not connected)
                Rectangle {
                    visible: item.isSaved && !item.isConnected
                    width: savedText.implicitWidth + 8
                    height: 16
                    radius: 4
                    color: Colors.surface0
                    
                    Text {
                        id: savedText
                        anchors.centerIn: parent
                        text: "已保存"
                        font.pixelSize: 9
                        color: Colors.subtext
                    }
                }
            }
        }
        
        // Signal percentage
        Text {
            text: item.signal + "%"
            font.pixelSize: 12
            color: getSignalColor(item.signal)
            font.bold: true
        }
        
        // Forget button for saved networks (not currently connected)
        Rectangle {
            visible: item.isSaved && !item.isConnected
            width: 28
            height: 28
            radius: 6
            color: forgetBtnMouse.containsMouse ? Colors.tertiary : Colors.surface1
            
            Text {
                anchors.centerIn: parent
                text: "󰆴"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: forgetBtnMouse.containsMouse ? Colors.base : Colors.text
            }
            
            MouseArea {
                id: forgetBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: item.forgetRequested()
            }
        }
        
        // Disconnect button for connected network
        Rectangle {
            visible: item.isConnected
            width: 28
            height: 28
            radius: 6
            color: disconnectBtnMouse.containsMouse ? Colors.red : Colors.surface1
            
            Text {
                anchors.centerIn: parent
                text: "󰖪"
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
        cursorShape: item.isConnected ? Qt.ArrowCursor : Qt.PointingHandCursor
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                item.rightClicked()
            } else if (!item.isConnected) {
                item.connectRequested()
            }
        }
    }
    
    // Get WiFi signal icon based on strength
    function getSignalIcon(strength) {
        if (strength >= 80) return "󰤨"      // Excellent
        if (strength >= 60) return "󰤥"      // Good
        if (strength >= 40) return "󰤢"      // Fair
        if (strength >= 20) return "󰤟"      // Weak
        return "󰤯"                           // Very weak
    }
    
    // Get color based on signal strength
    function getSignalColor(strength) {
        if (strength >= 70) return Colors.green  // Green - excellent
        if (strength >= 50) return Colors.yellow  // Yellow - good
        if (strength >= 30) return Colors.tertiary  // Orange - fair
        return Colors.red                       // Red - weak
    }
    
    // Simplify security label
    function getSecurityLabel(sec) {
        if (sec.includes("WPA3")) return "WPA3"
        if (sec.includes("WPA2")) return "WPA2"
        if (sec.includes("WPA")) return "WPA"
        if (sec.includes("WEP")) return "WEP"
        return sec.substring(0, 6)
    }
}
