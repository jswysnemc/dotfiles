import datetime
from kitty.fast_data_types import Screen, get_options
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_title,
)
from kitty.utils import color_as_int

opts = get_options()

def get_tab_icon(title: str) -> str:
    """根据 Tab 标题识别当前运行进程，并返回对应的 Nerd Font 图标

    参数:
        title (str): Tab 的标题文本

    返回:
        str: 对应的 Nerd Font 图标字符
    """
    # 1. 将标题转换为小写以进行模糊匹配
    title = title.lower()
    
    # 2. 匹配常见开发工具并返回对应图标
    if "nvim" in title or "vim" in title:
        return ""
    if "git" in title or "ggh" in title:
        return ""
    if "python" in title or "py" in title:
        return ""
    if "node" in title or "npm" in title or "yarn" in title or "bun" in title:
        return ""
    if "docker" in title:
        return "󰡨"
    if "rust" in title or "cargo" in title:
        return ""
    if "zsh" in title or "bash" in title or "sh" in title:
        return ""
    if "sudo" in title:
        return "󰽬"
    if "lazygit" in title:
        return ""
    if "yazi" in title:
        return "󰇄"
    if "fzf" in title:
        return ""
    if "ssh" in title:
        return "󰣀"
    return ""

def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    """绘制单个 Tab 的外观，采用融合底色的极简星轨指示器风格，并支持新建标签页按钮

    参数:
        draw_data (DrawData): 包含系统主题颜色等绘图元数据
        screen (Screen): Kitty 的绘图屏幕对象
        tab (TabBarData): 当前绘制 of Tab 数据
        before (int): 绘制前的光标 x 坐标
        max_title_length (int): 允许的最大标题长度
        index (int): Tab 的索引序号
        is_last (bool): 是否为最后一个 Tab
        extra_data (ExtraData): 额外绘图数据

    返回:
        int: 绘制完成后的光标 x 坐标
    """
    # 1. 提取 Kitty 系统主题的 Matugen 配色并转换为 RGB 格式
    active_bg = as_rgb(color_as_int(draw_data.active_bg))
    inactive_fg = as_rgb(color_as_int(draw_data.inactive_fg))
    default_bg = as_rgb(color_as_int(draw_data.default_bg))
    
    # 2. 判断是否为合成的新建标签页 '+' 按钮
    if tab.tab_id < 0:
        # 3. 设置加号按钮样式，亮色字体，透明背景
        screen.cursor.bold = True
        screen.cursor.fg = active_bg
        screen.cursor.bg = default_bg
        screen.draw("  ")
        
        # 4. 在按钮后绘制一格空格
        screen.draw(" ")
        
        # 5. 若是最后一个元素则在最右侧绘制星轨系统状态栏
        if is_last:
            draw_right_status(screen, draw_data, default_bg, active_bg, inactive_fg)
        return screen.cursor.x
        
    # 6. 配置普通标签页的绘制样式，根据激活状态切换星轨圆点指示器
    if tab.is_active:
        screen.cursor.bold = True
        screen.cursor.fg = active_bg
        screen.cursor.bg = default_bg
        indicator = "●"
    else:
        screen.cursor.bold = False
        screen.cursor.fg = inactive_fg
        screen.cursor.bg = default_bg
        indicator = "○"
        
    # 7. 绘制标签前缀，包括星轨指示器圆点与标签序号
    screen.draw(" ")
    screen.draw(f"{indicator} {index} ")
    
    # 8. 绘制动态匹配 of 进程图标
    icon = get_tab_icon(tab.title)
    screen.draw(f"{icon} ")
    
    # 9. 调整最大标题长度并调用官方标题渲染
    adjusted_max_len = max(5, max_title_length - 6)
    draw_title(draw_data, screen, tab, index, adjusted_max_len)
    screen.draw(" ")
    
    # 10. 绘制标签之间的轻量级斜杠分隔符
    screen.cursor.bold = False
    screen.cursor.fg = inactive_fg
    screen.draw("╱")
    
    # 11. 若是最后一个真实标签则绘制最右侧系统状态
    if is_last:
        draw_right_status(screen, draw_data, default_bg, active_bg, inactive_fg)
        
    return screen.cursor.x

