// Animations.js - 统一动画系统
// 为所有 QuickShell 组件提供一致的动画体验

.pragma library

// ============================================================
// 动画时长 (Duration)
// ============================================================

// 微交互 - 即时反馈 (hover, press, toggle)
var durationInstant = 80

// 快速 - 小型 UI 变化 (颜色、边框)
var durationFast = 120

// 标准 - 常规过渡 (展开、收起)
var durationNormal = 200

// 中等 - 面板/弹窗动画
var durationMedium = 280

// 慢速 - 大型过渡、强调动画
var durationSlow = 380

// 超慢 - 背景模糊、渐变效果
var durationVerySlow = 500

// ============================================================
// 缓动曲线 (Easing) - 参考 Material Design 3
// ============================================================

// --- 标准缓动 (Standard) ---
// 用于大多数 UI 元素的进入和退出

// 标准 - 通用过渡
var easingStandard = { type: 3, amplitude: 1.0, period: 0.3 }  // Easing.OutCubic

// 标准加速 - 元素退出屏幕
var easingStandardAccelerate = { type: 2 }  // Easing.InCubic

// 标准减速 - 元素进入屏幕
var easingStandardDecelerate = { type: 3 }  // Easing.OutCubic

// --- 强调缓动 (Emphasized) ---
// 用于需要吸引注意力的动画

// 强调 - 弹性效果
var easingEmphasized = { type: 6, amplitude: 1.0, period: 0.4 }  // Easing.OutBack

// 强调减速 - 弹入效果
var easingEmphasizedDecelerate = { type: 7, overshoot: 1.2 }  // Easing.OutBack with overshoot

// 强调加速 - 弹出效果
var easingEmphasizedAccelerate = { type: 4, overshoot: 1.5 }  // Easing.InBack

// --- 弹簧缓动 (Spring) ---
// 用于自然、有机的动画

// 轻弹簧 - 轻微弹跳
var easingSpringLight = { type: 41, amplitude: 0.5, period: 0.25 }  // Easing.OutElastic

// 中弹簧 - 明显弹跳
var easingSpringMedium = { type: 41, amplitude: 0.8, period: 0.35 }

// 重弹簧 - 强烈弹跳
var easingSpringHeavy = { type: 41, amplitude: 1.0, period: 0.45 }

// --- 线性和平滑 ---

// 线性 - 匀速动画 (进度条、旋转)
var easingLinear = { type: 0 }  // Easing.Linear

// 平滑 - 缓入缓出
var easingSmooth = { type: 5 }  // Easing.InOutCubic

// 正弦 - 呼吸效果
var easingSine = { type: 17 }  // Easing.InOutSine

// ============================================================
// 预设动画配置 (Animation Presets)
// ============================================================

// --- 入场动画 (Enter) ---

var enterFade = {
    property: "opacity",
    from: 0, to: 1,
    duration: durationNormal,
    easing: easingStandardDecelerate
}

var enterScale = {
    property: "scale",
    from: 0.8, to: 1.0,
    duration: durationMedium,
    easing: easingEmphasizedDecelerate
}

var enterScaleSpring = {
    property: "scale",
    from: 0.5, to: 1.0,
    duration: durationSlow,
    easing: easingSpringMedium
}

var enterSlideUp = {
    property: "y",
    fromOffset: 20,
    duration: durationMedium,
    easing: easingEmphasizedDecelerate
}

var enterSlideDown = {
    property: "y",
    fromOffset: -20,
    duration: durationMedium,
    easing: easingEmphasizedDecelerate
}

var enterSlideLeft = {
    property: "x",
    fromOffset: 30,
    duration: durationMedium,
    easing: easingEmphasizedDecelerate
}

var enterSlideRight = {
    property: "x",
    fromOffset: -30,
    duration: durationMedium,
    easing: easingEmphasizedDecelerate
}

// --- 退场动画 (Exit) ---

var exitFade = {
    property: "opacity",
    from: 1, to: 0,
    duration: durationFast,
    easing: easingStandardAccelerate
}

var exitScale = {
    property: "scale",
    from: 1.0, to: 0.8,
    duration: durationNormal,
    easing: easingEmphasizedAccelerate
}

