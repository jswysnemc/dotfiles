// Quickshell 颜色定义 - 由 Matugen 自动生成
// 使用方式: import "colors.js" as Colors

.pragma library

// === 核心背景 ===
var base = "{{colors.surface.default.hex}}"           // 基础背景
var surface0 = "{{colors.surface_container.default.hex}}"  // 容器背景
var surface1 = "{{colors.surface_container_high.default.hex}}"  // 高亮容器
var surface2 = "{{colors.surface_container_highest.default.hex}}"  // 最高容器

// === 文字颜色 ===
var text = "{{colors.on_surface.default.hex}}"        // 主文字
var subtext = "{{colors.on_surface_variant.default.hex}}"  // 次要文字
var overlay = "{{colors.outline.default.hex}}"        // 覆盖层/边框

// === 主题色 ===
var primary = "{{colors.primary.default.hex}}"        // 主色 (蓝色)
var secondary = "{{colors.secondary.default.hex}}"    // 次要色
var tertiary = "{{colors.tertiary.default.hex}}"      // 第三色

// === 语义色 ===
var red = "{{colors.error.default.hex}}"              // 错误/危险
var green = "{{colors.secondary.default.hex}}"        // 成功/正常
var yellow = "{{colors.tertiary.default.hex}}"        // 警告
var blue = "{{colors.primary.default.hex}}"           // 信息/链接

// === 反色文字 (用于彩色背景) ===
var onPrimary = "{{colors.on_primary.default.hex}}"
var onSecondary = "{{colors.on_secondary.default.hex}}"
var onError = "{{colors.on_error.default.hex}}"

// === 透明度变体 ===
function withAlpha(hex, alpha) {
    return Qt.rgba(
        parseInt(hex.slice(1,3), 16) / 255,
        parseInt(hex.slice(3,5), 16) / 255,
        parseInt(hex.slice(5,7), 16) / 255,
        alpha
    )
}
