# 字体配置

此目录包含系统字体配置文件，用于管理系统中安装的字体。

## 目录结构

```
~/.config/fontconfig/
└── fonts.conf    # 字体配置文件
```

## 配置说明

配置文件使用 Fontconfig 语法，用于：
- 指定字体搜索路径
- 设置字体替换规则
- 配置字体别名
- 设置默认字体

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `fontconfig` | 字体配置系统 |

### 推荐字体

| 包名 | 用途 |
|------|------|
| `noto-fonts-cjk` | Noto CJK 字体（中文、日文、韩文） |
| `noto-fonts` | Noto 字体系列（基础） |
| `noto-fonts-emoji` | Noto Emoji 字体 |
| `jetbrains-mono-nerd-font` | JetBrains Mono Nerd Font（等宽） |
| `maple-mono-nf` | Maple Mono Nerd Font（等宽） |
| `nerd-fonts` | Nerd Font 集合 |

### 可选字体

| 包名 | 用途 |
|------|------|
| `adobe-source-han-sans-cn-fonts` | Source Han Sans CN（思源黑体） |
| `adobe-source-han-serif-cn-fonts` | Source Han Serif CN（思源宋体） |
| `wqy-zenhei` | 文泉驿正黑 |
| `wqy-microhei` | 文泉驿微米黑 |

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow font
   ```

2. 安装字体：
   ```bash
   # 基础字体
   sudo pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji

   # Nerd Font
   sudo pacman -S jetbrains-mono-nerd-font

   # 可选字体
   yay -S maple-mono-nf
   ```

3. 刷新字体缓存：
   ```bash
   fc-cache -fv
   ```

## 配置文件

配置文件 `fonts.conf` 包含：
- 字体目录配置
- 字体匹配规则
- 字体替换规则

## 使用

配置后，应用程序会自动使用 Fontconfig 配置的字体。

查看可用字体：
```bash
fc-list : family
```

测试字体渲染：
```bash
fc-match "Noto Sans CJK"
```

## 许可

MIT License
