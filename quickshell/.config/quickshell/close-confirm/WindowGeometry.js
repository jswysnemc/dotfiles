/**
 * 判断输入是否为可用于几何计算的数字。
 * @param value 需要检查的输入值
 * @returns {boolean} 是有限数字时返回 true，否则返回 false
 */
function isUsableNumber(value) {
    return typeof value === "number" && isFinite(value)
}

/**
 * 从数组中读取指定下标的数字。
 * @param values 可能包含坐标或尺寸的数组
 * @param index 需要读取的数组下标
 * @returns {number|null} 读取成功返回数字，否则返回 null
 */
function numberAt(values, index) {
    if (!values || values.length <= index) return null

    var value = values[index]
    return isUsableNumber(value) ? value : null
}

/**
 * 判断窗口是否有平铺布局坐标。
 * @param win niri 返回的窗口对象
 * @returns {boolean} 有平铺坐标时返回 true，否则返回 false
 */
function hasTiledPosition(win) {
    return !!(win && win.layout && win.layout.pos_in_scrolling_layout)
}

/**
 * 判断两个窗口是否位于同一个平铺列。
 * @param left 左侧窗口对象
 * @param right 右侧窗口对象
 * @returns {boolean} 两个窗口属于同工作区同列时返回 true，否则返回 false
 */
function isSameTiledColumn(left, right) {
    if (!hasTiledPosition(left) || !hasTiledPosition(right)) return false

    var leftColumn = numberAt(left.layout.pos_in_scrolling_layout, 0)
    var rightColumn = numberAt(right.layout.pos_in_scrolling_layout, 0)
    return left.workspace_id === right.workspace_id && leftColumn !== null && leftColumn === rightColumn
}

/**
 * 收集目标窗口所在平铺列的窗口。
 * @param target niri 返回的目标窗口对象
 * @param windows niri windows 返回的窗口列表
 * @returns {Array} 同工作区同列窗口列表
 */
function tiledColumnWindows(target, windows) {
    if (!hasTiledPosition(target) || !windows || windows.length === undefined) return []

    var result = []
    for (var i = 0; i < windows.length; i++) {
        var win = windows[i]
        if (win && !win.is_floating && isSameTiledColumn(target, win)) {
            result.push(win)
        }
    }

    result.sort(function(a, b) {
        return numberAt(a.layout.pos_in_scrolling_layout, 1) - numberAt(b.layout.pos_in_scrolling_layout, 1)
    })
    return result
}

/**
 * 计算平铺窗口在列内的顶部坐标。
 * @param target niri 返回的目标窗口对象
 * @param windows niri windows 返回的窗口列表
 * @param screenHeight 当前输出高度
 * @returns {number|null} 成功返回窗口顶部坐标，否则返回 null
 */
function tiledWindowTop(target, windows, screenHeight) {
    var columnWindows = tiledColumnWindows(target, windows)
    if (columnWindows.length === 0) return null

    // 1. 汇总列内窗口高度，用剩余空间估算 niri 的上下间隙
    var totalHeight = 0
    for (var i = 0; i < columnWindows.length; i++) {
        totalHeight += windowSize(columnWindows[i], 1) || 0
    }

    var safeScreenHeight = isUsableNumber(screenHeight) && screenHeight > 0 ? screenHeight : totalHeight
    var gap = Math.max(0, safeScreenHeight - totalHeight) / (columnWindows.length + 1)
    var top = gap

    // 2. 累加目标窗口之前的窗口高度和间隙
    for (var j = 0; j < columnWindows.length; j++) {
        if (columnWindows[j].id === target.id) return top

        top += (windowSize(columnWindows[j], 1) || 0) + gap
    }

    return null
}

/**
 * 收集目标工作区内的平铺列信息。
 * @param target niri 返回的目标窗口对象
 * @param windows niri windows 返回的窗口列表
 * @returns {Array} 平铺列信息列表
 */
function tiledColumns(target, windows) {
    if (!hasTiledPosition(target) || !windows || windows.length === undefined) return []

    var columns = []
    for (var i = 0; i < windows.length; i++) {
        var win = windows[i]
        if (!win || win.is_floating || win.workspace_id !== target.workspace_id || !hasTiledPosition(win)) continue

        var columnIndex = numberAt(win.layout.pos_in_scrolling_layout, 0)
        if (columnIndex === null) continue

        var column = null
        for (var j = 0; j < columns.length; j++) {
            if (columns[j].index === columnIndex) {
                column = columns[j]
                break
            }
        }

        if (!column) {
            column = { index: columnIndex, width: 0 }
            columns.push(column)
        }
        column.width = Math.max(column.width, windowSize(win, 0) || 0)
    }

    columns.sort(function(a, b) { return a.index - b.index })
    return columns
}