def draw_right_status(
    screen: Screen, 
    draw_data: DrawData, 
    default_bg: int, 
    active_bg: int,
    inactive_fg: int
) -> None:
    """在屏幕最右侧绘制融合整体设计风格 of 轻量斜杠切分系统状态栏

    参数:
        screen (Screen): Kitty 的绘图屏幕对象
        draw_data (DrawData): 包含系统主题颜色等绘图元数据
        default_bg (int): 默认背景色
        active_bg (int): 激活状态背景色
        inactive_fg (int): 未激活状态前景色
    """
    # 1. 获取当前日期与时间并添加 Nerd Font 图标
    now = datetime.datetime.now()
    date_str = now.strftime(" 󰃭 %Y-%m-%d ")
    time_str = now.strftime(" 󰅐 %H:%M ")
    
    # 2. 计算包括斜杠分隔符在内的文本总宽度
    cols = screen.columns
    text_width = len(date_str) + len(time_str) + 1
    
    # 3. 进行边缘防重叠检测，若空间不足则不绘制
    if screen.cursor.x >= cols - text_width:
        return
        
    # 4. 强制将光标移动 to 右侧起点
    screen.cursor.x = cols - text_width
    
    # 5. 绘制日期信息，使用低调 of 暗色前景色
    screen.cursor.bold = False
    screen.cursor.fg = inactive_fg
    screen.cursor.bg = default_bg
    screen.draw(date_str)
    
    # 6. 绘制轻量斜线分隔符
    screen.draw("╱")
    
    # 7. 绘制时间信息，使用激活主题色加粗高亮
    screen.cursor.bold = True
    screen.cursor.fg = active_bg
    screen.draw(time_str)

from kitty.tabs import TabManager
from kitty.fast_data_types import GLFW_RELEASE, get_boss

# 保存系统原始的鼠标事件处理函数
original_handle_tab_bar_mouse = TabManager.handle_tab_bar_mouse

def patched_handle_tab_bar_mouse(self, x: float, y: float, button: int, modifiers: int, action: int) -> None:
    """对 Kitty 的标签栏鼠标事件进行代理拦截，额外支持鼠标右键点击关闭标签页

    参数:
        self (TabManager): Kitty 的 Tab 管理器实例
        x (float): 鼠标点击的 x 坐标
        y (float): 鼠标点击 of y 坐标
        button (int): 点击的鼠标按键编号
        modifiers (int): 键盘修饰键状态
        action (int): 鼠标动作类型（按下或释放）
    """
    # 1. 尝试从 fast_data_types 中导入右键常量，若失败则使用 GLFW 标准值 1
    try:
        from kitty.fast_data_types import GLFW_MOUSE_BUTTON_RIGHT
    except ImportError:
        GLFW_MOUSE_BUTTON_RIGHT = 1

    # 2. 如果点击的按键为右键
    if button == GLFW_MOUSE_BUTTON_RIGHT:
        # 3. 仅在鼠标右键释放时执行关闭逻辑
        if action == GLFW_RELEASE:
            tab_id_at_x = self.tab_bar.tab_id_at(int(x))
            # 4. 仅当点击在有效的真实标签页上时触发关闭动作
            if tab_id_at_x > 0:
                tab = self.tab_for_id(tab_id_at_x)
                if tab is not None:
                    get_boss().close_tab(tab)
        return

    # 5. 对于非右键事件，执行 Kitty 原生的鼠标事件处理逻辑
    original_handle_tab_bar_mouse(self, x, y, button, modifiers, action)

# 6. 将新的代理函数动态注入到 TabManager 类中以使补丁生效
TabManager.handle_tab_bar_mouse = patched_handle_tab_bar_mouse
