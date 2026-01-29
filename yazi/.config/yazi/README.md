# Yazi 文件管理器配置

Yazi 是一个用 Rust 编写的现代化终端文件管理器，支持快速导航、预览和插件扩展。

## 从零开始安装

### 1. 安装依赖

```bash
# 核心
paru -S yazi fd ripgrep fzf

# 预览支持
paru -S ffmpegthumbnailer poppler jq imagemagick ffmpeg mpv

# 可选
paru -S exiftool zoxide
```

### 2. 应用配置

```bash
cd ~/.dotfiles
stow yazi
```

### 3. 安装插件

插件已包含在配置中，无需额外安装。

### 4. 验证安装

```bash
# 启动 Yazi
yazi

# 检查版本
yazi --version
```

## 目录结构

```
~/.config/yazi/
├── yazi.toml              # 主配置文件
├── keymap.toml            # 快捷键配置
├── theme.toml             # 主题配置
├── init.lua              # Lua 插件入口
├── package.toml           # 插件包配置
└── plugins/              # 插件目录
    ├── compress.yazi/     # 压缩插件
    ├── git.yazi/         # Git 状态插件
    ├── smart-enter.yazi/  # 智能进入插件
    ├── smart-filter.yazi/  # 智能过滤插件
    ├── starship.yazi/    # Starship 集成
    └── zoom.yazi/        # 缩放插件
```

## 配置特性

### 文件管理器 (mgr)
- 列布局比例：`[1, 4, 3]`
- 排序方式：字母顺序
- 显示隐藏文件：关闭
- 显示符号链接：开启
- 滚动偏移：5 行

### 预览 (preview)
- 最大宽度：600px
- 最大高度：900px
- 图像质量：75%
- 图像滤镜：triangle

### 文件打开器 (opener)
- 编辑器：`$EDITOR` 或 `vi`
- 打开：`xdg-open`（Linux）
- 揭示：`xdg-open` 显示父目录
- 解压：`ya pub extract`
- 播放：`mpv --force-window`

### 预览器 (previewers)
支持以下文件类型预览：
- 文本文件
- 图片（AVIF、HEIC、JXL、SVG、普通图片）
- 视频
- PDF
- 字体
- 压缩包

### 插件

| 插件 | 说明 |
|------|------|
| **compress.yazi** | 压缩文件 |
| **git.yazi** | 显示 Git 状态 |
| **smart-enter.yazi** | 智能进入目录/打开文件 |
| **smart-filter.yazi** | 智能过滤 |
| **starship.yazi** | Starship 提示符集成 |
| **zoom.yazi** | 缩放视图 |

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `yazi` | 文件管理器 |
| `fd` | 文件查找 |
| `ripgrep` | 内容搜索 |
| `fzf` | 模糊查找 |

### 预览依赖

| 包名 | 用途 |
|------|------|
| `ffmpegthumbnailer` | 视频缩略图 |
| `poppler` | PDF 预览 |
| `jq` | JSON 预览 |
| `unarchiver` | 压缩包预览 |
| `imagemagick` | 图片处理（某些格式） |
| `ffmpeg` | 视频预览 |

### 打开器依赖

| 包名 | 用途 |
|------|------|
| `xdg-utils` | xdg-open 命令 |
| `mpv` | 媒体播放 |

### 可选依赖

| 包名 | 用途 |
|------|------|
| `exiftool` | 显示 EXIF 信息 |
| `zoxide` | 智能目录跳转 |
| `starship` | 提示符集成 |

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow yazi
   ```

2. 安装预览依赖：
   ```bash
   sudo pacman -S ffmpegthumbnailer poppler jq unarchiver imagemagick ffmpeg mpv xdg-utils
   ```

3. 安装命令行工具：
   ```bash
   sudo pacman -S fd ripgrep fzf
   ```

## Neovim 集成

在 Neovim 中打开 Yazi：
- `<leader>E` - 在当前文件位置打开
- `<leader>cw` - 在工作目录打开

## 许可

MIT License
