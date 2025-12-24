# Tmux 终端复用器配置

Tmux 是一个终端复用器，允许在单个终端窗口中创建、访问和控制多个终端会话。

## 目录结构

```
~/.config/tmux/
└── tmux.conf    # 主配置文件
```

## 配置特性

### 基础设置
- 默认终端类型：`tmux-256color`
- 启用真彩色支持
- 启用鼠标支持
- 历史记录缓冲区大小：10,000 行
- 窗口和面板索引从 1 开始
- 关闭窗口时自动重新编号
- 减少 Esc 键延迟为 0

### 快捷键绑定

#### 前缀键
- `Ctrl+Space` - 前缀键（替代默认的 Ctrl+b）

#### 面板操作
| 快捷键 | 功能 |
|--------|------|
| `prefix + \|` | 水平分割面板 |
| `prefix + -` | 垂直分割面板 |
| `prefix + h/j/k/l` | 选择面板（左/下/上/右） |
| `prefix + H/J/K/L` | 调整面板大小 |
| `prefix + x` | 关闭面板 |
| `prefix + C-l` | 清屏（发送 Ctrl+l） |

#### 窗口操作
| 快捷键 | 功能 |
|--------|------|
| `prefix + c` | 新建窗口 |
| `prefix + p` | 上一个窗口 |
| `prefix + n` | 下一个窗口 |
| `prefix + w` | 选择窗口 |
| `prefix + &` | 关闭窗口 |

#### Vim 复制模式
| 快捷键 | 功能 |
|--------|------|
| `prefix + [` | 进入复制模式 |
| `v` | 开始选择 |
| `C-v` | 矩形选择 |
| `y` | 复制选择 |
| `P` | 粘贴 |

### 插件

使用 [TPM (Tmux Plugin Manager)](https://github.com/tmux-plugins/tpm) 管理插件：

| 插件 | 说明 |
|------|------|
| `tmux-plugins/tpm` | 插件管理器 |
| `tmux-plugins/tmux-sensible` | 合理的默认设置 |
| `jaclu/tmux-menus` | 菜单系统（`Space` 触发） |
| `2kabhishek/tmux2k` | 主题（onedark） |
| `tmux-plugins/tmux-resurrect` | 会话持久化 |
| `joshmedeski/tmux-nerd-font-window-name` | Nerd Font 窗口名称 |

### 主题配置
- 主题：`onedark`
- 图标模式：仅图标
- 电源线：禁用
- 左侧插件：session, git, cpu, ram
- 右侧插件：battery, network, time

## Arch Linux 依赖

| 包名 | 用途 |
|------|------|
| `tmux` | 终端复用器 |
| `git` | TPM 插件克隆 |

### 可选依赖（用于插件功能）

| 包名 | 用途 |
|------|------|
| `bc` | CPU/内存计算 |
| `upower` | 电池信息 |
| `networkmanager` | 网络信息 |

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow tmux
   ```

2. 安装 TPM 和插件：
   ```bash
   # 按 `prefix + I` 安装插件
   # 按 `prefix + U` 更新插件
   ```

## 快捷键参考

| 操作 | 快捷键 |
|------|--------|
| 重载配置 | `prefix + r` |
| 菜单 | `prefix + Space` |
| 复制模式 | `prefix + [` |
| 选择 | `v` |
| 矩形选择 | `C-v` |
| 复制 | `y` |
| 粘贴 | `P` |
| 水平分割 | `prefix + \|` |
| 垂直分割 | `prefix + -` |
| 选择面板 | `prefix + h/j/k/l` |
| 新建窗口 | `prefix + c` |
| 关闭面板 | `prefix + x` |
| 关闭窗口 | `prefix + &` |

## 许可

MIT License
