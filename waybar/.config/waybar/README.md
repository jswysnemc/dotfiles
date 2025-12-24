# Waybar 配置

为 [Niri](https://github.com/YaLTeR/niri) Wayland 合成器定制的 Waybar 配置，采用胶囊风格设计。

## 目录结构

```
~/.config/waybar/
├── config.jsonc      # 主配置文件
├── style.css         # 样式文件
├── colors.css        # 颜色定义 (matugen 生成，符号链接)
├── scripts/          # 脚本目录
│   ├── screenshot.sh       # 截图
│   ├── power-screenshot.sh # 高级截图
│   ├── scroll-capture.sh   # 长截图
│   ├── wf-recorder.sh      # 屏幕录制
│   ├── weather.sh          # 天气详情
│   ├── wifi.sh             # WiFi 管理
│   ├── calendar.sh         # 日历
│   └── mihomo-toggle.sh    # Mihomo 代理切换
└── icons/            # 图标目录
```

## 模块布局

```
┌─────────────────────────────────────────────────────────────────────┐
│ 左侧                    │ 中间     │ 右侧                            │
├─────────────────────────────────────────────────────────────────────┤
│  天气 | 工作区 | 媒体   │ 窗口标题 │ 通知 硬件 网络 蓝牙 音量 电池 时钟 │
│  ▸快捷启动 ▸AI工具 任务栏│          │ 亮度 工具 Mihomo 托盘 电源       │
└─────────────────────────────────────────────────────────────────────┘
```

## 模块说明

### 左侧模块

| 模块 | 说明 | 交互 |
|------|------|------|
| `custom/arch` | Arch Logo 启动器 | 左键: nwg-drawer, 右键: 重载 waybar |
| `custom/weather` | 天气显示 | 左键: 天气详情 |
| `niri/workspaces` | 工作区切换 | 点击切换工作区 |
| `custom/media` | 媒体播放状态 | 左键: 播放/暂停, 右键: 控制面板, 滚轮: 切歌 |
| `custom/visualizer` | 音频可视化 (cava) | 左键: 播放/暂停 |
| `group/quick-start` | 快捷启动 | Dolphin, Firefox, Kitty |
| `group/ai-drawer` | AI 工具抽屉 | GPT, Gemini, DeepSeek 等 |
| `group/shot-recoder` | 截图录屏 | 截图, 长截图, 录屏 |
| `wlr/taskbar` | 任务栏 | 左键: 激活, 中键: 关闭 |

### 中间模块

| 模块 | 说明 | 交互 |
|------|------|------|
| `niri/window` | 当前窗口标题 | 左键: 浮动切换, 中键: 关闭, 右键: 切换列宽 |

### 右侧模块

| 模块 | 说明 | 交互 |
|------|------|------|
| `custom/notification` | 通知中心 | 左键: 打开面板, 右键: 勿扰模式 |
| `group/hardware` | CPU/温度/内存 | 左键: btop |
| `network` | 网络状态 & 速度 | 左键: WiFi 管理 |
| `bluetooth` | 蓝牙 | 左键: blueman |
| `group/audio` | 音量控制 | 左键: 静音, 右键: pavucontrol, 滚轮: 调节 |
| `group/g-backlight` | 屏幕亮度 | 抽屉式滑块 |
| `group/tools` | 工具组 | 咖啡模式 + 性能模式 |
| `battery` | 电池状态 | 自动图标变化 |
| `clock` | 时钟 | 左键: 切换日期, 右键: 日历 |
| `custom/mihomo` | Mihomo 代理 | 左键: 切换模式, 右键: 控制面板 |
| `tray` | 系统托盘 | - |
| `group/power` | 电源菜单 | 关机, 重启, 睡眠, 锁屏, 注销 |

## Quickshell 集成

部分模块使用 Quickshell 提供弹窗界面：

```bash
# 媒体控制弹窗
POPUP_TYPE=media quickshell -c ~/.config/quickshell

# 通知中心弹窗
POPUP_TYPE=notification quickshell -c ~/.config/quickshell
```

脚本位于 `~/.config/quickshell/scripts/`：
- `media_status.sh` - 媒体状态输出
- `media_visualizer.sh` - 音频可视化 (cava)
- `notification_daemon.py` - 通知守护进程
- `weather_fetch.py` - 天气数据获取

## Matugen 主题集成

颜色由 [matugen](https://github.com/InioX/matugen) 动态生成：

- 模板: `~/.config/matugen/templates/waybar-colors.css`
- 输出: `~/.cache/matugen/waybar/colors.css`
- 链接: `~/.config/waybar/colors.css`

生成后自动发送 `SIGUSR2` 信号热重载样式。

```bash
# 生成主题色
matugen image /path/to/wallpaper.jpg
```

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `waybar` | 状态栏 |
| `niri` | Wayland 合成器 |

### 媒体和音频

| 包名 | 用途 |
|------|------|
| `playerctl` | 媒体控制 |
| `wireplumber` | PipeWire 音频服务（提供 wpctl） |
| `cava` | 音频可视化 |

### 截图和录屏

| 包名 | 用途 |
|------|------|
| `grim` | 截图工具 |
| `slurp` | 区域选择工具 |
| `wf-recorder` | 屏幕录制 |
| `wayfreeze` | 截图冻结工具 |

### 应用启动器

| 包名 | 用途 |
|------|------|
| `nwg-drawer` | 应用启动器 |
| `rofi` | 应用启动器（备用） |
| `fuzzel` | 模糊菜单（备用） |
| `wofi` | 应用启动器（备用） |

### 蓝牙和网络

| 包名 | 用途 |
|------|------|
| `blueman` | 蓝牙管理 |
| `networkmanager` | 网络管理 |
| `rfkill` | 蓝牙管理 |

### 系统工具

| 包名 | 用途 |
|------|------|
| `pavucontrol` | 音频控制面板 |
| `btop` | 系统监控 |
| `brightnessctl` | 亮度控制 |
| `power-profiles-daemon` | 电源配置管理 |

### Quickshell 集成

| 包名 | 用途 |
|------|------|
| `quickshell` | QML 桌面组件框架 |
| `qt6-quickcontrols` | Qt Quick 控件 |

### 其他工具

| 包名 | 用途 |
|------|------|
| `jq` | JSON 处理 |
| `curl` | HTTP 客户端 |
| `python` | Python 脚本 |
| `python-pip` | Python 包管理器 |
| `systemd` | 系统服务管理 |
| `notify-send` | 通知发送 |

### 脚本依赖

| 脚本 | 依赖 |
|------|------|
| `cava.sh` | `cava` |
| `longshot.sh` | `wf-recorder`, `slurp`, `wf-stitch`, `fuzzel`/`wofi`/`rofi`, `imv`/`markpix`, `wl-copy` |
| `longshot_rust-v1.sh` | `wf-recorder`, `slurp`, `rust-stitch`, `fuzzel`/`wofi`/`rofi`, `imv`/`markpix`, `wl-copy` |
| `longshot.sh.v1` | `wf-recorder`, `slurp`, `wf-stitch`, `zenity` |
| `longshot.sh.v2` | `wf-recorder`, `slurp`, `wf-stitch`, `yad` |
| `mihomo-toggle.sh` | `curl`, `jq` |
| `power-screenshot.sh` | `wayfreeze`, `slurp`, `markpix` |
| `proxies-control.sh` | `curl`, `jq`, `systemctl` |
| `screenshot.sh` | `grim`, `slurp`, `wl-copy` |
| `scroll-capture.sh` | `wf-recorder`, `slurp`, `rust-stitch`, `fuzzel`, `imv` |
| `toggle-bluetooth.sh` | `rfkill` |
| `wf-recorder.sh` | `wf-recorder`, `slurp`, `fuzzel`/`wofi`/`rofi`/`bemenu`/`fzf`, `notify-send`, `systemd` |
| `weather.sh` | `quickshell`, `python` |
| `wifi.sh` | `quickshell`, `python` |
| `calendar.sh` | `quickshell`, `python` |

### 图像和视频处理

| 包名 | 用途 |
|------|------|
| `wf-stitch` | 长截图拼接工具 |
| `rust-stitch` | 长截图拼接工具 |
| `imv` | 图像查看器 |
| `markpix` | 图像标记工具 |

### 菜单工具

| 包名 | 用途 |
|------|------|
| `fuzzel` | 模糊菜单工具 |
| `wofi` | 模糊菜单工具 |
| `rofi` | 模糊菜单工具 |
| `bemenu` | 模糊菜单工具 |
| `fzf` | 模糊查找工具 |
| `zenity` | 图形对话框工具 |
| `yad` | 图形对话框工具 |

### 通知工具

| 包名 | 用途 |
|------|------|
| `mako` | 通知守护进程（可选，Quickshell 有内置通知） |

### Wayland 工具

| 包名 | 用途 |
|------|------|
| `wl-clipboard` | Wayland 剪贴板工具（wl-paste, wl-copy） |
| `wl-copy` | Wayland 剪贴板工具 |

### 代理工具

| 包名 | 用途 |
|------|------|
| `mihomo` | Mihomo 代理内核 |
| `sing-box` | Sing-box 代理内核 |
| `google-chrome-stable` | Chrome 浏览器（代理面板） |

## 样式特点

- 胶囊风格模块设计
- 半透明背景 (60%)
- 悬停动画效果
- Nerd Font 图标
- Catppuccin 风格配色 (可通过 matugen 自定义)

## 快捷键参考

| 操作 | 快捷键 |
|------|--------|
| 截图 | 点击截图按钮 |
| 长截图 | 中键截图按钮 |
| 高级截图 | 右键截图按钮 |
| 开始/停止录屏 | 点击录屏按钮 |
| 重载 Waybar | 右键 Arch Logo |

## 许可

MIT License
