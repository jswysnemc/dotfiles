import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

// Unified Lockscreen with Grace Period
// Phase 1 (Grace): User can dismiss by moving mouse/pressing key
// Phase 2 (Locked): Requires PAM authentication to unlock

ShellRoot {
    id: root

    // ==================== Configuration ====================
    // Grace period duration (seconds) - can be set via environment variable
    // Set to 0 to skip grace phase entirely
    property int graceDuration: {
        var envTimeout = Quickshell.env("LOCK_GRACE_TIMEOUT")
        var t = parseInt(envTimeout)
        return (!isNaN(t) && t >= 0) ? t : 5
    }

    // Current phase: "grace" or "locked"
    // If graceDuration is 0, start directly in locked phase
    property string phase: graceDuration > 0 ? "grace" : "locked"
    property int graceRemaining: graceDuration
    property bool inputEnabled: false
    property point lastMousePos: Qt.point(-1, -1)

    // Grace period animation properties
    property real graceProgress: 1.0 - (graceRemaining / graceDuration)
    property real smoothGraceProgress: 0.0
    property bool isTransitioning: false
    property real ringScale: 1.0
    property real lockIconScale: 0.0
    property real transitionFade: 0.0

    Behavior on smoothGraceProgress {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutCubic
        }
    }

    onGraceProgressChanged: smoothGraceProgress = graceProgress

    // ==================== Theme Colors ====================
    readonly property color primaryColor: "#3b82f6"
    readonly property color secondaryColor: "#8b5cf6"
    readonly property color errorColor: "#ef4444"
    readonly property color textColor: "#ffffff"
    readonly property color textMuted: Qt.rgba(1, 1, 1, 0.7)
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.5)

    // ==================== Auth State ====================
    property bool authInProgress: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string userName: Quickshell.env("USER") || "User"
    property string homeDir: Quickshell.env("HOME") || "/home"

    // ==================== Time Properties ====================
    property string currentTime: ""
    property string currentDate: ""
    property string lunarDate: ""
    property string lunarYear: ""
    property string festival: ""
    property string wallpaperPath: ""
    property string screenshotPath: ""  // Screenshot for grace phase

    // ==================== Timers ====================

    // Delay before accepting input in grace phase
    Timer {
        id: inputDelayTimer
        interval: 800
        running: phase === "grace"
        onTriggered: inputEnabled = true
    }

    // Grace period countdown
    Timer {
        id: graceTimer
        interval: 1000
        repeat: true
        running: phase === "grace" && !isTransitioning
        onTriggered: {
            graceRemaining--
            if (graceRemaining <= 0) {
                triggerTransition()
            }
        }
    }

    // Update time every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            currentTime = Qt.formatTime(now, "HH:mm")
            var weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
            currentDate = Qt.formatDate(now, "M月d日 ") + weekdays[now.getDay()]
        }
    }

    // ==================== Processes ====================

    // Get lunar calendar info
    Process {
        id: lunarProcess
        command: [homeDir + "/.config/quickshell/.venv/bin/python",
                  homeDir + "/.config/quickshell/lockscreen/lunar_info.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var info = JSON.parse(data)
                    if (info.hasLunar) {
                        lunarDate = info.lunarFull || ""
                        lunarYear = (info.ganzhiYear || "") + (info.zodiac ? "年 " + info.zodiac + "年" : "")
                        festival = info.festival || ""
                    }
                } catch (e) {
                    console.log("Failed to parse lunar info:", e)
                }
            }
        }
    }

    // Get current wallpaper
    Process {
        id: wallpaperProcess
        command: ["readlink", "-f", homeDir + "/.cache/current_wallpaper"]
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (path) {
                    wallpaperPath = "file://" + path
                }
            }
        }
    }

    // Take screenshot for grace phase blur
    Process {
        id: screenshotProcess
        command: ["grim", "/tmp/lockscreen-screenshot.png"]
        onRunningChanged: {
            if (!running && screenshotPath === "") {
                // Add timestamp to force image reload
                screenshotPath = "file:///tmp/lockscreen-screenshot.png?" + Date.now()
            }
        }
    }

    // Screenshot image loader (outside surface so it loads before lock)
    Image {
        id: screenshotLoader
        source: screenshotPath
        asynchronous: false
        visible: false
        onStatusChanged: {
            if (status === Image.Ready && !sessionLock.locked) {
                sessionLock.locked = true
            }
        }
    }

    // Screenshot ready state
    property bool screenshotReady: screenshotLoader.status === Image.Ready

    Component.onCompleted: {
        lunarProcess.running = true
        wallpaperProcess.running = true
        screenshotProcess.running = true
    }

    // ==================== PAM Authentication ====================
    // 两个独立的 PAM 上下文：
    // - pamFace: 使用 sudo 配置（包含 howdy 人脸识别）
    // - pamPassword: 使用 qs-lock 配置（只有密码）

    PamContext {
        id: pamFace
        config: "sudo"
        user: userName

        onActiveChanged: {
            if (active) {
                authInProgress = true
                statusMessage = "正在进行人脸识别..."
            }
        }

        onPamMessage: {
            console.log("PAM Face message:", pamFace.message, "responseRequired:", pamFace.responseRequired)
            if (pamFace.responseRequired) {
                if (pamFace.responseVisible) {
                    pamFace.respond(userName)
                } else {
                    // howdy 失败后会要求密码，中断 pamFace，让用户用 pamPassword
                    pamFace.abort()
                    statusMessage = "人脸识别失败，请输入密码"
                    authInProgress = false
                }
            } else {
                statusMessage = pamFace.message
            }
        }

        onCompleted: function(result) {
            console.log("PAM Face completed:", result)
            authInProgress = false
            statusMessage = ""

            if (result === PamResult.Success) {
                sessionLock.locked = false
            } else {
                // 人脸识别失败，不显示错误，让用户输入密码
                statusMessage = "请输入密码"
            }
        }

        onError: function(err) {
            console.log("PAM Face error:", err)
            authInProgress = false
            statusMessage = "请输入密码"
        }
    }

    PamContext {
        id: pamPassword
        config: "qs-lock"
        user: userName

        onActiveChanged: {
            if (active) {
                authInProgress = true
                statusMessage = "正在验证密码..."
            }
        }

        onPamMessage: {
            console.log("PAM Password message:", pamPassword.message, "responseRequired:", pamPassword.responseRequired)
            if (pamPassword.responseRequired) {
                // 如果有待处理的密码，直接提交
                if (pendingPassword.length > 0) {
                    pamPassword.respond(pendingPassword)
                    pendingPassword = ""
                    return
                }
                if (pamPassword.responseVisible) {
                    pamPassword.respond(userName)
                } else {
                    statusMessage = pamPassword.message || "请输入密码"
                    authInProgress = false
                }
            } else {
                statusMessage = pamPassword.message
            }
        }

        onCompleted: function(result) {
            console.log("PAM Password completed:", result)
            authInProgress = false
            statusMessage = ""

            if (result === PamResult.Success) {
                sessionLock.locked = false
            } else {
                errorMessage = "密码错误"
                errorClearTimer.restart()
            }
        }

        onError: function(err) {
            console.log("PAM Password error:", err)
            authInProgress = false
            statusMessage = ""
            errorMessage = "认证错误"
            errorClearTimer.restart()
        }
    }

    property string pendingPassword: ""

    Timer {
        id: errorClearTimer
        interval: 3000
        onTriggered: errorMessage = ""
    }

    // ==================== Transition Animation ====================
    function triggerTransition() {
        graceTimer.stop()
        isTransitioning = true
        transitionSequence.start()
    }

    SequentialAnimation {
        id: transitionSequence

        // Ring collapse
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

        // Lock icon pop
        ParallelAnimation {
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

            // Fade transition
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation {
                    target: root
                    property: "transitionFade"
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
                phase = "locked"
                isTransitioning = false
            }
        }
    }

    // ==================== Dismiss Function (Grace Phase Only) ====================
    function dismiss() {
        if (phase === "grace" && !isTransitioning) {
            graceTimer.stop()
            sessionLock.locked = false
        }
    }

    // ==================== Session Lock ====================
    WlSessionLock {
        id: sessionLock
        // If no grace period, lock immediately; otherwise wait for screenshot
        locked: graceDuration === 0

        onLockedChanged: {
            console.log("Session lock changed:", locked)
            if (!locked) {
                Qt.quit()
            }
        }

        surface: Component {
            WlSessionLockSurface {
                id: lockSurface
                color: "#000000"

                // Blurred screenshot - only visible during grace phase
                MultiEffect {
                    anchors.fill: parent
                    source: screenshotLoader
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.6
                    blurMax: 64
                    visible: phase === "grace"
                }

                // Wallpaper background (only visible in locked phase)
                Image {
                    id: wallpaperImage
                    anchors.fill: parent
                    source: wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: phase === "locked"

                    // Fallback gradient if no wallpaper
                    Rectangle {
                        anchors.fill: parent
                        visible: wallpaperImage.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#1a1a2e" }
                            GradientStop { position: 0.5; color: "#16213e" }
                            GradientStop { position: 1.0; color: "#0f0f23" }
                        }
                    }
                }

                // Dark overlay - lighter during grace, darker when locked
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, phase === "grace" ? 0.2 : 0.5)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                // ==================== Grace Phase UI ====================
                Item {
                    id: graceUI
                    anchors.fill: parent
                    opacity: phase === "grace" || isTransitioning ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }

                    // Input detection for grace phase
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        enabled: phase === "grace" && !isTransitioning
                        onPositionChanged: function(mouse) {
                            if (!inputEnabled || isTransitioning) return
                            if (lastMousePos.x >= 0 && lastMousePos.y >= 0) {
                                var dx = Math.abs(mouse.x - lastMousePos.x)
                                var dy = Math.abs(mouse.y - lastMousePos.y)
                                if (dx > 10 || dy > 10) {
                                    root.dismiss()
                                }
                            }
                            lastMousePos = Qt.point(mouse.x, mouse.y)
                        }
                        onClicked: function(mouse) {
                            if (!inputEnabled || isTransitioning) return
                            if (mouse.button === Qt.RightButton) {
                                root.triggerTransition()  // Right click: lock immediately
                            } else {
                                root.dismiss()  // Left click: dismiss
                            }
                        }
                        onWheel: if (inputEnabled && !isTransitioning) root.dismiss()
                    }

                    // Key handler for grace phase
                    Keys.onPressed: function(event) {
                        if (!inputEnabled || isTransitioning) return
                        // Win+L or Super+L: lock immediately
                        if (event.key === Qt.Key_L && (event.modifiers & Qt.MetaModifier)) {
                            root.triggerTransition()
                            event.accepted = true
                            return
                        }
                        // Any other key: dismiss
                        root.dismiss()
                    }
                    focus: phase === "grace"

                    // Center content - Ring progress
                    Item {
                        id: graceCenterContent
                        anchors.centerIn: parent
                        width: 200
                        height: 200

                        // Ring progress indicator
                        Canvas {
                            id: ringCanvas
                            anchors.centerIn: parent
                            width: 140
                            height: 140

                            property real prog: smoothGraceProgress
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
                                ctx.strokeStyle = isTransitioning ? "#FFFFFF" : "rgba(255, 255, 255, 0.08)"
                                ctx.stroke()

                                // Progress arc
                                if (!isTransitioning && prog > 0) {
                                    var startAngle = -Math.PI / 2
                                    var endAngle = startAngle + (Math.PI * 2 * prog)

                                    ctx.beginPath()
                                    ctx.arc(cx, cy, radius, startAngle, endAngle)
                                    ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
                                    ctx.lineWidth = thickness
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }

                                // Glow effect during transition
                                if (isTransitioning && scale > 0.01) {
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

                        // Lock icon (appears during transition)
                        Item {
                            id: lockIcon
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            scale: lockIconScale
                            opacity: lockIconScale > 0 ? 1 : 0
                            visible: isTransitioning

                            Canvas {
                                anchors.fill: parent

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

                                    // Lock body
                                    var bodyW = 28
                                    var bodyH = 22
                                    var bodyR = 4
                                    var bodyY = cy - 2

                                    drawRoundedRect(ctx, cx - bodyW/2, bodyY, bodyW, bodyH, bodyR)
                                    ctx.fill()

                                    // Lock shackle
                                    ctx.beginPath()
                                    ctx.arc(cx, bodyY - 2, 8, Math.PI, 0)
                                    ctx.stroke()
                                }

                                Component.onCompleted: requestPaint()
                            }
                        }
                    }

                    // Grace phase text
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 120
                        text: graceRemaining + " 秒后自动锁定"
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        font.letterSpacing: 0.5
                        color: Qt.rgba(1, 1, 1, 0.3)
                        opacity: isTransitioning ? 0 : 1
                        visible: !isTransitioning

                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }

                    // Bottom hint
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 50
                        text: "移动鼠标或按任意键取消 | 右键或 Super+L 立即锁定"
                        font.pixelSize: 11
                        font.weight: Font.Light
                        color: Qt.rgba(1, 1, 1, 0.2)
                        opacity: isTransitioning ? 0 : 1
                        visible: !isTransitioning
                    }
                }

                // ==================== Locked Phase UI ====================
                Item {
                    id: lockedUI
                    anchors.fill: parent
                    opacity: phase === "locked" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                    }

                    // ===== Top: Clock and Date =====
                    Column {
                        id: clockArea
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: parent.height * 0.1
                        spacing: 8

                        // Time
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: currentTime
                            font.pixelSize: 108
                            font.weight: Font.Light
                            font.letterSpacing: -2
                            color: root.textColor
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.4)
                        }

                        // Solar date
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: currentDate
                            font.pixelSize: 22
                            font.weight: Font.Normal
                            color: root.textMuted
                        }

                        // Lunar date row
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 16
                            visible: lunarDate.length > 0

                            Text {
                                text: lunarYear
                                font.pixelSize: 15
                                color: root.textDim
                            }

                            Rectangle {
                                width: 1
                                height: 14
                                color: root.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: lunarDate
                                font.pixelSize: 15
                                color: root.textDim
                            }
                        }

                        // Festival (if any)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: festival.length > 0
                            width: festivalText.width + 24
                            height: 28
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.15)

                            Text {
                                id: festivalText
                                anchors.centerIn: parent
                                text: festival
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: "#fbbf24"
                            }
                        }
                    }

                    // ===== Center: Login Area =====
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 30
                        spacing: 20
                        width: 340

                        // User avatar
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 100
                            height: 100
                            radius: 50
                            color: authInProgress ? root.secondaryColor :
                                   (avatarMouse.containsMouse ? Qt.lighter(root.primaryColor, 1.2) : root.primaryColor)

                            Behavior on color { ColorAnimation { duration: 200 } }

                            // Glow effect
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 8
                                height: parent.height + 8
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: authInProgress ? root.secondaryColor : root.primaryColor
                                opacity: 0.4

                                SequentialAnimation on scale {
                                    running: authInProgress
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.1; duration: 800; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                }
                            }

                            Text {
                                id: avatarIcon
                                anchors.centerIn: parent
                                text: pamFace.active ? "\uf2f1" : "\uf007"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 44
                                color: root.textColor
                                rotation: pamFace.active ? avatarRotation.rotation : 0

                                RotationAnimator {
                                    id: avatarRotation
                                    target: avatarIcon
                                    running: pamFace.active
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
                                enabled: !pamPassword.active && !pamPassword.responseRequired
                                onClicked: root.startAuth()
                            }
                        }

                        // Username
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: userName
                            font.pixelSize: 24
                            font.weight: Font.Medium
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
                            height: 52
                            radius: 26
                            color: Qt.rgba(1, 1, 1, 0.1)
                            border.color: passwordField.activeFocus ? root.primaryColor : Qt.rgba(1, 1, 1, 0.2)
                            border.width: 2

                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\uf023"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 18
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                }

                                TextInput {
                                    id: passwordField
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 80
                                    color: root.textColor
                                    font.pixelSize: 16
                                    echoMode: TextInput.Password
                                    clip: true

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "输入密码..."
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                        font.pixelSize: 16
                                        visible: !passwordField.text && !passwordField.activeFocus
                                    }

                                    onAccepted: {
                                        if (text.length > 0) {
                                            root.startAuthWithPassword(text)
                                            text = ""
                                        }
                                    }

                                    Keys.onEscapePressed: {
                                        text = ""
                                        errorMessage = ""
                                    }
                                }

                                Text {
                                    id: submitIcon
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: pamPassword.active ? "\uf110" : "\uf054"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 18
                                    color: root.primaryColor
                                    visible: passwordField.text.length > 0 || pamPassword.active
                                    rotation: pamPassword.active ? submitRotation.rotation : 0

                                    RotationAnimator {
                                        id: submitRotation
                                        target: submitIcon
                                        running: pamPassword.active
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
                                            root.startAuthWithPassword(passwordField.text)
                                            passwordField.text = ""
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
                            color: Qt.rgba(1, 1, 1, 0.4)
                            visible: !authInProgress && !pamPassword.responseRequired && passwordField.text.length === 0
                        }
                    }

                    // ===== Bottom: Power Buttons =====
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 50
                        spacing: 50

                        Repeater {
                            model: [
                                { icon: "\uf186", label: "睡眠", cmd: ["systemctl", "suspend"] },
                                { icon: "\uf021", label: "重启", cmd: ["systemctl", "reboot"] },
                                { icon: "\uf011", label: "关机", cmd: ["systemctl", "poweroff"] }
                            ]

                            Column {
                                spacing: 8

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 48
                                    height: 48
                                    radius: 24
                                    color: pwrMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 20
                                        color: pwrMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
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
                                    font.pixelSize: 12
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                }
                            }
                        }
                    }
                }

                // ==================== Global Key Handler ====================
                Item {
                    anchors.fill: parent
                    focus: true

                    Keys.onPressed: function(event) {
                        // Emergency exit: Ctrl+Alt+Q (for testing only)
                        if (event.key === Qt.Key_Q &&
                            (event.modifiers & Qt.ControlModifier) &&
                            (event.modifiers & Qt.AltModifier)) {
                            console.log("Emergency exit triggered")
                            sessionLock.locked = false
                            event.accepted = true
                            return
                        }

                        // Grace phase: any key dismisses
                        if (phase === "grace" && inputEnabled && !isTransitioning) {
                            root.dismiss()
                            event.accepted = true
                            return
                        }

                        // Locked phase: forward to password field
                        if (phase === "locked") {
                            if (!passwordField.activeFocus) {
                                passwordField.forceActiveFocus()
                                if (event.text.length > 0 && !event.modifiers) {
                                    passwordField.text += event.text
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                        forceActiveFocus()
                    }
                }

                Process {
                    id: pwrProc
                    running: false
                }
            }
        }
    }

    // 启动人脸识别（点击头像）
    function startAuth() {
        // 只检查密码认证是否在进行，允许重新触发人脸识别
        if (pamPassword.active) return

        // 如果人脸识别正在进行，先中断
        if (pamFace.active) {
            pamFace.abort()
        }

        errorMessage = ""
        pendingPassword = ""
        authInProgress = true
        statusMessage = "正在进行人脸识别..."
        pamFace.start()
    }

    // 启动密码认证（输入密码后回车）
    function startAuthWithPassword(password) {
        errorMessage = ""

        // 如果人脸识别正在进行，中断它
        if (pamFace.active) {
            pamFace.abort()
        }

        // 如果密码认证正在等待输入，直接提交
        if (pamPassword.responseRequired) {
            pamPassword.respond(password)
            return
        }

        // 如果密码认证已经在进行中，保存密码等待
        if (pamPassword.active) {
            pendingPassword = password
            return
        }

        // 启动密码认证
        pendingPassword = password
        pamPassword.start()
    }
}
