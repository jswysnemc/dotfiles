import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "colors.js" as Colors

FloatingWindow {
    id: popup
    
    implicitWidth: 1100
    implicitHeight: 750
    visible: true
    color: Colors.base
    title: "视觉模型处理"
    
    VisualModelManager {
        id: vmManager
    }
    
    // 文件选择器 Process (使用 yad)
    Process {
        id: filePickerProcess
        command: ["yad", "--file", "--multiple", "--separator=\n",
                  "--file-filter=图片文件|*.png *.jpg *.jpeg *.webp *.bmp *.gif *.PNG *.JPG *.JPEG",
                  "--title=选择图片", "--width=800", "--height=600"]
        
        
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (text.length > 0) {
                    var paths = text.split("\n")
                    for (var i = 0; i < paths.length; i++) {
                        var p = paths[i].trim()
                        if (p.length > 0) {
                            vmManager.addImage(p)
                        }
                    }
                }
            }
        }
    }
    
    // 主内容
    Item {
        id: mainPanel
        anchors.fill: parent
        
        // 标题栏
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: Colors.surface0
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                
                Text {
                    text: "󰄛"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 20
                    color: Colors.primary
                }
                
                Text {
                    text: "视觉模型处理"
                    font.pixelSize: 16
                    font.bold: true
                    color: Colors.text
                }
                
                // 当前模板显示
                Rectangle {
                    Layout.preferredWidth: templateLabel.implicitWidth + 24
                    Layout.preferredHeight: 28
                    radius: 14
                    color: Colors.surface1
                    visible: vmManager.currentTemplate !== null
                    
                    Text {
                        id: templateLabel
                        anchors.centerIn: parent
                        text: vmManager.currentTemplate ? vmManager.currentTemplate.name : ""
                        font.pixelSize: 12
                        color: Colors.green
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // 模板管理按钮
                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 28
                    radius: 14
                    color: templateBtn.containsMouse ? Colors.surface1 : Colors.surface0
                    border.color: Colors.surface1
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒓 模板管理"
                        font.family: "Symbols Nerd Font, sans-serif"
                        font.pixelSize: 12
                        color: Colors.text
                    }
                    
                    MouseArea {
                        id: templateBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: templateDialog.open()
                    }
                }
                
                // 关闭按钮
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: closeBtn.containsMouse ? Colors.red : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: closeBtn.containsMouse ? Colors.base : Colors.red
                    }
                    
                    MouseArea {
                        id: closeBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }
            }
        }
        
        // 内容区域
        RowLayout {
            anchors.top: titleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            spacing: 16
            
            // 左侧 - 图片区域
            Rectangle {
                Layout.preferredWidth: parent.width * 0.4
                Layout.fillHeight: true
                radius: 12
                color: Colors.surface0
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    // 图片区域标题
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "󰋩 图片列表"
                            font.family: "Symbols Nerd Font, sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                            color: Colors.text
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: vmManager.imageList.length + " 张"
                            font.pixelSize: 12
                            color: Colors.overlay
                        }
                    }
                    
                    // 图片列表
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: Colors.base
                        border.color: Colors.surface1
                        border.width: 1
                        
                        // 空状态提示
                        Column {
                            anchors.centerIn: parent
                            spacing: 12
                            visible: vmManager.imageList.length === 0
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰋩"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 48
                                color: Colors.surface1
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "点击下方按钮添加图片"
                                font.pixelSize: 14
                                color: Colors.overlay
                            }
                        }
                        
                        // 图片列表视图
                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 8
                            contentHeight: imageColumn.implicitHeight
                            clip: true
                            visible: vmManager.imageList.length > 0
                            
                            ColumnLayout {
                                id: imageColumn
                                width: parent.width
                                spacing: 8
                                
                                Repeater {
                                    model: vmManager.imageList
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 80
                                        radius: 8
                                        color: imgItemMouse.containsMouse ? Colors.surface1 : Colors.surface0
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 12
                                            
                                            // 图片预览
                                            Rectangle {
                                                Layout.preferredWidth: 64
                                                Layout.preferredHeight: 64
                                                radius: 6
                                                color: Colors.base
                                                clip: true
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    source: "file://" + modelData
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }
                                            
                                            // 文件名
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 4
                                                
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.split("/").pop()
                                                    font.pixelSize: 13
                                                    color: Colors.text
                                                    elide: Text.ElideMiddle
                                                }
                                                
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData
                                                    font.pixelSize: 10
                                                    color: Colors.overlay
                                                    elide: Text.ElideMiddle
                                                }
                                            }
                                            
                                            // 删除按钮
                                            Rectangle {
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                radius: 14
                                                color: delBtn.containsMouse ? Colors.red : "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅖"
                                                    font.family: "Symbols Nerd Font"
                                                    font.pixelSize: 14
                                                    color: delBtn.containsMouse ? Colors.base : Colors.red
                                                }
                                                
                                                MouseArea {
                                                    id: delBtn
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: vmManager.removeImage(index)
                                                }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: imgItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            z: -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 添加图片按钮
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 8
                        color: addImgBtn.containsMouse ? Colors.surface1 : Colors.surface0
                        border.color: Colors.primary
                        border.width: 1
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                text: "󰐕"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: Colors.primary
                            }
                            
                            Text {
                                text: "添加图片"
                                font.pixelSize: 14
                                color: Colors.primary
                            }
                        }
                        
                        MouseArea {
                            id: addImgBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: filePickerProcess.running = true
                        }
                    }
                }
            }
            
            // 右侧 - 日志和结果区域
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                
                // 日志区域
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: 10
                    color: Colors.surface0
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "📋 日志"
                                font.pixelSize: 13
                                font.bold: true
                                color: Colors.yellow
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 22
                                radius: 11
                                color: clearLogBtn.containsMouse ? Colors.surface1 : "transparent"
                                visible: vmManager.logOutput.length > 0
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "清空"
                                    font.pixelSize: 10
                                    color: Colors.overlay
                                }
                                
                                MouseArea {
                                    id: clearLogBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: vmManager.logOutput = ""
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            color: Colors.base
                            border.color: Colors.surface1
                            border.width: 1
                            
                            Flickable {
                                id: logFlick
                                anchors.fill: parent
                                anchors.margins: 6
                                contentHeight: logText.implicitHeight
                                clip: true
                                
                                Text {
                                    id: logText
                                    width: parent.width
                                    text: vmManager.logOutput || "等待运行..."
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    color: vmManager.logOutput ? Colors.subtext : Colors.overlay
                                    wrapMode: Text.Wrap
                                }
                                
                                onContentHeightChanged: {
                                    if (contentHeight > height) {
                                        contentY = contentHeight - height
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 结果区域
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Colors.surface0
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "✨ 结果"
                                font.pixelSize: 13
                                font.bold: true
                                color: Colors.green
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 22
                                radius: 11
                                color: copyBtn.containsMouse ? Colors.surface1 : "transparent"
                                visible: vmManager.hasResult
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "复制"
                                    font.pixelSize: 10
                                    color: Colors.overlay
                                }
                                
                                MouseArea {
                                    id: copyBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        resultArea.selectAll()
                                        resultArea.copy()
                                        resultArea.deselect()
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            color: Colors.base
                            border.color: vmManager.hasResult ? Colors.green : Colors.surface1
                            border.width: 1
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                visible: !vmManager.hasResult && !vmManager.isProcessing
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰊕"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 36
                                    color: Colors.surface1
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: vmManager.templates.length === 0 ? "请先创建模板" : "点击开始处理"
                                    font.pixelSize: 12
                                    color: Colors.overlay
                                }
                            }
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                visible: vmManager.isProcessing && !vmManager.hasResult
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰦖"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 36
                                    color: Colors.primary
                                    
                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: vmManager.isProcessing
                                    }
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "处理中..."
                                    font.pixelSize: 12
                                    color: Colors.primary
                                }
                            }
                            
                            Flickable {
                                id: resultFlick
                                anchors.fill: parent
                                anchors.margins: 6
                                contentHeight: resultArea.implicitHeight
                                clip: true
                                visible: vmManager.hasResult
                                
                                TextArea {
                                    id: resultArea
                                    width: parent.width
                                    text: vmManager.result
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                    color: Colors.text
                                    wrapMode: Text.Wrap
                                    selectByMouse: true
                                    background: null
                                    
                                    onTextChanged: {
                                        vmManager.result = text
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 操作按钮行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    // 模板选择下拉
                    Rectangle {
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 36
                        radius: 6
                        color: templateSelect.containsMouse ? Colors.surface1 : Colors.base
                        border.color: Colors.surface1
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            
                            Text {
                                Layout.fillWidth: true
                                text: vmManager.currentTemplate ? vmManager.currentTemplate.name : "选择模板..."
                                font.pixelSize: 12
                                color: vmManager.currentTemplate ? Colors.text : Colors.overlay
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "󰅀"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: Colors.overlay
                            }
                        }
                        
                        MouseArea {
                            id: templateSelect
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: templateMenu.open()
                        }
                        
                        Popup {
                            id: templateMenu
                            x: 0
                            y: -implicitHeight - 4
                            width: parent.width + 60
                            padding: 4
                            
                            background: Rectangle {
                                color: Colors.surface0
                                radius: 6
                                border.color: Colors.surface1
                                border.width: 1
                            }
                            
                            contentItem: ColumnLayout {
                                spacing: 2
                                
                                Text {
                                    Layout.fillWidth: true
                                    Layout.margins: 6
                                    text: "暂无模板"
                                    font.pixelSize: 11
                                    color: Colors.overlay
                                    visible: vmManager.templates.length === 0
                                }
                                
                                Repeater {
                                    model: vmManager.templates
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: 4
                                        color: menuItemMouse.containsMouse ? Colors.surface1 : "transparent"
                                        
                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            text: modelData.name
                                            font.pixelSize: 12
                                            color: Colors.text
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        MouseArea {
                                            id: menuItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                vmManager.selectTemplate(index)
                                                templateMenu.close()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // 停止按钮
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 36
                        radius: 6
                        color: stopBtn.containsMouse ? Colors.red : Colors.surface1
                        visible: vmManager.isProcessing
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "󰓛"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                color: stopBtn.containsMouse ? Colors.base : Colors.red
                            }
                            
                            Text {
                                text: "停止"
                                font.pixelSize: 13
                                color: stopBtn.containsMouse ? Colors.base : Colors.red
                            }
                        }
                        
                        MouseArea {
                            id: stopBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: vmManager.stopProcess()
                        }
                    }
                    
                    // 开始处理按钮
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        radius: 6
                        color: startBtn.containsMouse ? Colors.green : Colors.primary
                        visible: !vmManager.isProcessing
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "󰐊"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: Colors.base
                            }
                            
                            Text {
                                text: "开始处理"
                                font.pixelSize: 13
                                font.bold: true
                                color: Colors.base
                            }
                        }
                        
                        MouseArea {
                            id: startBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: vmManager.startProcess()
                        }
                    }
                }
            }
        }
    }
    
    // 模板管理对话框
    Popup {
        id: templateDialog
        anchors.centerIn: parent
        width: 500
        height: 500
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        
        background: Rectangle {
            color: Colors.base
            radius: 16
            border.color: Colors.surface1
            border.width: 1
        }
        
        property bool isEditing: false
        property int editingIndex: -1
        property string editName: ""
        property string editCode: ""
        property string editPrompt: ""
        
        contentItem: ColumnLayout {
            spacing: 0
            
            // 对话框标题
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Colors.surface0
                radius: 16
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 16
                    color: parent.color
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    
                    Text {
                        text: templateDialog.isEditing ? (templateDialog.editingIndex >= 0 ? "编辑模板" : "新建模板") : "模板管理"
                        font.pixelSize: 16
                        font.bold: true
                        color: Colors.text
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // 返回列表按钮
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: backBtn.containsMouse ? Colors.surface1 : "transparent"
                        visible: templateDialog.isEditing
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰁍"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: Colors.text
                        }
                        
                        MouseArea {
                            id: backBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: templateDialog.isEditing = false
                        }
                    }
                    
                    // 关闭按钮
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: dialogCloseBtn.containsMouse ? Colors.red : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: dialogCloseBtn.containsMouse ? Colors.base : Colors.red
                        }
                        
                        MouseArea {
                            id: dialogCloseBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: templateDialog.close()
                        }
                    }
                }
            }
            
            // 模板列表视图
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                visible: !templateDialog.isEditing
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    // 空状态
                    Column {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: vmManager.templates.length === 0
                        
                        Item { Layout.fillWidth: true; Layout.fillHeight: true }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰒓"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 64
                            color: Colors.surface1
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "暂无模板"
                            font.pixelSize: 16
                            color: Colors.overlay
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "点击下方按钮创建你的第一个模板"
                            font.pixelSize: 13
                            color: Colors.overlay
                        }
                        
                        Item { Layout.fillWidth: true; Layout.fillHeight: true }
                    }
                    
                    // 模板列表
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: templateListCol.implicitHeight
                        clip: true
                        visible: vmManager.templates.length > 0
                        
                        ColumnLayout {
                            id: templateListCol
                            width: parent.width
                            spacing: 8
                            
                            Repeater {
                                model: vmManager.templates
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    radius: 8
                                    color: tplItemMouse.containsMouse ? Colors.surface1 : Colors.surface0
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12
                                        
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            
                                            RowLayout {
                                                spacing: 8
                                                
                                                Text {
                                                    text: modelData.name
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: Colors.text
                                                }
                                                
                                                Rectangle {
                                                    width: codeLabel.implicitWidth + 12
                                                    height: 20
                                                    radius: 10
                                                    color: Colors.surface1
                                                    
                                                    Text {
                                                        id: codeLabel
                                                        anchors.centerIn: parent
                                                        text: modelData.code
                                                        font.pixelSize: 10
                                                        color: Colors.primary
                                                    }
                                                }
                                            }
                                            
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.prompt
                                                font.pixelSize: 11
                                                color: Colors.overlay
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                        
                                        // 编辑按钮
                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: editTplBtn.containsMouse ? Colors.primary : "transparent"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰏫"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 14
                                                color: editTplBtn.containsMouse ? Colors.base : Colors.primary
                                            }
                                            
                                            MouseArea {
                                                id: editTplBtn
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    templateDialog.editingIndex = index
                                                    templateDialog.editName = modelData.name
                                                    templateDialog.editCode = modelData.code
                                                    templateDialog.editPrompt = modelData.prompt
                                                    templateDialog.isEditing = true
                                                }
                                            }
                                        }
                                        
                                        // 删除按钮
                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: delTplBtn.containsMouse ? Colors.red : "transparent"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰆴"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 14
                                                color: delTplBtn.containsMouse ? Colors.base : Colors.red
                                            }
                                            
                                            MouseArea {
                                                id: delTplBtn
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: vmManager.deleteTemplate(index)
                                            }
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: tplItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        z: -1
                                    }
                                }
                            }
                        }
                    }
                    
                    // 新建模板按钮
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 8
                        color: newTplBtn.containsMouse ? Colors.surface1 : Colors.surface0
                        border.color: Colors.green
                        border.width: 1
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                text: "󰐕"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: Colors.green
                            }
                            
                            Text {
                                text: "新建模板"
                                font.pixelSize: 14
                                color: Colors.green
                            }
                        }
                        
                        MouseArea {
                            id: newTplBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                templateDialog.editingIndex = -1
                                templateDialog.editName = ""
                                templateDialog.editCode = ""
                                templateDialog.editPrompt = ""
                                templateDialog.isEditing = true
                            }
                        }
                    }
                }
            }
            
            // 编辑模板视图
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                visible: templateDialog.isEditing
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16
                    
                    // 模板名称
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        
                        Text {
                            text: "模板名称"
                            font.pixelSize: 13
                            color: Colors.text
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 8
                            color: Colors.surface0
                            border.color: nameInput.activeFocus ? Colors.primary : Colors.surface1
                            border.width: 1
                            
                            TextInput {
                                id: nameInput
                                anchors.fill: parent
                                anchors.margins: 12
                                text: templateDialog.editName
                                font.pixelSize: 14
                                color: Colors.text
                                clip: true
                                
                                onTextChanged: templateDialog.editName = text
                            }
                        }
                    }
                    
                    // 命令代号
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        
                        Text {
                            text: "命令代号 (用于命令行调用)"
                            font.pixelSize: 13
                            color: Colors.text
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 8
                            color: Colors.surface0
                            border.color: codeInput.activeFocus ? Colors.primary : Colors.surface1
                            border.width: 1
                            
                            TextInput {
                                id: codeInput
                                anchors.fill: parent
                                anchors.margins: 12
                                text: templateDialog.editCode
                                font.pixelSize: 14
                                font.family: "monospace"
                                color: Colors.text
                                clip: true
                                
                                onTextChanged: templateDialog.editCode = text
                            }
                        }
                    }
                    
                    // 提示词
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        
                        Text {
                            text: "提示词内容"
                            font.pixelSize: 13
                            color: Colors.text
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: Colors.surface0
                            border.color: promptArea.activeFocus ? Colors.primary : Colors.surface1
                            border.width: 1
                            
                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 8
                                contentHeight: promptArea.implicitHeight
                                clip: true
                                
                                TextArea {
                                    id: promptArea
                                    width: parent.width
                                    text: templateDialog.editPrompt
                                    font.pixelSize: 13
                                    color: Colors.text
                                    wrapMode: Text.Wrap
                                    background: null
                                    placeholderText: "输入提示词，例如：请识别这张图片中的所有文字内容..."
                                    placeholderTextColor: Colors.overlay
                                    
                                    onTextChanged: templateDialog.editPrompt = text
                                }
                            }
                        }
                    }
                    
                    // 保存按钮
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 8
                        color: saveTemplateBtn.containsMouse ? Colors.green : Colors.primary
                        
                        Text {
                            anchors.centerIn: parent
                            text: templateDialog.editingIndex >= 0 ? "保存修改" : "创建模板"
                            font.pixelSize: 14
                            font.bold: true
                            color: Colors.base
                        }
                        
                        MouseArea {
                            id: saveTemplateBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (templateDialog.editName.trim().length === 0) {
                                    return
                                }
                                if (templateDialog.editCode.trim().length === 0) {
                                    return
                                }
                                
                                if (templateDialog.editingIndex >= 0) {
                                    vmManager.updateTemplate(
                                        templateDialog.editingIndex,
                                        templateDialog.editName.trim(),
                                        templateDialog.editCode.trim(),
                                        templateDialog.editPrompt.trim()
                                    )
                                } else {
                                    vmManager.addTemplate(
                                        templateDialog.editName.trim(),
                                        templateDialog.editCode.trim(),
                                        templateDialog.editPrompt.trim()
                                    )
                                }
                                
                                templateDialog.isEditing = false
                            }
                        }
                    }
                }
            }
        }
    }
}
