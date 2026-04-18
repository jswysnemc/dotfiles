# Neovim 配置自述

这是一套基于 `lazy.nvim` 的个人 Neovim 配置，目标是：

- 用 `lazy.nvim` 按文件拆分插件配置
- 以 `LSP + Treesitter + 格式化 + Lint + 调试 + 搜索 + Git + 智能编程辅助` 为核心工作流
- 保持界面统一、透明背景、键位可发现
- 在日常编码场景下尽量减少重复配置

## 入口与结构

| 路径 | 作用 |
| --- | --- |
| `init.lua` | 设置 `mapleader`，引导 `lazy.nvim`，加载 `config/*`，导入 `plugins/*` |
| `lua/config/options.lua` | 基础选项、折叠、外观、分屏等全局设置 |
| `lua/config/keymaps.lua` | 全局快捷键 |
| `lua/config/autocmds.lua` | 自动命令，例如自动保存、特殊窗口 `q` 关闭 |
| `lua/plugins/*.lua` | 按功能拆分的插件配置 |
| `lazy-lock.json` | 插件版本锁文件 |
| `stylua.toml` | Lua 格式化规则 |

`init.lua` 的加载顺序：

1. 设置 `mapleader = " "` 与 `maplocalleader = "\\"`
2. 自举 `lazy.nvim`
3. 加载 `options`、`keymaps`、`autocmds`
4. 通过 `lazy.nvim` 导入 `lua/plugins/*.lua`

## 核心行为

### 基础选项

当前配置的几个关键默认值：

- 行号：仅绝对行号，`relativenumber = false`
- 剪贴板：`unnamedplus`
- 光标行：开启
- 缩进：4 空格，`expandtab`
- 屏幕自动换行：关闭，`wrap = false`
- 搜索：`ignorecase + smartcase + hlsearch + incsearch`
- 分屏：右侧 / 下方打开
- 持久撤销：`undofile = true`
- 列表字符：显示尾随空格与不可见字符
- 状态栏：全局状态栏，`laststatus = 3`
- 标签栏：始终显示，`showtabline = 2`
- 折叠：基于语法树表达式，默认展开，`foldlevel = 99`
- 界面：真彩色，折叠符号自定义

### 自动命令

`lua/config/autocmds.lua` 定义了以下自动行为：

- 复制后高亮
- 打开文件时跳回上次光标位置
- 终端大小变化时重排分屏
- `help` / `lspinfo` / `man` / `notify` / `qf` / `query` 类型窗口中，`q` 关闭窗口
- 文本变化或退出插入模式时自动保存已修改缓冲区

### 额外内置行为

- `<leader>uw`：切换当前窗口自动换行
- `<leader>qq`：全部退出
- `<leader>cr`：调用增量重命名命令
- 折叠相关按键由 `ufo` 接管，例如 `zR`、`zM`、`zr`、`zm`

## 插件概览

下面按功能说明当前实际启用的配置。

### 界面与基础编辑

- `lua/plugins/colorscheme.lua`
  - `catppuccin/nvim`
  - 主题为 `mocha`
  - 启用透明背景
  - 对浮窗、侧栏、搜索面板、补全面板等高亮做额外透明覆盖

- `lua/plugins/editor.lua`
  - `echasnovski/mini.icons`：图标支持，并兼容 `nvim-web-devicons` 接口
  - `folke/which-key.nvim`：快捷键提示与分组展示
  - `folke/todo-comments.nvim`：TODO / FIXME / NOTE 高亮与跳转
  - `folke/ts-comments.nvim`：基于语法树的注释支持
  - `echasnovski/mini.pairs`：自动补全括号、引号
  - `echasnovski/mini.ai`：增强文本对象
  - `echasnovski/mini.surround`：包围操作
  - `folke/persistence.nvim`：会话恢复与选择

- `lua/plugins/lualine.lua`
  - `nvim-lualine/lualine.nvim`
  - 作为当前状态栏方案
  - 集成分支、诊断、LSP 客户端、录制寄存器与补全助手状态

- `lua/plugins/tabby.lua`
  - `nanozuki/tabby.nvim`
  - 作为当前 Buffer / 窗口标签栏方案

- `lua/plugins/noice.lua`
  - `folke/noice.nvim`
  - 增强命令行、消息、LSP 浮窗显示

