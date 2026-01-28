import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Idle warning - fullscreen with realistic moon phase animation
// Dismisses on any user input (mouse move / key press)

ShellRoot {
    id: root

    property int warningSeconds: {
        var envTimeout = Quickshell.env("IDLE_WARN_TIMEOUT")
        var t = parseInt(envTimeout)
        return (!isNaN(t) && t > 0) ? t : 30
    }
    property int remainingSeconds: warningSeconds
    property bool inputEnabled: false
    property point lastMousePos: Qt.point(-1, -1)
    property string currentTime: ""
    property string currentDate: ""

    // Moon phase: 1.0 = full moon, 0.0 = new moon
    property real moonPhase: remainingSeconds / warningSeconds

    // Update time
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            currentTime = Qt.formatTime(now, "HH:mm")
            currentDate = Qt.formatDate(now, "M月d日 dddd")
        }
    }

    // Delay before accepting input
    Timer {
        id: inputDelayTimer
        interval: 1000
        running: true
        onTriggered: inputEnabled = true
    }

    // Countdown timer
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            remainingSeconds--
            if (remainingSeconds <= 0) {
                Qt.quit()
            }
        }
    }

    // Fullscreen overlay - covers everything including waybar
    PanelWindow {
        id: overlay
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "idle-warning"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusiveZone: -1  // Cover exclusive zones (waybar)

        color: "transparent"

        Rectangle {
            id: content
            anchors.fill: parent
            color: "transparent"
            focus: true

            property real bgOpacity: 0

            Component.onCompleted: fadeInAnim.start()

            NumberAnimation {
                id: fadeInAnim
                target: content
                property: "bgOpacity"
                from: 0
                to: 1
                duration: 500
                easing.type: Easing.OutCubic
            }

            // Dark background
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.02, 0.02, 0.06, 0.92 * content.bgOpacity)
            }

            // Input detection
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: function(mouse) {
                    if (!inputEnabled) return
                    if (lastMousePos.x >= 0 && lastMousePos.y >= 0) {
                        var dx = Math.abs(mouse.x - lastMousePos.x)
                        var dy = Math.abs(mouse.y - lastMousePos.y)
                        if (dx > 10 || dy > 10) {
                            root.dismiss()
                        }
                    }
                    lastMousePos = Qt.point(mouse.x, mouse.y)
                }
                onClicked: if (inputEnabled) root.dismiss()
                onWheel: if (inputEnabled) root.dismiss()
            }

            Keys.onPressed: function(event) {
                if (inputEnabled) root.dismiss()
            }

            // Center content
            Item {
                id: centerContent
                anchors.centerIn: parent
                width: 400
                height: 320
                opacity: content.bgOpacity

                property real slideY: 20

                Component.onCompleted: slideAnim.start()

                NumberAnimation {
                    id: slideAnim
                    target: centerContent
                    property: "slideY"
                    from: 20
                    to: 0
                    duration: 600
                    easing.type: Easing.OutCubic
                }

                transform: Translate { y: centerContent.slideY }

                // Time
                Text {
                    id: timeText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: currentTime
                    font.pixelSize: 64
                    font.weight: Font.Light
                    font.letterSpacing: -1
                    color: "#ffffff"
                }

                // Date
                Text {
                    id: dateText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: timeText.bottom
                    anchors.topMargin: 4
                    text: currentDate
                    font.pixelSize: 16
                    color: Qt.rgba(1, 1, 1, 0.6)
                }

                // Moon container
                Item {
                    id: moonContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: dateText.bottom
                    anchors.topMargin: 36
                    width: 90
                    height: 90

                    // Outer glow ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: 110
                        height: 110
                        radius: 55
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        SequentialAnimation on scale {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.1; duration: 2500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2500; easing.type: Easing.InOutSine }
                        }

                        SequentialAnimation on opacity {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 2500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2500; easing.type: Easing.InOutSine }
                        }
                    }

                    // Moon canvas - realistic moon phase
                    Canvas {
                        id: moonCanvas
                        anchors.centerIn: parent
                        width: 80
                        height: 80
                        property real phase: moonPhase

                        onPhaseChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var cx = width / 2
                            var cy = height / 2
                            var r = 38

                            // Draw the dark moon base
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.fillStyle = Qt.rgba(0.12, 0.12, 0.18, 1)
                            ctx.fill()

                            // Draw the lit portion using proper moon phase geometry
                            ctx.save()
                            ctx.beginPath()

                            // Clip to moon circle
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.clip()

                            // Calculate terminator curve
                            // phase 1.0 = full moon (all lit)
                            // phase 0.5 = half moon
                            // phase 0.0 = new moon (all dark)

                            var illumination = phase

                            if (illumination > 0) {
                                ctx.beginPath()

                                // Draw lit portion from right side (waning)
                                // Right semicircle is always lit for waning moon
                                ctx.arc(cx, cy, r, -Math.PI/2, Math.PI/2, false)

                                // Terminator curve (the shadow edge)
                                // When phase = 1.0, terminator is at left edge (full moon)
                                // When phase = 0.5, terminator is at center (half moon)
                                // When phase = 0.0, terminator is at right edge (new moon)

                                var terminatorX = cx + r * (2 * illumination - 1)
                                var curveWidth = r * Math.abs(2 * illumination - 1)

                                if (illumination >= 0.5) {
                                    // Gibbous phase - terminator curves outward on left
                                    ctx.ellipse(terminatorX - curveWidth, cy - r, curveWidth * 2, r * 2)
                                } else {
                                    // Crescent phase - terminator curves inward on right
                                    ctx.ellipse(terminatorX - curveWidth, cy - r, curveWidth * 2, r * 2)
                                }

                                // Moon surface gradient
                                var gradient = ctx.createRadialGradient(cx - r*0.3, cy - r*0.3, 0, cx, cy, r)
                                gradient.addColorStop(0, Qt.rgba(1, 1, 0.95, 1))
                                gradient.addColorStop(0.5, Qt.rgba(0.95, 0.93, 0.85, 1))
                                gradient.addColorStop(1, Qt.rgba(0.85, 0.82, 0.75, 1))

                                ctx.fillStyle = gradient
                                ctx.fill()
                            }

                            ctx.restore()

                            // Add subtle crater texture
                            ctx.globalAlpha = 0.1
                            ctx.beginPath()
                            ctx.arc(cx - 10, cy - 8, 6, 0, Math.PI * 2)
                            ctx.fillStyle = Qt.rgba(0.5, 0.5, 0.5, 0.3)
                            ctx.fill()

                            ctx.beginPath()
                            ctx.arc(cx + 12, cy + 5, 4, 0, Math.PI * 2)
                            ctx.fill()

                            ctx.beginPath()
                            ctx.arc(cx - 5, cy + 15, 5, 0, Math.PI * 2)
                            ctx.fill()

                            ctx.globalAlpha = 1.0
                        }

                        Behavior on phase {
                            NumberAnimation { duration: 600; easing.type: Easing.OutQuad }
                        }
                    }
                }

                // Lock message
                Row {
                    id: lockRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: moonContainer.bottom
                    anchors.topMargin: 28
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf023"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 14
                        color: Qt.rgba(1, 1, 1, 0.6)

                        SequentialAnimation on opacity {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 1800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "屏幕即将锁定"
                        font.pixelSize: 14
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }
                }
            }

            // Bottom hint
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                text: "移动鼠标或按任意键取消"
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.3)
                opacity: content.bgOpacity

                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 3000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.5; duration: 3000; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    function dismiss() {
        countdownTimer.stop()
        Qt.quit()
    }
}
