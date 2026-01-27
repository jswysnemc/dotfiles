# Waybar 配置

为 [Niri](https://github.com/YaLTeR/niri) Wayland 合成器定制的 Waybar 配置，采用胶囊风格设计。

## 目录结构

```
~/.config/waybar/
├── config.jsonc          # 主配置文件
├── style.css             # 样式文件
├── colors.css            # 颜色定义 (matugen 生成，符号链接)
├── icons/                # 图标目录
│   ├── network.png
│   └── bluetooth.png
└── scripts/              # 脚本目录
    ├── proxies-control.sh    # 代理控制 (Mihomo/Sing-box)
    ├── wf-recorder.sh        # 屏幕录制
    ├── screenshot.sh         # 截图
    └── power-screenshot.sh   # 高级截图 (Markpix)
```

## 模块布局

```
+-------------------------------------------------------------------------+
| 左侧                      | 中间       | 右侧                            |
+-------------------------------------------------------------------------+
|  天气 | 工作区 | 媒体     | 窗口标题   | 通知 硬件 网络 蓝牙 音量 电池 时钟 |
|  可视化 快捷启动 AI工具   |            | 亮度 工具 代理 托盘 电源         |
|  截图录屏 任务栏          |            |                                 |
+-------------------------------------------------------------------------+
```

## 模块说明

### 左侧模块

| 模块 | 说明 | 交互 |
|------|------|------|
| `custom/arch` | Arch Logo 启动器 | 左键: qs-popup launcher, 右键: 重载 waybar |
| `custom/weather` | 天气显示 | 左键: qs-popup weather |
| `niri/workspaces` | 工作区切换 | 点击切换，滚轮切换 |
| `custom/media` | 媒体播放状态 | 左键: 播放/暂停, 右键: qs-popup media, 滚轮: 切歌 |
| `custom/visualizer` | 音频可视化 (cava) | 左键: 播放/暂停 |
| `group/quick-start` | 快捷启动 | Dolphin, Firefox, Kitty |
| `group/shortcuts` | AI 工具抽屉 | GPT, Gemini, AI Studio, DeepSeek, Claude, Linuxdo |
| `group/shot-recoder` | 截图录屏组 | 左键: 截图, 中键: 长截图, 右键: Markpix |
| `wlr/taskbar` | 任务栏 | 左键: 激活, 中键: 关闭 |

### 中间模块

| 模块 | 说明 | 交互 |
|------|------|------|
| `niri/window` | 当前窗口标题 | 左键: 浮动切换, 中键: 关闭确认, 右键: 切换列宽 |

### 右侧模块

| 模块 | 说明 | 交互 |
|------|------|------|
| `custom/notification` | 通知中心 | 左键: qs-popup notifications, 右键: 勿扰模式 |
| `group/hardware` | CPU/温度/内存 | 左键: btop |
| `network` | 网络状态 & 速度 | 左键: qs-popup wifi |
| `bluetooth` | 蓝牙 | 左键: qs-popup bluetooth, 右键: blueman |
| `group/audio` | 音量控制 (带滑块) | 左键: 静音, 右键: pavucontrol, 滚轮: 调节 |
| `group/g-backlight` | 屏幕亮度 (带滑块) | 抽屉式滑块 |
| `group/tools` | 工具组 | 咖啡模式 + 性能模式 |
| `battery` | 电池状态 | 自动图标变化，低电量警告 |
| `custom/clock` | 时钟 (农历) | 左键: 切换格式, 右键: qs-popup calendar |
| `group/proxies` | 代理控制组 | Mihomo/Sing-box 双内核切换 |
| `tray` | 系统托盘 | - |
| `group/power` | 电源菜单 | 关机, 重启, 睡眠, 锁屏, 注销 |

## 代理控制

支持 Mihomo 和 Sing-box 双内核切换：

| 功能 | 操作 |
|------|------|
| 切换内核 | 点击内核图标 |
| 切换模式 | 规则 (Rule) -> 全局 (Global) -> 直连 (Direct) |
| 开关代理 | 点击电源图标 |
| 控制面板 | 右键打开 http://127.0.0.1:9090/ui/#/proxies |

模式颜色编码：
- 规则模式: 默认色
- 全局模式: 橙色
- 直连模式: 绿色

## 截图录屏

| 操作 | 功能 | 工具 |
|------|------|------|
| 左键 | 选区截图到剪贴板 | grim + slurp |
| 中键 | 长截图 | wayscrollshot / rust-stitch |
| 右键 | 截图编辑 | wayfreeze + grim + markpix |
| 录屏按钮 | 开始/停止录屏 | wf-recorder |

录屏特性：
- 支持全屏和区域录制
- 可配置编码器 (默认 libx264)
- 支持音频录制
- 自动保存格式选择 (mp4/mkv/webm)
- Waybar 信号集成 (SIGUSR1+8)

## Quickshell 集成

多个模块使用 Quickshell 提供弹窗界面：

```bash
qs-popup launcher       # 应用启动器
qs-popup wallpaper      # 壁纸选择
qs-popup weather        # 天气详情
qs-popup media          # 媒体控制
qs-popup wifi           # WiFi 管理
qs-popup bluetooth      # 蓝牙管理
qs-popup notifications  # 通知中心
qs-popup calendar       # 日历
qs-popup windows        # 窗口切换
qs-popup close-confirm  # 关闭确认
qs-popup power          # 电源菜单
```

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

颜色变量：
- `@text-main` - 主文本色
- `@text-sub` - 次要文本色
- `@highlight` - 强调色
- `@accent-*` - 各种强调色 (orange, red, green, purple, yellow)
- `@base-bg` - 基础背景 (约 60% 透明度)
- `@hover-bg` - 悬停背景

## 样式特点

- **胶囊风格**: 圆角 12px (主模块), 6-8px (子模块)
- **半透明背景**: 约 60% 透明度
- **悬停效果**: 背景色变化 + 阴影
- **动画**: 立方贝塞尔曲线 (0.3s)
- **字体**: JetBrainsMono Nerd Font Propo, 11px

状态指示：
- **电池**: 绿色 (正常) -> 橙色 (30%) -> 红色闪烁 (15%)
- **温度**: 绿色 (正常) -> 红色 (80°C)
- **网络**: 图标变化 + 速度显示 (下载/上传)
- **蓝牙**: 连接数显示

## 依赖

### 核心

- **waybar** - 状态栏
- **niri** - Wayland 合成器

### 媒体控制

- **playerctl** - 媒体控制
- **wpctl** (WirePlumber) - 音频控制
- **cava** - 音频可视化

### 截图录屏

- **grim + slurp** - 截图
- **wf-recorder** - 屏幕录制
- **wayfreeze** - 屏幕冻结
- **markpix** - 截图编辑
- **rust-stitch** - 长截图拼接
- **wayscrollshot** - 滚动截图

### 系统工具

- **nwg-drawer** - 应用启动器 (备选)
- **blueman** - 蓝牙管理
- **pavucontrol** - 音频控制面板
- **btop** - 系统监控
- **nmtui** - 网络管理
- **brightnessctl** - 亮度控制
- **rfkill** - 蓝牙屏蔽

### 集成

- **quickshell** - QML 弹窗组件
- **matugen** - 主题生成
- **python3** - 脚本支持

## 交互参考

### 鼠标操作

| 操作 | 功能 |
|------|------|
| 左键 | 主要功能 (激活、打开、切换) |
| 中键 | 次要功能 (关闭、长截图) |
| 右键 | 高级功能 (菜单、设置、控制面板) |
| 滚轮 | 调节 (音量、亮度、工作区切换) |

### 快捷操作

| 操作 | 快捷键 |
|------|--------|
| 截图 | 点击截图按钮 |
| 长截图 | 中键截图按钮 |
| 高级截图 | 右键截图按钮 |
| 开始/停止录屏 | 点击录屏按钮 |
| 重载 Waybar | 右键 Arch Logo |

## 许可

MIT License
