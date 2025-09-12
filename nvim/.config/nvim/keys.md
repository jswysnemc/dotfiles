# Neovim 快捷键大全

本文档包含了我的 Neovim 配置中所有的自定义快捷键，按功能分类整理。

## 基础快捷键

### 插入模式
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Ctrl + h` | 向左移动光标 | Insert |
| `Ctrl + l` | 向右移动光标 | Insert |
| `Ctrl + j` | 向下移动光标 | Insert |
| `Ctrl + k` | 向上移动光标 | Insert |
| `jk` | 退出插入模式 | Insert |

### 普通模式
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Ctrl + h` | 切换到左侧窗口 | Normal |
| `Ctrl + l` | 切换到右侧窗口 | Normal |
| `Ctrl + j` | 切换到下方窗口 | Normal |
| `Ctrl + k` | 切换到上方窗口 | Normal |
| `Shift + H` | 跳转到行首 | Normal, Visual, Operator |
| `Shift + L` | 跳转到行尾 | Normal, Visual, Operator |
| `Q` | 退出所有窗口 | Normal, Visual |
| `qq` | 退出当前窗口 | Normal, Visual |
| `Alt + z` | 切换自动换行 | Normal |

### 通用
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>L` | 打开 Lazy.nvim | Normal |

## AI 辅助编程 (CodeCompanion)

### AI 操作
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>cca` | 显示 CodeCompanion 操作 | Normal, Visual |
| `<leader>cci` | 启动内联 AI 助手 | Normal, Visual |
| `<leader>ccc` | 切换聊天窗口 | Normal, Visual |
| `<leader>ccp` | 添加选中代码到聊天 | Visual |
| `<leader>ccs` | 选择 AI 模型 | Normal |

## Snacks.nvim

### 缓冲区管理
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Alt + w` | 删除当前缓冲区 | Normal |
| `<leader><space>` | 智能文件查找 | Normal |
| `<leader>,` | 缓冲区列表 | Normal |
| `<leader>sb` | 缓冲区列表 | Normal |

### 文件搜索
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>sf` | 文件搜索 | Normal |
| `<leader>sp` | 项目搜索 | Normal |
| `<leader>sr` | 最近文件 | Normal |

### Git 操作
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Ctrl + g` | 打开 Lazygit | Normal |
| `<leader>ggl` | Git 日志 | Normal |
| `<leader>ggd` | Git 差异 | Normal |
| `<leader>ggb` | 当前行 Git 责任 | Normal |
| `<leader>ggB` | Git 浏览 | Normal |

### 搜索和替换
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>sg` | 全局搜索 | Normal |
| `<leader>s"` | 寄存器搜索 | Normal |
| `<leader>s/` | 搜索历史 | Normal |
| `<leader>sa` | 拼写检查 | Normal |
| `<leader>sA` | 自动命令 | Normal |
| `<leader>s:` | 命令历史 | Normal |
| `<leader>sc` | 命令列表 | Normal |
| `<leader>sd` | 诊断信息 | Normal |
| `<leader>sD` | 当前缓冲区诊断 | Normal |
| `<leader>sH` | 帮助页面 | Normal |
| `<leader>sh` | 高亮组 | Normal |
| `<leader>sI` | 图标列表 | Normal |
| `<leader>sj` | 跳转列表 | Normal |
| `<leader>sk` | 键位映射 | Normal |
| `<leader>sl` | 位置列表 | Normal |
| `<leader>sm` | 标记列表 | Normal |
| `<leader>sM` | 手册页面 | Normal |
| `<leader>sp` | 插件搜索 | Normal |
| `<leader>sq` | 快速修复列表 | Normal |
| `<leader>sr` | 恢复上次搜索 | Normal |
| `<leader>su` | 撤销历史 | Normal |
| `<leader>sT` | TODO 注释（包含 NOTE） | Normal |
| `<leader>st` | TODO 注释（不包含 NOTE） | Normal |
| `<leader>sn` | 通知历史 | Normal |
| `<leader>sN` | Noice 历史消息 | Normal |

### LSP 集成
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `gd` | 跳转到定义 | Normal |
| `gD` | 跳转到声明 | Normal |
| `gr` | 查找引用 | Normal |
| `gI` | 跳转到实现 | Normal |
| `gy` | 跳转到类型定义 | Normal |
| `<leader>ss` | LSP 符号 | Normal |
| `<leader>sS` | 工作区 LSP 符号 | Normal |

### 终端和工具
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Alt + i` | 切换终端 | Normal, Terminal |
| `<leader>si` | 显示图片 | Normal |

### 通知管理
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>n` | 显示通知历史 | Normal |
| `<leader>un` | 清除所有通知 | Normal |

### 单词跳转
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `]]` | 下一个引用 | Normal, Terminal |
| `[[` | 上一个引用 | Normal, Terminal |