/**
 * 查找当前工作区内作为视图锚点的平铺列。
 * @param target niri 返回的目标窗口对象
 * @param windows niri windows 返回的窗口列表
 * @returns {number|null} 成功返回锚点列序号，否则返回 null
 */
function tiledAnchorColumn(target, windows) {
    if (!hasTiledPosition(target) || !windows || windows.length === undefined) return null

    // 1. 目标窗口本身聚焦时，niri 视图以目标列作为当前可见列
    if (target.is_focused) {
        return numberAt(target.layout.pos_in_scrolling_layout, 0)
    }

    // 2. 环境变量里的目标窗口未标记聚焦时，优先使用同工作区聚焦窗口
    for (var i = 0; i < windows.length; i++) {
        var win = windows[i]
        if (!win || win.is_floating || win.workspace_id !== target.workspace_id || !win.is_focused || !hasTiledPosition(win)) continue

        return numberAt(win.layout.pos_in_scrolling_layout, 0)
    }

    // 3. 没有聚焦标记时回退到目标列，适配启动后窗口列表聚焦状态更新滞后的情况
    return numberAt(target.layout.pos_in_scrolling_layout, 0)
}

/**
 * 计算目标平铺列相对锚点列的左侧坐标。
 * @param columns 平铺列信息列表
 * @param anchorColumn 锚点列序号
 * @param targetColumn 目标列序号
 * @returns {number|null} 成功返回相对左侧坐标，否则返回 null
 */
function tiledColumnLeftFromAnchor(columns, anchorColumn, targetColumn) {
    if (!columns || columns.length === 0 || anchorColumn === null || targetColumn === null) return null
    if (anchorColumn === targetColumn) return 0

    var anchorIndex = -1
    var targetIndex = -1
    for (var i = 0; i < columns.length; i++) {
        if (columns[i].index === anchorColumn) anchorIndex = i
        if (columns[i].index === targetColumn) targetIndex = i
    }
    if (anchorIndex === -1 || targetIndex === -1) return null

    var left = 0
    if (targetIndex > anchorIndex) {
        // 1. 目标列在锚点列右侧时，累加中间列宽
        for (var rightIndex = anchorIndex; rightIndex < targetIndex; rightIndex++) {
            left += columns[rightIndex].width
        }
        return left
    }

    // 2. 目标列在锚点列左侧时，反向累加中间列宽
    for (var leftIndex = targetIndex; leftIndex < anchorIndex; leftIndex++) {
        left -= columns[leftIndex].width
    }
    return left
}

/**
 * 在所有平铺列可同时显示时，按列顺序计算目标列左侧坐标。
 * @param columns 平铺列信息列表
 * @param targetColumn 目标列序号
 * @param screenWidth 当前输出宽度
 * @returns {number|null} 成功返回目标列左侧坐标，否则返回 null
 */
function tiledColumnLeftFromStart(columns, targetColumn, screenWidth) {
    if (!columns || columns.length === 0 || targetColumn === null || !isUsableNumber(screenWidth) || screenWidth <= 0) return null

    // 1. 只有所有列宽总和不超过输出宽度时，才认为列组完整可见
    var totalWidth = 0
    for (var i = 0; i < columns.length; i++) {
        totalWidth += columns[i].width
    }
    if (totalWidth <= 0 || totalWidth > screenWidth) return null

    // 2. center-focused-column 为 never 时，完整可见列组从左侧开始排列
    var left = 0
    for (var j = 0; j < columns.length; j++) {
        if (columns[j].index === targetColumn) return left

        left += columns[j].width
    }
    return null
}

/**
 * 计算平铺窗口所在列的左侧坐标。
 * @param target niri 返回的目标窗口对象
 * @param windows niri windows 返回的窗口列表
 * @param screenWidth 当前输出宽度
 * @returns {number|null} 成功返回窗口左侧坐标，否则返回 null
 */
function tiledWindowLeft(target, windows, screenWidth) {
    if (!hasTiledPosition(target)) return null

    var targetColumn = numberAt(target.layout.pos_in_scrolling_layout, 0)
    var targetWidth = windowSize(target, 0)
    if (targetColumn === null || targetWidth === null) return null

    var columns = tiledColumns(target, windows)
    var visibleLeft = tiledColumnLeftFromStart(columns, targetColumn, screenWidth)
    if (visibleLeft !== null) return visibleLeft

    var anchorColumn = tiledAnchorColumn(target, windows)
    var left = tiledColumnLeftFromAnchor(columns, anchorColumn, targetColumn)
    if (left !== null) return left

    // niri 配置 center-focused-column 为 never 时，当前列贴左显示
    return 0
}

