import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: manager
    
    // 命令行参数 - 通过环境变量传入
    property string argTemplate: Quickshell.env("VM_TEMPLATE") || ""
    property string argImages: Quickshell.env("VM_IMAGES") || ""
    
    // 当前选择的图片列表
    property var imageList: []
    
    // 当前选择的模板
    property var currentTemplate: null
    property int currentTemplateIndex: -1
    
    // 模板列表 (从配置文件加载)
    property var templates: []
    
    // 运行日志和结果分离
    property string logOutput: ""
    property string result: ""
    property bool isProcessing: false
    property bool hasResult: false
    
    // 原始输出缓冲
    property string rawOutput: ""
    
    // 自动启动定时器
    property var autoStartTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: manager.startProcess()
    }
    
    // 配置文件路径
    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/visual_model_templates.json"
    
    // 读取配置文件的进程
    property var loadConfigProcess: Process {
        command: ["cat", manager.configPath]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()
                if (output && output.length > 0) {
                    try {
                        manager.templates = JSON.parse(output)
                        manager.applyArguments()
                    } catch (e) {
                        console.log("解析模板配置失败: " + e)
                        manager.templates = []
                    }
                }
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // 文件不存在，创建默认配置
                manager.templates = []
                manager.saveTemplates()
            }
        }
    }
    
    // 处理输出，分离日志和结果
    function processOutput() {
        var text = rawOutput
        var separator = "=== Final Answer ==="
        var idx = text.indexOf(separator)
        
        if (idx >= 0) {
            // 分离日志和结果
            logOutput = text.substring(0, idx).trim()
            var resultText = text.substring(idx + separator.length).trim()
            
            // 清理特殊标记
            resultText = resultText.replace(/<\|begin_of_box\|>/g, "")
            resultText = resultText.replace(/<\|end_of_box\|>/g, "")
            result = resultText.trim()
            hasResult = true
        } else {
            // 还没有结果，全部作为日志
            logOutput = text
            result = ""
            hasResult = false
        }
    }
    
    // 处理命令执行
    property var modelProcess: Process {
        onExited: (exitCode, exitStatus) => {
            manager.isProcessing = false
            manager.processOutput()
            if (exitCode !== 0) {
                manager.logOutput += "\n[进程退出码: " + exitCode + "]"
            }
        }
        
        stdout: SplitParser {
            onRead: data => {
                manager.rawOutput += data + "\n"
                manager.processOutput()
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                manager.rawOutput += "[stderr] " + data + "\n"
                manager.processOutput()
            }
        }
    }
    
    // 保存配置文件的进程
    property var saveProcess: Process {
        property string dataToWrite: ""
    }
    
    // 应用命令行参数
    function applyArguments() {
        // 处理模板参数
        if (argTemplate && argTemplate.length > 0) {
            for (var i = 0; i < templates.length; i++) {
                if (templates[i].code === argTemplate) {
                    currentTemplateIndex = i
                    currentTemplate = templates[i]
                    break
                }
            }
        } else if (templates.length > 0 && currentTemplateIndex < 0) {
            // 默认选择第一个模板
            currentTemplateIndex = 0
            currentTemplate = templates[0]
        }
        
        // 处理图片参数
        if (argImages && argImages.length > 0) {
            var paths = argImages.split(",")
            for (var j = 0; j < paths.length; j++) {
                var path = paths[j].trim()
                if (path.length > 0) {
                    addImage(path)
                }
            }
        }
        
        // 如果同时指定了模板和图片，自动开始处理
        if (argTemplate && argTemplate.length > 0 && argImages && argImages.length > 0) {
            if (currentTemplate && imageList.length > 0) {
                autoStartTimer.start()
            }
        }
    }
    
    // 添加图片
    function addImage(path) {
        if (path && path.length > 0) {
            var newList = imageList.slice()
            // 检查是否已存在
            if (newList.indexOf(path) === -1) {
                newList.push(path)
                imageList = newList
            }
        }
    }
    
    // 移除图片
    function removeImage(index) {
        if (index >= 0 && index < imageList.length) {
            var newList = imageList.slice()
            newList.splice(index, 1)
            imageList = newList
        }
    }
    
    // 清空所有图片
    function clearImages() {
        imageList = []
    }
    
    // 选择模板
    function selectTemplate(index) {
        if (index >= 0 && index < templates.length) {
            currentTemplateIndex = index
            currentTemplate = templates[index]
        }
    }
    
    // 添加新模板
    function addTemplate(name, code, prompt) {
        var newTemplate = {
            "name": name,
            "code": code,
            "prompt": prompt
        }
        var newList = templates.slice()
        newList.push(newTemplate)
        templates = newList
        saveTemplates()
        
        // 如果是第一个模板，自动选择
        if (templates.length === 1) {
            selectTemplate(0)
        }
    }
    
    // 删除模板
    function deleteTemplate(index) {
        if (index >= 0 && index < templates.length) {
            var newList = templates.slice()
            newList.splice(index, 1)
            templates = newList
            
            // 调整当前选择
            if (currentTemplateIndex === index) {
                if (templates.length > 0) {
                    currentTemplateIndex = 0
                    currentTemplate = templates[0]
                } else {
                    currentTemplateIndex = -1
                    currentTemplate = null
                }
            } else if (currentTemplateIndex > index) {
                currentTemplateIndex--
            }
            
            saveTemplates()
        }
    }
    
    // 更新模板
    function updateTemplate(index, name, code, prompt) {
        if (index >= 0 && index < templates.length) {
            var newList = templates.slice()
            newList[index] = {
                "name": name,
                "code": code,
                "prompt": prompt
            }
            templates = newList
            
            if (currentTemplateIndex === index) {
                currentTemplate = templates[index]
            }
            
            saveTemplates()
        }
    }
    
    // 保存模板到文件
    function saveTemplates() {
        var jsonData = JSON.stringify(templates, null, 2)
        // 使用 printf 来避免特殊字符问题，通过临时文件方式写入
        var escapedData = jsonData.replace(/'/g, "'\"'\"'")
        saveProcess.command = ["bash", "-c", "printf '%s' '" + escapedData + "' > '" + configPath + "'"]
        saveProcess.running = true
    }
    
    // 开始处理
    function startProcess() {
        if (imageList.length === 0) {
            result = "[错误] 请先添加至少一张图片"
            return
        }
        
        if (!currentTemplate) {
            result = "[错误] 请先选择或创建一个模板"
            return
        }
        
        isProcessing = true
        rawOutput = ""
        logOutput = ""
        result = ""
        hasResult = false
        
        // 构建命令
        var args = ["visual-model-base-run"]
        
        // 添加图片参数
        for (var i = 0; i < imageList.length; i++) {
            args.push("-img")
            args.push(imageList[i])
        }
        
        // 添加提示词
        if (currentTemplate.prompt && currentTemplate.prompt.length > 0) {
            args.push("-p")
            args.push(currentTemplate.prompt)
        }
        
        rawOutput = "[执行命令] " + args.join(" ") + "\n\n"
        logOutput = rawOutput
        modelProcess.command = args
        modelProcess.running = true
    }
    
    // 停止处理
    function stopProcess() {
        if (isProcessing) {
            modelProcess.running = false
            isProcessing = false
            logOutput += "\n[已中断]"
        }
    }
    
    // 初始化 - 确保配置目录和文件存在
    property var initProcess: Process {
        command: ["bash", "-c", "mkdir -p ~/.config/quickshell"]
        
        onExited: {
            // 加载配置文件
            loadConfigProcess.running = true
        }
    }
    
    Component.onCompleted: {
        initProcess.running = true
    }
}
