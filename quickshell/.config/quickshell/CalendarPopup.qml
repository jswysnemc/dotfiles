import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "colors.js" as Colors

PanelWindow {
    id: popup
    
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    visible: true
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "calendar-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    // 点击外部关闭
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    
    // 日历管理器
    CalendarManager {
        id: calendarManager
    }
    
    // 主容器
    Rectangle {
        id: background
        anchors.top: parent.top
        // anchors.horizontalCenter: parent.horizontalCenter
        anchors.right: parent.right  // 右侧对齐
        anchors.topMargin: 0
        anchors.rightMargin: 80
        width: 380
        height: contentColumn.implicitHeight + 32
        color: Colors.base
        radius: 16
        border.color: Colors.surface1
        border.width: 1
        
        // 滚轮切换月份/年份
        MouseArea {
            anchors.fill: parent
            onClicked: {}
            onWheel: (wheel) => {
                if (background.yearSelectMode) {
                    // 年份选择模式：滚轮切换年份范围
                    if (wheel.angleDelta.y > 0) {
                        background.yearSelectBase -= 12
                    } else if (wheel.angleDelta.y < 0) {
                        background.yearSelectBase += 12
                    }
                } else {
                    // 日历模式：滚轮切换月份
                    if (wheel.angleDelta.y > 0) {
                        calendarManager.prevMonth()
                    } else if (wheel.angleDelta.y < 0) {
                        calendarManager.nextMonth()
                    }
                }
            }
        }
        
        // 年份选择状态
        property bool yearSelectMode: false
        property int yearSelectBase: calendarManager.currentYear - 6
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            // 顶部：今日信息
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: Colors.surface0
                radius: 12
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    // 日期数字
                    Text {
                        text: calendarManager.todayDay
                        font.pixelSize: 36
                        font.bold: true
                        color: Colors.primary
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: calendarManager.todayYear + "年" + calendarManager.todayMonth + "月 " + calendarManager.todayWeekday
                            font.pixelSize: 13
                            color: Colors.text
                        }
                        
                        Text {
                            text: calendarManager.todayLunar + (calendarManager.todayFestival ? " · " + calendarManager.todayFestival : "")
                            font.pixelSize: 11
                            color: calendarManager.todayFestival ? Colors.yellow : Colors.subtext
                            visible: calendarManager.todayLunar !== ""
                        }
                    }
                    
                    // 回到今天按钮
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        color: todayMouse.containsMouse ? Colors.surface1 : "transparent"
                        visible: calendarManager.currentYear !== calendarManager.todayYear || 
                                 calendarManager.currentMonth !== calendarManager.todayMonth
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰃭"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: Colors.primary
                        }
                        
                        MouseArea {
                            id: todayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarManager.goToToday()
                        }
                    }
                }
            }
            
            // 月份导航
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // 上一年按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: prevYearMouse.containsMouse ? Colors.surface1 : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰄽"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: Colors.primary
                    }
                    
                    MouseArea {
                        id: prevYearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (background.yearSelectMode) {
                                background.yearSelectBase -= 12
                            } else {
                                calendarManager.prevYear()
                            }
                        }
                    }
                }
                
                // 上个月按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: prevMouse.containsMouse ? Colors.surface1 : "transparent"
                    visible: !background.yearSelectMode
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰅁"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: Colors.text
                    }
                    
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarManager.prevMonth()
                    }
                }
                
                // 当前年月（可点击切换年份选择模式）
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 8
                    color: yearMonthMouse.containsMouse ? Colors.surface0 : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: background.yearSelectMode ? 
                              (background.yearSelectBase + "年 - " + (background.yearSelectBase + 11) + "年") :
                              (calendarManager.currentYear + "年 " + calendarManager.getMonthName())
                        font.pixelSize: 16
                        font.bold: true
                        color: background.yearSelectMode ? Colors.primary : Colors.text
                    }
                    
                    MouseArea {
                        id: yearMonthMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            background.yearSelectMode = !background.yearSelectMode
                            if (background.yearSelectMode) {
                                background.yearSelectBase = calendarManager.currentYear - 6
                            }
                        }
                    }
                }
                
                // 下个月按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: nextMouse.containsMouse ? Colors.surface1 : "transparent"
                    visible: !background.yearSelectMode
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰅂"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: Colors.text
                    }
                    
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarManager.nextMonth()
                    }
                }
                
                // 下一年按钮
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: nextYearMouse.containsMouse ? Colors.surface1 : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰄾"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: Colors.primary
                    }
                    
                    MouseArea {
                        id: nextYearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (background.yearSelectMode) {
                                background.yearSelectBase += 12
                            } else {
                                calendarManager.nextYear()
                            }
                        }
                    }
                }
            }
            
            // 年份选择网格（在年份选择模式下显示）
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 8
                columnSpacing: 8
                visible: background.yearSelectMode
                
                Repeater {
                    model: 12
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 8
                        color: {
                            let year = background.yearSelectBase + index
                            if (year === calendarManager.currentYear) return Colors.surface1
                            if (yearItemMouse.containsMouse) return Colors.surface0
                            return "transparent"
                        }
                        border.color: (background.yearSelectBase + index) === calendarManager.todayYear ? Colors.primary : "transparent"
                        border.width: (background.yearSelectBase + index) === calendarManager.todayYear ? 2 : 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: background.yearSelectBase + index
                            font.pixelSize: 14
                            font.bold: (background.yearSelectBase + index) === calendarManager.currentYear
                            color: {
                                let year = background.yearSelectBase + index
                                if (year === calendarManager.currentYear) return Colors.primary
                                if (year === calendarManager.todayYear) return Colors.primary
                                return Colors.text
                            }
                        }
                        
                        MouseArea {
                            id: yearItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calendarManager.goToYear(background.yearSelectBase + index)
                                background.yearSelectMode = false
                            }
                        }
                    }
                }
            }
            
            // 星期标题行（日历模式下显示）
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: !background.yearSelectMode
                
                Repeater {
                    model: ["日", "一", "二", "三", "四", "五", "六"]
                    
                    Text {
                        Layout.fillWidth: true
                        text: modelData
                        font.pixelSize: 12
                        font.bold: true
                        color: index === 0 || index === 6 ? Colors.red : Colors.subtext
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            
            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.surface1
                visible: !background.yearSelectMode
            }
            
            // 日期网格（日历模式下显示）
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 4
                columnSpacing: 0
                visible: !background.yearSelectMode
                
                Repeater {
                    model: calendarManager.daysData
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: {
                            if (modelData.isToday) return Colors.surface1
                            if (dayMouse.containsMouse && modelData.currentMonth) return Colors.surface0
                            return "transparent"
                        }
                        radius: 8
                        border.color: modelData.isToday ? Colors.primary : "transparent"
                        border.width: modelData.isToday ? 2 : 0
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            
                            // 日期数字
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.day
                                font.pixelSize: 14
                                font.bold: modelData.isToday
                                color: {
                                    if (!modelData.currentMonth) return Colors.surface1
                                    if (modelData.isToday) return Colors.primary
                                    // 周末颜色
                                    let dayIndex = index % 7
                                    if (dayIndex === 0 || dayIndex === 6) return Colors.red
                                    return Colors.text
                                }
                            }
                            
                            // 农历/节日
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.lunar || ""
                                font.pixelSize: 9
                                color: {
                                    if (modelData.festival) return Colors.yellow
                                    if (!modelData.currentMonth) return Colors.surface1
                                    return Colors.overlay
                                }
                                visible: modelData.lunar !== ""
                            }
                        }
                        
                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.currentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            
                            onClicked: {
                                if (modelData.currentMonth) {
                                    // 可以在这里添加点击日期的操作
                                    console.log("选择日期:", modelData.year + "-" + modelData.month + "-" + modelData.day)
                                }
                            }
                        }
                        
                        // 节日指示器小点
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            width: 4
                            height: 4
                            radius: 2
                            color: Colors.yellow
                            visible: modelData.festival !== "" && modelData.currentMonth
                        }
                    }
                }
            }
            
            // 底部提示
            Text {
                Layout.fillWidth: true
                text: background.yearSelectMode ? 
                      "点击年份选择 · 滚轮切换年份范围" :
                      (calendarManager.hasLunar ? "滚轮切换月份 · 点击年月选择年份" : "pip install lunarcalendar 启用农历")
                font.pixelSize: 10
                color: Colors.overlay
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        // 加载指示器
        Rectangle {
            anchors.fill: parent
            color: Colors.base
            opacity: 0.8
            radius: 16
            visible: calendarManager.isLoading
            
            Text {
                anchors.centerIn: parent
                text: "加载中..."
                font.pixelSize: 14
                color: Colors.text
            }
        }
    }
}
