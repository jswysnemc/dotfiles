# Matugen 主题生成器配置

Matugen 是一个基于 Material Design 3 的主题生成工具，可以从壁纸颜色生成配色方案，并应用到多个应用程序。

## 目录结构

```
~/.config/matugen/
├── config.toml              # 主配置文件
└── templates/               # 模板目录
    ├── waybar-colors.css   # Waybar 颜色模板
    ├── swaync-colors.css   # SwayNC 颜色模板
    ├── nwg-drawer-colors.css # nwg-drawer 颜色模板
    ├── wofi-colors.css     # Wofi 颜色模板
    ├── eww-colors.scss     # EWW 颜色模板
    ├── ags-colors.scss     # AGS 颜色模板
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

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `matugen` | 主题生成器 |
| `python` | Python 运行时 |
| `python-pip` | Python 包管理器 |

### 应用集成

| 应用 | 用途 |
|------|------|
| `waybar` | 状态栏 |
| `swaync` | 通知中心 |
| `nwg-drawer` | 应用启动器 |
| `wofi` | 应用启动器 |
| `eww` | ElKowars Widge Widgets |
| `ags` | Another GTK Shell |
| `quickshell` | QML 桌面组件 |

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow matugen
   ```

2. 安装 Matugen：
   ```bash
   # 从 AUR 安装
   yay -S matugen

   # 或从源码安装
   cargo install matugen
   ```

## 使用

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

## 集成

### Waybar
生成后自动发送 `SIGUSR2` 信号热重载样式。

### SwayNC
生成后自动调用 `swaync-client -rs` 重载样式。

### EWW
生成后自动调用 `eww reload` 重载。

### AGS
生成后自动调用 `ags quit` 重启。

### Quickshell
生成的颜色文件需要符号链接到 `~/.config/quickshell/colors.js`。

## 许可

MIT License
