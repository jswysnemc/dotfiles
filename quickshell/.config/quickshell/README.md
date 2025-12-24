# Quickshell 组件集

基于 [Quickshell](https://quickshell.outfoxxed.me/) 的桌面组件集合，为 Wayland 桌面环境提供现代化的弹窗界面。

## 功能模块

| 模块 | 文件 | 说明 |
|------|------|------|
| **媒体控制** | `MediaManager.qml` / `MediaPopup.qml` | 媒体播放控制，支持 MPRIS |
| **通知中心** | `NotificationManager.qml` / `NotificationPopup.qml` | 通知管理，支持历史记录 |
| **蓝牙管理** | `BluetoothManager.qml` / `BluetoothPopup.qml` | 蓝牙设备扫描与连接 |
| **WiFi 管理** | `WifiManager.qml` / `WifiPopup.qml` | 无线网络管理 |
| **天气预报** | `WeatherManager.qml` / `WeatherPopup.qml` | 天气信息显示 |
| **日历** | `CalendarManager.qml` / `CalendarPopup.qml` | 日历与农历支持 |
| **控制中心** | `ControlCenterManager.qml` / `ControlCenterPopup.qml` | 快捷设置面板 |
| **视觉模型** | `VisualModelManager.qml` / `VisualModelPopup.qml` | AI 图像识别工具 |

## 目录结构

```
~/.config/quickshell/
├── shell.qml                 # 主入口
├── colors.js                 # 颜色定义 (matugen 生成，符号链接)
├── *Manager.qml              # 各模块逻辑管理器
├── *Popup.qml                # 各模块 UI 弹窗
├── scripts/                  # 脚本目录
│   ├── media_status.sh       # Waybar 媒体状态
│   ├── media_visualizer.sh   # Waybar 音律条 (cava)
│   ├── notification_daemon.py # 通知监听守护进程
│   ├── lunar_calendar.py     # 农历计算
│   ├── weather_fetch.py      # 天气数据获取
│   └── visual-model-launcher.sh # 视觉模型启动器
└── visual_model_templates.json # 视觉模型模板配置
```

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `quickshell` | QML 桌面组件框架 |
| `qt6-declarative` | Qt Quick 声明 |
| `qt6-quickcontrols` | Qt Quick 控件 |

### 媒体和音频

| 包名 | 用途 |
|------|------|
| `playerctl` | 媒体播放控制 |
| `wireplumber` | PipeWire 音频服务（提供 wpctl） |
| `cava` | 音频可视化 |

### 网络和蓝牙

| 包名 | 用途 |
|------|------|
| `blueman` | 蓝牙管理 |
| `networkmanager` | 网络管理 |

### 主题集成

| 包名 | 用途 |
|------|------|
| `matugen` | 主题色生成器 |

### 其他工具

| 包名 | 用途 |
|------|------|
| `jq` | JSON 处理 |
| `curl` | HTTP 客户端 |
| `python` | Python 脚本 |
| `python-pip` | Python 包管理器 |

### 可选依赖

| 包名 | 用途 |
|------|------|
| `bat` | Markdown 渲染（可选） |
| `mdcat` | Markdown 渲染（可选） |
| `glow` | Markdown 渲染（可选） |

### 脚本依赖

| 脚本 | 依赖 |
|------|------|
| `media_status.sh` | `bash`, `playerctl` |
| `media_visualizer.sh` | `bash`, `cava`, `playerctl` |
| `notification_daemon.py` | `python`, `dbus-monitor`, `makoctl` |
| `weather_fetch.py` | `python`, `curl`, `urllib`, `subprocess`, `json` |
| `visual-model-launcher.sh` | `bash`, `jq`, `quickshell` |
| `lunar_calendar.py` | `python`, `lunarcalendar` (pip), `calendar`, `datetime` |

### Python 依赖

```bash
# 安装农历转换库
pip install lunarcalendar
```

## 使用方式

### 从 Waybar 调用

```jsonc
// ~/.config/waybar/config.jsonc
"custom/media": {
    "exec": "~/.config/quickshell/scripts/media_status.sh",
    "on-click": "POPUP_TYPE=media quickshell -c ~/.config/quickshell"
}
```

### 直接启动弹窗

```bash
# 媒体控制
POPUP_TYPE=media quickshell -c ~/.config/quickshell

# 通知中心
POPUP_TYPE=notification quickshell -c ~/.config/quickshell

# 蓝牙管理
POPUP_TYPE=bluetooth quickshell -c ~/.config/quickshell

# WiFi 管理
POPUP_TYPE=wifi quickshell -c ~/.config/quickshell

# 天气
POPUP_TYPE=weather quickshell -c ~/.config/quickshell

# 日历
POPUP_TYPE=calendar quickshell -c ~/.config/quickshell
```

## Matugen 主题集成

颜色由 [matugen](https://github.com/InioX/matugen) 动态生成，配置位于：

- 模板: `~/.config/matugen/templates/quickshell-colors.js`
- 输出: `~/.cache/matugen/quickshell/colors.js`
- 链接: `~/.config/quickshell/colors.js`

生成主题色：

```bash
matugen image /path/to/wallpaper.jpg
# 或使用指定颜色
matugen color hex "#89b4fa"
```

## 通知守护进程

启动通知监听：

```bash
python ~/.config/quickshell/scripts/notification_daemon.py &
```

建议添加到自启动脚本。

## 许可

MIT License
