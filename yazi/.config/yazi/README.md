# Yazi 配置

这套配置面向高频终端文件管理：三栏布局、Kitty 图片预览、Git 状态、模糊跳转、内容搜索、压缩、预览缩放和 Starship 头部信息。

## 文件结构

```text
~/.config/yazi/
├── yazi.toml
├── keymap.toml
├── theme.toml
├── init.lua
├── package.toml
└── plugins/
```

## 依赖

```bash
paru -S yazi fd ripgrep fzf zoxide ffmpegthumbnailer poppler jq imagemagick ffmpeg mpv p7zip
paru -S exiftool mediainfo starship
```

`fd` 用于文件名搜索，`ripgrep` 用于内容搜索，`fzf` 用于模糊跳转，`zoxide` 用于常用目录跳转。`mpv`、`exiftool`、`mediainfo` 负责打开器和元信息查看。

## 插件

```bash
ya pkg install
```

当前插件由 `package.toml` 管理：

- `smart-enter`：使用 `l` 进入目录或打开文件。
- `smart-filter`：使用 `F` 进行连续智能过滤。
- `git`：显示 Git 状态，可通过 `mg` 切换到 Git 行模式。
- `zoom`：使用 `+` 和 `-` 调整预览大小。
- `compress`：使用 `ca` 前缀压缩文件。
- `full-border`：为三栏界面绘制完整边框。
- `starship`：渲染头部路径信息。

## 高频快捷键

| 快捷键 | 功能 |
| --- | --- |
| `h` / `l` | 返回上级 / 进入或打开 |
| `j` / `k` | 下一个 / 上一个 |
| `H` / `L` | 历史后退 / 前进 |
| `.` | 切换隐藏文件 |
| `s` | 按文件名搜索 |
| `S` | 按内容搜索 |
| `F` | 智能过滤 |
| `z` | 通过 fzf 跳转 |
| `Z` | 通过 zoxide 跳转 |
| `cc` | 复制完整路径 |
| `cd` | 复制目录路径 |
| `cf` | 复制文件名 |
| `cn` | 复制不含扩展名的文件名 |
| `+` / `-` | 放大 / 缩小预览 |
| `mg` | 显示 Git 行模式 |

## 压缩快捷键

| 快捷键 | 功能 |
| --- | --- |
| `caa` | 压缩选中的文件 |
| `cap` | 压缩并设置密码 |
| `cah` | 压缩并加密文件头 |
| `cal` | 压缩并设置压缩级别 |
| `cau` | 压缩并启用完整选项 |

## 排序与行模式

| 快捷键 | 功能 |
| --- | --- |
| `,n` / `,N` | 自然顺序 / 倒序 |
| `,m` | 按修改时间排序 |
| `,s` | 按文件大小排序 |
| `,e` | 按扩展名排序 |
| `,a` | 按字母顺序排序 |
| `ms` | 显示大小 |
| `mp` | 显示权限 |
| `mm` | 显示修改时间 |
| `mb` | 显示创建时间 |
| `mo` | 显示所有者 |
| `mn` | 关闭行模式 |

## 快速跳转

| 快捷键 | 目录 |
| --- | --- |
| `gh` | `~` |
| `gc` | `~/.config` |
| `gd` | `~/Downloads` |
| `gp` | `~/Projects` |
| `g.` | `~/.dotfiles` |
| `g<Space>` | 交互式选择目录 |
