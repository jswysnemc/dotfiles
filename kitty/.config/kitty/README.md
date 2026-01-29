# Kitty 终端模拟器配置

Kitty 是一个快速、功能丰富的 GPU 加速终端模拟器。此配置提供了现代化的终端体验，包括主题、滚动回退查看、快捷键等。

## 从零开始安装

### 1. 安装依赖

```bash
# Kitty
paru -S kitty

# 字体
paru -S ttf-jetbrains-mono-nerd

# Neovim 滚动回退 (可选)
paru -S neovim python-pynvim
```

### 2. 应用配置

```bash
cd ~/.dotfiles
stow kitty
```

### 3. 设置默认主题

```bash
# 链接到默认主题
ln -sf ~/.config/kitty/kitty-themes/00-Default.conf ~/.config/kitty/current-theme.conf
```

### 4. 安装 Neovim 插件 (可选)

如果使用 Neovim 滚动回退功能：

```bash
# 在 Neovim 中安装 kitty-scrollback.nvim
:Lazy install
```

### 5. 验证安装

```bash
# 启动 Kitty
kitty

# 检查版本
kitty --version
```

## 目录结构

```
~/.config/kitty/
├── kitty.conf              # 主配置文件
├── current-theme.conf      # 当前主题（符号链接）
├── kitty_scrollback_nvim.py  # Neovim 滚动回退查看器
├── zoom_toggle.py         # 缩放切换脚本
└── kitty-themes/          # 主题集合
    ├── 00-Default.conf
    ├── 01-Wallust.conf
    └── ... (更多主题)
```

## 配置特性

### 远程控制
- `socket-only` 模式，仅允许通过 socket 进行远程控制
- 监听 Unix socket 路径：`/tmp/kitty`

### Shell 集成
- 启用 shell 集成功能
- 支持显示命令状态

### Neovim 滚动回退
- 集成 [kitty-scrollback.nvim](https://github.com/mikesmithgh/kitty-scrollback.nvim)
- `kitty_mod+h` - 打开 nvim scrollback 查看器
- `kitty_mod+g` - 查看最后一个命令的输出
- `Ctrl+Shift+右键` - 选择命令输出并用 nvim 查看

### 鼠标操作
- 中键点击 - 复制选区到系统剪贴板
- 右键点击 - 从系统剪贴板粘贴

### 字体配置
- 主字体：`JetBrainsMono Nerd Font`
- 字体大小：14
- 禁用连字（编程时字符更清晰）

### 外观
- 背景透明度：70%
- 动态背景透明度：70%
- 光标拖尾效果：启用
- 滚动回看缓冲区：200,000 行
- 鼠标滚轮最小滚动行数：1

### 音频
- 禁用终端铃声

### 窗口
- 窗口内边距：2px
- 关闭窗口时不显示确认对话框

## Arch Linux 依赖

| 包名 | 用途 |
|------|------|
| `kitty` | 终端模拟器 |
| `neovim` | 滚动回退查看器 |
| `kitty-scrollback.nvim` | Neovim 滚动回退插件 |
| `python-pynvim` | Neovim Python 客户端 |
| `jetbrains-mono-nerd-font` | Nerd Font 等宽字体 |
| `maple-mono-nf` | Maple Mono Nerd Font（可选） |

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `kitty_mod+h` | 打开 nvim scrollback 查看器 |
| `kitty_mod+g` | 查看最后一个命令的输出 |
| `Ctrl+Shift+右键` | 选择命令输出并用 nvim 查看 |
| `中键` | 复制选区到系统剪贴板 |
| `右键` | 从系统剪贴板粘贴 |

## 主题

配置支持多种主题，通过符号链接 `current-theme.conf` 切换：

```bash
# 切换主题
ln -sf ~/.config/kitty/kitty-themes/01-Wallust.conf ~/.config/kitty/current-theme.conf
```

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow kitty
   ```

2. 安装 Neovim 插件：
   ```bash
   # 在 Neovim 中执行
   :Lazy install
   ```

3. 安装字体：
   ```bash
   sudo pacman -S jetbrains-mono-nerd-font
   ```

## 许可

MIT License
