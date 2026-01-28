import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// QuickShell Lockscreen - using ext-session-lock-v1 protocol
// This is a REAL secure lock screen that blocks all input until unlocked

ShellRoot {
    id: root

    // Theme colors (dark theme for lockscreen)
    readonly property color bgColor: "#1a1a2e"
    readonly property color primaryColor: "#3b82f6"
    readonly property color secondaryColor: "#8b5cf6"
    readonly property color errorColor: "#ef4444"
    readonly property color textColor: "#ffffff"
    readonly property color textMuted: "#9ca3af"

    property bool authInProgress: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string currentTime: ""
    property string currentDate: ""
    property string userName: Quickshell.env("USER") || "User"

    // Update time every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            currentTime = Qt.formatTime(now, "HH:mm")
            currentDate = Qt.formatDate(now, "yyyy年M月d日 dddd")
        }
    }

    // PAM authentication context
    PamContext {
        id: pam
        config: "sudo"  // Use sudo PAM config which has howdy
        user: userName

        onActiveChanged: {
            if (active) {
                authInProgress = true
                statusMessage = "正在认证..."
            }
        }

        // pamMessage signal has no parameters - use properties instead
        onPamMessage: {
            console.log("PAM message:", pam.message, "responseRequired:", pam.responseRequired, "responseVisible:", pam.responseVisible)
            if (pam.responseRequired) {
                if (pam.responseVisible) {
                    // Username prompt - auto respond
                    pam.respond(userName)
                } else {
                    // Password prompt - wait for user input
                    statusMessage = pam.message || "请输入密码或进行人脸识别"
                    authInProgress = false  // Allow input
                }
            } else {
                statusMessage = pam.message
            }
        }

        onCompleted: function(result) {
            console.log("PAM completed:", result)
            authInProgress = false
            statusMessage = ""

            if (result === PamResult.Success) {
                // Unlock the session
                sessionLock.locked = false
            } else {
                errorMessage = "认证失败"
                errorClearTimer.restart()
            }
        }

        onError: function(err) {
            console.log("PAM error:", err)
            authInProgress = false
            statusMessage = ""
            errorMessage = "认证错误"
            errorClearTimer.restart()
        }
    }

    Timer {
        id: errorClearTimer
        interval: 3000
        onTriggered: errorMessage = ""
    }

    // Session Lock - ext-session-lock-v1 protocol
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

        // Surface for each screen
        surface: Component {
            WlSessionLockSurface {
                id: lockSurface
                color: root.bgColor

                // Main container
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"

                    // Gradient overlay
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.2) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.5) }
                        }
                    }

                    // Clock at top
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: parent.height * 0.12
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: currentTime
                            font.pixelSize: 96
                            font.weight: Font.Light
                            color: root.textColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: currentDate
                            font.pixelSize: 20
                            color: root.textMuted
                        }
                    }

                    // Center login area
                    Column {
                        anchors.centerIn: parent
                        spacing: 20
                        width: 320

                        // User avatar button
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 96
                            height: 96
                            radius: 48
                            color: authInProgress ? root.secondaryColor :
                                   (avatarMouse.containsMouse ? Qt.lighter(root.primaryColor, 1.2) : root.primaryColor)

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: authInProgress ? "\uf2f1" : "\uf007"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 42
                                color: root.textColor

                                RotationAnimator on rotation {
                                    running: authInProgress
                                    from: 0; to: 360
                                    duration: 2000
                                    loops: Animation.Infinite
                                }
                            }

                            MouseArea {
                                id: avatarMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !authInProgress && !pam.responseRequired
                                onClicked: root.startAuth()
                            }
                        }

                        // Username
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: userName
                            font.pixelSize: 22
                            color: root.textColor
                        }

                        // Status message
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: statusMessage
                            font.pixelSize: 14
                            color: root.secondaryColor
                            visible: statusMessage.length > 0
                        }

                        // Password input
                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: 25
                            color: Qt.rgba(1, 1, 1, 0.1)
                            border.color: passwordField.activeFocus ? root.primaryColor : Qt.rgba(1, 1, 1, 0.2)
                            border.width: 2

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                spacing: 12

                                // Lock icon
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\uf023"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 18
                                    color: "#888888"
                                }

                                // Input field
                                TextInput {
                                    id: passwordField
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 80
                                    color: root.textColor
                                    font.pixelSize: 16
                                    echoMode: TextInput.Password
                                    clip: true
                                    focus: true

                                    property string placeholder: "输入密码..."

                                    Text {
                                        anchors.fill: parent
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: passwordField.placeholder
                                        color: "#666666"
                                        font.pixelSize: 16
                                        visible: !passwordField.text && !passwordField.activeFocus
                                    }

                                    onAccepted: {
                                        if (text.length > 0) {
                                            if (pam.responseRequired) {
                                                pam.respond(text)
                                                text = ""
                                            } else {
                                                root.startAuthWithPassword(text)
                                            }
                                        }
                                    }

                                    Keys.onEscapePressed: {
                                        text = ""
                                        errorMessage = ""
                                    }
                                }

                                // Submit button
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: authInProgress ? "\uf110" : "\uf054"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 18
                                    color: root.primaryColor
                                    visible: passwordField.text.length > 0 || authInProgress

                                    RotationAnimator on rotation {
                                        running: authInProgress
                                        from: 0; to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -10
                                        enabled: !authInProgress && passwordField.text.length > 0
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (pam.responseRequired) {
                                                pam.respond(passwordField.text)
                                                passwordField.text = ""
                                            } else {
                                                root.startAuthWithPassword(passwordField.text)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Error message
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: errorMessage
                            font.pixelSize: 14
                            color: root.errorColor
                            visible: errorMessage.length > 0
                        }

                        // Hint
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "点击头像进行人脸识别，或输入密码"
                            font.pixelSize: 12
                            color: "#666666"
                            visible: !authInProgress && !pam.responseRequired && passwordField.text.length === 0
                        }
                    }

                    // Power buttons at bottom
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 40
                        spacing: 40

                        Repeater {
                            model: [
                                { icon: "\uf186", label: "睡眠", cmd: ["systemctl", "suspend"] },
                                { icon: "\uf021", label: "重启", cmd: ["systemctl", "reboot"] },
                                { icon: "\uf011", label: "关机", cmd: ["systemctl", "poweroff"] }
                            ]

                            Column {
                                spacing: 6

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 44
                                    height: 44
                                    radius: 22
                                    color: pwrMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 18
                                        color: pwrMouse.containsMouse ? "#ffffff" : "#888888"
                                    }

                                    MouseArea {
                                        id: pwrMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            pwrProc.command = modelData.cmd
                                            pwrProc.running = true
                                        }
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    font.pixelSize: 11
                                    color: "#666666"
                                }
                            }
                        }
                    }

                    // Global key handler
                    focus: true
                    Keys.onPressed: function(event) {
                        // Any key press focuses password field
                        if (!passwordField.activeFocus) {
                            passwordField.forceActiveFocus()
                            if (event.text.length > 0 && !event.modifiers) {
                                passwordField.text += event.text
                                event.accepted = true
                            }
                        }
                    }

                    Component.onCompleted: {
                        passwordField.forceActiveFocus()
                    }
                }

                Process {
                    id: pwrProc
                    running: false
                }
            }
        }
    }

    // Store password for PAM response
    property string pendingPassword: ""

    function startAuth() {
        if (authInProgress || pam.active) return
        errorMessage = ""
        pendingPassword = ""
        pam.start()
    }

    function startAuthWithPassword(password) {
        if (authInProgress) return
        errorMessage = ""
        pendingPassword = password
        if (!pam.active) {
            pam.start()
        } else if (pam.responseRequired) {
            pam.respond(password)
        }
    }
}