- `lua/plugins/snacks.lua`
  - `folke/snacks.nvim`
  - 启用 Dashboard、Explorer、Terminal、Notifier、Words、Indent、Input、Scroll 等模块
  - 明确关闭 `picker`，主搜索方案仍然是 `fzf-lua`

- `lua/plugins/rainbow.lua`
  - `HiPhish/rainbow-delimiters.nvim`
  - 彩虹括号

- `lua/plugins/flash.lua`
  - `smoka7/hop.nvim`
  - 快速跳转与行跳转

- `lua/plugins/flit.lua`
  - `chrisgrieser/nvim-spider`
  - 改进 `w/e/b/ge` 的子词跳转行为

- `lua/plugins/ufo.lua`
  - `kevinhwang91/nvim-ufo`
  - 提供更完整的折叠预览与折叠管理

- `lua/plugins/mini-align.lua`
  - `echasnovski/mini.align`
  - 交互式文本对齐

- `lua/plugins/mini-animate.lua`
  - `echasnovski/mini.animate`
  - 光标、窗口开关与尺寸变化动画
  - 滚动动画关闭，交由 `snacks.scroll` 处理

- `lua/plugins/mini-hipatterns.lua`
  - `echasnovski/mini.hipatterns`
  - 高亮十六进制颜色值

- `lua/plugins/yanky.lua`
  - `gbprod/yanky.nvim`
  - 剪贴板历史与增强粘贴

### 语言与代码能力

- `lua/plugins/completion.lua`
  - `saghen/blink.cmp`
  - `rafamadriz/friendly-snippets`
  - 补全源：`lsp` / `path` / `snippets` / `buffer`
  - 文档自动显示，延迟 500ms
  - 启用 ghost text
  - 开启签名帮助

- `lua/plugins/lsp.lua`
  - `folke/lazydev.nvim`：Lua 开发增强
  - `mason-org/mason.nvim`：外部工具安装器
  - `mason-org/mason-lspconfig.nvim`：Mason 与 LSP 桥接
  - `neovim/nvim-lspconfig`：LSP 配置

  当前通过 Mason 保证安装的服务端：

  - `lua_ls`
  - `gopls`
  - `rust_analyzer`
  - `pyright`
  - `ts_ls`
  - `clangd`
  - `html`
  - `cssls`
  - `jsonls`
  - `bashls`

  额外定制：

  - `lua_ls`：关闭第三方工作区检查，识别 `vim`
  - `rust_analyzer`：保存时执行 `clippy`，开启全部 Cargo features
  - 诊断符号：`E/W/I/H`
  - `LspAttach` 时注册定义、声明、引用、实现、类型定义、悬停、签名帮助、CodeLens、重命名、代码操作等按键

- `lua/plugins/treesitter.lua`
  - `nvim-treesitter/nvim-treesitter`
  - `nvim-treesitter/nvim-treesitter-textobjects`
  - 自动安装并补齐常用语言解析器
  - 提供函数、类、参数文本对象与跳转

  当前配置的解析器包含：

  - `bash` `c` `cpp` `css` `diff` `go` `gomod` `gosum` `gowork`
  - `html` `java` `javascript` `json` `jsonc`
  - `lua` `luadoc` `luap`
  - `markdown` `markdown_inline`
  - `python` `query` `regex`
  - `rust` `scss` `toml`
  - `tsx` `typescript`
  - `vim` `vimdoc`
  - `vue` `yaml`

- `lua/plugins/format.lua`
  - `stevearc/conform.nvim`
  - 保存时自动格式化
  - `<leader>cf` 手动格式化
  - `<leader>tf` 切换自动格式化
  - `:FormatDisable[!]` / `:FormatEnable` 手动开关

  配置的格式化器：

  - `stylua`
  - `gofmt`
  - `goimports`
  - `ruff_format`
  - `rustfmt`
  - `prettierd`
  - `shfmt`
  - `clang-format`

- `lua/plugins/lint.lua`
  - `mfussenegger/nvim-lint`
  - 在 `BufEnter` / `BufWritePost` / `InsertLeave` 自动执行
  - `<leader>xl` 手动执行

  文件类型到 linter：

  - `python -> ruff`
  - `sh/bash -> shellcheck`
  - `dockerfile -> hadolint`
  - `yaml -> yamllint`

- `lua/plugins/inc-rename.lua`
  - `smjonas/inc-rename.nvim`
  - 提供增量重命名输入体验

### 调试

