# 优化性能

skip_global_compinit=1
DISABLE_MAGIC_FUNCTIONS=true
ZSH_DISABLE_COMPFIX=true

# 补全系统设置
COMPLETION_WAITING_DOTS="true"
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# 早加载 vi (zsh-vi-mode 必须同步加载，需要此变量)
export ZVM_INIT_MODE=sourcing


# 定义zi 相关目录
typeset -Ag ZI
typeset -gx ZI[HOME_DIR]="${HOME}/.local/share/zi"
typeset -gx ZI[BIN_DIR]="${ZI[HOME_DIR]}/bin"

# 自动下载 zi 插件
if [ ! -f "${ZI[BIN_DIR]}/zi.zsh" ] ;
then
    command git clone https://github.com/z-shell/zi.git "$ZI[BIN_DIR]"
fi


# 加载zi 插件
source "${ZI[BIN_DIR]}/zi.zsh"

# 指定 补全缓存的路径
local zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
zinit ice compinit-opts'-d "${zsh_cache_dir}/zcompdump"'

# 启用补全
#autoload -Uz compinit
#compinit

# 加载zi 相关补全
#autoload -Uz _zi
#(( ${+_comps} )) && _comps[zi]=_zi

export EDITOR=nvim
autoload -z edit-command-line
zle -N edit-command-line
bindkey '^v' edit-command-line

source $HOME/.config/zsh/plugins.zsh
