import QtQuick 2.0

Rectangle {
    id: keyBtn
    width: 44
    height: 42
    radius: 8
    color: keyArea.containsMouse ? "#70ffffff" : "#45ffffff"
    border.width: 1
    border.color: keyArea.containsMouse ? "#80ffffff" : "#30ffffff"
    
    property string keyText: ""

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        text: keyBtn.keyText
        color: "white"
        font.pixelSize: 16
        font.family: "Noto Sans CJK SC"
    }

    MouseArea {
        id: keyArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            var input = virtualKeyboard.targetInput
            input.text += keyBtn.keyText
            if (virtualKeyboard.shiftPressed) virtualKeyboard.shiftPressed = false
        }
    }
}
