# Starship 提示符配置

Starship 是一个用 Rust 编写的极简、快速、可定制的 shell 提示符，适用于任何 shell。

## 从零开始安装

### 1. 安装 Starship

```bash
paru -S starship
```

### 2. 安装字体

```bash
paru -S ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono-nerd noto-fonts-cjk
```

### 3. 应用配置

```bash
cd ~/.dotfiles
stow starship
```

### 4. 在 Shell 中启用

**Zsh** (在 `~/.zshrc` 中，已包含在 zsh 配置中)：
```bash
eval "$(starship init zsh)"
```

**Bash** (在 `~/.bashrc` 中)：
```bash
eval "$(starship init bash)"
```

**Fish** (在 `~/.config/fish/config.fish` 中)：
```fish
starship init fish | source
```

### 5. 验证安装

```bash
# 检查版本
starship --version

# 检查配置
starship explain
```

## 目录结构

```
~/.config/starship/
└── starship.toml    # 主配置文件
```

## 配置特性

### 提示符格式
```
[shell][os][username][hostname] [directory] [container] [all] [character]
```

### 模块配置

#### 字符 (character)
- 成功符号：`➜`（绿色）
- 错误符号：`➜`（红色）
- Vim 模式符号：
  - 普通：`󰰒`
  - 可视：`󰬝`
  - 替换：`󰬙`

#### Shell
显示当前 shell 类型：
- fish: ``
- powershell: ``
- bash: `󰬉`
- zsh: `󰬡`
- cmd: ``

#### 命令执行时间 (cmd_duration)
- 最小显示时间：500ms
- 格式：` [duration]`（黄色）

#### Git 分支 (git_branch)
- 符号：``
- 样式：蓝色背景

#### 用户名 (username)
- 样式：黄色加粗
- Root 用户：红色加粗
- 始终显示

#### 主机名 (hostname)
- SSH 符号：` `
- 仅 SSH 连接时显示
- 样式：暗蓝色

#### 目录 (directory)
- 符号：` [path]`
- 不截断路径
- 不截断到仓库根目录

#### 操作系统 (os)
- 显示系统图标：
  - Arch: ` `
  - Debian: ` `
  - Ubuntu: ` `
  - Fedora: ` `
  - 等等...

#### 自定义模块：Zsh 启动时间 (custom.zsh_startup)
- 显示 Zsh 首次启动时间
- 格式：`[startup_time]`
- 样式：绿色加粗
- 仅首次显示

#### 其他语言模块
- AWS: ` `
- Conda: ` `
- Dart: ` `
- Docker: ` `
- Elixir: ` `
- Elm: ` `
- Golang: ` `
- Java: ` `
- Julia: ` `
- Memory: ` `
- Nim: ` `
- Nix Shell: ` `
- Package: ` `
- Perl: ` `
- PHP: ` `
- Python: ` `
- Ruby: ` `
- Rust: ` `
- Scala: ` `
- Swift: `ﯣ `
- Lua: ` `

## Arch Linux 依赖

| 包名 | 用途 |
|------|------|
| `starship` | 提示符 |
| `zsh` | Shell（主要） |
| `bash` | Shell（可选） |
| `fish` | Shell（可选） |

### 字体依赖

| 包名 | 用途 |
|------|------|
| `noto-fonts-cjk` | 中文字体 |
| `nerd-fonts` | Nerd Font 图标 |

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow starship
   ```

2. 安装 Starship：
   ```bash
   sudo pacman -S starship
   ```

3. 在 Shell 中启用：

   **Zsh** (在 `~/.zshrc` 中)：
   ```bash
   eval "$(starship init zsh)"
   ```

   **Bash** (在 `~/.bashrc` 中)：
   ```bash
   eval "$(starship init bash)"
   ```

   **Fish** (在 `~/.config/fish/config.fish` 中)：
   ```fish
   starship init fish | source
   ```

## 配置

配置文件位于 `~/.config/starship/starship.toml`。

主要配置项：
- `format` - 提示符格式
- `add_newline` - 提示符之间是否添加空行
- 各模块的详细配置

## 许可

MIT License