var exitSlideUp = {
    property: "y",
    toOffset: -20,
    duration: durationNormal,
    easing: easingStandardAccelerate
}

var exitSlideDown = {
    property: "y",
    toOffset: 20,
    duration: durationNormal,
    easing: easingStandardAccelerate
}

// --- 交互动画 (Interaction) ---

var hoverScale = {
    property: "scale",
    normal: 1.0, hovered: 1.05,
    duration: durationFast,
    easing: easingStandard
}

var hoverScaleLarge = {
    property: "scale",
    normal: 1.0, hovered: 1.1,
    duration: durationFast,
    easing: easingEmphasized
}

var pressScale = {
    property: "scale",
    normal: 1.0, pressed: 0.95,
    duration: durationInstant,
    easing: easingStandard
}

var hoverElevation = {
    property: "y",
    normal: 0, hovered: -2,
    duration: durationFast,
    easing: easingStandard
}

// --- 状态动画 (State) ---

var toggleSwitch = {
    duration: durationNormal,
    easing: easingEmphasized
}

var expandCollapse = {
    duration: durationMedium,
    easing: easingEmphasizedDecelerate
}

var focusRing = {
    duration: durationFast,
    easing: easingStandard
}

// --- 加载动画 (Loading) ---

var spinnerRotation = {
    duration: 1000,
    easing: easingLinear
}

var pulseScale = {
    from: 1.0, to: 1.1,
    duration: 800,
    easing: easingSine
}

var shimmer = {
    duration: 1500,
    easing: easingLinear
}

// --- 通知动画 (Notification) ---

var notificationEnter = {
    slide: { from: 50, to: 0, duration: durationMedium },
    fade: { from: 0, to: 1, duration: durationNormal },
    easing: easingEmphasizedDecelerate
}

var notificationExit = {
    slide: { from: 0, to: -30, duration: durationNormal },
    fade: { from: 1, to: 0, duration: durationFast },
    easing: easingStandardAccelerate
}

// ============================================================
// 交错动画延迟计算 (Stagger)
// ============================================================

// 计算列表项的交错延迟
function staggerDelay(index, baseDelay) {
    baseDelay = baseDelay || 30
    return index * baseDelay
}

// 计算网格项的交错延迟 (从中心扩散)
function staggerDelayGrid(index, columns, baseDelay) {
    baseDelay = baseDelay || 25
    var row = Math.floor(index / columns)
    var col = index % columns
    var centerCol = (columns - 1) / 2
    var distance = Math.abs(col - centerCol) + row
    return distance * baseDelay
}

// 计算从特定位置扩散的延迟
function staggerDelayFromPoint(index, columns, originIndex, baseDelay) {
    baseDelay = baseDelay || 20
    var row = Math.floor(index / columns)
    var col = index % columns
    var originRow = Math.floor(originIndex / columns)
    var originCol = originIndex % columns
    var distance = Math.abs(row - originRow) + Math.abs(col - originCol)
    return distance * baseDelay
}

// ============================================================
// 动画组合 (Combinations)
// ============================================================

// 弹窗入场组合
var popupEnter = {
    scale: { from: 0.9, to: 1.0 },
    opacity: { from: 0, to: 1 },
    duration: durationMedium,
    easing: easingEmphasizedDecelerate
}

// 弹窗退场组合
var popupExit = {
    scale: { from: 1.0, to: 0.95 },
    opacity: { from: 1, to: 0 },
    duration: durationNormal,
    easing: easingStandardAccelerate
}

// 卡片悬停组合
var cardHover = {
    scale: { normal: 1.0, hovered: 1.02 },
    elevation: { normal: 0, hovered: -2 },
    duration: durationFast,
    easing: easingStandard
}

// 按钮点击组合
var buttonPress = {
    scale: { normal: 1.0, pressed: 0.96 },
    duration: durationInstant,
    easing: easingStandard
}

// 图标弹跳
var iconBounce = {
    scale: [1.0, 1.2, 0.9, 1.05, 1.0],
    duration: durationSlow,
    easing: easingSpringMedium
}
