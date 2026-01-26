// Quickshell 颜色定义 - 默认深色主题
// 使用方式: import "colors.js" as Colors

.pragma library

// === 核心背景 ===
var base = "#11111b"           // 基础背景
var surface0 = "#1e1e2e"       // 容器背景
var surface1 = "#313244"       // 高亮容器
var surface2 = "#45475a"       // 最高容器

// === 文字颜色 ===
var text = "#cdd6f4"           // 主文字
var subtext = "#a6adc8"        // 次要文字
var overlay = "#6c7086"        // 覆盖层/边框

// === 主题色 ===
var primary = "#89b4fa"        // 主色 (蓝色)
var secondary = "#a6e3a1"      // 次要色 (绿色)
var tertiary = "#fab387"       // 第三色 (橙色)

// === 语义色 ===
var red = "#f38ba8"            // 错误/危险
var green = "#a6e3a1"          // 成功/正常
var yellow = "#f9e2af"         // 警告
var blue = "#89b4fa"           // 信息/链接

// === 反色文字 (用于彩色背景) ===
var onPrimary = "#1e1e2e"
var onSecondary = "#1e1e2e"
var onError = "#1e1e2e"

// === 透明度变体 ===
function withAlpha(hex, alpha) {
    return Qt.rgba(
        parseInt(hex.slice(1,3), 16) / 255,
        parseInt(hex.slice(3,5), 16) / 255,
        parseInt(hex.slice(5,7), 16) / 255,
        alpha
    )
}