- `lua/plugins/dap.lua`
  - `mfussenegger/nvim-dap`
  - `jay-babu/mason-nvim-dap.nvim`
  - `rcarriga/nvim-dap-ui`
  - `nvim-neotest/nvim-nio`
  - `theHamsta/nvim-dap-virtual-text`
  - `mfussenegger/nvim-dap-python`
  - `leoluz/nvim-dap-go`
  - `mxsdev/nvim-dap-vscode-js`

当前调试适配器：

- Python：`debugpy`
- Go：`delve`
- Rust / C / C++：`codelldb`
- JavaScript / TypeScript：`js-debug-adapter`

调试语言集成：

- Python：方法级测试调试
- Go：测试调试
- JavaScript / TypeScript：
  - 启动当前文件
  - 附加到 Node 进程
  - 启动浏览器调试前端

`dap-ui` 会在 attach / launch 时自动打开，在 terminated / exited 时自动关闭。

### 搜索、文件与工作流

- `lua/plugins/fzf.lua`
  - `ibhagwan/fzf-lua`
  - 负责文件、全文、当前词、当前文件、命令、帮助、快捷键、LSP 符号、诊断等搜索
  - 预览窗口为纵向布局
  - 搜索命令显式使用 `rg`

- `lua/plugins/oil.lua`
  - `stevearc/oil.nvim`
  - 作为默认文件浏览器
  - 显示图标
  - 显示隐藏文件
  - 启用 LSP 文件方法
  - 删除走回收站

- `lua/plugins/spectre.lua`
  - `nvim-pack/nvim-spectre`
  - 提供全局搜索替换
  - 查找使用 `rg`，替换使用 `sed`

- `lua/plugins/translate.lua`
  - `uga-rosa/translate.nvim`
  - 提供浮动窗口翻译与替换翻译

### Git 与协作

- `lua/plugins/git.lua`
  - `lewis6991/gitsigns.nvim`
  - 行内 Git 标记、修改块导航、暂存、重置、预览、Blame
  - 启用当前行 Blame

- `lua/plugins/git-ui.lua`
  - `NeogitOrg/neogit`
  - `sindrets/diffview.nvim`
  - 提供 Git 终端界面、Diff 视图与文件历史

### 智能编程辅助

- `lua/plugins/ai.lua`
  - `yetone/avante.nvim`
  - `zbirenbaum/copilot.lua`
  - 以及对应 UI / 输入 / 选择 / Markdown 渲染依赖

  `avante.nvim` 的关键配置：

  - 主 provider：`wishub`
  - 输入使用 `snacks`
  - selector 使用 `fzf_lua`
  - 模式：`agentic`
  - 自动建议关闭
  - 自动注册键位开启
  - 自动添加当前文件开启
  - 最小化 diff 开启
  - 通过环境变量 `WISHUB_API_KEY` 认证

  `copilot.lua` 的关键配置：

  - 启用行内建议
  - 自动触发开启
  - 使用 `<C-l>` 接受建议
  - `<leader>tc` 切换启用状态
  - 面板关闭

- `lua/plugins/codecompanion.lua`
  - `olimorris/codecompanion.nvim`
  - 提供动作面板、对话与内联操作入口
  - 相关命令按需加载

## 已禁用的插件文件

下列插件文件仍保留在仓库中，但当前未启用：

- `lua/plugins/bufferline.lua`：已禁用，改用 `tabby.nvim`
- `lua/plugins/incline.lua`：已禁用
- `lua/plugins/mini-statusline.lua`：已禁用，改用 `lualine.nvim`

## 快捷键总览

说明：

- 下表只列出本仓库显式定义或显式配置的快捷键
- 某些插件默认键位未在此展开
- 少数键位会被多个插件复用，实际以当前生效映射为准

### Normal 模式：全局快捷键

