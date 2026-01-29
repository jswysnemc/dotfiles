# Matugen 主题生成器配置

Matugen 是一个基于 Material Design 3 的主题生成工具，可以从壁纸颜色生成配色方案，并应用到多个应用程序。

## 目录

- [从零开始安装](#从零开始安装)
- [目录结构](#目录结构)
- [配置说明](#配置说明)
- [使用方法](#使用方法)
- [集成说明](#集成说明)
- [依赖](#依赖)

## 从零开始安装

### 1. 安装 Matugen

```bash
# 从 AUR 安装
paru -S matugen

# 或从 crates.io 安装
cargo install matugen
```

### 2. 应用配置

```bash
cd ~/.dotfiles
stow matugen
```

### 3. 初始化颜色文件 (重要)

**首次安装必须执行此步骤**，否则 Waybar、Quickshell 等组件会因缺少颜色文件而报错。

```bash
# 初始化默认颜色文件
~/.config/matugen/defaults/matugen-init -s

# 检查初始化状态
~/.config/matugen/defaults/matugen-init -c
```

`matugen-init` 脚本选项：
- `-h, --help` - 显示帮助信息
- `-f, --force` - 强制覆盖已存在的文件
- `-c, --check` - 仅检查文件状态
- `-l, --list` - 列出所有默认颜色文件
- `-s, --symlinks` - 同时创建符号链接

### 4. 创建符号链接 (可选)

某些应用需要在配置目录创建符号链接：

```bash
# Waybar 颜色链接
ln -sf ~/.cache/matugen/waybar/colors.css ~/.config/waybar/colors.css
```

### 5. 生成动态主题

使用壁纸生成主题：

```bash
matugen image /path/to/your/wallpaper.jpg
```

## 目录结构

```
~/.config/matugen/
├── config.toml              # 主配置文件
├── defaults/                # 默认颜色文件目录
│   ├── matugen-init         # 初始化脚本
│   ├── waybar-colors.css    # Waybar 默认颜色
│   ├── swaync-colors.css    # SwayNC 默认颜色
│   ├── nwg-drawer-colors.css# nwg-drawer 默认颜色
│   ├── wofi-colors.css      # Wofi 默认颜色
│   ├── eww-colors.scss      # EWW 默认颜色
│   ├── ags-colors.scss      # AGS 默认颜色
│   └── quickshell-colors.js # Quickshell 默认颜色
└── templates/               # 模板目录
    ├── waybar-colors.css    # Waybar 颜色模板
    ├── swaync-colors.css    # SwayNC 颜色模板
    ├── nwg-drawer-colors.css# nwg-drawer 颜色模板
    ├── wofi-colors.css      # Wofi 颜色模板
    ├── eww-colors.scss      # EWW 颜色模板
    ├── ags-colors.scss      # AGS 颜色模板
    └── quickshell-colors.js # Quickshell 颜色模板
```

## 配置说明

### 方案变体 (config.scheme_variant)

支持的变体：
- `content` - 内容风格
- `express` - 表达风格
- `fidelity` - 保真风格
- `fruit_salad` - 水果沙拉风格
- `monochrome` - 单色风格
- `neutral` - 中性风格
- `rainbow` - 彩虹风格
- `spot` - 斑点风格
- `tonal_spot` - 色调斑点风格（默认）

### 模板配置

每个模板包含：
- `input_path` - 模板文件路径
- `output_path` - 输出文件路径
- `hook` - 生成后执行的命令

#### Waybar 模板
```toml
[templates.waybar]
input_path = "~/.config/matugen/templates/waybar-colors.css"
output_path = "~/.cache/matugen/waybar/colors.css"

# Hook: 生成后发送信号给 Waybar 热重载
[templates.waybar.hook]
command = "pkill"
args = ["-SIGUSR2", "waybar"]
```

#### SwayNC 模板
```toml
[templates.swaync]
input_path = "~/.config/matugen/templates/swaync-colors.css"
output_path = "~/.cache/matugen/swaync/colors.css"

# Hook: 重载 SwayNC
[templates.swaync.hook]
command = "swaync-client"
args = ["-rs"]
```

#### EWW 模板
```toml
[templates.eww]
input_path = "~/.config/matugen/templates/eww-colors.scss"
output_path = "~/.cache/matugen/eww/colors.scss"

# Hook: 重新加载 EWW
[templates.eww.hook]
command = "eww"
args = ["reload"]
```

#### AGS 模板
```toml
[templates.ags]
input_path = "~/.config/matugen/templates/ags-colors.scss"
output_path = "~/.cache/matugen/ags/colors.scss"

# Hook: 重启 AGS
[templates.ags.hook]
command = "ags"
args = ["quit"]
```

#### Quickshell 模板
```toml
[templates.quickshell]
input_path = "~/.config/matugen/templates/quickshell-colors.js"
output_path = "~/.cache/matugen/quickshell/colors.js"
```

#### nwg-drawer 模板
```toml
[templates.nwg-drawer]
input_path = "~/.config/matugen/templates/nwg-drawer-colors.css"
output_path = "~/.cache/matugen/nwg-drawer/colors.css"
```

#### Wofi 模板
```toml
[templates.wofi-colors]
input_path = "~/.config/matugen/templates/wofi-colors.css"
output_path = "~/.cache/matugen/wofi/colors.css"
```

## 使用方法

### 从壁纸生成主题

```bash
matugen image /path/to/wallpaper.jpg
```

### 从指定颜色生成主题

```bash
matugen color hex "#89b4fa"
```

### 指定方案变体

```bash
matugen image /path/to/wallpaper.jpg --scheme-variant tonal_spot
```

### 查看初始化状态

```bash
~/.config/matugen/defaults/matugen-init -c
```

### 强制重置为默认主题

```bash
~/.config/matugen/defaults/matugen-init -f -s
```

## 集成说明

### Waybar

生成后自动发送 `SIGUSR2` 信号热重载样式。

需要创建符号链接：
```bash
ln -sf ~/.cache/matugen/waybar/colors.css ~/.config/waybar/colors.css
```

### SwayNC

生成后自动调用 `swaync-client -rs` 重载样式。

### EWW

生成后自动调用 `eww reload` 重载。

### AGS

生成后自动调用 `ags quit` 重启。

### Quickshell

生成的颜色文件位于 `~/.cache/matugen/quickshell/colors.js`。

### 与壁纸切换集成

在 Niri 配置的壁纸选择器中已集成 matugen，切换壁纸时会自动生成对应主题。

## 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `matugen` | 主题生成器 |

### 应用集成 (可选)

| 应用 | 用途 |
|------|------|
| `waybar` | 状态栏 |
| `swaync` | 通知中心 |
| `nwg-drawer` | 应用启动器 |
| `wofi` | 应用启动器 |
| `eww` | ElKowars Widgets |
| `ags` | Another GTK Shell |
| `quickshell` | QML 桌面组件 |

## 输出目录映射

| 模板 | 输出路径 |
|------|----------|
| `waybar-colors.css` | `~/.cache/matugen/waybar/colors.css` |
| `swaync-colors.css` | `~/.cache/matugen/swaync/colors.css` |
| `nwg-drawer-colors.css` | `~/.cache/matugen/nwg-drawer/colors.css` |
| `wofi-colors.css` | `~/.cache/matugen/wofi/colors.css` |
| `eww-colors.scss` | `~/.cache/matugen/eww/colors.scss` |
| `ags-colors.scss` | `~/.cache/matugen/ags/colors.scss` |
| `quickshell-colors.js` | `~/.cache/matugen/quickshell/colors.js` |

## 故障排除

### 颜色文件缺失导致应用报错

运行初始化脚本：

```bash
~/.config/matugen/defaults/matugen-init -s
```

### Waybar 样式不更新

手动发送重载信号：

```bash
pkill -SIGUSR2 waybar
```

### 检查颜色文件状态

```bash
~/.config/matugen/defaults/matugen-init -c
```

### 符号链接错误

重新创建符号链接：

```bash
rm ~/.config/waybar/colors.css
ln -sf ~/.cache/matugen/waybar/colors.css ~/.config/waybar/colors.css
```

## 许可

MIT License
