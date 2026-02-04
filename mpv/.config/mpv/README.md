# MPV 配置

这是一个针对动漫观看优化的 [mpv](https://mpv.io/) 播放器配置，集成了 Anime4K 画质增强着色器。

## 目录

- [特性](#特性)
- [安装](#安装)
- [目录结构](#目录结构)
- [快捷键](#快捷键)
- [Anime4K 模式](#anime4k-模式)

## 特性

- **Anime4K 画质增强**：实时动漫画质提升，支持多种模式切换
- **ModernZ OSC**：现代化的播放控制界面
- **双字幕支持**：主字幕 + 次字幕同时显示（mpv 0.40+）
- **硬件解码**：自动硬件加速，兼容 SVP 补帧
- **缩略图预览**：进度条悬停显示缩略图

## 安装

### 1. 应用配置

```bash
cd ~/.dotfiles
stow mpv
```

### 2. 下载 Anime4K 着色器

shaders 文件夹未包含在仓库中，需要手动下载：

```bash
git clone https://github.com/bloc97/Anime4K.git /tmp/Anime4K
cp -r /tmp/Anime4K/glsl_4.0/* ~/.config/mpv/shaders/
rm -rf /tmp/Anime4K
```

### 3. 启用 Anime4K 着色器

下载完成后，编辑 `~/.config/mpv/mpv.conf`，找到以下行并解开注释：

```conf
# glsl-shaders="~~/shaders/Anime4K_Clamp_Highlights.glsl:..."
```

改为：

```conf
glsl-shaders="~~/shaders/Anime4K_Clamp_Highlights.glsl:..."
```

或者使用命令一键启用：

```bash
sed -i 's/^# glsl-shaders=/glsl-shaders=/' ~/.config/mpv/mpv.conf
```

> 如果使用 `install.sh` 安装脚本，选择下载 Anime4K 着色器后会自动启用。

## 目录结构

```
mpv/
└── .config/mpv/
    ├── mpv.conf              # 主配置文件
    ├── input.conf            # 快捷键配置
    ├── fonts/                # 图标字体
    │   ├── fluent-system-icons.ttf
    │   └── material-design-icons.ttf
    ├── scripts/              # Lua 脚本
    │   ├── modernz.lua       # 现代化 OSC
    │   ├── thumbfast.lua     # 缩略图生成
    │   ├── autoload.lua      # 自动加载同目录文件
    │   └── playlistmanager.lua
    ├── script-opts/          # 脚本配置
    │   ├── modernz.conf
    │   ├── autoload.conf
    │   └── playlistmanager.conf
    └── shaders/              # Anime4K 着色器 (需手动下载)
```

## 快捷键

### 基础操作

| 快捷键 | 功能 |
|--------|------|
| `双击左键` | 暂停/播放 |
| `滚轮上/下` | 音量 +/-2 |
| `左/右` | 快退/快进 5 秒 |
| `上/下` | 音量 +/-5 |
| `Shift+左/右` | 快退/快进 60 秒 |
| `Ctrl+左/右` | 跳到上/下一个字幕 |

### 播放控制

| 快捷键 | 功能 |
|--------|------|
| `[` / `]` | 速度 -/+10% |
| `{` / `}` | 速度 0.5x / 2x |
| `Backspace` | 重置速度为 1.0 |
| `f` | 切换全屏 |
| `t` | 切换窗口置顶 |

### 字幕控制

| 快捷键 | 功能 |
|--------|------|
| `j` / `J` | 切换主字幕轨道 |
| `k` / `K` | 切换次字幕轨道 |

### 截图

| 快捷键 | 功能 |
|--------|------|
| `s` | 截图（含字幕） |
| `S` | 截图（纯视频） |

### 其他

| 快捷键 | 功能 |
|--------|------|
| `Tab` | 切换 OSC 显示模式 |

## Anime4K 模式

使用 `Ctrl+数字键` 切换不同的画质增强模式：

| 快捷键 | 模式 | 说明 |
|--------|------|------|
| `Ctrl+1` | Mode A (HQ) | 适合大多数动漫 |
| `Ctrl+2` | Mode B (HQ) | 适合老旧/模糊动漫 |
| `Ctrl+3` | Mode C (HQ) | 适合有噪点的动漫 |
| `Ctrl+4` | Mode A+A (HQ) | 双重处理，画质最佳 |
| `Ctrl+5` | Mode B+B (HQ) | 双重柔化处理 |
| `Ctrl+6` | Mode C+A (HQ) | 降噪 + 增强 |
| `Ctrl+0` | 关闭 | 清除所有着色器 |

> 默认启用 Mode A+A (HQ)，适合高端 GPU。如果卡顿，按 `Ctrl+0` 关闭或切换到更轻量的模式。

## 依赖

- mpv >= 0.40（双字幕支持）
- GPU 支持 OpenGL 4.0+（Anime4K 着色器）
