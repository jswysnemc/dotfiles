import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    property int currentYear: new Date().getFullYear()
    property int currentMonth: new Date().getMonth() + 1
    property int todayYear: new Date().getFullYear()
    property int todayMonth: new Date().getMonth() + 1
    property int todayDay: new Date().getDate()
    
    property var daysData: []
    property bool hasLunar: false
    property bool isLoading: false
    
    // 今日信息
    property string todayLunar: ""
    property string todayFestival: ""
    property string todayWeekday: ""
    
    // 脚本路径
    property string scriptPath: Qt.resolvedUrl("scripts/lunar_calendar.py").toString().replace("file://", "")
    
    // 获取月份数据的进程
    property var monthProcess: Process {
        command: [manager.scriptPath, "month", manager.currentYear.toString(), manager.currentMonth.toString()]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text)
                    manager.daysData = data.days || []
                    manager.hasLunar = data.hasLunar || false
                    manager.isLoading = false
                } catch (e) {
                    console.log("解析月份数据失败:", e, this.text)
                    manager.isLoading = false
                    // 使用备用方案生成日历
                    manager.generateFallbackCalendar()
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) {
                    console.log("月份数据错误:", this.text)
                }
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                manager.isLoading = false
                manager.generateFallbackCalendar()
            }
        }
    }
    
    // 获取今日信息的进程
    property var todayProcess: Process {
        command: [manager.scriptPath, "today"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text)
                    manager.todayLunar = data.lunar || ""
                    manager.todayFestival = data.festival || ""
                    manager.todayWeekday = data.weekday || ""
                } catch (e) {
                    console.log("解析今日数据失败:", e)
                }
            }
        }
    }
    
    // 备用方案：不使用农历的简单日历
    function generateFallbackCalendar() {
        let year = currentYear
        let month = currentMonth
        
        // JavaScript月份从0开始
        let firstDay = new Date(year, month - 1, 1)
        let lastDay = new Date(year, month, 0)
        let daysInMonth = lastDay.getDate()
        let firstWeekday = firstDay.getDay()  // 0 = 周日
        
        // 上个月天数
        let prevLastDay = new Date(year, month - 1, 0)
        let prevDays = prevLastDay.getDate()
        
        let days = []
        
        // 填充上个月
        for (let i = 0; i < firstWeekday; i++) {
            let d = prevDays - firstWeekday + 1 + i
            let m = month === 1 ? 12 : month - 1
            let y = month === 1 ? year - 1 : year
            days.push({
                day: d,
                currentMonth: false,
                isToday: false,
                lunar: "",
                festival: "",
                year: y,
                month: m
            })
        }
        
        // 当月
        let today = new Date()
        for (let d = 1; d <= daysInMonth; d++) {
            let isToday = (year === today.getFullYear() && month === today.getMonth() + 1 && d === today.getDate())
            days.push({
                day: d,
                currentMonth: true,
                isToday: isToday,
                lunar: "",
                festival: getFallbackFestival(month, d),
                year: year,
                month: month
            })
        }
        
        // 填充下个月
        let remaining = 42 - days.length
        let nextMonth = month === 12 ? 1 : month + 1
        let nextYear = month === 12 ? year + 1 : year
        for (let d = 1; d <= remaining; d++) {
            days.push({
                day: d,
                currentMonth: false,
                isToday: false,
                lunar: "",
                festival: "",
                year: nextYear,
                month: nextMonth
            })
        }
        
        daysData = days
    }
    
    // 简单的节日查询
    function getFallbackFestival(month, day) {
        let festivals = {
            "1-1": "元旦",
            "2-14": "情人节",
            "3-8": "妇女节",
            "5-1": "劳动节",
            "6-1": "儿童节",
            "10-1": "国庆节",
            "12-25": "圣诞节"
        }
        return festivals[month + "-" + day] || ""
    }
    
    function loadMonth() {
        isLoading = true
        monthProcess.command = [scriptPath, "month", currentYear.toString(), currentMonth.toString()]
        monthProcess.running = true
    }
    
    function loadTodayInfo() {
        todayProcess.running = true
    }
    
    function prevMonth() {
        if (currentMonth === 1) {
            currentMonth = 12
            currentYear--
        } else {
            currentMonth--
        }
        loadMonth()
    }
    
    function nextMonth() {
        if (currentMonth === 12) {
            currentMonth = 1
            currentYear++
        } else {
            currentMonth++
        }
        loadMonth()
    }
    
    function goToToday() {
        let today = new Date()
        currentYear = today.getFullYear()
        currentMonth = today.getMonth() + 1
        loadMonth()
    }
    
    function prevYear() {
        currentYear--
        loadMonth()
    }
    
    function nextYear() {
        currentYear++
        loadMonth()
    }
    
    function goToYear(year) {
        currentYear = year
        loadMonth()
    }
    
    function getMonthName() {
        let months = ["一月", "二月", "三月", "四月", "五月", "六月", 
                      "七月", "八月", "九月", "十月", "十一月", "十二月"]
        return months[currentMonth - 1]
    }
    
    Component.onCompleted: {
        loadMonth()
        loadTodayInfo()
    }
}
