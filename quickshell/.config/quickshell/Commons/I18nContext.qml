import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string catalog: ""
    property string language: detectLanguage()
    readonly property string normalizedLanguage: normalizeLanguage(language)
    readonly property string configRoot: Quickshell.env("QS_CONFIG_ROOT")
        || Quickshell.env("HOME") + "/.config/quickshell"
    property var commonTranslations: ({})
    property var featureTranslations: ({})
    property var fallbackCommonTranslations: ({})
    property var fallbackFeatureTranslations: ({})
    readonly property bool ready: Object.keys(commonTranslations).length > 0
        && (!catalog || Object.keys(featureTranslations).length > 0)

    FileView {
        id: commonFile
        path: root.catalogPath("common", root.normalizedLanguage)
        watchChanges: true
        onLoaded: root.commonTranslations = root.parseCatalog(commonFile.text(), path)
        onFileChanged: commonFile.reload()
        onLoadFailed: error => root.handleLoadFailure(path, error)
    }

    FileView {
        id: featureFile
        path: root.catalog ? root.catalogPath(root.catalog, root.normalizedLanguage) : ""
        watchChanges: true
        onLoaded: root.featureTranslations = root.parseCatalog(featureFile.text(), path)
        onFileChanged: featureFile.reload()
        onLoadFailed: error => root.handleLoadFailure(path, error)
    }

    FileView {
        id: fallbackCommonFile
        path: root.catalogPath("common", "en_US")
        watchChanges: true
        onLoaded: root.fallbackCommonTranslations = root.parseCatalog(fallbackCommonFile.text(), path)
        onFileChanged: fallbackCommonFile.reload()
        onLoadFailed: error => root.handleLoadFailure(path, error)
    }

    FileView {
        id: fallbackFeatureFile
        path: root.catalog ? root.catalogPath(root.catalog, "en_US") : ""
        watchChanges: true
        onLoaded: root.fallbackFeatureTranslations = root.parseCatalog(fallbackFeatureFile.text(), path)
        onFileChanged: fallbackFeatureFile.reload()
        onLoadFailed: error => root.handleLoadFailure(path, error)
    }

    /**
     * 检测当前进程使用的界面语言
     * @returns {string} 环境变量中的语言代码
     */
    function detectLanguage() {
        // 1. 优先读取显式的 QuickShell 语言覆盖
        var candidates = [
            Quickshell.env("QS_LANG"),
            Quickshell.env("LANG"),
            Quickshell.env("LC_ALL"),
            Quickshell.env("LC_MESSAGES")
        ]

        // 2. 返回第一个有效语言设置
        for (var i = 0; i < candidates.length; i++) {
            if (candidates[i]) {
                return candidates[i]
            }
        }
        return "en_US"
    }

    /**
     * 将系统语言代码归一化为受支持的语言
     * @param {string} langCode 原始语言代码
     * @returns {string} 受支持的语言代码
     */
    function normalizeLanguage(langCode) {
        var value = String(langCode || "").replace("-", "_").toLowerCase()
        return value.indexOf("zh") === 0 ? "zh_CN" : "en_US"
    }

    /**
     * 生成指定语言包的绝对路径
     * @param {string} catalogName 功能语言包名称
     * @param {string} langCode 归一化后的语言代码
     * @returns {string} 语言包绝对路径
     */
    function catalogPath(catalogName, langCode) {
        return configRoot + "/locales/" + langCode + "/" + catalogName + ".json"
    }

    /**
     * 解析语言包文本
     * @param {string} content JSON文本
     * @param {string} path 语言包路径
     * @returns {object} 语言包对象，解析失败时返回空对象
     */
    function parseCatalog(content, path) {
        try {
            return JSON.parse(content)
        } catch (error) {
            console.error("【Quickshell/I18n】【解析语言包】解析失败:", path, error)
        }
        return ({})
    }

    /**
     * 处理语言包读取失败
     * @param {string} path 语言包路径
     * @param {var} error FileView错误
     * @returns {void}
     */
    function handleLoadFailure(path, error) {
        if (path) {
            console.error("【Quickshell/I18n】【加载语言包】加载失败:", path, error)
        }
    }

    /**
     * 从语言包中读取点分隔的翻译键
     * @param {object} source 语言包对象
     * @param {string} key 点分隔的翻译键
     * @returns {var} 翻译值，未找到时返回undefined
     */
    function lookup(source, key) {
        var parts = String(key || "").split(".")
        var current = source
        for (var i = 0; i < parts.length; i++) {
            if (!current || typeof current !== "object" || !(parts[i] in current)) {
                return undefined
            }
            current = current[parts[i]]
        }
        return current
    }

    /**
     * 从语言包中读取完整字面量翻译
     * @param {object} source 语言包对象
     * @param {string} literal 原始界面文本
     * @returns {var} 翻译值，未找到时返回undefined
     */
    function lookupLiteral(source, literal) {
        if (!source || typeof source !== "object") {
            return undefined
        }
        if (!source.literals || typeof source.literals !== "object") {
            return undefined
        }
        return source.literals[String(literal)]
    }

    /**
     * 替换翻译文本中的变量占位符
     * @param {string} text 翻译文本
     * @param {object} variables 变量映射
     * @returns {string} 替换后的文本
     */
    function interpolate(text, variables) {
        var result = String(text)
        if (!variables || typeof variables !== "object") {
            return result
        }

        for (var name in variables) {
            var pattern = new RegExp("\\{" + name + "\\}", "g")
            result = result.replace(pattern, String(variables[name]))
        }
        return result
    }

    /**
     * 获取当前功能的翻译文本
     * @param {string} key 翻译键
     * @param {object} variables 变量映射
     * @returns {string} 翻译文本，缺失时返回翻译键
     */
    function tr(key, variables) {
        var value = lookup(featureTranslations, key)
        if (value === undefined) {
            value = lookup(commonTranslations, key)
        }
        if (value === undefined) {
            value = lookup(fallbackFeatureTranslations, key)
        }
        if (value === undefined) {
            value = lookup(fallbackCommonTranslations, key)
        }
        return typeof value === "string" ? interpolate(value, variables) : key
    }

    /**
     * 翻译从旧界面迁移的完整字面量
     * @param {string} source 原始中文界面文本
     * @param {object} variables 变量映射
     * @returns {string} 当前语言对应的界面文本
     */
    function trLiteral(source, variables) {
        var value = lookupLiteral(featureTranslations, source)
        if (value === undefined) {
            value = lookupLiteral(fallbackFeatureTranslations, source)
        }
        return typeof value === "string" ? interpolate(value, variables) : interpolate(source, variables)
    }

    /**
     * 临时切换当前弹窗的界面语言
     * @param {string} langCode 目标语言代码
     * @returns {void}
     */
    function setLanguage(langCode) {
        language = langCode
    }
}
