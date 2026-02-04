# Neovim 配置

基于 Lua 的现代化 Neovim 配置，集成了大量优秀的插件和工具，旨在提供一个高效、美观且功能丰富的开发环境。

## 从零开始安装

### 1. 安装依赖

```bash
# Neovim
paru -S neovim

# 必需工具
paru -S git nodejs npm ripgrep fd fzf bat

# 语言支持
paru -S tree-sitter clang stylua ruff pyright lua-language-server
```

### 2. 应用配置

```bash
cd ~/.dotfiles
stow nvim
```

### 3. 安装插件

> **注意**：如果使用 dotfiles 安装脚本 (`install.sh`)，lazy.nvim 会自动 bootstrap 并安装所有插件。

首次启动 Neovim 时，Lazy.nvim 会自动克隆并安装所有插件：

```bash
nvim
```

或者使用命令行 headless 模式安装：

```bash
nvim --headless "+Lazy! sync" +qa
```

### 4. 安装语言服务器

```bash
# 在 Neovim 中运行
:Mason
```

### 5. 验证安装

```bash
# 检查健康状态
:checkhealth
```

## 目录结构

```
~/.config/nvim/
├── init.lua                 # 主配置文件
├── lua/
│   ├── config/
│   │   └── lazy.lua         # Lazy.nvim 插件管理器配置
│   ├── keymapping.lua       # 基础键位映射
│   ├── plugins/
│   │   ├── ai.lua           # AI 相关插件配置
│   │   ├── snacks.lua       # Snacks.nvim 核心插件
│   │   ├── colorscheme.lua  # 主题和外观
│   │   ├── ui.lua           # UI 相关插件
│   │   ├── completion.lua   # 代码补全
│   │   ├── lsp.lua          # 语言服务器协议
│   │   ├── edit.lua         # 编辑增强
│   │   ├── treesitter.lua   # 语法高亮
│   │   ├── session.lua      # 会话管理
│   │   └── extra.lua        # 额外工具
│   ├── plugins/lang/
│   │   ├── lua.lua          # Lua 语言支持
│   │   └── python.lua       # Python 语言支持
│   └── utils/
│       └── codecompanion_fidget_spinner.lua  # 工具函数
├── nvim.md                 # 详细配置文档
└── keys.md                 # 快捷键参考
```

## 核心插件

### AI 辅助编程
- **CodeCompanion.nvim** - 多模型 AI 助手（Qwen、GLM、DeepSeek、Kimi 等）
- **Copilot.lua** - GitHub Copilot 集成

### 界面和美化
- **Catppuccin** - 主题配色
- **Snacks.nvim** - 多合一插件（Dashboard、Picker、Notifier、Terminal 等）
- **Lualine** - 状态栏
- **Barbar.nvim** - 标签页
- **Nvim-tree** - 文件浏览器

### 代码补全和 LSP
- **Blink.cmp** - 现代代码补全引擎
- **nvim-lspconfig** - LSP 客户端配置
- **Mason.nvim** - LSP/Formatter/Linter 管理器

### 编辑增强
- **nvim-autopairs** - 自动配对
- **Comment.nvim** - 智能注释
- **smartyank** - 增强复制粘贴
- **mini.surround** - 环绕文本对象
- **mini.ai** - 扩展文本对象
- **Flash.nvim** - 快速跳转
- **nvim-hlslens** - 搜索高亮增强
- **multicursor.nvim** - 多光标编辑

### Git 集成
- **Gitsigns.nvim** - Git 状态显示
- **Trouble.nvim** - 诊断和问题管理

### 文件管理
- **Yazi.nvim** - 文件管理器集成

### 语法高亮和折叠
- **nvim-treesitter** - 语法高亮
- **nvim-ufo** - 现代代码折叠

### 会话管理
- **auto-session** - 自动保存和恢复会话

