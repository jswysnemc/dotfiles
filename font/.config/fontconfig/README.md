# Fontconfig 配置

这是用户级的 fontconfig 配置，用于控制 Linux 系统中的字体渲染和替换规则。

## 目录结构

```
~/.config/fontconfig/
├── fonts.conf           # 主配置文件
├── fonts.conf.back      # 备份配置文件
└── conf.d/              # 模块化配置目录
    ├── 50-generic.conf  # 通用字体配置
    ├── 51-lang.conf     # 语言特定字体配置
    └── 52-replace.conf  # 字体替换规则
```

## 配置文件说明

### 1. fonts.conf

主配置文件，包含以下主要设置：

- **伪斜体生成**：为没有斜体字重的字体自动生成斜体
- **粗体模拟**：为没有粗体字重的字体模拟粗体效果
- **子像素渲染**：启用 RGB 子像素渲染，提高 LCD 屏幕显示效果
- **字体目录**：添加 `~/.local/share/fonts` 为用户字体目录

### 2. conf.d/50-generic.conf

通用字体渲染设置：

- 抗锯齿：启用
- 提示：轻微提示
- 子像素渲染：RGB 顺序
- 微调：轻微提示样式
- 自动提示：启用
- 提示样式：hintslight
- 子像素几何：RGB
- 抗锯齿方法：rgba

### 3. conf.d/51-lang.conf

语言特定的字体配置：

- **中文**：优先使用 Noto Sans CJK SC
- **日文**：优先使用 Noto Sans CJK JP
- **韩文**：优先使用 Noto Sans CJK KR
- **英文**：优先使用 Inter 或 Noto Sans
- **等宽字体**：优先使用 JetBrainsMono Nerd Font

### 4. conf.d/52-replace.conf

字体替换规则：

| 原始字体 | 替换为 |
|---------|--------|
| Arial | Noto Sans |
| Helvetica | Noto Sans |
| Times New Roman | Noto Serif |
| Courier New | JetBrainsMono Nerd Font |
| SimSun | Noto Sans CJK SC |
| Microsoft YaHei | Noto Sans CJK SC |
| 宋体 | Noto Serif CJK SC |
| 黑体 | Noto Sans CJK SC |
| 微软雅黑 | Noto Sans CJK SC |
| Meiryo | Noto Sans CJK JP |
| MS Gothic | Noto Sans CJK JP |

## 使用说明

1. **安装字体**：
   - 将字体文件放入 `~/.local/share/fonts/` 目录
   - 运行 `fc-cache -fv` 更新字体缓存

2. **应用配置**：
   修改配置后，重启应用程序或运行 `fc-cache -r` 使更改生效

3. **验证配置**：
   - 使用 `fc-match` 命令测试字体匹配
   - 例如：`fc-match -s sans` 查看无衬线字体匹配顺序

## 依赖字体

- Noto Sans CJK SC/JP/KR
- Inter
- JetBrainsMono Nerd Font
- Noto Sans/Serif
- Emoji 字体（Noto Color Emoji 或 Twitter Color Emoji）

## 故障排除

如果遇到字体显示问题：

1. 检查字体是否正确安装：`fc-list | grep "字体名称"`
2. 清除字体缓存：`rm -rf ~/.cache/fontconfig` 然后 `fc-cache -r`
3. 检查配置语法：`fc-validate`
4. 查看实际应用的字体：`fc-match -v sans`

## 参考

- [Fontconfig 文档](https://www.freedesktop.org/software/fontconfig/fontconfig-user.html)
- [Arch Linux Font Configuration](https://wiki.archlinux.org/title/Font_configuration)
