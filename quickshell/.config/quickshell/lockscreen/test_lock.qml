import Quickshell
import Quickshell.Wayland
import QtQuick

// Minimal lockscreen test
ShellRoot {
    id: root

    WlSessionLock {
        id: sessionLock
        locked: true

        onLockedChanged: {
            console.log("Session lock changed:", locked)
            if (!locked) {
                Qt.quit()
            }
        }

        onSecureChanged: {
            console.log("Session lock secure:", secure)
        }

        surface: Component {
            WlSessionLockSurface {
                id: lockSurface
                color: "#1a1a2e"  // Dark blue, not black

                Rectangle {
                    anchors.centerIn: parent
                    width: 400
                    height: 200
                    radius: 20
                    color: "#2d2d44"

                    Column {
                        anchors.centerIn: parent
                        spacing: 20

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Lockscreen Test"
                            font.pixelSize: 32
                            color: "#ffffff"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Press Ctrl+Alt+Q to exit"
                            font.pixelSize: 16
                            color: "#aaaaaa"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Secure: " + sessionLock.secure
                            font.pixelSize: 14
                            color: sessionLock.secure ? "#00ff00" : "#ff0000"
                        }
                    }
                }

                // Key handler
                Item {
                    anchors.fill: parent
                    focus: true

                    Keys.onPressed: function(event) {
                        console.log("Key pressed:", event.key, "modifiers:", event.modifiers)
                        if (event.key === Qt.Key_Q &&
                            (event.modifiers & Qt.ControlModifier) &&
                            (event.modifiers & Qt.AltModifier)) {
                            console.log("Emergency exit!")
                            sessionLock.locked = false
                            event.accepted = true
                        }
                    }

                    Component.onCompleted: {
                        forceActiveFocus()
                        console.log("Focus set")
                    }
                }
            }
        }
    }
}