### 格式化和检查
- **Conform.nvim** - 代码格式化
- **nvim-lint** - 代码检查

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `neovim` | 编辑器 |
| `git` | 版本控制 |
| `nodejs` | Neovim 插件依赖（某些插件需要） |
| `npm` | Node.js 包管理器 |

### 命令行工具

| 包名 | 用途 |
|------|------|
| `ripgrep` | 快速内容搜索 |
| `fd` | 文件查找 |
| `bat` | 文件查看（语法高亮） |
| `fzf` | 模糊查找 |
| `tree-sitter` | 语法解析 |
| `tree-sitter-cli` | Treesitter 命令行工具 |

### C/C++ 支持

| 包名 | 用途 |
|------|------|
| `clang` | C/C++ 编译器 |
| `clang-format` | C/C++ 代码格式化 |

### Python 支持

| 包名 | 用途 |
|------|------|
| `python` | Python 解释器 |
| `python-pip` | Python 包管理器 |
| `ruff` | Python Linter/Formatter |
| `pyright` | Python LSP |

### Lua 支持

| 包名 | 用途 |
|------|------|
| `lua` | Lua 解释器 |
| `lua-language-server` | Lua LSP |
| `stylua` | Lua 代码格式化 |

### 通用工具

| 包名 | 用途 |
|------|------|
| `codespell` | 拼写检查 |
| `curl` | HTTP 客户端 |
| `wget` | 下载工具 |

## 快捷键

### 基础键位
- `Space` - Leader 键
- `\` - 本地 Leader 键
- `jk` - 快速退出插入模式

### 文件搜索
- `<leader><space>` - 智能文件查找
- `<leader>sf` - 文件搜索
- `<leader>sg` - 全局搜索
- `<leader>sb` - 缓冲区搜索

### AI 助手
- `<leader>cca` - 显示 CodeCompanion 操作
- `<leader>cci` - 内联 AI 助手
- `<leader>ccc` - 切换聊天窗口
- `<leader>ccp` - 添加选中代码到聊天
- `<leader>ccs` - 选择 AI 模型

### 文件管理
- `<leader>E` - 在当前文件位置打开 Yazi
- `<leader>cw` - 在工作目录打开 Yazi

### Git 操作
- `]h/[h` - 下一个/上一个代码块
- `<leader>ggs` - 暂存代码块
- `<leader>ggr` - 重置代码块
- `<leader>ggp` - 预览代码块

### 诊断
- `<leader>gd` - 显示诊断
- `<leader>gs` - 显示符号
- `<leader>gl` - LSP 定义/引用
- `<Alt>j/k` - 下一个/上一个诊断

### 格式化
- `<leader>tf` - 切换自动格式化

更多快捷键请参考 [`keys.md`](keys.md:1)

## 配置文件

| 文件 | 说明 |
|------|------|
| [`init.lua`](init.lua:1) | 主配置文件 |
| [`lua/config/lazy.lua`](lua/config/lazy.lua:1) | Lazy.nvim 配置 |
| [`lua/keymapping.lua`](lua/keymapping.lua:1) | 键位映射 |
| [`lua/plugins/lsp.lua`](lua/plugins/lsp.lua:1) | LSP 配置 |
| [`lua/plugins/completion.lua`](lua/plugins/completion.lua:1) | 代码补全配置 |
| [`lua/plugins/treesitter.lua`](lua/plugins/treesitter.lua:1) | Treesitter 配置 |
| [`lua/plugins/lang/python.lua`](lua/plugins/lang/python.lua:1) | Python 语言支持 |
| [`lua/plugins/lang/lua.lua`](lua/plugins/lang/lua.lua:1) | Lua 语言支持 |

## 详细文档

详细的配置说明请参考 [`nvim.md`](nvim.md:1)。

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow nvim
   ```

2. 首次启动 Neovim 时，Lazy.nvim 会自动安装所有插件。

3. 安装语言服务器和格式化工具：
   ```bash
   # Python
   pip install ruff pyright

   # Lua
   pip install stylua

   # C/C++
   sudo pacman -S clang clang-format
   ```

## 许可

MIT License
