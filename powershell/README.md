# PowerShell 配置

PowerShell 配置文件，用于跨平台的命令行 shell。

## 目录结构

```
~/.config/powershell/
└── 01_base.ps1    # 基础配置
```

## 配置说明

此配置包含 PowerShell 的基础设置，包括：
- 环境变量配置
- 别名定义
- 函数定义
- 模块导入
- 提示符配置

## Arch Linux 依赖

| 包名 | 用途 |
|------|------|
| `powershell` | PowerShell Core |
| `dotnet-runtime` | .NET 运行时（某些模块需要） |
| `zoxide` | 智能目录跳转 |
| `fzf` | 模糊查找工具 |
| `starship` | 提示符 |
| `psfzf` | PowerShell Fzf 集成 |
| `carapace` | 命令补全工具 |

## 配置说明

此配置包含 PowerShell 的基础设置，包括：
- **环境变量配置**：XDG 目录、Zoxide 配置、Starship 配置
- **别名定义**：`vim`/`v` 指向 `nvim`
- **函数定义**：`c` 函数（交互式 cd）、`explain` 函数（命令解释）
- **模块导入**：PSReadLine、PSFzf、Carapace
- **提示符配置**：使用 Starship 提示符
- **Vi 模式**：使用 Vi 编辑模式

## 安装

1. 使用 Stow 安装配置：
   ```bash
   cd ~/.dotfiles
   stow powershell
   ```

2. 安装 PowerShell：
   ```bash
   sudo pacman -S powershell
   ```

3. 配置文件会自动在 PowerShell 启动时加载。

## 使用

启动 PowerShell：
```bash
pwsh
```

配置文件位于 `~/.config/powershell/01_base.ps1`，会在启动时自动加载。

## 许可

MIT License