/**
 * 计算目标窗口左上角到输出左上角的距离。
 * @param win niri focused-window 返回的窗口对象
 * @param windows niri windows 返回的窗口列表
 * @param screenSize 当前输出在指定轴上的尺寸
 * @param axis 需要读取的坐标轴，0 为水平轴，1 为垂直轴
 * @returns {number|null} 成功返回窗口坐标，否则返回 null
 */
function windowPosition(win, windows, screenSize, axis) {
    if (!win || !win.layout) return null

    // 1. 优先使用工作区视图内坐标，该坐标最接近当前输出上的可见位置
    var tilePosition = numberAt(win.layout.tile_pos_in_workspace_view, axis)
    if (tilePosition === null && hasTiledPosition(win)) {
        tilePosition = axis === 0 ? tiledWindowLeft(win, windows, screenSize) : tiledWindowTop(win, windows, screenSize)
    }
    if (tilePosition === null) return null

    // 2. 累加窗口在 tile 内的偏移，浮动窗口和带内边距的 tile 都需要该修正
    var windowOffset = numberAt(win.layout.window_offset_in_tile, axis)
    return tilePosition + (windowOffset === null ? 0 : windowOffset)
}

/**
 * 读取目标窗口指定坐标轴上的尺寸。
 * @param win niri focused-window 返回的窗口对象
 * @param axis 需要读取的坐标轴，0 为宽度，1 为高度
 * @returns {number|null} 成功返回窗口尺寸，否则返回 null
 */
function windowSize(win, axis) {
    if (!win || !win.layout) return null

    // 1. 真实窗口尺寸优先，能避免 tile 尺寸和窗口实际大小不一致
    var size = numberAt(win.layout.window_size, axis)
    if (size !== null) return size

    // 2. 缺少真实窗口尺寸时回退到 tile 尺寸
    return numberAt(win.layout.tile_size, axis)
}

/**
 * 计算确认面板单轴边距，使面板中心对齐目标窗口中心。
 * @param win niri focused-window 返回的窗口对象
 * @param windows niri windows 返回的窗口列表
 * @param screenSize 当前输出在指定轴上的尺寸
 * @param panelSize 确认面板在指定轴上的尺寸
 * @param axis 需要计算的坐标轴，0 为水平轴，1 为垂直轴
 * @returns {number} 屏幕内安全的边距
 */
function panelAxisMargin(win, windows, screenSize, panelSize, axis) {
    var fallbackScreenSize = axis === 0 ? 1280 : 720
    var safeScreenSize = isUsableNumber(screenSize) && screenSize > 0 ? screenSize : fallbackScreenSize
    var safePanelSize = isUsableNumber(panelSize) && panelSize > 0 ? panelSize : 0
    var maxMargin = Math.max(0, safeScreenSize - safePanelSize)

    // 1. 有目标窗口几何时对齐目标窗口中心
    var position = windowPosition(win, windows, safeScreenSize, axis)
    var size = windowSize(win, axis)
    var center = position !== null && size !== null ? position + size / 2 : safeScreenSize / 2

    // 2. 计算面板边距，并限制在当前输出范围内
    var margin = Math.round(center - safePanelSize / 2)
    return Math.max(0, Math.min(margin, maxMargin))
}

/**
 * 计算确认面板左侧边距，使面板水平中心对齐目标窗口中心。
 * @param win niri focused-window 返回的窗口对象
 * @param windows niri windows 返回的窗口列表
 * @param screenWidth 当前输出宽度
 * @param panelWidth 确认面板宽度
 * @returns {number} 屏幕内安全的左侧边距
 */
function panelLeftMargin(win, windows, screenWidth, panelWidth) {
    return panelAxisMargin(win, windows, screenWidth, panelWidth, 0)
}

/**
 * 计算确认面板顶部边距，使面板垂直中心对齐目标窗口中心。
 * @param win niri focused-window 返回的窗口对象
 * @param windows niri windows 返回的窗口列表
 * @param screenHeight 当前输出高度
 * @param panelHeight 确认面板高度
 * @returns {number} 屏幕内安全的顶部边距
 */
function panelTopMargin(win, windows, screenHeight, panelHeight) {
    return panelAxisMargin(win, windows, screenHeight, panelHeight, 1)
}