### 专注模式
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>z` | 切换禅模式 | Normal |
| `<leader>Z` | 切换缩放模式 | Normal |

## 切换功能 (Snacks Toggle)

### 开关类快捷键
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>ta` | 切换动画 | Normal |
| `<leader>tS` | 切换滚动动画 | Normal |
| `<leader>tD` | 切换背景变暗 | Normal |
| `<leader>ts` | 切换拼写检查 | Normal |
| `<leader>tw` | 切换自动换行 | Normal |
| `<leader>tL` | 切换相对行号 | Normal |
| `<leader>td` | 切换诊断 | Normal |
| `<leader>tl` | 切换行号 | Normal |
| `<leader>tc` | 切换隐藏级别 | Normal |
| `<leader>tT` | 切换 Treesitter | Normal |
| `<leader>tb` | 切换深色背景 | Normal |
| `<leader>th` | 切换内联提示 | Normal |
| `<leader>tg` | 切换缩进指示器 | Normal |
| `<leader>tpp` | 切换性能分析器 | Normal |
| `<leader>tph` | 切换性能分析器高亮 | Normal |
| `<leader>tf` | 切换自动格式化 | Normal |
| `<leader>tgb` | 切换 Git 责任行 | Normal |
| `<leader>tgw` | 切换 Git 单词差异 | Normal |

## UI 相关

### 标签页导航 (Barbar)
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Alt + <` | 缓冲区左移 | Normal |
| `Alt + >` | 缓冲区右移 | Normal |
| `Alt + 1-9` | 跳转到第 1-9 个缓冲区 | Normal |
| `Alt + h` | 上一个缓冲区 | Normal |
| `Alt + l` | 下一个缓冲区 | Normal |

### 文件管理
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>e` | 切换 NvimTree | Normal |
| `<leader>E` | 在当前文件位置打开 Yazi | Normal, Visual |
| `<leader>cw` | 在工作目录打开 Yazi | Normal |
| `Ctrl + ↑` | 恢复上次 Yazi 会话 | Normal |

### 消息历史 (Noice)
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>N` | 显示历史消息 | Normal |

### 键位帮助 (WhichKey)
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>?` | 显示本地键位映射 | Normal |

## 编辑增强

### 注释功能 (Comment.nvim)
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>/` | 切换行注释 | Normal, Visual |
| `Ctrl + /` | 切换行注释 | Normal, Visual |

### Flash 跳转
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>f` | Flash 跳转 | Normal, Visual, Operator |
| `<leader>F` | Flash Treesitter 跳转 | Normal, Visual, Operator |
| `<leader>F` | Flash Treesitter 搜索 | Operator, Visual |
| `Ctrl + f` | 切换 Flash 搜索 | Command |
| `<leader>j` | Flash 行跳转 | Normal, Visual, Operator |
| `<leader>k` | Flash 行跳转 | Normal, Visual, Operator |

### 多光标编辑 (multicursor)
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `mI` | 在选中位置插入光标 | Visual |
| `mA` | 在选中位置追加光标 | Visual |

