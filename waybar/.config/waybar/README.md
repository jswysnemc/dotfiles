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

## 依赖

- **waybar** - 状态栏
- **niri** - Wayland 合成器
- **playerctl** - 媒体控制
- **wpctl** (WirePlumber) - 音频控制
- **cava** - 音频可视化
- **wf-recorder** - 屏幕录制
- **grim + slurp** - 截图
- **nwg-drawer** - 应用启动器
- **blueman** - 蓝牙管理
- **pavucontrol** - 音频控制面板
- **quickshell** - QML 弹窗组件

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
