# Dotfiles 配置仓库

![preview](.assets/image-20251222200951834.png)
![image-20251222195029965](.assets/image-20251222195029965.png)
![image-20251222195239887](.assets/image-20251222195239887.png)
![image-20251222195801393](.assets/image-20251222195801393.png)
![image-20251222195830240](.assets/image-20251222195830240.png)
![image-20251222195854008](.assets/image-20251222195854008.png)

这个仓库包含了我的开发环境配置文件，使用 GNU Stow 进行管理。

## 包含的配置

| 配置 | 说明 |
|------|------|
| **nvim** | Neovim 编辑器配置 |
| **starship** | Starship 提示符配置 |
| **tmux** | Tmux 终端复用器配置 |
| **yazi** | Yazi 文件管理器配置 |
| **zsh** | Zsh shell 配置 |
| **kitty** | Kitty 终端模拟器配置 |
| **niri** | Niri Wayland 窗口管理器配置 |
| **waybar** | Waybar 状态栏配置 |
| **matugen** | Matugen 主题生成器配置 |
| **quickshell** | Quickshell QML 桌面组件配置 |
| **my-scripts** | 自定义脚本集合 |
| **font** | 字体配置 |

## Arch Linux 依赖

### 核心工具

| 包名 | 用途 |
|------|------|
| `stow` | GNU Stow dotfiles 管理 |
| `git` | 版本控制 |

### Niri (Wayland 合成器)

| 包名 | 用途 |
|------|------|
| `niri` | Wayland 窗口管理器 |
| `fcitx5` | 中文输入法 |
| `fcitx5-im` | 输入法集成 |
| `fcitx5-chinese-addons` | 中文输入法支持 |
| `mako` | 通知守护进程 |
| `waybar` | 状态栏 |
| `cliphist` | 剪贴板历史 |
| `clipse` | 剪贴板管理器 |
| `swww` | 壁纸管理 |
| `swayidle` | 空闲管理 |
| `hyprpolkitagent` | 权限认证 |
| `brightnessctl` | 亮度控制 |
| `wireplumber` | PipeWire 音频服务 |
| `wl-clipboard` | Wayland 剪贴板工具 |
| `grim` | 截图工具 |
| `slurp` | 区域选择工具 |
| `wayfreeze` | 截图冻结工具 |
| `kitty` | 终端模拟器 |
| `rofi` | 应用启动器 |
| `dolphin` | 文件管理器 |
| `firefox` | 浏览器 |
| `nwg-drawer` | 应用启动器 |
| `blueman` | 蓝牙管理 |
| `pavucontrol` | 音频控制面板 |
| `btop` | 系统监控 |
| `wtype` | 模拟键盘输入 |
| `hyprlock` | 锁屏工具 |
| `networkmanager` | 网络管理 |
| `power-profiles-daemon` | 电源配置管理 |
| `ffmpeg` | 视频处理 |
| `imagemagick` | 图像处理 |
| `xclip` | X11 剪贴板工具 |

### Waybar

| 包名 | 用途 |
|------|------|
| `waybar` | 状态栏 |
| `playerctl` | 媒体控制 |
| `cava` | 音频可视化 |
| `wf-recorder` | 屏幕录制 |
| `jq` | JSON 处理 |
| `wf-stitch` | 长截图拼接工具 |
| `rust-stitch` | 长截图拼接工具 |
| `imv` | 图像查看器 |
| `markpix` | 图像标记工具 |
| `fuzzel` | 模糊菜单工具 |
| `wofi` | 模糊菜单工具 |
| `rofi` | 模糊菜单工具 |
| `bemenu` | 模糊菜单工具 |
| `fzf` | 模糊查找工具 |
| `zenity` | 图形对话框工具 |
| `yad` | 图形对话框工具 |
| `rfkill` | 蓝牙管理 |

### Quickshell

| 包名 | 用途 |
|------|------|
| `quickshell` | QML 桌面组件框架 |
| `qt6-quickcontrols` | Qt Quick 控件 |
| `qt6-declarative` | Qt Quick 声明 |
| `dbus-monitor` | DBus 消息监听 |
| `makoctl` | Mako 通知控制 |
| `lunarcalendar` | 农历转换（pip） |

### Matugen

| 包名 | 用途 |
|------|------|
| `matugen` | 主题色生成器 |

### Neovim

