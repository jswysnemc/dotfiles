# Niri 配置

这是一个模块化的 [Niri](https://github.com/YaLTeR/niri) 窗口管理器配置，适用于 Wayland 环境。

## 目录结构

```
~/.config/niri/
├── config.kdl              # 主配置文件（模块加载器）
├── noctalia.kdl            # Noctalia 主题配色
├── conf.d/                 # 模块化配置目录
│   ├── input.kdl           # 输入设备配置
│   ├── output.kdl          # 显示器配置
│   ├── layout.kdl          # 布局配置
│   ├── appearance.kdl      # 外观配置
│   ├── environment.kdl     # 环境变量配置
│   ├── autostart.kdl       # 自启动程序配置
│   ├── window-rules.kdl    # 窗口规则配置
│   └── binds.kdl           # 快捷键配置
└── scripts/                # 自定义脚本目录
    ├── swww.sh             # 壁纸管理
    ├── swayidle.sh         # 空闲管理
    ├── auto-archive.sh     # 文件自动归档
    ├── clipboard-sync      # 剪贴板同步 (X11/Wayland)
    ├── wallpaper-selector.sh       # 壁纸选择器 (Rofi)
    ├── wallpaper-selector-fuzzul.sh # 壁纸选择器 (Fuzzel)
    └── niri-monitor-switch.sh      # 显示器配置切换
```

## 模块说明

### 输入设备 (`input.kdl`)

- **键盘**: 启用数字小键盘
- **触摸板**: 启用轻触点击、自然滚动
- **鼠标行为**: 焦点跟随鼠标、鼠标自动跳转到新焦点窗口

### 显示器 (`output.kdl`)

| 输出 | 分辨率 | 缩放 |
|------|--------|------|
| eDP-1 | 2560x1600@240Hz | 1.0 |

### 布局 (`layout.kdl`)

- **间距**: 5px
- **预设列宽**: 50%、100%（半屏/全屏切换）
- **焦点环**: 2px 宽，活动颜色 `#7fc8ff`，非活动 `#505050`
- **阴影**: 已启用，柔和度 20，扩散 10，颜色 `#0007`
- **模糊**: 已启用，2 次通过，半径 4，噪声 0.1

### 外观 (`appearance.kdl`)

- **光标主题**: `phinger-cursors-light`，大小 24
- **截图路径**: `~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png`
- **禁用 CSD**: 使用 niri 原生窗口装饰
- **快捷键提示**: 启动时跳过

### 环境变量 (`environment.kdl`)

- **语言**: 中文 (`zh_CN.UTF-8`) - 完整的 LC_* 设置
- **Qt 主题**: `qt6ct`
- **输入法**: Fcitx5 (`XMODIFIERS="@im=fcitx"`)

### 主题 (`noctalia.kdl`)

Noctalia 配色方案：

| 元素 | 活动 | 非活动 | 紧急 |
|------|------|--------|------|
| 焦点环 | `#5257a1` | `#fbf8ff` | `#ba1a1a` |
| 边框 | `#5257a1` | `#fbf8ff` | `#ba1a1a` |
| 标签指示器 | `#5257a1` | `#a9aefe` | `#ba1a1a` |

- **阴影**: `#00000070`
- **插入提示**: `#5257a180`

### 自启动 (`autostart.kdl`)

| 服务 | 说明 |
|------|------|
| fcitx5 | 输入法 |
| quickshell notifications | 通知守护进程 (uv run) |
| sticky-notes | 便签服务 |
| wl-paste + cliphist | 剪贴板管理 (文本+图片) |
| clipboard-sync | X11/Wayland 剪贴板同步 |
| swayidle.sh | 空闲管理 |
| swww.sh | 壁纸管理 |
| auto-archive.sh | 文件自动归档 |
| waybar | 状态栏 |
| hyprpolkitagent | 权限认证 |
| XDG Portal | 文件对话框支持 |

### 窗口规则 (`window-rules.kdl`)

**全局规则**:
- 透明度: 0.9
- 圆角: 2px
- 禁用边框背景绘制

**特殊应用规则**:

| 应用 | 规则 |
|------|------|
| 壁纸工具 | 背景层，不随工作区缩放 |
| Fcitx5 输入法 | 浮动，禁用焦点环/阴影，启用边框 |
| CopyQ | 浮动，固定 800x600 |
| Waybar | 启用模糊 (2 次通过，半径 4) |
| Clash Verge | 浮动 |
| kitty-float | 浮动，固定 1200x1000 |
| Mission Center | 浮动，固定 1200x1000 |
| Firefox 画中画 | 浮动 |
| GSR UI / Waydroid | 全屏浮动，禁用焦点环/阴影 |
| 蓝牙/音量控制 | 右上角浮动 |

## 快捷键

### 程序启动

| 快捷键 | 功能 |
|--------|------|
| `Mod+T` / `Mod+Return` | 终端 (kitty) |
| `Alt+Space` | 应用启动器 (quickshell launcher) |
| `Alt+V` | 剪贴板 (quickshell clipboard) |
| `Mod+B` | 浏览器 (Firefox) |
| `Mod+E` | 文件管理器 (Dolphin) |
| `Super+Alt+L` | 锁屏 (swaylock) |
| `Mod+Shift+Return` | 浮动终端 |
| `Mod+Shift+B` | 重启 waybar |
| `Mod+Z` | 任务管理器 (Mission Center) |
| `Mod+Shift+W` | 切换壁纸 (quickshell wallpaper) |
| `Mod+Ctrl+S` | 刷新率配置 |

### 截图

| 快捷键 | 功能 |
|--------|------|
| `Mod+Shift+S` | 区域截图到剪贴板 |
| `Alt+Ctrl+S` | 截图编辑 (Markpix) |
| `Print` | 全屏截图 |
| `Ctrl+Print` | 当前屏幕截图 |
| `Alt+Print` | 窗口截图 |

### 音量/亮度

| 快捷键 | 功能 |
|--------|------|
| `XF86AudioRaiseVolume` | 音量增加 |
| `XF86AudioLowerVolume` | 音量减少 |
| `XF86AudioMute` | 静音切换 |
| `XF86AudioMicMute` | 麦克风静音 |
| `XF86MonBrightnessUp` | 亮度增加 |
| `XF86MonBrightnessDown` | 亮度减少 |

### 窗口操作

| 快捷键 | 功能 |
|--------|------|
| `Mod+C` | 关闭窗口 |
| `Mod+O` | 概览视图 |
| `Mod+V` | 切换浮动/平铺 |
| `Mod+Shift+V` | 在浮动和平铺间切换焦点 |
| `Mod+W` | 切换标签模式 |
| `Mod+F` | 最大化列 |
| `Mod+Shift+F` | 全屏窗口 |
| `Mod+Ctrl+F` | 扩展列到可用宽度 |
| `Mod+A` | 居中列 |
| `Mod+Ctrl+C` | 居中所有可见列 |
| `Mod+R` | 切换预设列宽 |
| `Mod+Shift+R` | 切换预设窗口高度 |
| `Mod+Ctrl+R` | 重置窗口高度 |
| `Mod+Minus/Equal` | 调整列宽 (-/+10%) |
| `Mod+Shift+Minus/Equal` | 调整窗口高度 (-/+10%) |

### 焦点移动

| 快捷键 | 功能 |
|--------|------|
| `Mod+H/J/K/L` | 左/下/上/右移动焦点 |
| `Mod+方向键` | 同上 |
| `Mod+Home/End` | 焦点到列首/尾 |
| `Mod+Ctrl+H/J/K/L` | 移动窗口 |
| `Mod+Ctrl+Home/End` | 移动列到首/尾 |
| `Mod+Shift+H/J/K/L` | 跨显示器焦点移动 |
| `Mod+Shift+Ctrl+H/J/K/L` | 跨显示器移动列 |

### 工作区

| 快捷键 | 功能 |
|--------|------|
| `Mod+1-9` | 切换到工作区 1-9 |
| `Mod+Ctrl+1-9` | 移动列到工作区 1-9 |
| `Mod+U/I` | 上/下工作区 |
| `Mod+Page_Down/Page_Up` | 同上 |
| `Mod+Ctrl+U/I` | 移动列到上/下工作区 |
| `Mod+Shift+U/I` | 移动工作区上/下 |
| `Mod+滚轮` | 切换工作区/列 |

### 列操作

| 快捷键 | 功能 |
|--------|------|
| `Mod+BracketLeft/Right` | 消费/驱逐窗口左/右 |
| `Mod+Comma` | 消费窗口进列 |
| `Mod+Period` | 驱逐窗口出列 |

### 系统

| 快捷键 | 功能 |
|--------|------|
| `XF86PowerOff` | 电源菜单 (quickshell power-menu) |
| `Mod+MouseMiddle` | 关闭确认对话框 |
| `Mod+Escape` | 切换键盘快捷键禁用 |
| `Mod+Shift+E` | 退出 Niri |
| `Ctrl+Alt+Delete` | 退出 Niri |
| `Mod+Shift+P` | 关闭显示器 |
| `Mod+Shift+Slash` | 显示快捷键帮助 |

## 自定义脚本

### swww.sh - 壁纸管理

启动 swww 守护进程并设置壁纸，使用 grow 过渡效果。

### swayidle.sh - 空闲管理

- 60 秒空闲: 锁屏 (hyprlock)
- 120 秒空闲: 关闭显示器
- 唤醒后: 自动按回车触发认证

### auto-archive.sh - 文件自动归档

根据文件创建日期自动归档到 `YYYY-MM-DD` 格式的日期文件夹。需要在目标目录创建 `.auto-archive/config` 配置文件启用。

### clipboard-sync - 剪贴板同步

X11 和 Wayland 剪贴板双向同步：
- X11 监听: 使用 clipnotify (事件驱动)
- Wayland 监听: 使用轮询
- 支持文本、图片、文件列表
- 哈希对比避免重复同步

### wallpaper-selector.sh - 壁纸选择器

使用 Rofi 选择和设置壁纸，支持缩略图预览、视频首帧提取、matugen 主题生成。

### niri-monitor-switch.sh - 显示器配置切换

使用 Fuzzel 菜单交互式选择显示器分辨率和刷新率。

## 依赖

- **终端**: kitty
- **启动器**: quickshell
- **文件管理器**: dolphin
- **浏览器**: firefox
- **状态栏**: waybar
- **通知**: quickshell notifications
- **锁屏**: swaylock, hyprlock
- **壁纸**: swww
- **空闲管理**: swayidle
- **截图**: grim, slurp, wayfreeze, markpix
- **剪贴板**: wl-paste, cliphist, xclip, clipnotify
- **输入法**: fcitx5
- **权限认证**: hyprpolkitagent
- **亮度控制**: brightnessctl
- **音频控制**: wpctl (WirePlumber)
- **Python**: uv (包管理器)

## 参考

- [Niri 官方文档](https://github.com/YaLTeR/niri/wiki)
- [Niri 配置介绍](https://yalter.github.io/niri/Configuration:-Introduction)
