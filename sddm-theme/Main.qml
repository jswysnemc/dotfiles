import QtQuick 2.7
import SddmComponents 2.0

Rectangle {
    id: root
    width: 640
    height: 480
    
    property string fontName: config.fontFamily || "Noto Sans CJK SC"
    property int currentSessionIndex: sessionModel.lastIndex
    property bool sessionMenuOpen: false
    property string authStatus: ""  // "", "scanning", "success", "failed"
    property string statusMessage: ""
    property bool virtualKeyboardVisible: false

    // 背景图片
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        visible: config.type !== "color"
    }
    
    Rectangle {
        id: backgroundSolid
        anchors.fill: parent
        color: config.color || "#1e293b"
        visible: config.type === "color"
    }

    // 暗色遮罩
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.25
    }

    // 主内容区
    Item {
        id: mainContent
        anchors.centerIn: parent
        width: 340
        height: 600

        // 时间
        Text {
            id: timeText
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            color: "white"
            font.pixelSize: 72
            font.family: root.fontName
            font.weight: Font.Light
            
            layer.enabled: true
            layer.effect: ShaderEffect {
                fragmentShader: "
                    varying highp vec2 qt_TexCoord0;
                    uniform sampler2D source;
                    uniform lowp float qt_Opacity;
                    void main() {
                        lowp vec4 tex = texture2D(source, qt_TexCoord0);
                        gl_FragColor = vec4(tex.rgb, tex.a * qt_Opacity);
                    }"
            }
        }

        // 公历日期
        Text {
            id: dateText
            anchors.top: timeText.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), Qt.DefaultLocaleLongDate)
            color: "white"
            opacity: 0.85
            font.pixelSize: 14
            font.family: root.fontName
        }

        // 农历日期
        Text {
            id: lunarText
            anchors.top: dateText.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            text: getLunarDate(new Date())
            color: "white"
            opacity: 0.65
            font.pixelSize: 13
            font.family: root.fontName
        }

        // 头像容器
        Rectangle {
            id: avatarContainer
            anchors.top: lunarText.bottom
            anchors.topMargin: 25
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96
            height: 96
            radius: 48
            color: "transparent"
            border.width: 3
            border.color: {
                if (root.authStatus === "scanning") return "#60a5fa"
                if (root.authStatus === "success") return "#4ade80"
                if (root.authStatus === "failed") return "#f87171"
                return "#60ffffff"
            }
            clip: true

            Behavior on border.color { ColorAnimation { duration: 200 } }

            // 扫描动画光圈
            Rectangle {
                id: scanRing
                anchors.centerIn: parent
                width: parent.width + 12
                height: parent.height + 12
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: "#60a5fa"
                opacity: 0
                visible: root.authStatus === "scanning"

                SequentialAnimation on opacity {
                    running: root.authStatus === "scanning"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.8; duration: 600 }
                    NumberAnimation { to: 0; duration: 600 }
                }

                SequentialAnimation on scale {
                    running: root.authStatus === "scanning"
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.35; duration: 1200 }
                    NumberAnimation { to: 1.0; duration: 0 }
                }
            }

            Image {
                id: userAvatar
                anchors.fill: parent
                anchors.margins: 3
                source: usernameInput.text ? "file:///home/" + usernameInput.text + "/.face" : ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                
                layer.enabled: true
                layer.effect: ShaderEffect {
                    fragmentShader: "
                        uniform sampler2D source;
                        uniform highp float qt_Opacity;
                        varying highp vec2 qt_TexCoord0;
                        void main() {
                            highp vec4 tex = texture2D(source, qt_TexCoord0);
                            highp float dist = distance(qt_TexCoord0, vec2(0.5));
                            gl_FragColor = dist < 0.5 ? tex * qt_Opacity : vec4(0.0);
                        }"
                }
            }

            Image {
                id: defaultAvatar
                anchors.fill: parent
                source: "default-avatar.svg"
                fillMode: Image.PreserveAspectFit
                visible: userAvatar.status !== Image.Ready
            }
        }

        // 状态提示
        Text {
            id: statusText
            anchors.top: avatarContainer.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.statusMessage
            color: {
                if (root.authStatus === "scanning") return "#60a5fa"
                if (root.authStatus === "success") return "#4ade80"
                if (root.authStatus === "failed") return "#f87171"
                return "white"
            }
            font.pixelSize: 13
            font.family: root.fontName
            opacity: root.statusMessage ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // 用户名输入
        Rectangle {
            id: usernameField
            anchors.top: avatarContainer.bottom
            anchors.topMargin: 35
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260
            height: 48
            radius: 24
            color: usernameInput.activeFocus ? "#55000000" : "#40000000"
            border.width: 1
            border.color: usernameInput.activeFocus ? "#a0ffffff" : "#50ffffff"

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: !usernameInput.text && !usernameInput.activeFocus

                Image {
                    source: "icons/user.svg"
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: 0.7
                }

                Text {
                    text: "用户名"
                    color: "#a0ffffff"
                    font.pixelSize: 14
                    font.family: root.fontName
                }
            }

            TextInput {
                id: usernameInput
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                color: "white"
                font.pixelSize: 15
                font.family: root.fontName
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                text: userModel.lastUser || ""
                activeFocusOnTab: true
                KeyNavigation.tab: passwordInput
                KeyNavigation.backtab: passwordInput
            }
        }

        // 密码输入
        Rectangle {
            id: passwordField
            anchors.top: usernameField.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260
            height: 48
            radius: 24
            color: passwordInput.activeFocus ? "#55000000" : "#40000000"
            border.width: root.authStatus === "failed" ? 2 : 1
            border.color: {
                if (root.authStatus === "failed") return "#f87171"
                return passwordInput.activeFocus ? "#a0ffffff" : "#50ffffff"
            }

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // 抖动动画
            SequentialAnimation {
                id: shakeAnimation
                PropertyAnimation { target: passwordField; property: "x"; to: passwordField.x - 12; duration: 50 }
                PropertyAnimation { target: passwordField; property: "x"; to: passwordField.x + 12; duration: 50 }
                PropertyAnimation { target: passwordField; property: "x"; to: passwordField.x - 12; duration: 50 }
                PropertyAnimation { target: passwordField; property: "x"; to: passwordField.x + 12; duration: 50 }
                PropertyAnimation { target: passwordField; property: "x"; to: passwordField.x; duration: 50 }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: !passwordInput.text && !passwordInput.activeFocus

                Image {
                    source: "icons/lock.svg"
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: 0.7
                }

                Text {
                    text: "密码"
                    color: "#a0ffffff"
                    font.pixelSize: 14
                    font.family: root.fontName
                }
            }

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                color: "white"
                font.pixelSize: 16
                font.family: root.fontName
                echoMode: TextInput.Password
                passwordCharacter: "●"
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                focus: true
                activeFocusOnTab: true
                KeyNavigation.tab: usernameInput
                KeyNavigation.backtab: usernameInput

                onAccepted: doLogin()
            }
        }

        // 登录按钮区域
        Row {
            id: loginRow
            anchors.top: passwordField.bottom
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            // 虚拟键盘按钮
            Rectangle {
                id: keyboardBtn
                width: 46
                height: 46
                radius: 23
                color: keyboardArea.containsMouse ? "#55000000" : "#40000000"
                border.width: 1
                border.color: root.virtualKeyboardVisible ? "#60a5fa" : "#50ffffff"

                Behavior on color { ColorAnimation { duration: 150 } }

                Image {
                    anchors.centerIn: parent
                    source: "icons/keyboard.svg"
                    width: 24
                    height: 24
                }

                MouseArea {
                    id: keyboardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.virtualKeyboardVisible = !root.virtualKeyboardVisible
                }
            }

            // 人脸识别按钮
            Rectangle {
                id: faceBtn
                width: 46
                height: 46
                radius: 23
                color: {
                    if (root.authStatus === "scanning") return "#50306090"
                    return faceArea.containsMouse ? "#55000000" : "#40000000"
                }
                border.width: 1
                border.color: root.authStatus === "scanning" ? "#60a5fa" : "#50ffffff"

                Behavior on color { ColorAnimation { duration: 150 } }

                Image {
                    anchors.centerIn: parent
                    source: "icons/face.svg"
                    width: 24
                    height: 24

                    RotationAnimation on rotation {
                        running: root.authStatus === "scanning"
                        from: 0
                        to: 360
                        duration: 2000
                        loops: Animation.Infinite
                    }
                }

                MouseArea {
                    id: faceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: triggerFaceAuth()
                }
            }

            // 登录按钮
            Rectangle {
                id: loginBtn
                width: 140
                height: 46
                radius: 23
                color: loginArea.pressed ? "#2563eb" : "#3b82f6"

                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        source: "icons/login.svg"
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "登 录"
                        color: "white"
                        font.pixelSize: 15
                        font.family: root.fontName
                        font.bold: true
                    }
                }

                MouseArea {
                    id: loginArea
                    anchors.fill: parent
                    onClicked: doLogin()
                }
            }
        }

        // 底部栏
        Row {
            id: bottomRow
            anchors.top: loginRow.bottom
            anchors.topMargin: 30
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            // 桌面环境选择器
            Rectangle {
                id: sessionSelector
                width: sessionContent.width + 24
                height: 34
                radius: 17
                color: sessionArea.containsMouse ? "#50000000" : "#35000000"
                border.width: 1
                border.color: "#50ffffff"

                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: sessionContent
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        source: "icons/desktop.svg"
                        width: 14
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: sessionList.currentItem ? sessionList.currentItem.sessionName : "默认"
                        color: "white"
                        font.pixelSize: 12
                        font.family: root.fontName
                    }

                    Text {
                        text: root.sessionMenuOpen ? "▲" : "▼"
                        color: "#b0ffffff"
                        font.pixelSize: 8
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: sessionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.sessionMenuOpen = !root.sessionMenuOpen
                }
            }

            // 分隔线
            Rectangle {
                width: 1
                height: 22
                color: "#50ffffff"
                anchors.verticalCenter: parent.verticalCenter
            }

            // 睡眠
            Rectangle {
                width: 58
                height: 34
                radius: 17
                color: sleepArea.containsMouse ? "#50000000" : "#35000000"
                border.width: 1
                border.color: "#50ffffff"

                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Image {
                        source: "icons/sleep.svg"
                        width: 12
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "睡眠"
                        color: "#e0ffffff"
                        font.pixelSize: 11
                        font.family: root.fontName
                    }
                }

                MouseArea {
                    id: sleepArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sddm.suspend()
                }
            }

            // 重启
            Rectangle {
                width: 58
                height: 34
                radius: 17
                color: rebootArea.containsMouse ? "#50000000" : "#35000000"
                border.width: 1
                border.color: "#50ffffff"

                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Image {
                        source: "icons/reboot.svg"
                        width: 12
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "重启"
                        color: "#e0ffffff"
                        font.pixelSize: 11
                        font.family: root.fontName
                    }
                }

                MouseArea {
                    id: rebootArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sddm.reboot()
                }
            }

            // 关机
            Rectangle {
                width: 58
                height: 34
                radius: 17
                color: poweroffArea.containsMouse ? "#50100000" : "#35100000"
                border.width: 1
                border.color: "#70ef4444"

                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Image {
                        source: "icons/power.svg"
                        width: 12
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "关机"
                        color: "#fca5a5"
                        font.pixelSize: 11
                        font.family: root.fontName
                    }
                }

                MouseArea {
                    id: poweroffArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sddm.powerOff()
                }
            }
        }

        // 下拉菜单
        Rectangle {
            id: sessionMenu
            anchors.bottom: bottomRow.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: 180
            height: sessionModel.count * 38 + 12
            radius: 16
            color: "#e0181820"
            border.width: 1
            border.color: "#60ffffff"
            visible: root.sessionMenuOpen
            z: 999

            ListView {
                id: sessionList
                anchors.fill: parent
                anchors.margins: 6
                model: sessionModel
                currentIndex: root.currentSessionIndex
                interactive: false
                
                delegate: Rectangle {
                    width: parent.width
                    height: 36
                    radius: 10
                    color: menuItemArea.containsMouse ? "#50ffffff" : "transparent"
                    
                    property string sessionName: name
                    
                    Text {
                        anchors.centerIn: parent
                        text: name
                        color: index === root.currentSessionIndex ? "#60a5fa" : "white"
                        font.pixelSize: 12
                        font.family: root.fontName
                        font.bold: index === root.currentSessionIndex
                    }
                    
                    MouseArea {
                        id: menuItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.currentSessionIndex = index
                            sessionList.currentIndex = index
                            root.sessionMenuOpen = false
                        }
                    }
                }
            }
        }
    }

    // ========== PAM 状态处理 ==========
    Connections {
        target: sddm
        
        function onLoginFailed() {
            root.authStatus = "failed"
            root.statusMessage = "认证失败，请重试"
            shakeAnimation.start()
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
            clearStatusTimer.start()
        }
        
        function onLoginSucceeded() {
            root.authStatus = "success"
            root.statusMessage = "认证成功"
        }
    }

    Timer {
        id: clearStatusTimer
        interval: 3000
        onTriggered: {
            root.authStatus = ""
            root.statusMessage = ""
        }
    }

    // ========== 函数 ==========
    function triggerFaceAuth() {
        if (usernameInput.text) {
            root.authStatus = "scanning"
            root.statusMessage = "正在进行人脸识别..."
            sddm.login(usernameInput.text, "", root.currentSessionIndex)
        }
    }

    function doLogin() {
        root.authStatus = ""
        root.statusMessage = ""
        sddm.login(usernameInput.text, passwordInput.text, root.currentSessionIndex)
    }

    // ========== 农历计算函数 ==========
    function getLunarDate(date) {
        var lunarInfo = [
            0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
            0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
            0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
            0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
            0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
            0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5d0, 0x14573, 0x052d0, 0x0a9a8, 0x0e950, 0x06aa0,
            0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
            0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b5a0, 0x195a6,
            0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
            0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
            0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
            0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
            0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
            0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
            0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0
        ];

        var tianGan = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"];
        var diZhi = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"];
        var animals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"];
        var lunarMonths = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"];
        var lunarDays = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                         "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                         "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"];

        function lYearDays(y) {
            var sum = 348;
            for (var i = 0x8000; i > 0x8; i >>= 1) sum += (lunarInfo[y - 1900] & i) ? 1 : 0;
            return sum + leapDays(y);
        }

        function leapDays(y) {
            if (leapMonth(y)) return (lunarInfo[y - 1900] & 0x10000) ? 30 : 29;
            return 0;
        }

        function leapMonth(y) {
            return lunarInfo[y - 1900] & 0xf;
        }

        function monthDays(y, m) {
            return (lunarInfo[y - 1900] & (0x10000 >> m)) ? 30 : 29;
        }

        var baseDate = new Date(1900, 0, 31);
        var offset = Math.floor((date - baseDate) / 86400000);

        var year = 1900;
        var temp = 0;
        for (year = 1900; year < 2100 && offset > 0; year++) {
            temp = lYearDays(year);
            offset -= temp;
        }
        if (offset < 0) {
            offset += temp;
            year--;
        }

        var leap = leapMonth(year);
        var isLeap = false;
        var month = 1;
        for (month = 1; month < 13 && offset > 0; month++) {
            if (leap > 0 && month === (leap + 1) && !isLeap) {
                --month;
                isLeap = true;
                temp = leapDays(year);
            } else {
                temp = monthDays(year, month);
            }
            if (isLeap && month === (leap + 1)) isLeap = false;
            offset -= temp;
        }
        if (offset === 0 && leap > 0 && month === leap + 1) {
            if (isLeap) isLeap = false;
            else { isLeap = true; --month; }
        }
        if (offset < 0) { offset += temp; --month; }

        var day = offset + 1;
        var ganIndex = (year - 4) % 10;
        var zhiIndex = (year - 4) % 12;

        return tianGan[ganIndex] + diZhi[zhiIndex] + "年 " + 
               (isLeap ? "闰" : "") + lunarMonths[month - 1] + "月" + lunarDays[day - 1] + 
               " 【" + animals[zhiIndex] + "年】";
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.sessionMenuOpen = false
            passwordInput.forceActiveFocus()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            timeText.text = Qt.formatTime(new Date(), "HH:mm")
            dateText.text = Qt.formatDate(new Date(), Qt.DefaultLocaleLongDate)
            lunarText.text = getLunarDate(new Date())
        }
    }
    
    // 自动触发 PAM 认证
    Timer {
        id: autoLoginTimer
        interval: 1500
        running: true
        repeat: false
        onTriggered: triggerFaceAuth()
    }

    // ========== 虚拟键盘 ==========
    Rectangle {
        id: virtualKeyboard
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 40, 680)
        height: 280
        radius: 20
        color: "#e8151520"
        border.width: 1
        border.color: "#60ffffff"
        visible: root.virtualKeyboardVisible
        z: 1000

        property bool shiftPressed: false
        property bool capsLock: false
        property var targetInput: passwordInput.activeFocus ? passwordInput : usernameInput

        // 关闭按钮
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            width: 32
            height: 32
            radius: 16
            color: closeArea.containsMouse ? "#50ffffff" : "#30ffffff"

            Text {
                anchors.centerIn: parent
                text: "×"
                color: "white"
                font.pixelSize: 20
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.virtualKeyboardVisible = false
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 8

            // 数字行
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ? 
                           ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+"] :
                           ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
                    delegate: KeyButton { keyText: modelData }
                }
            }

            // 第一行字母
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ?
                           ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "{", "}"] :
                           ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]"]
                    delegate: KeyButton { keyText: modelData }
                }
            }

            // 第二行字母
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ?
                           ["A", "S", "D", "F", "G", "H", "J", "K", "L", ":", "\""] :
                           ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"]
                    delegate: KeyButton { keyText: modelData }
                }
            }

            // 第三行字母
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                // Shift键
                Rectangle {
                    width: 76
                    height: 44
                    radius: 10
                    color: virtualKeyboard.shiftPressed ? "#60a5fa" : (shiftArea.containsMouse ? "#60ffffff" : "#45ffffff")
                    border.width: 1
                    border.color: virtualKeyboard.shiftPressed ? "#80a5fa" : "#30ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "Shift"
                        color: "white"
                        font.pixelSize: 13
                        font.family: root.fontName
                    }

                    MouseArea {
                        id: shiftArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: virtualKeyboard.shiftPressed = !virtualKeyboard.shiftPressed
                    }
                }

                Repeater {
                    model: virtualKeyboard.shiftPressed || virtualKeyboard.capsLock ?
                           ["Z", "X", "C", "V", "B", "N", "M", "<", ">", "?"] :
                           ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
                    delegate: KeyButton { keyText: modelData }
                }

                // 退格键
                Rectangle {
                    width: 76
                    height: 44
                    radius: 10
                    color: bsArea.containsMouse ? "#60ffffff" : "#45ffffff"
                    border.width: 1
                    border.color: "#30ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "⌫"
                        color: "white"
                        font.pixelSize: 22
                    }

                    MouseArea {
                        id: bsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            var input = virtualKeyboard.targetInput
                            if (input.text.length > 0) {
                                input.text = input.text.slice(0, -1)
                            }
                        }
                    }
                }
            }

            // 空格行
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                // Caps Lock
                Rectangle {
                    width: 76
                    height: 44
                    radius: 10
                    color: virtualKeyboard.capsLock ? "#60a5fa" : (capsArea.containsMouse ? "#60ffffff" : "#45ffffff")
                    border.width: 1
                    border.color: virtualKeyboard.capsLock ? "#80a5fa" : "#30ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "Caps"
                        color: "white"
                        font.pixelSize: 13
                        font.family: root.fontName
                    }

                    MouseArea {
                        id: capsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: virtualKeyboard.capsLock = !virtualKeyboard.capsLock
                    }
                }

                // 空格键
                Rectangle {
                    width: 300
                    height: 44
                    radius: 10
                    color: spaceArea.containsMouse ? "#60ffffff" : "#45ffffff"
                    border.width: 1
                    border.color: "#30ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "Space"
                        color: "white"
                        font.pixelSize: 13
                        font.family: root.fontName
                    }

                    MouseArea {
                        id: spaceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: virtualKeyboard.targetInput.text += " "
                    }
                }

                // 回车键
                Rectangle {
                    width: 100
                    height: 44
                    radius: 10
                    color: enterArea.containsMouse ? "#3b82f6" : "#2563eb"

                    Text {
                        anchors.centerIn: parent
                        text: "Enter ↵"
                        color: "white"
                        font.pixelSize: 13
                        font.family: root.fontName
                        font.bold: true
                    }

                    MouseArea {
                        id: enterArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: doLogin()
                    }
                }
            }
        }
    }

    Component.onCompleted: passwordInput.forceActiveFocus()
}
