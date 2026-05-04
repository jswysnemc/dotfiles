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
    cliphist wl-clipboard xclip clipnotify file xdg-utils xdg-user-dirs awww playerctl cava \
    grim slurp wayfreeze hyprpicker tesseract imagemagick

# 剪贴板视频预览可选依赖
paru -S ffmpeg

# 截图编辑、长截图和贴图 (AUR)
paru -S markpix-bin mark-shot wayscrollshot-bin qt-img-viewer
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
此脚本在仓库的local-bin中可以找到

```bash
mkdir -p ~/.local/bin
```

### 5. 确保 PATH 包含 ~/.local/bin

在 `~/.zshrc` 或 `~/.bashrc` 中添加：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 6. 启动剪贴板历史监听

剪贴板面板只负责读取和重新激活 `cliphist` 历史，不负责常驻监听剪贴板。必须在窗口管理器或用户服务中启动 `wl-paste --watch cliphist store`。

当前 Niri 配置使用两条监听命令，分别保存文本和图片：

```kdl
spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
```

如果不区分 MIME 类型，也可以使用通用监听：

```bash
wl-paste --watch cliphist store
```

### 7. 启动通知守护进程 (可选)

```bash
cd ~/.config/quickshell
uv run python notifications/main.py &
```

或在 Niri 配置中自动启动（已配置在 `autostart.kdl`）。

### 8. 验证安装

```bash
# 测试 qs-popup
qs-popup --help

# 测试启动器
qs-popup launcher

# 测试剪贴板历史
cliphist list | head
qs-popup clipboard
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
| 截图工具箱 | `qs-popup screenshot-toolbox` | `screenshot`, `shot`, `ss` | 截图、标注、长截图、OCR、取色、测量和贴图 |
| 启动器 | `qs-popup launcher` | `launch`, `app` | 应用启动器 |
| 剪贴板 | `qs-popup clipboard` | `clip`, `cb` | 剪贴板历史 (cliphist) |
| 电源菜单 | `qs-popup power-menu` | `power`, `pm` | 关机/重启/注销 |
| 壁纸选择 | `qs-popup wallpaper-selector` | `wallpaper`, `wp` | 壁纸切换 (awww) |
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
├── 功能组件目录
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
│   ├── screenshot-toolbox/
│   │   ├── shell.qml
│   │   ├── screenshot-toolbox.sh
│   │   └── Theme.js
│   ├── color-viewer/            # 取色结果详情页
│   │   ├── shell.qml
│   │   └── Theme.js
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
| 剪贴板 | `cliphist`, `wl-clipboard`, `xclip` (X11 同步), `clipnotify` (X11 事件监听), `file`, `xdg-utils`, `xdg-user-dirs`, `ffmpeg` 或 `ffmpegthumbnailer` (视频预览) |
| 壁纸 | `awww` 或 `swaybg` |
| 通知 | `python>=3.11`, `uv`, `dbus-python` |
| 可视化 | `cava` |
| 截图工具箱 | `grim`, `slurp`, `wl-clipboard`, `wayfreeze`, `wayscrollshot-bin`, `hyprpicker`, `tesseract`, `imagemagick`, `markpix`, `mark-shot`, `qt-img-viewer` |

```bash
# 安装所有可选依赖 (Arch Linux)
paru -S networkmanager bluez pipewire brightnessctl curl jq \
        cliphist wl-clipboard xclip clipnotify file xdg-utils xdg-user-dirs awww playerctl cava \
        grim slurp wayfreeze hyprpicker tesseract imagemagick

# 剪贴板视频预览
paru -S ffmpeg

