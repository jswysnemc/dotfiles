# Zsh Shell 配置

Zsh (Z Shell) 是一个功能强大的交互式 shell，提供了丰富的配置选项和插件支持。此配置使用 Zi 作为插件管理器，集成了众多实用工具。

## 目录

- [从零开始安装](#从零开始安装)
- [目录结构](#目录结构)
- [配置特性](#配置特性)
- [插件列表](#插件列表)
- [自定义函数](#自定义函数)
- [依赖](#依赖)

## 从零开始安装

### 1. 安装 Zsh 和工具

```bash
# 核心
paru -S zsh

# 提示符
paru -S starship

# 命令行工具
paru -S fzf fd ripgrep bat eza zoxide atuin thefuck
```

### 2. 应用配置

```bash
cd ~/.dotfiles
stow zsh
stow starship
```

### 3. 设置 Zsh 为默认 Shell

```bash
chsh -s /bin/zsh
```

### 4. 创建必要的符号链接

Zsh 默认读取 `~/.zshrc` 和 `~/.zshenv`，需要创建符号链接：

```bash
# 链接到 XDG 配置目录
ln -sf ~/.config/zsh/.zshrc ~/.zshrc
ln -sf ~/.config/zsh/.zshenv ~/.zshenv
```

或者在 `/etc/zsh/zshenv` 中设置 `ZDOTDIR`（需要 root 权限）：

```bash
echo 'export ZDOTDIR="$HOME/.config/zsh"' | sudo tee -a /etc/zsh/zshenv
```

### 5. 安装插件

首次启动 Zsh 时，Zi 插件管理器会自动安装。如果需要手动安装：

```bash
# 删除旧的 Zi 目录（如果存在）
rm -rf ~/.local/share/zi

# 启动新终端，Zi 会自动克隆并安装
zsh
```

### 6. 验证安装

```bash
# 检查 Zsh 版本
zsh --version

# 检查插件是否加载
zi list

# 测试工具
starship --version
fzf --version
zoxide --version
```

## 目录结构

```
~/.config/zsh/
├── .zshrc              # 主配置文件
├── .zshenv             # 环境变量配置
├── conf.d/             # 配置模块目录
│   ├── 00-functions.zsh   # 基础函数
│   ├── 01-environment.zsh # 环境变量
│   ├── 02-optins.zsh      # Zsh 选项
│   ├── 04-grml.zsh        # GRML 配置
│   ├── 05-aliases.zsh     # 别名定义
│   ├── 06-functions.zsh   # 自定义函数
│   ├── 100-eza-aliases.zsh # Eza 别名
│   ├── 101-archive-helper.plugin.zsh # 压缩解压助手
│   ├── 103-conda.zsh      # Conda 配置
│   ├── 104-expend-alias.zsh # 别名展开
│   ├── 105-tmp.env.zsh    # 临时环境变量
│   └── 106-cmdh-expand.zsh # cmdh 命令展开
├── preload.zsh         # 预加载配置 (Zi 初始化)
├── plugins.zsh         # 插件配置
├── lastload.zsh        # 最后加载配置 (Starship)
└── zsh-dependencies.txt # 依赖列表
```

## 配置特性

### 模块化配置

配置被拆分为多个模块，按数字顺序加载，便于维护：
- `00-*` - 基础函数和工具
- `01-*` - 环境变量
- `02-*` - Zsh 选项
- `05-*` - 别名
- `06-*` - 自定义函数
- `100-*` - 工具集成

### 启动时间优化

- 使用 Zi 异步加载插件
- 延迟加载补全系统
- 启动时间测量与 Starship 集成

### Zsh 启动时间测量

配置包含 Zsh 启动时间测量功能，首次启动时会在 Starship 提示符中显示启动时间。

## 插件列表

使用 [Zi](https://github.com/z-shell/zi) 管理插件：

| 插件 | 说明 |
|------|------|
| `colored-man-pages` | 彩色 man 页面 |
| `sudo` | Alt + S 添加 sudo |
| `zsh-vi-mode` | Vi 模式行编辑 |
| `zsh-completions` | 补全增强 |
| `fzf-tab` | FZF 补全菜单 |
| `atuin` | 历史记录管理 |
| `zsh-autosuggestions` | 自动建议 |
| `fast-syntax-highlighting` | 语法高亮 |

### Zoxide 集成

智能目录跳转：

```bash
z foo      # 跳转到包含 foo 的最常用目录
zl         # 交互式选择目录
c          # 选择目录并 cd
```

### Atuin 集成

增强历史记录搜索：

```bash
Ctrl+R     # 搜索历史记录
```

## 自定义函数

### export_from_file

从文件导出环境变量：

```bash
export_from_file VAR_NAME /path/to/file "default_value"
```

### cv

清空文件并用编辑器打开：

```bash
cv <filename>
```

## 环境变量

### PATH 配置

```bash
export PATH=$HOME/.custom/bin:$PATH
export PATH=$PATH:$HOME/.local/share/cargo/bin
export PATH=$PATH:$HOME/.local/bin
```

### pnpm 配置

```bash
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
```

### 编辑器

```bash
export EDITOR=nvim
```

## 别名

### Eza 别名 (ls 替代)

| 别名 | 命令 |
|------|------|
| `ls` | `eza --icons` |
| `ll` | `eza -l --icons` |
| `la` | `eza -la --icons` |
| `lt` | `eza --tree --icons` |

### 常用别名

查看 `conf.d/05-aliases.zsh` 获取完整别名列表。

## 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `zsh` | Shell |
| `git` | 插件克隆 |

### 推荐工具

| 包名 | 用途 |
|------|------|
| `starship` | 提示符 |
| `fzf` | 模糊查找 |
| `fd` | 文件查找 |
| `ripgrep` | 快速搜索 |
| `bat` | 文件查看 |
| `eza` | 现代 ls |
| `zoxide` | 智能目录跳转 |
| `atuin` | 历史记录管理 |
| `thefuck` | 命令纠错 |

### 可选依赖

| 包名 | 用途 |
|------|------|
| `neovim` | 默认编辑器 |
| `curl` | HTTP 客户端 |
| `wget` | 下载工具 |

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `jj` | 退出插入模式 (Vi 模式) |
| `Ctrl+V` | 用编辑器编辑命令 |
| `Ctrl+R` | 搜索历史记录 (Atuin) |
| `` ` `` | 接受自动建议 |
| `Esc Esc` | 在命令前添加 sudo |

## 故障排除

### Zi 插件安装失败

```bash
# 删除 Zi 目录重新安装
rm -rf ~/.local/share/zi
zsh
```

### 补全不工作

```bash
# 重建补全缓存
rm -rf ~/.cache/zsh/zcompdump*
compinit
```

### Starship 不显示

确保在终端模拟器中（不是 Linux 控制台）：

```bash
# 检查终端类型
echo $TERM
```

### 启动慢

```bash
# 启用性能分析
# 取消 .zshrc 中 zmodload zsh/zprof 的注释
# 然后在末尾取消 zprof 的注释
```

## 配置文件

| 文件 | 说明 |
|------|------|
| [`.zshrc`](.zshrc) | 主配置文件 |
| [`.zshenv`](.zshenv) | 环境变量配置 |
| [`preload.zsh`](preload.zsh) | 预加载配置 |
| [`plugins.zsh`](plugins.zsh) | 插件配置 |
| [`lastload.zsh`](lastload.zsh) | 最后加载配置 |
| [`conf.d/`](conf.d/) | 模块化配置目录 |

## 许可

MIT License