| 键位 | 说明 | 来源 |
| --- | --- | --- |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | 窗口导航 | `config/keymaps.lua` |
| `<S-h>` `<S-l>` | 上一个 / 下一个 Buffer | `config/keymaps.lua` / `tabby.lua` |
| `[b` `]b` | 上一个 / 下一个 Buffer | `config/keymaps.lua` / `tabby.lua` |
| `<Esc>` | 清除搜索高亮 | `config/keymaps.lua` |
| `<C-Up>` `<C-Down>` | 调整窗口高度 | `config/keymaps.lua` |
| `<C-Left>` `<C-Right>` | 调整窗口宽度 | `config/keymaps.lua` |
| `<A-j>` `<A-k>` | 上下移动当前行 | `config/keymaps.lua` |
| `<leader>-` | 水平分屏 | `config/keymaps.lua` |
| `<leader>\|` | 垂直分屏 | `config/keymaps.lua` |
| `<leader>uw` | 切换自动换行 | `config/keymaps.lua` |
| `<leader>qq` | 全部退出 | `config/keymaps.lua` |
| `-` | 打开上级目录 | `oil.lua` |
| `s` | 快速跳转 | `flash.lua` |
| `S` | 行跳转 | `flash.lua` |
| `w` `e` `b` `ge` | 子词跳转 | `flit.lua` |
| `zR` `zM` `zr` `zm` | 折叠控制 | `ufo.lua` |
| `K` | 预览折叠，若无折叠则显示悬停文档 | `ufo.lua` / `lsp.lua` |
| `]]` `[[` | 下一个 / 上一个引用词 | `snacks.lua` |
| `p` `P` `gp` `gP` | 增强粘贴 | `yanky.lua` |
| `<C-p>` `<C-n>` | 剪贴板历史前后切换 | `yanky.lua` |

### Visual / Operator 模式：文本操作

| 键位 | 说明 | 来源 |
| --- | --- | --- |
| `<A-j>` `<A-k>` | 上下移动选区 | `config/keymaps.lua` |
| `af` `if` | 选择函数外层 / 内层 | `treesitter.lua` |
| `ac` `ic` | 选择类外层 / 内层 | `treesitter.lua` |
| `aa` `ia` | 选择参数外层 / 内层 | `treesitter.lua` |
| `ih` | 选择修改块 | `git.lua` |
| `r` | 远程操作跳转 | `flash.lua` |

### Leader 分组快捷键

| 键位 | 说明 | 来源 |
| --- | --- | --- |
| `<leader>?` | 当前 Buffer 快捷键 | `editor.lua` |
| `<leader><space>` | 查找文件 | `fzf.lua` |
| `<leader>/` | 全局搜索 | `fzf.lua` |
| `<leader>,` | Buffer 列表 | `fzf.lua` |
| `<leader>:` | 命令历史 | `fzf.lua` |
| `<leader>aa` | 提问 | `ai.lua` |
| `<leader>ae` | 编辑 | `ai.lua` |
| `<leader>ar` | 刷新选区结果 | `ai.lua` |
| `<leader>at` | 切换默认功能 | `ai.lua` |
| `<leader>ad` | 调试开关 | `ai.lua` |
| `<leader>ah` | 提示开关 | `ai.lua` |
| `<leader>as` | 建议开关 | `ai.lua` |
| `<leader>bd` | 关闭 Buffer | `snacks.lua` |
| `<leader>ca` | 代码操作 / 动作入口 | `lsp.lua` / `codecompanion.lua` |
| `<leader>cc` | 对话 | `codecompanion.lua` |
| `<leader>cf` | 格式化代码 | `format.lua` |
| `<leader>ci` | 内联操作 | `codecompanion.lua` |
| `<leader>cl` | 运行 CodeLens | `lsp.lua` |
| `<leader>cr` | 重命名 | `lsp.lua` / `config/keymaps.lua` |
| `<leader>db` `<leader>dB` | 切换断点 / 条件断点 | `dap.lua` |
| `<leader>dc` `<leader>dC` | 开始继续 / 运行到光标处 | `dap.lua` |
| `<leader>de` | 查看表达式值 | `dap.lua` |
| `<leader>di` `<leader>do` `<leader>dO` | 单步进入 / 跳过 / 跳出 | `dap.lua` |
| `<leader>dl` | 重新运行上次调试 | `dap.lua` |
| `<leader>dn` | 调试最近测试 | `dap.lua` |
| `<leader>dr` | 打开调试 REPL | `dap.lua` |
| `<leader>dt` | 结束调试 | `dap.lua` |
| `<leader>du` | 切换调试界面 | `dap.lua` |
| `<leader>dx` | 清除所有断点 | `dap.lua` |
| `<leader>e` | Explorer | `snacks.lua` |
| `<leader>fe` | 文件管理器 | `oil.lua` |
| `<leader>fr` | 最近文件 | `fzf.lua` |
| `<leader>gB` | 在浏览器中打开当前 Git 目标 | `snacks.lua` |
| `<leader>gc` | Git 提交 | `git-ui.lua` |
| `<leader>gd` | Diff 视图 | `git-ui.lua` |
| `<leader>gD` | 文件历史 | `git-ui.lua` |
| `<leader>gg` | Lazygit | `snacks.lua` |
| `<leader>gn` | Neogit | `git-ui.lua` |
| `<leader>hb` `<leader>hd` `<leader>hD` | Git blame / diff | `git.lua` |
| `<leader>hp` `<leader>hs` `<leader>hS` | 预览 / 暂存修改块 / 暂存整个文件 | `git.lua` |
| `<leader>hr` `<leader>hR` | 重置修改块 / 重置整个文件 | `git.lua` |
| `<leader>n` | 通知历史 | `snacks.lua` |
| `<leader>nh` `<leader>nl` `<leader>nn` | 消息历史 / 最后一条 / 清除消息 | `noice.lua` |
| `<leader>qd` `<leader>ql` `<leader>qS` `<leader>qs` | 会话管理 | `editor.lua` |
| `<leader>sb` | 当前文件搜索 | `fzf.lua` |
| `<leader>sc` | 命令列表 | `fzf.lua` |
| `<leader>sdb` `<leader>sdd` | 文件 / 工作区诊断搜索 | `fzf.lua` |
| `<leader>sg` | 全局搜索 | `fzf.lua` |
| `<leader>sh` | 帮助文档 | `fzf.lua` |
| `<leader>sk` | 快捷键列表 | `fzf.lua` |
| `<leader>sr` | 搜索替换界面 | `spectre.lua` |
| `<leader>ss` `<leader>sS` | 文档 / 工作区符号 | `fzf.lua` |
| `<leader>st` | 待办事项 | `editor.lua` / `fzf.lua` |
| `<leader>sw` | 搜索当前词 | `fzf.lua` |
| `<leader>tb` | 切换当前行 blame | `git.lua` |
| `<leader>tc` | 切换补全助手 | `ai.lua` |
| `<leader>td` | 切换已删除行显示 | `git.lua` |
| `<leader>te` | 翻译为英文 | `translate.lua` |
| `<leader>tf` | 切换自动格式化 | `format.lua` |
| `<leader>tw` | 翻译为中文 | `translate.lua` |
| `<leader>tW` | 翻译并替换 | `translate.lua` |
| `<leader>un` | 清除通知 | `snacks.lua` |
| `<leader>xl` | 触发 Lint | `lint.lua` |
| `<leader>yh` | 剪贴板历史 | `yanky.lua` |

