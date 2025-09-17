# 指定chcp 为 65001 urf-8 字符编码
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 加载 PSReadLine 模块增强体验
#Import-Module -Name PSReadLine -RequiredVersion 2.3.6 -Force
Import-Module -Name PSReadLine

#Import-Module PSCompletions

# 使用vi 模式
Set-PSReadlineOption -EditMode Vi
Set-PSReadlineOption -ViModeIndicator Cursor

# 以下配置无效
#Set-PSReadLineOption -ChordTimeoutMilliseconds 150
#Set-PSReadLineKeyHandler -Chord 'j','k' -Function ViCommandMode -ViMode Insert

#Tab键会出现自动补全菜单
Import-Module PSFzf
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete


# Set-PSReadLineOption -PredictionSource HistoryAndPlugin
if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 2) {
#     仅在 PowerShell 7.2 及以上版本中执行这里的代码
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
}

#Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -BellStyle None


if(Get-Module -ListAvailable -Name "PSFzf" -ErrorAction Stop) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}


# 引入 CARAPACE.exe 增强补全体验
#$env:CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional

# 检查 PowerShell 版本，仅在 v7 或更高版本中设置 ANSI 颜色
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Set-PSReadLineOption -Colors @{ "Selection" = "`e[7m" }
}else{
    # Windows PowerShell 5.1 使用固定的颜色来模拟反显效果
	#Set-PSReadLineOption -Colors White
}

# 检查 carapace 命令是否存在，避免路径问题导致报错
if (Get-Command carapace -ErrorAction SilentlyContinue) {
    carapace _carapace | Out-String | Invoke-Expression
}


# 使用 c 命令开启 交互式 cd
function c {
  zoxide query -i | Set-Location
}

# 设置别名
Set-Alias -Name vim -Value nvim
Set-Alias -Name v -Value nvim


# 使用解释命令 api 
function explain {
    $cmd = $args -join "+"
    Invoke-RestMethod -Uri "https://cheat.sh/$cmd" -UseBasicParsing
}


# --- Zoxide Configuration ---

# 跳转前打印目标路径
$env:_ZO_ECHO = "0"

# 排除不想被 zoxide 记录的目录
# 例如：下载目录、所有 .git 和 node_modules 目录、Windows 系统目录
$env:_ZO_EXCLUDE_DIRS = "\*\.git\*;\*\node_modules\*;\C:\Windows\*"


# 定义重复的路径前缀变量
$home_prefix = "D:\Users\snemc"

# zoxide 相关设置
$env:_ZO_FZF_OPTS = '--height 40% --reverse --border'
$env:_ZO_DATA_DIR = "$home_prefix\.local\share\zoxide\dirs"

# XDG Base Directory Specification
$env:XDG_CONFIG_HOME = "$home_prefix\.config"
$env:XDG_DATA_HOME = "$home_prefix\.local\share"
$env:XDG_CACHE_HOME = "$home_prefix\.cache"
$env:XDG_STATE_HOME = "$home_prefix\.local\state"

# 旧版的 XDG 变量（如果需要兼容）
$env:XDG_CONFIG_DIR = "$home_prefix\.config"
$env:XDG_DATA_DIR = "$home_prefix\.local\share"
$env:XDG_CACHE_DIR = "$home_prefix\.cache"
$env:XDG_STATE_DIR = "$home_prefix\.local\state"
$env:XDG_RUNTIME_DIR = "$home_prefix\.local\runtime"

# 指定 winget 默认安装位置
$env:XDG_APP_DIR = "$home_prefix\.local\share"

# 配置 starship 使用自定义 prompt
 $ENV:STARSHIP_CONFIG = "D:\Users\snemc\.config\starship\starship.toml"
 Invoke-Expression (&starship init powershell)

# 尝试放弃staisihp，效果不理想
#function prompt{
#	"    $pwd`n➜ "
#}
#  snemc  D:\Users\snemc\Desktop
#➜

# --- End of Zoxide Configuration ---
# 这一行必须在环境变量设置之后
Invoke-Expression (& { (zoxide.exe init powershell --cmd z | Out-String) })
