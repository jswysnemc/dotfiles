# -----------------------------------------------------------------------------
# EZA ALIASES - A modern replacement for 'ls'
#
# The philosophy is twofold:
# 1. 'ls', 'l', 'la': Script-friendly, clean output for piping to awk, grep, etc.
# 2. 'll', 'lls', etc.: Human-friendly, rich output for interactive viewing.
# -----------------------------------------------------------------------------

# --- Tier 1: Script-Friendly Aliases (Machine Readable) ---
# These aliases produce clean output WITHOUT headers or icons.
# They are safe to use in scripts and pipes, e.g., `l | awk '{print $9}'`

# 'ls' is the base command. Add --git for context, but keep it clean.
# --group-directories-first (-g) is great for readability.
alias ls='eza --git -g'

# 'l' is the classic 'ls -l'. This is the most important alias for scripting.
alias l='eza -l --git -g'

# 'la' shows hidden ("all") files.
alias la='eza -la --git -g'


# --- Tier 2: Human-Friendly Aliases (Interactive Use) ---
# These aliases are for you to use directly in the terminal.
# They include icons and headers for a rich visual experience.
# DO NOT use these in scripts.

# 'lls' (ls short) shows a grid view with icons.
alias lls='eza --icons --git -g'
alias lla='eza --icons --git -g -al'

# 'll' is your main "power-ls". Long format, all files, with icons and header.
alias ll='eza -la --header --icons --git -g'

# 'llt' sorts the pretty list by modification time, newest first.
alias llt='eza -la --header --icons --git -g -s modified'

# 'llS' sorts the pretty list by size, largest first.
alias llS='eza -la --header --icons --git -g -s size'


# --- Tier 3: Tree Aliases (Always for Humans) ---
# The 'tree' command is almost never used for scripting,
# so we keep it rich with icons by default.

alias tree2='eza --tree --level=2 --icons -g'
