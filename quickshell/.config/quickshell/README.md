# QuickShell Popups

轻量级、独立的 Wayland 弹出组件集合，专为 Waybar 和 Niri 窗口管理器设计。

## 目录

- [从零开始安装](#从零开始安装)
- [功能特性](#功能特性)
- [组件列表](#组件列表)
- [目录结构](#目录结构)
- [配置](#配置)
- [Waybar 集成](#waybar-集成)
- [Niri 快捷键](#niri-快捷键)
- [快捷键](#快捷键)
- [故障排除](#故障排除)

## 从零开始安装

### 1. 安装依赖

```bash
# Quickshell (从 AUR)
paru -S quickshell-git

# Nerd Fonts (图标支持)
paru -S ttf-nerd-fonts-symbols-mono

# Python 包管理器
paru -S uv

# 可选依赖 (按需安装)
paru -S networkmanager bluez pipewire brightnessctl \
    cliphist wl-clipboard swww playerctl cava
```

### 2. 应用配置

```bash
cd ~/.dotfiles
stow quickshell
```

### 3. 安装 Python 依赖

```bash
cd ~/.config/quickshell
uv sync
```

### 4. 创建 qs-popup 启动脚本

创建 `~/.local/bin/qs-popup` 脚本用于启动/切换弹窗组件：

```bash
mkdir -p ~/.local/bin

cat > ~/.local/bin/qs-popup << 'EOFSCRIPT'
#!/bin/bash
# QuickShell popup launcher for Waybar integration

QS_CONFIG_DIR="$HOME/.config/quickshell"
QS_POS_CONF="$QS_CONFIG_DIR/position.conf"

COMPONENT="$1"
if [ $# -gt 0 ]; then
    shift
fi

show_help() {
    echo "Usage: qs-popup <component> [options]"
    echo ""
    echo "Components:"
    echo "  wifi           - WiFi network manager"
    echo "  bluetooth      - Bluetooth device manager"
    echo "  notifications  - Notification center"
    echo "  weather        - Weather widget"
    echo "  calendar       - Calendar widget"
    echo "  media          - Media player controls"
    echo "  volume         - Volume and brightness controls"
    echo "  launcher       - Application launcher"
    echo "  clipboard      - Clipboard manager"
    echo "  wallpaper      - Wallpaper selector"
    echo "  close-confirm  - Close window confirmation"
    echo "  window-switcher - Window switcher"
    echo "  power-menu     - Power menu"
}

# Read position from config file
read_config() {
    local name="$1"
    QS_POS="top-right"
    QS_MARGIN_T="8"
    QS_MARGIN_R="8"
    QS_MARGIN_B="0"
    QS_MARGIN_L="0"

    if [[ -f "$QS_POS_CONF" ]]; then
        local line
        line=$(grep "^${name}=" "$QS_POS_CONF" 2>/dev/null | head -1)
        if [[ -n "$line" ]]; then
            local value="${line#*=}"
            IFS=',' read -ra parts <<< "$value"
            [[ -n "${parts[0]}" ]] && QS_POS="${parts[0]}"
            [[ -n "${parts[1]}" ]] && QS_MARGIN_T="${parts[1]}"
            [[ -n "${parts[2]}" ]] && QS_MARGIN_R="${parts[2]}"
        fi
    fi
}

toggle_popup() {
    local name="$1"
    local shell_path="$QS_CONFIG_DIR/$name/shell.qml"

    if pgrep -f "quickshell.*$name/shell.qml" > /dev/null; then
        pkill -f "quickshell.*$name/shell.qml"
    else
        if [[ -f "$shell_path" ]]; then
            read_config "$name"
            QS_POS="$QS_POS" \
            QS_MARGIN_T="$QS_MARGIN_T" \
            QS_MARGIN_R="$QS_MARGIN_R" \
            QS_MARGIN_B="$QS_MARGIN_B" \
            QS_MARGIN_L="$QS_MARGIN_L" \
            quickshell -p "$shell_path" &
        else
            notify-send "QuickShell" "Component not found: $shell_path"
            exit 1
        fi
    fi
}

if [[ -z "$COMPONENT" ]]; then
    show_help
    exit 0
fi

case "$COMPONENT" in
    wifi) toggle_popup "wifi" ;;
    bluetooth) toggle_popup "bluetooth" ;;
    notifications|notif) toggle_popup "notifications" ;;
    weather) toggle_popup "weather" ;;
    calendar|cal) toggle_popup "calendar" ;;
    media|player) toggle_popup "media" ;;
    volume|vol|brightness) toggle_popup "volume" ;;
    launcher|launch|app) toggle_popup "launcher" ;;
    clipboard|clip|cb) toggle_popup "clipboard" ;;
    power-menu|power|pm) toggle_popup "power-menu" ;;
    wallpaper-selector|wallpaper|wp) toggle_popup "wallpaper-selector" ;;
    close-confirm|close) toggle_popup "close-confirm" ;;
    window-switcher|windows|ws) toggle_popup "window-switcher" ;;
    -h|--help|help) show_help ;;
    *) echo "Unknown component: $COMPONENT"; show_help; exit 1 ;;
esac
EOFSCRIPT

chmod +x ~/.local/bin/qs-popup
```

### 5. 确保 PATH 包含 ~/.local/bin

在 `~/.zshrc` 或 `~/.bashrc` 中添加：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 6. 启动通知守护进程 (可选)

```bash
cd ~/.config/quickshell
uv run python notifications/main.py &
```

或在 Niri 配置中自动启动（已配置在 `autostart.kdl`）。

### 7. 验证安装

```bash
# 测试 qs-popup
qs-popup --help

# 测试启动器
qs-popup launcher
```

## 功能特性

- 统一的主题设计 (Commons/Theme.js)
- 支持自定义位置和边距 (position.conf)
- 键盘友好 (Escape 关闭，方向键导航)
- 低资源占用，按需启动
- 环境变量驱动的模块化架构

## 组件列表

| 组件 | 命令 | 别名 | 描述 |
|------|------|------|------|
| WiFi | `qs-popup wifi` | - | WiFi 网络管理 (NetworkManager) |
| 蓝牙 | `qs-popup bluetooth` | - | 蓝牙设备管理 (bluetoothctl) |
| 音量 | `qs-popup volume` | `vol`, `brightness` | 音量与亮度控制 (PipeWire) |
| 日历 | `qs-popup calendar` | `cal` | 农历日历 (lunarcalendar) |
| 天气 | `qs-popup weather` | - | 天气预报 (Open-Meteo API) |
| 媒体 | `qs-popup media` | `player` | MPRIS 媒体控制 + 歌词 |
| 通知 | `qs-popup notifications` | `notif` | 通知中心 (D-Bus) |
| 启动器 | `qs-popup launcher` | `launch`, `app` | 应用启动器 |
| 剪贴板 | `qs-popup clipboard` | `clip`, `cb` | 剪贴板历史 (cliphist) |
| 电源菜单 | `qs-popup power-menu` | `power`, `pm` | 关机/重启/注销 |
| 壁纸选择 | `qs-popup wallpaper-selector` | `wallpaper`, `wp` | 壁纸切换 (swww) |
| 关闭确认 | `qs-popup close-confirm` | `close` | 窗口关闭确认 |
| 窗口切换 | `qs-popup window-switcher` | `windows`, `ws` | 模糊搜索窗口切换 |
| 锁屏 | `qs-lock` | - | 锁屏界面 (PAM 认证 + 人脸识别) |

## 目录结构

```
~/.config/quickshell/
├── shell.qml                    # 主入口 (通过 POPUP_TYPE 环境变量加载)
├── position.conf                # 组件位置配置
├── pyproject.toml               # Python 依赖管理
├── uv.lock                      # 依赖锁定文件
├── visual_model_templates.json  # 视觉模型模板 (OCR/图片描述)
│
├── Commons/
│   └── Theme.js                 # 统一主题配置
│
├── 功能组件目录 (14 个)
│   ├── wifi/shell.qml
│   ├── bluetooth/
│   │   ├── shell.qml
│   │   ├── bluetooth-connect.sh
│   │   └── BluetoothUtils.js
│   ├── volume/shell.qml
│   ├── calendar/
│   │   ├── shell.qml
│   │   ├── main.py
│   │   └── lunar_calendar.py
│   ├── weather/shell.qml
│   ├── media/
│   │   ├── shell.qml
│   │   └── lyrics_fetcher.py    # 歌词获取 (lrclib.net)
│   ├── notifications/
│   │   ├── shell.qml
│   │   ├── popup.qml
│   │   └── main.py
│   ├── launcher/shell.qml
│   ├── clipboard/shell.qml
│   ├── power-menu/shell.qml
│   ├── wallpaper-selector/shell.qml
│   ├── close-confirm/shell.qml
│   ├── window-switcher/shell.qml
│   └── lockscreen/              # 锁屏组件
│       ├── shell.qml
│       ├── lunar_info.py
│       └── README.md
│
└── scripts/                     # Waybar 集成脚本
    ├── clock_lunar.sh           # 农历时钟 (3 种格式)
    ├── clock_toggle.sh          # 时钟显示切换
    ├── lunar_today.sh           # 今日农历信息
    ├── media_status.sh          # 媒体状态
    ├── media_visualizer.sh      # 音频可视化 (cava)
    ├── weather_fetch.py         # 天气获取 (Open-Meteo)
    ├── notification_daemon.py   # 通知守护进程
    └── lunar_calendar.py        # 农历计算库
```

## 依赖

### 必需

```bash
# Arch Linux
paru -S quickshell-git ttf-nerd-fonts-symbols-mono uv
```

- **quickshell** - QML Shell 框架
- **Nerd Fonts** - 图标字体 (Symbols Nerd Font Mono)
- **uv** - Python 包管理器

### Python 依赖

```bash
# 使用 uv 管理
cd ~/.config/quickshell
uv sync
```

- **dbus-next** >= 0.2.3 - D-Bus 通信
- **httpx** >= 0.28.1 - HTTP 请求
- **lunarcalendar** >= 0.0.9 - 农历计算

### 可选 (按组件)

| 组件 | 依赖 |
|------|------|
| WiFi | `networkmanager`, `nmcli` |
| 蓝牙 | `bluez`, `bluetoothctl` |
| 音量 | `pipewire`, `brightnessctl` |
| 天气 | `curl`, `jq` |
| 日历 | `python-lunarcalendar` |
| 媒体 | `playerctl` |
| 剪贴板 | `cliphist`, `wl-clipboard` |
| 壁纸 | `swww` 或 `swaybg` |
| 通知 | `python>=3.11`, `uv`, `dbus-python` |
| 可视化 | `cava` |

```bash
# 安装所有可选依赖 (Arch Linux)
paru -S networkmanager bluez pipewire brightnessctl curl jq \
        cliphist wl-clipboard swww playerctl cava
```

## 配置

### 位置配置

编辑 `~/.config/quickshell/position.conf`：

```ini
# 格式: 组件名=位置[,边距1[,边距2]]

# 可用位置:
#   top-left      top-center      top-right
#   center-left   center          center-right
#   bottom-left   bottom-center   bottom-right

# 示例
wifi=top-right,30,450      # 上=30, 右=450
calendar=top-center,8      # 上=8
launcher=center            # 屏幕居中
```

### 主题配置

编辑 `~/.config/quickshell/Commons/Theme.js`：

```javascript
// 颜色系统
var background = "#f6f7fb"
var surface = "#ffffff"
var primary = "#3b6ef5"
var secondary = "#7a56d6"
var tertiary = "#..."
var success = "#2e9d63"
var warning = "#c57f1b"
var error = "#e04f5f"
var textPrimary = "#1f2430"
var textSecondary = "#..."
var textMuted = "#6b7280"
var outline = "#d5dbe7"

// 字体大小
var fontSizeXS = 10
var fontSizeS = 11
var fontSizeM = 12
var fontSizeL = 14
var fontSizeXL = 16
var fontSizeHuge = 28

// 间距
var spacingXS = 4
var spacingS = 6
var spacingM = 10
var spacingL = 14
var spacingXL = 20

// 圆角
var radiusS = 6
var radiusM = 10
var radiusL = 14
var radiusPill = 100

// 动画时长
var animFast = 120
var animNormal = 200
var animSlow = 300

// 辅助函数
function alpha(color, a) { ... }
```

### 天气配置

编辑 `~/.config/quickshell/weather/shell.qml`：

```qml
property real latitude: 39.9042      // 纬度
property real longitude: 116.4074    // 经度
property string locationName: "北京"
property bool useCelsius: true       // 摄氏度
```

## Waybar 集成

在 Waybar 配置中添加：

```jsonc
{
    "modules-right": ["custom/wifi", "custom/bluetooth", "custom/volume", "clock"],

    "custom/wifi": {
        "format": "\uf1eb",
        "tooltip-format": "网络",
        "on-click": "qs-popup wifi"
    },

    "custom/bluetooth": {
        "format": "\uf293",
        "tooltip-format": "蓝牙",
        "on-click": "qs-popup bluetooth"
    },

    "custom/volume": {
        "format": "\uf028",
        "tooltip-format": "音量",
        "on-click": "qs-popup volume"
    },

    "clock": {
        "format": "{:%H:%M}",
        "on-click": "qs-popup calendar"
    }
}
```

### Waybar 脚本

| 脚本 | 功能 | 用途 |
|------|------|------|
| `clock_lunar.sh` | 农历时钟 | 支持 3 种格式切换 |
| `media_status.sh` | 媒体状态 | 显示当前播放信息 |
| `media_visualizer.sh` | 音频可视化 | cava 集成 |
| `weather_fetch.py` | 天气数据 | Open-Meteo API + 缓存 |

## Niri 快捷键

在 `~/.config/niri/config.kdl` 中添加：

```kdl
binds {
    // 应用启动器
    Alt+Space { spawn "qs-popup" "launcher"; }

    // 电源菜单
    XF86PowerOff { spawn "qs-popup" "power-menu"; }

    // 窗口切换
    Mod+Tab { spawn "qs-popup" "window-switcher"; }

    // 剪贴板
    Alt+V { spawn "qs-popup" "clipboard"; }

    // 关闭确认
    Mod+MouseMiddle { spawn "qs-popup" "close-confirm"; }

    // 壁纸切换
    Mod+Shift+W { spawn "qs-popup" "wallpaper"; }
}
```

## 快捷键

### 通用

| 快捷键 | 功能 |
|--------|------|
| `Escape` | 关闭弹窗 |
| `Enter` | 确认/执行 |

### 启动器 (launcher)

| 快捷键 | 功能 |
|--------|------|
| `方向键` | 导航 |
| `Tab` | 下一分类 |
| `Shift+Tab` | 上一分类 |
| `F11` | 全屏切换 |
| `Enter` | 启动应用 |

### 窗口切换 (window-switcher)

| 快捷键 | 功能 |
|--------|------|
| `方向键` / `Tab` | 导航 |
| `Enter` | 切换到窗口 |
| 输入文字 | 模糊搜索 |

### 剪贴板 (clipboard)

| 快捷键 | 功能 |
|--------|------|
| `方向键` | 导航 |
| `Enter` | 粘贴选中项 |
| `Delete` | 删除选中项 |

### 日历 (calendar)

| 快捷键 | 功能 |
|--------|------|
| `滚轮` | 切换月份 |
| 点击年月 | 年份选择 |

### 媒体 (media)

| 快捷键 | 功能 |
|--------|------|
| `Space` | 播放/暂停 |
| `左/右` | 上一曲/下一曲 |
| 滚轮 | 调节音量 |

## 故障排除

### 组件无法启动

```bash
# 检查 quickshell 是否安装
quickshell --version

# 手动运行查看错误
POPUP_TYPE=launcher quickshell -c ~/.config/quickshell
```

### 图标显示为方块

确保安装了 Nerd Fonts：

```bash
# Arch Linux
paru -S ttf-nerd-fonts-symbols-mono
```

### 蓝牙/WiFi 无响应

```bash
# 检查服务状态
systemctl status bluetooth
systemctl status NetworkManager

# 启动服务
sudo systemctl enable --now bluetooth
sudo systemctl enable --now NetworkManager
```

### 通知守护进程问题

```bash
# 检查 D-Bus 连接
cd ~/.config/quickshell/notifications
uv run python main.py

# 查看日志
journalctl --user -f
```

### 主题修改不生效

主题文件通过 `Commons/Theme.js` 共享，修改后需要重启组件：

```bash
# 关闭所有 quickshell 实例
pkill quickshell

# 重新启动组件
qs-popup launcher
```

### qs-popup 命令找不到

确保 `~/.local/bin` 在 PATH 中：

```bash
echo $PATH | grep -q ".local/bin" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## 技术栈

**前端**:
- QML (Qt Quick) - UI 框架
- JavaScript - 逻辑脚本
- Quickshell - Wayland Shell 框架

**后端**:
- Python 3.13+ - 脚本和守护进程
- Bash - 系统集成脚本
- D-Bus - 系统通知
- MPRIS - 媒体控制

**依赖管理**:
- uv - Python 包管理器
- pyproject.toml - 项目配置

## 许可证

MIT License
