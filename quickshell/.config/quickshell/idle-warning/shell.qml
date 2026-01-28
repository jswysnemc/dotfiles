import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Phantom Lock - Minimal, low-intrusion idle warning
// Design: Ultra-thin ring progress, ghost-like presence
// Lock animation: Ring collapse + lock icon pop + screen fade

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

    // Progress: 0.0 = start, 1.0 = complete
    property real progress: 1.0 - (remainingSeconds / warningSeconds)

    // Animation states
    property bool isLocking: false
    property real ringScale: 1.0
    property real lockIconScale: 0.0
    property real screenFade: 0.0

    // Smooth progress for rendering
    property real smoothProgress: 0.0

    Behavior on smoothProgress {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutCubic
        }
    }

    onProgressChanged: smoothProgress = progress

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
                triggerLockAnimation()
            }
        }
    }

    // Lock animation sequence
    function triggerLockAnimation() {
        countdownTimer.stop()
        isLocking = true
        lockSequence.start()
    }

    SequentialAnimation {
        id: lockSequence

        // Ring collapse with easeInBack
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "ringScale"
                from: 1.0
                to: 0.0
                duration: 300
                easing.type: Easing.InBack
                easing.overshoot: 1.7
            }
        }

        // Lock icon pop (with slight delay)
        ParallelAnimation {
            // Lock icon spring animation
            SequentialAnimation {
                NumberAnimation {
                    target: root
                    property: "lockIconScale"
                    from: 0.0
                    to: 1.15
                    duration: 200
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: root
                    property: "lockIconScale"
                    to: 1.0
                    duration: 150
                    easing.type: Easing.InOutQuad
                }
            }

            // Screen fade to black
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation {
                    target: root
                    property: "screenFade"
                    from: 0.0
                    to: 1.0
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }
        }

        PauseAnimation { duration: 200 }

        ScriptAction {
            script: {
                // 先退出 idle-warning，然后延迟启动锁屏
                // 使用 bash 在后台延迟执行，确保 idle-warning 完全退出后再启动锁屏
                delayedLockProcess.running = true
            }
        }

        PauseAnimation { duration: 100 }

        ScriptAction { script: Qt.quit() }
    }

    // 延迟启动锁屏（在后台执行，idle-warning 退出后才会真正启动）
    Process {
        id: delayedLockProcess
        command: ["bash", "-c", "sleep 0.3 && qs-lock"]
    }

    // Fullscreen overlay
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.exclusiveZone: -1

        color: "transparent"

        Rectangle {
            id: content
            anchors.fill: parent
            color: "transparent"
            focus: true

            property real fadeIn: 0

            Component.onCompleted: fadeInAnim.start()

            NumberAnimation {
                id: fadeInAnim
                target: content
                property: "fadeIn"
                from: 0
                to: 1
                duration: 500
                easing.type: Easing.OutCubic
            }

            // Semi-transparent background (very subtle)
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.3 * content.fadeIn)
            }

            // Black screen overlay for lock transition
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: screenFade
                z: 100
            }

            // Input detection
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: function(mouse) {
                    if (!inputEnabled || isLocking) return
                    if (lastMousePos.x >= 0 && lastMousePos.y >= 0) {
                        var dx = Math.abs(mouse.x - lastMousePos.x)
                        var dy = Math.abs(mouse.y - lastMousePos.y)
                        if (dx > 10 || dy > 10) {
                            root.dismiss()
                        }
                    }
                    lastMousePos = Qt.point(mouse.x, mouse.y)
                }
                onClicked: if (inputEnabled && !isLocking) root.dismiss()
                onWheel: if (inputEnabled && !isLocking) root.dismiss()
            }

            Keys.onPressed: function(event) {
                if (inputEnabled && !isLocking) root.dismiss()
            }

            // Center content
            Item {
                id: centerContent
                anchors.centerIn: parent
                width: 200
                height: 200
                opacity: content.fadeIn

                // Ring progress indicator
                Canvas {
                    id: ringCanvas
                    anchors.centerIn: parent
                    width: 140
                    height: 140

                    property real prog: smoothProgress
                    property real scale: ringScale

                    onProgChanged: requestPaint()
                    onScaleChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var cx = width / 2
                        var cy = height / 2
                        var radius = 60 * scale
                        var thickness = 3

                        if (radius < 1) return

                        // Track (ultra faint)
                        ctx.beginPath()
                        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                        ctx.lineWidth = thickness
                        ctx.strokeStyle = isLocking ? "#FFFFFF" : "rgba(255, 255, 255, 0.08)"
                        ctx.stroke()

                        // Progress arc (low contrast gray)
                        if (!isLocking && prog > 0) {
                            var startAngle = -Math.PI / 2
                            var endAngle = startAngle + (Math.PI * 2 * prog)

                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, startAngle, endAngle)
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
                            ctx.lineWidth = thickness
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }

                        // Glow effect during lock
                        if (isLocking && scale > 0.01) {
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                            ctx.strokeStyle = "#FFFFFF"
                            ctx.lineWidth = thickness * 1.5
                            ctx.shadowColor = "rgba(255, 255, 255, 0.5)"
                            ctx.shadowBlur = 10
                            ctx.stroke()
                            ctx.shadowBlur = 0
                        }
                    }
                }

                // Lock icon (appears during lock animation)
                Item {
                    id: lockIcon
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    scale: lockIconScale
                    opacity: lockIconScale > 0 ? 1 : 0
                    visible: isLocking

                    Canvas {
                        anchors.fill: parent

                        // Helper function: draw rounded rectangle (QML Canvas doesn't have roundRect)
                        function drawRoundedRect(ctx, x, y, w, h, r) {
                            ctx.beginPath()
                            ctx.moveTo(x + r, y)
                            ctx.lineTo(x + w - r, y)
                            ctx.arcTo(x + w, y, x + w, y + r, r)
                            ctx.lineTo(x + w, y + h - r)
                            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                            ctx.lineTo(x + r, y + h)
                            ctx.arcTo(x, y + h, x, y + h - r, r)
                            ctx.lineTo(x, y + r)
                            ctx.arcTo(x, y, x + r, y, r)
                            ctx.closePath()
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var cx = width / 2
                            var cy = height / 2

                            ctx.fillStyle = "#FFFFFF"
                            ctx.strokeStyle = "#FFFFFF"
                            ctx.lineWidth = 4
                            ctx.lineCap = "round"

                            // Lock body (rounded rectangle)
                            var bodyW = 28
                            var bodyH = 22
                            var bodyR = 4
                            var bodyY = cy - 2

                            drawRoundedRect(ctx, cx - bodyW/2, bodyY, bodyW, bodyH, bodyR)
                            ctx.fill()

                            // Lock shackle (arc)
                            ctx.beginPath()
                            ctx.arc(cx, bodyY - 2, 8, Math.PI, 0)
                            ctx.stroke()
                        }

                        Component.onCompleted: requestPaint()
                    }
                }
            }

            // Instruction text (minimal)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 120
                text: remainingSeconds + " 秒后自动锁定"
                font.pixelSize: 13
                font.weight: Font.Normal
                font.letterSpacing: 0.5
                color: Qt.rgba(1, 1, 1, 0.3)
                opacity: content.fadeIn * (isLocking ? 0 : 1)
                visible: !isLocking

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }

            // Bottom hint
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 50
                text: "移动鼠标或按任意键取消"
                font.pixelSize: 11
                font.weight: Font.Light
                color: Qt.rgba(1, 1, 1, 0.2)
                opacity: content.fadeIn * (isLocking ? 0 : 1)
                visible: !isLocking
            }
        }
    }

    function dismiss() {
        countdownTimer.stop()
        Qt.quit()
    }
}