# 截图工具箱高级功能 (AUR)
paru -S markpix-bin mark-shot wayscrollshot-bin qt-img-viewer
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
screenshot-toolbox=top-left,30,260
launcher=center            # 屏幕居中
```

### 主题配置

编辑 `~/.config/quickshell/Commons/Theme.js`：
或者通过matugen配置

### 剪贴板配置

剪贴板组件入口是 `~/.config/quickshell/clipboard/shell.qml`，启动命令是：

```bash
qs-popup clipboard
qs-popup clip
qs-popup cb
```

它不是剪贴板监听守护进程。历史来源是 `cliphist list`，选择、预览、删除和清空记录时再调用 `cliphist decode`、`cliphist delete`、`cliphist wipe`。

#### 剪贴板依赖

| 依赖 | 必要性 | 用途 |
|------|--------|------|
| `cliphist` | 必需 | 保存历史、列出历史、解码历史、删除和清空历史 |
| `wl-clipboard` | 必需 | 提供 `wl-paste` 和 `wl-copy`；`wl-paste` 负责监听，`wl-copy` 负责重新写入 Wayland 剪贴板 |
| `bash`, `awk`, `grep`, `head`, `sed`, `coreutils` | 必需 | 解析 `cliphist list` 输出、限制读取数量、生成临时文件、计算哈希、清理缓存 |
| `file` | 建议安装 | 判断文件和图片 MIME 类型；缺少时文件分类、图片重新激活和预览准确性会下降 |
| `xclip` | 可选 | 选择历史后同步写入 X11 剪贴板选择区，给 XWayland/X11 应用使用 |
| `xdg-utils` | 可选 | 预览视频时通过 `xdg-open` 打开原文件 |
| `xdg-user-dirs` | 可选 | 保存图片时定位图片目录；缺少时回退到 `~/Pictures` |
| `ffmpeg` | 可选 | 生成视频缩略图，并通过 `ffprobe` 读取视频尺寸、时长、格式等信息 |
| `ffmpegthumbnailer` | 可选 | 没有 `ffmpeg` 时作为视频缩略图生成后备方案 |
| `clipnotify` | 可选 | 当前 `clipse-sync` 二进制用于监听 X11 剪贴板事件 |

#### 历史监听

在 Niri 中建议保持当前两条自启动配置：

```kdl
spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
```

这两条分别保存文本和图片 MIME，图片历史才能被组件识别为图片并显示预览。如果只需要基础文本历史，可以改成：

```bash
wl-paste --watch cliphist store
```

X11 和 Wayland 剪贴板同步由 Niri 自启动中的 `~/.local/bin/clipse-sync` 负责。这个同步器独立于 QuickShell clipboard 面板；如果不使用 X11/XWayland 应用，可以不启动它。

#### 内容类型

| 类型 | 行为 |
|------|------|
| 文本 | 显示摘要，右键可查看全文，选择后用 `wl-copy` 写回剪贴板 |
| HTML | 识别 HTML 内容；选择时按 `text/html` 或纯文本重新写入 |
| 代码 | 根据文本特征归类，支持通过 `#code` 过滤 |
| URL | 根据链接特征归类，支持通过 `#url` 或 `#链接` 过滤 |
| 颜色 | 识别 HEX、RGB、RGBA、HSL、HSV 和 Qt 颜色格式，并显示色块 |
| 图片 | 解码到 `${XDG_RUNTIME_DIR}/qs-clipboard` 后显示预览，选择后按原 MIME 写回 |
| 文件 | 解析 `text/uri-list`、`copy`、`cut` 和本地路径，选择后写回 `text/uri-list` |
| 视频文件 | 用 `ffmpeg` 或 `ffmpegthumbnailer` 生成缩略图；右键预览时显示元数据和打开按钮 |

#### 搜索和过滤

搜索框支持普通关键字、模糊匹配和标签过滤。标签可以直接输入，也可以点击过滤按钮显示标签条。

常用标签：

```text
#text #code #url #image #file #video #html #color
```

中文别名也可使用，例如 `#文本`、`#代码`、`#链接`、`#图片`、`#文件`、`#视频`、`#颜色`。

#### 选择后的写入规则

选择记录时组件会先把当前内容哈希写入 `${XDG_RUNTIME_DIR}/clipboard-sync/last_hash`，再写入剪贴板。这样可以减少剪贴板同步器把同一条记录来回同步的概率。

| 记录类型 | Wayland 写入 | X11 写入 |
|----------|--------------|----------|
| 普通文本 | `wl-copy`，HTML 使用 `--type text/html` | `xclip -selection clipboard -t UTF8_STRING` |
| 图片 | `wl-copy --type image/*` | `xclip -selection clipboard -t image/*` |
| 文件列表 | `wl-copy --type text/uri-list` | `xclip -selection clipboard -t text/uri-list` |
| 单个非 GIF 图片文件 | 默认按图片 MIME 写入 | 同步写入图片 MIME |

`QS_IMAGE_FILE_MODE` 控制单个图片文件的写入方式：

