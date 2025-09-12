# Dotfiles 配置仓库

这个仓库包含了我的开发环境配置文件，使用 GNU Stow 进行管理。

## 包含的配置

- **nvim** - Neovim 编辑器配置
- **starship** - Starship 提示符配置
- **tmux** - Tmux 终端复用器配置
- **yazi** - Yazi 文件管理器配置
- **zsh** - Zsh shell 配置

## 安装和使用

### 前置要求

- GNU Stow
- 相应的应用程序（neovim, starship, tmux, yazi, zsh）

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

## 配置详情

### Neovim (nvim)

- 配置文件位置：`~/.config/nvim/`
- 使用 Lua 配置
- 包含 LSP、格式化、代码补全等功能

### Starship

- 配置文件：`~/.config/starship.toml`
- 跨 shell 提示符定制

### Tmux

- 配置文件：`~/.config/tmux/tmux.conf`
- 终端会话管理快捷键和配置

### Yazi

- 配置文件：`~/.config/yazi/`
- 文件管理器主题、键位映射等配置

### Zsh

- 配置文件：`~/.config/zsh/`
- shell 别名、函数、插件配置

## 维护

### 添加新配置

1. 将配置文件放入相应的目录
2. 运行 `stow <directory>` 创建符号链接

### 更新配置

1. 修改配置文件
2. 重新加载相关应用程序或重启终端

## 许可证