### LSP / 语法树 / Git 导航键

| 键位 | 说明 | 来源 |
| --- | --- | --- |
| `gd` `gD` | 跳转到定义 / 声明 | `lsp.lua` |
| `gr` `gI` `gy` | 引用 / 实现 / 类型定义 | `lsp.lua` |
| `gK` | 签名帮助 | `lsp.lua` |
| `[f` `]f` `[F` `]F` | 函数开始 / 结束跳转 | `treesitter.lua` |
| `[c` `]c` `[C` `]C` | 类开始 / 结束跳转 | `treesitter.lua` |
| `[h` `]h` | 上一个 / 下一个修改块 | `git.lua` |
| `[t` `]t` | 上一个 / 下一个待办 | `editor.lua` |

## 使用说明

### 首次启动

首次启动 Neovim 时会自动：

1. 克隆 `lazy.nvim`
2. 根据插件配置拉取插件
3. 按需安装语法树解析器
4. 通过 Mason 安装配置中声明的 LSP / DAP 相关工具

### 外部依赖建议

为了让整套配置工作完整，建议系统中安装：

- `git`
- `ripgrep`
- `fd`
- 各语言格式化器与 linter
- 调试适配器所需运行时

### 常见入口

- `:Mason`：查看外部工具安装情况
- `:Lazy`：查看插件加载情况
- `:FzfLua files`：查找文件
- `:Neogit`：打开 Git 界面
- `:Oil`：打开文件管理器
- `:Translate zh` / `:Translate en`：翻译文本
- `:FormatDisable` / `:FormatEnable`：切换自动格式化

## 总结

这套配置目前偏向完整开发工作流，重点特征是：

- `tabby + lualine + noice + snacks` 组成主要界面层
- `LSP + Treesitter + blink.cmp + conform + lint` 组成代码能力层
- `nvim-dap` 负责调试
- `fzf-lua + oil + spectre` 负责搜索与文件操作
- `gitsigns + neogit + diffview` 负责版本控制
- 多套智能编程辅助工具并存，可按需使用
