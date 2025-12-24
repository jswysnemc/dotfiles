# Zsh Shell 配置

Zsh (Z Shell) 是一个功能强大的交互式 shell，提供了丰富的配置选项和插件支持。

## 目录结构

```
~/.config/zsh/
├── .zshrc              # 主配置文件
├── .zshenv             # 环境变量配置
├── conf.d/              # 配置模块目录
│   ├── 00-functions.zsh   # 自定义函数
│   └── 01-environment.zsh # 环境变量
├── preload.zsh         # 预加载配置
└── lastload.zsh        # 最后加载配置
```

## 配置特性

### 模块化配置
配置被拆分为多个模块，便于维护：
- `conf.d/00-functions.zsh` - 自定义函数
- `conf.d/01-environment.zsh` - 环境变量

### 自定义函数

#### export_from_file
从文件导出环境变量：
```bash
export_from_file VAR_NAME /path/to/file "default_value"
```

#### cv
清空文件并用编辑器打开：
```bash
cv <filename>
```

### 环境变量

#### PATH 配置
```bash
export PATH=$HOME/.custom/bin:$PATH
export PATH=$PATH:$HOME/.local/share/cargo/bin
export PATH=$PATH:$HOME/.local/bin
```

#### pnpm 配置
```bash
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
```

### Zsh 启动时间测量

配置包含 Zsh 启动时间测量功能，与 Starship 集成显示启动时间。

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `zsh` | Shell |
| `zsh-completions` | 命令补全 |
| `zsh-autosuggestions` | 自动建议 |
| `zsh-syntax-highlighting` | 语法高亮 |

### 工具依赖

| 包名 | 用途 |
|------|------|
| `starship` | 提示符 |
| `fzf` | 模糊查找 |
| `fd` | 文件查找 |
| `ripgrep` | 快速搜索 |
| `bat` | 文件查看 |
| `exa` 或 `eza` | 文件列表 |
| `zoxide` | 智能目录跳转 |
| `thefuck` | 命令纠错 |

### 可选依赖

| 包名 | 用途 |
|------|------|
| `git` | 版本控制 |
| `curl` | HTTP 客户端 |
| `wget` | 下载工具 |

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow zsh
   ```

2. 安装 Zsh：
   ```bash
   sudo pacman -S zsh
   ```

3. 安装插件和工具：
   ```bash
   # Zsh 插件
   sudo pacman -S zsh-completions zsh-autosuggestions zsh-syntax-highlighting

   # 工具
   sudo pacman -S starship fzf fd ripgrep bat eza zoxide thefuck
   ```

4. 设置 Zsh 为默认 shell：
   ```bash
   chsh -s /bin/zsh
   ```

## 配置文件

| 文件 | 说明 |
|------|------|
| [`.zshrc`](.zshrc:1) | 主配置文件 |
| [`.zshenv`](.zshenv:1) | 环境变量配置 |
| [`conf.d/00-functions.zsh`](conf.d/00-functions.zsh:1) | 自定义函数 |
| [`conf.d/01-environment.zsh`](conf.d/01-environment.zsh:1) | 环境变量 |

## 自定义函数

### cv
清空文件并用编辑器打开：
```bash
cv <filename>
```

### export_from_file
从文件导出环境变量：
```bash
export_from_file VAR_NAME /path/to/file "default_value"
```

## 许可

MIT License
