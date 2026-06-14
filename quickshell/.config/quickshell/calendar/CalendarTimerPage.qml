import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "./Theme.js" as Theme

ColumnLayout {
    id: timerPage

    // ============ 属性声明 ============
    required property var controller

    property string selectedMode: "pomodoro"
    property int selectedMinutes: 25
    property bool timerActive: false
    property bool timerRunning: false
    property string timerMode: "stopwatch"
    property string timerModeLabel: controller.i18nContext.trLiteral("番茄时钟")
    property string timerDisplay: "25:00"
    property string timerDetail: controller.i18nContext.trLiteral("选择模式后开始计时")
    property real timerProgress: 0.0

    readonly property string timerScriptPath: Qt.resolvedUrl("timer_state.py").toString().replace("file://", "")

    Layout.fillWidth: true
    spacing: Theme.spacingM
    visible: controller.activeRoute === "timer"

    // ============ 进程声明 ============
    Process {
        id: timerProcess
        command: []

        stdout: StdioCollector {
            onStreamFinished: timerPage.applyStatus(text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    console.log("Timer command error:", text)
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: timerPage.visible
        repeat: true
        onTriggered: timerPage.requestStatus()
    }

    Component.onCompleted: requestStatus()

    /**
     * 运行计时器状态命令。
     * @param {var} args - 传给状态脚本的参数数组。
     * @returns 无返回值。
     */
    function runTimerCommand(args) {
        if (timerProcess.running) {
            return
        }

        // 1. 组装 Python 状态脚本调用参数
        let commandArgs = ["python3", timerScriptPath]
        for (let i = 0; i < args.length; i++) {
            commandArgs.push(args[i])
        }

        // 2. 执行命令并等待 stdout 回填状态
        timerProcess.command = commandArgs
        timerProcess.running = true
    }

    /**
     * 请求当前计时器状态。
     * @returns 无返回值。
     */
    function requestStatus() {
        runTimerCommand(["status"])
    }

    /**
     * 启动当前选择的计时模式。
     * @returns 无返回值。
     */
    function startSelectedTimer() {
        let duration = selectedMode === "stopwatch" ? 0 : selectedMinutes * 60
        runTimerCommand(["start", "--mode", selectedMode, "--duration", duration.toString()])
    }

    /**
     * 根据脚本输出刷新页面状态。
     * @param {string} text - JSON 状态文本。
     * @returns 无返回值。
     */
    function applyStatus(text) {
        if (!text || !text.trim()) {
            return
        }

        try {
            let data = JSON.parse(text)
            timerActive = data.active || false
            timerRunning = data.running || false
            timerMode = data.mode || selectedMode
            timerModeLabel = data.modeLabel || modeLabel(selectedMode)
            timerProgress = data.progress || 0

            if (timerActive) {
                timerDisplay = data.display || "00:00"
                timerDetail = timerRunning
                    ? controller.i18nContext.trLiteral("运行中")
                    : controller.i18nContext.trLiteral("已暂停")
            } else {
                timerDisplay = previewDisplay()
                timerDetail = controller.i18nContext.trLiteral("选择模式后开始计时")
            }
        } catch (e) {
            console.log("Failed to parse timer status:", e, text)
        }
    }

    /**
     * 获取模式标签。
     * @param {string} mode - 计时模式。
     * @returns {string} 模式显示名称。
     */
    function modeLabel(mode) {
        if (mode === "countdown") return controller.i18nContext.trLiteral("倒计时")
        if (mode === "pomodoro") return controller.i18nContext.trLiteral("番茄时钟")
        return controller.i18nContext.trLiteral("正计时")
    }

    /**
     * 格式化秒数。
     * @param {int} seconds - 秒数。
     * @returns {string} 时间文本。
     */
    function formatSeconds(seconds) {
        let safeSeconds = Math.max(0, seconds)
        let hours = Math.floor(safeSeconds / 3600)
        let minutes = Math.floor((safeSeconds % 3600) / 60)
        let remain = safeSeconds % 60
        if (hours > 0) {
            return String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0") + ":" + String(remain).padStart(2, "0")
        }
        return String(minutes).padStart(2, "0") + ":" + String(remain).padStart(2, "0")
    }

    /**
     * 生成未启动时的预览时间。
     * @returns {string} 预览时间文本。
     */
    function previewDisplay() {
        if (selectedMode === "stopwatch") {
            return "00:00"
        }
        return formatSeconds(selectedMinutes * 60)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 132
        radius: Theme.radiusL
        color: Theme.alpha(Theme.surface, 0.54)
        border.color: Theme.alpha(timerActive ? Theme.primary : Theme.outline, timerActive ? 0.55 : 0.5)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Text {
                    text: timerActive ? timerModeLabel : modeLabel(selectedMode)
                    font.pixelSize: Theme.fontSizeM
                    font.bold: true
                    color: Theme.textSecondary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: statusText.implicitWidth + Theme.spacingM * 2
                    implicitHeight: 24
                    radius: Theme.radiusPill
                    color: timerRunning ? Theme.alpha(Theme.primary, 0.16) : Theme.alpha(Theme.surfaceVariant, 0.72)
                    border.color: timerRunning ? Theme.alpha(Theme.primary, 0.42) : Theme.alpha(Theme.outline, 0.45)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: timerActive ? timerDetail : timerPage.controller.i18nContext.trLiteral("待开始")
                        font.pixelSize: Theme.fontSizeXS
                        font.bold: true
                        color: timerRunning ? Theme.primary : Theme.textMuted
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: timerDisplay
                font.pixelSize: 46
                font.weight: Font.Black
                color: timerActive ? Theme.primary : Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 7
                radius: 4
                color: Theme.alpha(Theme.outline, 0.34)
                visible: (timerActive && timerMode !== "stopwatch") || (!timerActive && selectedMode !== "stopwatch")

                Rectangle {
                    width: parent.width * (timerActive ? timerProgress : 0)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary

                    Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    TimerModeSelector {
        controller: timerPage.controller
        selectedMode: timerPage.selectedMode
        onModeSelected: (mode) => {
            timerPage.selectedMode = mode
            if (!timerPage.timerActive) {
                timerPage.timerDisplay = timerPage.previewDisplay()
                timerPage.timerDetail = timerPage.controller.i18nContext.trLiteral("选择模式后开始计时")
            }
        }
    }

    TimerDurationPicker {
        controller: timerPage.controller
        selectedMinutes: timerPage.selectedMinutes
        visible: timerPage.selectedMode !== "stopwatch"
        onDurationSelected: (minutes) => {
            timerPage.selectedMinutes = minutes
            if (!timerPage.timerActive) {
                timerPage.timerDisplay = timerPage.previewDisplay()
            }
        }
    }

    TimerControls {
        controller: timerPage.controller
        active: timerPage.timerActive
        running: timerPage.timerRunning
        onStartRequested: timerPage.startSelectedTimer()
        onPauseRequested: timerPage.runTimerCommand(["pause"])
        onResumeRequested: timerPage.runTimerCommand(["resume"])
        onStopRequested: timerPage.runTimerCommand(["stop"])
    }

    Text {
        Layout.fillWidth: true
        text: controller.i18nContext.trLiteral("Waybar 仅在计时运行或暂停时显示状态")
        font.pixelSize: Theme.fontSizeXS
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
    }
}
