# Niri 配置

这是一个模块化的 [Niri](https://github.com/YaLTeR/niri) 窗口管理器配置，适用于 Wayland 环境。

## 目录结构

```
~/.config/niri/
├── config.kdl          # 主配置文件（加载所有模块）
├── config.kdl.all      # 完整配置备份
├── conf.d/             # 模块化配置目录
│   ├── input.kdl       # 输入设备配置
│   ├── output.kdl      # 显示器配置
│   ├── layout.kdl      # 布局配置
│   ├── appearance.kdl  # 外观配置
│   ├── environment.kdl # 环境变量配置
│   ├── autostart.kdl   # 自启动程序配置
│   ├── window-rules.kdl# 窗口规则配置
│   └── binds.kdl       # 快捷键配置
└── scripts/            # 自定义脚本目录
```

## 模块说明

### 输入设备 (`input.kdl`)

- **键盘**: 启用数字小键盘
- **触摸板**: 启用轻触点击、自然滚动
- **鼠标行为**: 焦点跟随鼠标、鼠标自动跳转到新焦点窗口

### 显示器 (`output.kdl`)

| 输出 | 分辨率 | 缩放 |
|------|--------|------|
| eDP-1 | 2560x1600@60Hz | 1.1 |

### 布局 (`layout.kdl`)

- **间距**: 5px
- **预设列宽**: 1/3、1/2、2/3
- **默认列宽**: 50%
- **焦点环**: 2px 宽，活动颜色 `#7fc8ff`
- **阴影**: 已启用，柔和度 20，扩散 10

### 外观 (`appearance.kdl`)

- **光标主题**: `phinger-cursors-light`，大小 24
- **截图路径**: `~/Pictures/Screenshots/`
- **禁用 CSD**: 使用 niri 原生窗口装饰

### 环境变量 (`environment.kdl`)

- **语言**: 中文 (`zh_CN.UTF-8`)
- **Qt 主题**: `qt6ct`
- **输入法**: Fcitx5

### 自启动 (`autostart.kdl`)

| 服务 | 说明 |
|------|------|
| fcitx5 | 输入法 |
| mako | 通知守护进程 |
| waybar | 状态栏 |
| cliphist/clipse | 剪贴板管理 |
| swww | 壁纸 |
| swayidle | 空闲管理 |
| hyprpolkitagent | 权限认证 |

### 窗口规则 (`window-rules.kdl`)

- **全局**: 圆角 2px，透明度 0.99
- **浮动窗口**: CopyQ、Clash Verge、Mission Center、Firefox 画中画等
- **输入法窗口**: 禁用焦点环、边框、阴影
- **全屏窗口**: GPU Screen Recorder UI、Waydroid

## 快捷键

### 程序启动

| 快捷键 | 功能 |
|--------|------|
| `Mod+T` / `Mod+Return` | 终端 (kitty) |
| `Alt+Space` | 应用启动器 (rofi) |
| `Mod+B` | 浏览器 (Firefox) |
| `Mod+E` | 文件管理器 (Dolphin) |
| `Alt+V` | 剪贴板 (clipse-gui) |
| `Mod+Shift+Return` | 浮动终端 |
| `Mod+Z` | 任务管理器 (Mission Center) |

### 截图

| 快捷键 | 功能 |
|--------|------|
| `Mod+Shift+S` | 区域截图到剪贴板 |
| `Alt+Ctrl+S` | 截图编辑 |
| `Print` | 全屏截图 |
| `Ctrl+Print` | 当前屏幕截图 |
| `Alt+Print` | 窗口截图 |

### 窗口操作

| 快捷键 | 功能 |
|--------|------|
| `Mod+C` | 关闭窗口 |
| `Mod+F` | 最大化列 |
| `Mod+Shift+F` | 全屏 |
| `Mod+V` | 切换浮动/平铺 |
| `Mod+W` | 切换标签模式 |
| `Mod+A` | 居中列 |
| `Mod+R` | 切换预设列宽 |

### 焦点移动

| 快捷键 | 功能 |
|--------|------|
| `Mod+H/J/K/L` | 左/下/上/右移动焦点 |
| `Mod+方向键` | 同上 |
| `Mod+Ctrl+H/J/K/L` | 移动窗口 |
| `Mod+Shift+H/J/K/L` | 跨显示器焦点 |

### 工作区

| 快捷键 | 功能 |
|--------|------|
| `Mod+1-9` | 切换到工作区 1-9 |
| `Mod+Ctrl+1-9` | 移动窗口到工作区 1-9 |
| `Mod+U/I` | 上/下工作区 |
| `Mod+O` | 概览视图 |
| `Mod+滚轮` | 切换工作区 |

### 系统

| 快捷键 | 功能 |
|--------|------|
| `Super+Alt+L` | 锁屏 |
| `Mod+Shift+E` | 退出 niri |
| `Mod+Shift+P` | 关闭显示器 |
| `Mod+Shift+?` | 显示快捷键帮助 |

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `niri` | Wayland 窗口管理器 |
| `fcitx5` | 中文输入法 |
| `fcitx5-im` | 输入法集成 |
| `fcitx5-chinese-addons` | 中文输入法支持 |

### 桌面应用

| 包名 | 用途 |
|------|------|
| `kitty` | 终端模拟器 |
| `rofi` | 应用启动器 |
| `dolphin` | 文件管理器 |
| `firefox` | 浏览器 |

### 系统服务

| 包名 | 用途 |
|------|------|
| `waybar` | 状态栏 |
| `mako` | 通知守护进程 |
| `hyprlock` | 锁屏工具 |
| `hyprpolkitagent` | 权限认证 |

### 壁纸和主题

| 包名 | 用途 |
|------|------|
| `swww` | 壁纸管理 |
| `matugen` | 主题生成器 |

### 空闲管理

| 包名 | 用途 |
|------|------|
| `swayidle` | 空闲管理 |

### 截图和录屏

| 包名 | 用途 |
|------|------|
| `grim` | 截图工具 |
| `slurp` | 区域选择工具 |
| `wayfreeze` | 截图冻结工具 |
| `wf-recorder` | 屏幕录制 |

### 剪贴板

| 包名 | 用途 |
|------|------|
| `wl-clipboard` | Wayland 剪贴板工具（wl-paste, wl-copy） |
| `cliphist` | 剪贴板历史 |
| `clipse` | 剪贴板管理器 |

### 硬件控制

| 包名 | 用途 |
|------|------|
| `brightnessctl` | 亮度控制 |
| `wireplumber` | PipeWire 音频服务（提供 wpctl） |

### 网络和蓝牙

| 包名 | 用途 |
|------|------|
| `networkmanager` | 网络管理 |
| `blueman` | 蓝牙管理 |

### 其他工具

| 包名 | 用途 |
|------|------|
| `nwg-drawer` | 应用启动器 |
| `pavucontrol` | 音频控制面板 |
| `btop` | 系统监控 |
| `wtype` | 模拟键盘输入 |
| `power-profiles-daemon` | 电源配置管理 |
| `ffmpeg` | 视频处理 |
| `imagemagick` | 图像处理 |
| `xclip` | X11 剪贴板工具 |

## 脚本依赖

| 脚本 | 依赖 |
|------|------|
| `swww.sh` | `swww` |
| `swayidle.sh` | `swayidle`, `hyprlock`, `wtype`, `niri` |
| `clipboard-sync` | `wl-clipboard`, `xclip`, `md5sum` |
| `wallpaper-selector.sh` | `rofi`, `swww`, `matugen`, `ffmpeg`, `imagemagick`, `notify-send` |
| `wallpaper-selector-fuzzul.sh` | `fuzzel`, `swww`, `matugen`, `ffmpeg`, `imagemagick`, `notify-send` |
| `niri-monitor-switch.sh` | `niri` |

## 参考

- [Niri 官方文档](https://github.com/YaLTeR/niri/wiki)
- [Niri 配置介绍](https://yalter.github.io/niri/Configuration:-Introduction)