| 包名 | 用途 |
|------|------|
| `neovim` | 编辑器 |
| `nodejs` | Neovim 插件依赖 |
| `npm` | Neovim 插件依赖 |
| `ripgrep` | 快速搜索 |
| `fd` | 文件查找 |
| `bat` | 文件查看 |
| `fzf` | 模糊查找 |
| `git` | 版本控制 |
| `tree-sitter` | 语法高亮 |
| `clang` | C/C++ 编译器 |
| `clang-format` | C/C++ 格式化 |
| `python` | Python 支持 |
| `python-pip` | Python 包管理 |
| `stylua` | Lua 格式化 |
| `ruff` | Python Linter/Formatter |
| `pyright` | Python LSP |
| `lua-language-server` | Lua LSP |
| `codespell` | 拼写检查 |

### Tmux

| 包名 | 用途 |
|------|------|
| `tmux` | 终端复用器 |
| `tmux-plugin-manager` | 插件管理器 |

### Yazi

| 包名 | 用途 |
|------|------|
| `yazi` | 文件管理器 |
| `ffmpegthumbnailer` | 视频缩略图 |
| `poppler` | PDF 预览 |
| `fd` | 文件查找 |
| `ripgrep` | 内容搜索 |
| `fzf` | 模糊查找 |
| `jq` | JSON 处理 |
| `unarchiver` | 压缩包支持 |

### Shell

| 包名 | 用途 |
|------|------|
| `zsh` | Shell |
| `starship` | 提示符 |
| `exa` 或 `eza` | 文件列表 |
| `bat` | 文件查看 |
| `fzf` | 模糊查找 |
| `ripgrep` | 快速搜索 |
| `fd` | 文件查找 |
| `zoxide` | 智能目录跳转 |
| `thefuck` | 命令纠错 |

### 字体

| 包名 | 用途 |
|------|------|
| `noto-fonts-cjk` | 中文字体 |
| `jetbrains-mono-nerd-font` | Nerd Font 等宽字体 |
| `maple-mono-nf` | Maple Mono Nerd Font |

### 其他工具

| 包名 | 用途 |
|------|------|
| `curl` | HTTP 客户端 |
| `wget` | 下载工具 |
| `jq` | JSON 处理 |
| `base64` | Base64 编码 |
| `file` | 文件类型检测 |
| `openssl` | 加密工具 |
| `python3` | Python 脚本 |
| `bash` | Shell 脚本 |
| `sed` | 文本处理 |
| `awk` | 文本处理 |
| `grep` | 文本搜索 |
| `find` | 文件查找 |
| `xargs` | 命令构建 |
| `systemctl` | systemd 控制 |
| `loginctl` | 会话控制 |
| `xdg-open` | 打开文件 |
| `xdg-utils` | XDG 工具集 |
| `qt6ct` | Qt 主题配置 |
| `xdg-desktop-portal-kde` | KDE XDG Portal |
| `xdg-desktop-portal` | XDG Portal |
| `notify-send` | 通知发送 |
| `pot` | 本地 OCR 工具 |
| `nodejs` | Node.js 运行时 |
| `npm` | Node.js 包管理器 |
| `man` | 手册页查看 |
| `less` | 文本查看器 |
| `sha256sum` | 校验和计算 |
| `shasum` | 校验和计算 |

## 安装和使用

### 前置要求

- GNU Stow
- 相应的应用程序（见上方依赖列表）

### 安装步骤

1. 克隆仓库到本地：
    ```bash
    git clone <repository-url> ~/.dotfiles
    cd ~/.dotfiles
    ```

2. 使用 GNU Stow 创建符号链接：
    ```bash
    # 安装所有配置
    stow */
    
    # 或者单独安装特定配置
    stow nvim
    stow starship
    stow tmux
    stow yazi
    stow zsh
    stow kitty
    stow niri
    stow waybar
    stow matugen
    stow quickshell
    stow my-scripts
    stow font
    ```

3. 重新加载 shell 配置：
    ```bash
    source ~/.zshrc
    ```

### 聚合脚本

仓库包含一个聚合脚本 `to_stow.sh`，用于从系统配置文件创建 dotfiles：

```bash
./to_stow.sh mainfest.txt
```

## 环境变量

部分脚本需要设置以下环境变量：

```bash
# Gemini API 配置（用于 gtrans, gchat, gocr, cmdh 等脚本）
export G_API_URL="https://gemini.snemc.top/v1/chat/completions"
export G_API_KEY="your-api-key"
export G_TEXT_MODEL="gemini-1.5-flash-latest"
export G_VISION_MODEL="gemini-1.5-pro-latest"
export G_TRANS_MODEL="gemini-1.5-flash-latest"

# 腾讯云 API 配置（用于 ttrans 脚本）
export T_SECRET_ID="your-secret-id"
export T_SECRET_KEY="your-secret-key"

# WiFi 登录配置（用于 wifi_login 脚本）
export WIFI_USERNAME="your-username"
export WIFI_PASSWORD="your-password"
```

## 许可证

MIT License

