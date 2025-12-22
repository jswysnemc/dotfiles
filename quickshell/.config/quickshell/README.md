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

## 依赖

- **Quickshell** - QML 桌面组件框架
- **playerctl** - 媒体播放控制
- **wpctl** (WirePlumber) - 音频音量控制
- **bluetoothctl** - 蓝牙管理
- **nmcli** (NetworkManager) - 网络管理
- **cava** - 音频可视化 (可选)
- **matugen** - 主题色生成 (可选)

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