### 撤销树 (Undotree)
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>ut` | 切换撤销树 | Normal |

## Git 集成 (Gitsigns)

### 导航
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `]h` | 下一个 Git 代码块 | Normal |
| `]H` | 最后一个 Git 代码块 | Normal |
| `[h` | 上一个 Git 代码块 | Normal |
| `[H` | 第一个 Git 代码块 | Normal |

### 操作
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>ggs` | 暂存代码块 | Normal |
| `<leader>ggs` | 暂存代码块（可视化模式） | Visual |
| `<leader>ggr` | 重置代码块 | Normal |
| `<leader>ggr` | 重置代码块（可视化模式） | Visual |
| `<leader>ggS` | 暂存整个缓冲区 | Normal |
| `<leader>ggR` | 重置整个缓冲区 | Normal |
| `<leader>ggp` | 预览代码块 | Normal |
| `<leader>ggP` | 内联预览代码块 | Normal |
| `<leader>ggQ` | 显示所有差异（快速修复列表） | Normal |
| `<leader>ggq` | 显示差异（快速修复列表） | Normal |

### 文本对象
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `ih` | 当前代码块 | Operator, Visual |

## 代码补全 (Blink.cmp)

### 补全菜单导航
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Alt + j` | 选择下一个项目 | Insert |
| `Alt + k` | 选择上一个项目 | Insert |
| `Ctrl + n` | 选择下一个项目 | Insert |
| `Ctrl + p` | 选择上一个项目 | Insert |
| `Tab` | 选择下一个项目 | Insert |
| `Shift + Tab` | 选择上一个项目 | Insert |
| `Ctrl + u` | 文档向上滚动 | Insert |
| `Ctrl + d` | 文档向下滚动 | Insert |
| `Enter` | 接受选中项目 | Insert |
| `Shift + Enter` | 关闭补全并换行 | Insert |
| `Alt + /` | 显示/隐藏补全菜单 | Insert |
| `Alt + n` | 显示缓冲区补全 | Insert |
| `Alt + p` | 显示缓冲区补全 | Insert |

### 命令行模式补全
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Alt + j` | 选择下一个项目 | Command |
| `Alt + k` | 选择上一个项目 | Command |
| `Ctrl + n` | 选择下一个项目 | Command |
| `Ctrl + p` | 选择上一个项目 | Command |
| `Tab` | 选择下一个项目 | Command |
| `Shift + Tab` | 选择上一个项目 | Command |
| `Enter` | 接受选中项目 | Command |
| `Alt + /` | 显示/隐藏补全菜单 | Command |

## LSP 相关

### 基础 LSP 功能
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>d` | 显示诊断信息 | Normal |
| `<leader>gk` | 显示签名帮助 | Normal |
| `<leader>wa` | 添加工作区文件夹 | Normal |
| `<leader>wr` | 移除工作区文件夹 | Normal |
| `<leader>wl` | 列出工作区文件夹 | Normal |
| `<leader>rn` | 重命名符号 | Normal |
| `K` | 显示悬停信息（或在 UFO 中预览折叠） | Normal |

### Trouble.nvim (诊断管理)
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `Alt + j` | 跳转到下一个诊断 | Normal |
| `Alt + k` | 跳转到上一个诊断 | Normal |
| `<leader>gd` | 切换缓冲区诊断 | Normal |
| `<leader>gs` | 切换符号列表 | Normal |
| `<leader>gl` | 切换 LSP 定义/引用 | Normal |
| `<leader>gL` | 切换位置列表 | Normal |
| `<leader>gq` | 切换快速修复列表 | Normal |

## 代码折叠 (nvim-ufo)

### 折叠控制
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `K` | 预览折叠行 | Normal |
| `zM` | 关闭所有折叠 | Normal |
| `zR` | 打开所有折叠 | Normal |
| `zm` | 增加折叠级别 | Normal |
| `zr` | 减少折叠级别 | Normal |
| `zS` | 设置折叠级别 | Normal |

### 禁用的键位
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `zE` | 已禁用 | Normal |
| `zx` | 已禁用 | Normal |
| `zX` | 已禁用 | Normal |

## 搜索增强 (nvim-hlslens)

### 搜索导航
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `n` | 下一个匹配项（居中） | Normal |
| `N` | 上一个匹配项（居中） | Normal |
| `*` | 向下搜索当前单词 | Normal |
| `#` | 向上搜索当前单词 | Normal |
| `g*` | 向下搜索当前单词（部分匹配） | Normal |
| `g#` | 向上搜索当前单词（部分匹配） | Normal |
| `//` | 清除搜索高亮 | Normal |

## 会话管理 (auto-session)

### 会话操作
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>ps` | 恢复会话 | Normal |
| `<leader>pS` | 搜索会话 | Normal |
| `<leader>pD` | 删除会话 | Normal |

## Python 开发

### 虚拟环境
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `<leader>cv` | 选择虚拟环境 | Normal (Python 文件) |

## 工具类

### 启动时间分析
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `:StartupTime` | 显示启动时间分析 | Command |

### 按键显示
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `:ShowkeysToggle` | 切换按键显示 | Command |

## 禁用的默认键位

### mini.surround
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `s` | 已禁用（由 mini.surround 接管） | Normal, Visual, Operator |

### LSP Code Actions
| 快捷键 | 作用 | 模式 |
|--------|------|------|
| `grn` | 已禁用 | Normal |
| `gra` | 已禁用 | Normal |
| `grr` | 已禁用 | Normal |
| `gri` | 已禁用 | Normal |

## 使用提示

1. **Leader 键**：`<leader>` 对应空格键
2. **模式说明**：
   - `Normal`：普通模式
   - `Insert`：插入模式
   - `Visual`：可视化模式
   - `Operator`：操作符模式
   - `Command`：命令行模式
   - `Terminal`：终端模式

3. **Alt 键**：在某些键盘布局中可能需要使用 `Meta` 键
4. **文件类型相关**：部分快捷键仅在特定文件类型中可用

## 快捷键组织逻辑

这个快捷键体系遵循以下组织原则：

1. **`<leader>` 开头**：主要功能入口
2. **`s` 系列**：搜索和选择功能
3. **`t` 系列**：切换功能
4. **`g` 系列**：Git 相关功能
5. **`c` 系列**：代码相关功能
6. **`p` 系列**：项目和会话功能
7. **`Alt` 组合**：快速访问常用功能
8. **`Ctrl` 组合**：传统 Vim 功能扩展

这个设计使得快捷键既易于记忆，又能高效使用。