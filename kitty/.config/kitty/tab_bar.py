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
    # 1. 提取 Kitty 系统主题的 Matugen 配色
    active_bg = as_rgb(color_as_int(draw_data.active_bg))
    active_fg = as_rgb(color_as_int(draw_data.active_fg))
    inactive_bg = as_rgb(color_as_int(draw_data.inactive_bg))
    inactive_fg = as_rgb(color_as_int(draw_data.inactive_fg))
    default_bg = as_rgb(color_as_int(draw_data.default_bg))
    
    # 2. 选用胶囊风格切片符号 (Powerline Round)
    left_cap = ""
    right_cap = ""
    
    if tab.is_active:
        bg = active_bg
        fg = active_fg
    else:
        bg = inactive_bg
        fg = inactive_fg
        
    # 3. 绘制左半圆切片
    screen.cursor.fg = bg
    screen.cursor.bg = default_bg
    screen.draw(left_cap)
    
    # 4. 绘制 Tab 序号和标题
    screen.cursor.bg = bg
    screen.cursor.fg = fg
    screen.draw(f" {index} ")
    draw_title(draw_data, screen, tab, index, max_title_length)
    screen.draw(" ")
    
    # 5. 绘制右半圆切片
    screen.cursor.fg = bg
    screen.cursor.bg = default_bg
    screen.draw(right_cap)
    
    # 6. 胶囊之间留一个空格的呼吸空间
    screen.cursor.bg = default_bg
    screen.draw(" ")
    
    # 7. 如果是最后一个 Tab，在屏幕最右侧绘制系统信息胶囊，实现视觉天平
    if is_last:
        draw_right_status(screen, draw_data, default_bg, active_bg, inactive_bg)
        
    return screen.cursor.x

def draw_right_status(
    screen: Screen, 
    draw_data: DrawData, 
    default_bg: int, 
    active_bg: int,
    inactive_bg: int
) -> None:
    # 获当前日期与时间
    now = datetime.datetime.now().strftime(" %Y-%m-%d %H:%M ")
    # 选用时钟 Nerd Font 图标: 󰅐
    right_text = f"󰅐{now}"
    
    cols = screen.columns
    # 左右圆角占 2 列，加上文本长度
    text_width = len(right_text) + 2
    
    # 边缘防重叠检测
    if screen.cursor.x >= cols - text_width:
        return
        
    # 强制将光标对齐移动到右侧起点
    screen.cursor.x = cols - text_width
    
    # 绘制右侧系统信息胶囊的左圆角 (前景色为 inactive_bg 以示优雅的副级区分)
    screen.cursor.fg = inactive_bg
    screen.cursor.bg = default_bg
    screen.draw("")
    
    # 绘制系统信息正文 (背景色为 inactive_bg，前景色为 draw_data.inactive_fg)
    screen.cursor.bg = inactive_bg
    screen.cursor.fg = as_rgb(color_as_int(draw_data.inactive_fg))
    screen.draw(right_text)
    
    # 绘制右侧系统信息胶囊的右圆角
    screen.cursor.fg = inactive_bg
    screen.cursor.bg = default_bg
    screen.draw("")