| 值 | 行为 |
|----|------|
| `auto` | 默认值；普通图片文件按图片内容写入，QQ 缩略图路径按 URI 写入 |
| `image` | 强制按图片内容写入 |
| `uri` | 强制按 `text/uri-list` 写入 |

#### 性能参数

| 环境变量 | 默认值 | 作用 |
|----------|--------|------|
| `QS_CLIPBOARD_LIST_LIMIT` | `750` | `cliphist list` 最多读取的历史条数 |
| `QS_CLIPBOARD_PARSE_CHUNK` | `60` | 首屏后每批解析的历史条数 |
| `QS_CLIPBOARD_DECODE_CHUNK` | `24` | 后台为搜索索引批量解码的条数 |
| `QS_CLIPBOARD_SEARCH_TEXT_LIMIT` | `20000` | 每条历史最多读取多少字符用于搜索 |
| `QS_IMAGE_FILE_MODE` | `auto` | 单个图片文件选择后按图片内容还是 URI 写入 |

临时缓存目录是 `${XDG_RUNTIME_DIR}/qs-clipboard`。点击顶部清空按钮会执行 `cliphist wipe`，并删除该缓存目录。

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

    "custom/screenshot": {
        "format": "",
        "tooltip-format": "截图工具箱",
        "on-click": "qs-popup screenshot-toolbox"
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
| `Up` / `Down` | 在过滤后的历史列表中移动选中项 |
| `Enter` / `Return` | 重新激活选中项，并关闭面板 |
| `Escape` | 关闭面板；预览层打开时先关闭预览 |
| 输入文字 | 搜索历史内容，支持模糊匹配 |
| 输入 `#标签` | 按类型过滤，例如 `#image`、`#代码`、`#文件` |

| 鼠标操作 | 功能 |
|----------|------|
| 左键点击记录 | 重新激活该记录，并关闭面板 |
| 右键点击记录 | 打开预览层 |
| 点击记录右侧删除按钮 | 删除单条历史 |
| 点击顶部垃圾桶按钮 | 清空全部 `cliphist` 历史并删除预览缓存 |
| 点击搜索框右侧过滤按钮 | 显示或隐藏标签过滤条 |

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

### 截图工具箱 (screenshot-toolbox)

| 操作 | 功能 |
|------|------|
| `选框复制` | 选区截图并复制到剪贴板 |
| `窗口截图` | 鼠标选择窗口后调用 Niri 截图 |
| `全屏截图` | 保存全屏截图并复制 |
| `长截图` | 调用 wayscrollshot |
| `像素测量` | 复制选区宽高和面积 |
| `OCR 识别` | 识别选区文字并复制 |
| `颜色选取` | 取色并打开颜色详情页 |
| `截图编辑` | 选区截图后打开 markpix |
| `选取标注` | 调用 mark-shot 进行选区截图标注 |
| `全屏标注` | 调用 mark-shot --fullscreen 进行全屏截图标注 |
| `选区贴图` | 选区截图后用 qt-img-viewer 贴图 |
| `贴最新图` | 打开最近的截图或图片 |

## 故障排除

### 组件无法启动

```bash
# 检查 quickshell 是否安装
quickshell --version

# 手动运行查看错误
POPUP_TYPE=launcher quickshell -c ~/.config/quickshell
```

### 剪贴板为空

先确认 `cliphist` 中确实有历史：

```bash
cliphist list | head
```

如果没有输出，检查 `wl-paste` 监听是否启动：

```bash
pgrep -af "wl-paste.*cliphist store"
```

手动测试监听：

```bash
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
```

### 剪贴板图片或文件类型不准确

确认 `file` 命令存在：

```bash
command -v file
```

图片历史需要用带 MIME 的监听方式保存：

```bash
wl-paste --type image --watch cliphist store
```

### 选择历史后 X11 应用无法粘贴

确认 `xclip` 和剪贴板同步器存在：

```bash
command -v xclip
pgrep -af clipse-sync
```

QuickShell clipboard 会优先写入 Wayland 剪贴板；X11 写入依赖 `xclip`，跨协议同步依赖当前 Niri 自启动中的 `~/.local/bin/clipse-sync`。

### 视频没有缩略图或元数据

安装 `ffmpeg` 后重新打开剪贴板面板：

```bash
paru -S ffmpeg
qs-popup clipboard
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
