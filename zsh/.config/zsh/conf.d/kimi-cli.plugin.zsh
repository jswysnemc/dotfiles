# Fallback to kimi when a command is not found.

# Configure the prefix that marks commands for kimi fallback.
typeset -g __KIMI_CLI_PREFIX_CHAR
: "${__KIMI_CLI_PREFIX_CHAR:="✨"}"

typeset -g __KIMI_CLI_PREFIX
: "${__KIMI_CLI_PREFIX:="${__KIMI_CLI_PREFIX_CHAR} "}"

typeset -g __KIMI_CLI_PREFIX_ACTIVE=0
typeset -g __KIMI_CLI_WIDGETS_INSTALLED=0
typeset -g __KIMI_CLI_HAS_PREV_LINE_INIT=0
typeset -g __KIMI_CLI_HAS_PREV_LINE_PRE_REDRAW=0
typeset -g __KIMI_CLI_HAS_PREV_LINE_FINISH=0
typeset -gA __KIMI_CLI_GUARD_WIDGET_ALIASES=()
typeset -gA __KIMI_CLI_GUARD_WIDGETS_REGISTERED=()

# Preserve any previously defined handler so we can delegate if needed.
if (( $+functions[command_not_found_handler] )); then
  functions[__kimi_cli_original_command_not_found_handler]=$functions[command_not_found_handler]
fi

command_not_found_handler() {
  emulate -L zsh

  local missing_command="$1"
  local -a cmd_with_args=("$@")

  shift
  local -a remaining_args=("$@")

  # Nothing to do without a command name.
  if [[ -z "$missing_command" ]]; then
    if (( $+functions[__kimi_cli_original_command_not_found_handler] )); then
      __kimi_cli_original_command_not_found_handler "${cmd_with_args[@]}"
      return $?
    fi
    return 127
  fi

  local prefix_char="${__KIMI_CLI_PREFIX_CHAR:-✨}"

  local handled=false
  local -a effective_cmd=()

  if [[ "$missing_command" == "$prefix_char" ]]; then
    handled=true
    effective_cmd=("${remaining_args[@]}")
  elif [[ "$missing_command" == ${prefix_char}* ]]; then
    handled=true
    local stripped="${missing_command#$prefix_char}"
    if [[ -n "$stripped" ]]; then
      effective_cmd=("$stripped" "${remaining_args[@]}")
    else
      effective_cmd=("${remaining_args[@]}")
    fi
  fi

  if [[ "$handled" != true ]]; then
    if (( $+functions[__kimi_cli_original_command_not_found_handler] )); then
      __kimi_cli_original_command_not_found_handler "${cmd_with_args[@]}"
      return $?
    fi
    print -u2 "zsh: command not found: ${missing_command}"
    return 127
  fi

  if (( ${#effective_cmd[@]} == 0 )); then
    print -u2 "kimi-cli: nothing to run after '${prefix_char}'."
    return 127
  fi

  if ! command -v kimi >/dev/null 2>&1; then
    if (( $+functions[__kimi_cli_original_command_not_found_handler] )); then
      __kimi_cli_original_command_not_found_handler "${cmd_with_args[@]}"
      return $?
    fi
    print -u2 "kimi: command not found; unable to handle '${effective_cmd[1]}'."
    return 127
  fi

  local full_cmd
  full_cmd="$(printf '%q ' "${effective_cmd[@]}")"
  full_cmd="${full_cmd% }"

  kimi -c "$full_cmd"
  return $?
}

__kimi_cli_toggle_prefix() {
  emulate -L zsh

  local prefix="${__KIMI_CLI_PREFIX:-${__KIMI_CLI_PREFIX_CHAR} }"
  local prefix_len=${#prefix}

  if [[ "$BUFFER" == "$prefix"* ]]; then
    BUFFER="${BUFFER#$prefix}"
    if (( CURSOR > prefix_len )); then
      CURSOR=$(( CURSOR - prefix_len ))
    else
      CURSOR=0
    fi
    __KIMI_CLI_PREFIX_ACTIVE=0
  else
    BUFFER="${prefix}${BUFFER}"
    CURSOR=$(( CURSOR + prefix_len ))
    __KIMI_CLI_PREFIX_ACTIVE=1
  fi
}

__kimi_cli_line_init() {
  emulate -L zsh

  # Add prefix at the start of a new line if prefix mode is active
  if (( __KIMI_CLI_PREFIX_ACTIVE )); then
    local prefix="${__KIMI_CLI_PREFIX:-${__KIMI_CLI_PREFIX_CHAR} }"
    BUFFER="${prefix}"
    CURSOR=${#prefix}
  fi

  if (( __KIMI_CLI_HAS_PREV_LINE_INIT )); then
    zle __kimi_cli_prev_line_init 2>/dev/null
  fi
}

__kimi_cli_line_pre_redraw() {
  emulate -L zsh

  if (( __KIMI_CLI_PREFIX_ACTIVE )); then
    local prefix="${__KIMI_CLI_PREFIX:-${__KIMI_CLI_PREFIX_CHAR} }"
    local prefix_len=${#prefix}

    if (( CURSOR < prefix_len )); then
      CURSOR=$prefix_len
    fi

    local buffer_len=${#BUFFER}
    if (( CURSOR > buffer_len )); then
      CURSOR=$buffer_len
    fi
  fi

  if (( __KIMI_CLI_HAS_PREV_LINE_PRE_REDRAW )); then
    zle __kimi_cli_prev_line_pre_redraw 2>/dev/null
  fi
}

__kimi_cli_line_finish() {
  emulate -L zsh

  if (( __KIMI_CLI_HAS_PREV_LINE_FINISH )); then
    zle __kimi_cli_prev_line_finish 2>/dev/null
  fi
}

__kimi_cli_guard_backward_action() {
  emulate -L zsh

  if (( ! __KIMI_CLI_PREFIX_ACTIVE )); then
    __kimi_cli_call_guarded_original
    return
  fi

  local prefix="${__KIMI_CLI_PREFIX:-${__KIMI_CLI_PREFIX_CHAR} }"
  local prefix_len=${#prefix}

  if [[ "$BUFFER" == "$prefix"* ]] && (( CURSOR <= prefix_len )); then
    zle beep 2>/dev/null
    return
  fi

  __kimi_cli_call_guarded_original
}

__kimi_cli_call_guarded_original() {
  emulate -L zsh

  local saved_info="${__KIMI_CLI_GUARD_WIDGET_ALIASES[$WIDGET]-}"

  # Always try the built-in widget first if it exists.
  # This avoids calling wrapped versions from other plugins.
  if (( ${+widgets[.${WIDGET}]} )); then
    zle ".${WIDGET}"
    return
  fi

  # If no built-in exists and we saved a user widget, try calling it.
  if [[ -n "$saved_info" && "$saved_info" == user:* ]]; then
    local func_name="${saved_info#user:}"
    if (( ${+functions[$func_name]} )); then
      "$func_name"
      return
    fi
  fi
}

__kimi_cli_register_guard_widget() {
  emulate -L zsh

  local widget="$1"

  # Check if we've already registered this widget.
  if [[ -n "${__KIMI_CLI_GUARD_WIDGETS_REGISTERED[$widget]}" ]]; then
    return 0
  fi

  # Check if widget exists.
  if (( ! ${+widgets[$widget]} )); then
    return 1
  fi

  # Save the current widget type (not the function itself).
  local current_widget="${widgets[$widget]}"

  if [[ "$current_widget" == user:* ]]; then
    # Save the function name for later direct invocation.
    __KIMI_CLI_GUARD_WIDGET_ALIASES[$widget]="$current_widget"
  elif [[ "$current_widget" == builtin ]]; then
    __KIMI_CLI_GUARD_WIDGET_ALIASES[$widget]="builtin"
  elif [[ "$current_widget" == completion:* ]]; then
    __KIMI_CLI_GUARD_WIDGET_ALIASES[$widget]="$current_widget"
  fi

  # Mark this widget as registered.
  __KIMI_CLI_GUARD_WIDGETS_REGISTERED[$widget]=1

  # Now wrap the widget with our guard.
  zle -N "$widget" __kimi_cli_guard_backward_action
}

if [[ -o interactive ]]; then
  zle -N __kimi_cli_toggle_prefix

  local -a __kimi_cli_keymaps=("emacs" "viins")
  local keymap
  for keymap in "${__kimi_cli_keymaps[@]}"; do
    bindkey -M "$keymap" '^X' __kimi_cli_toggle_prefix 2>/dev/null
  done
  unset keymap __kimi_cli_keymaps

  if (( ! __KIMI_CLI_WIDGETS_INSTALLED )); then
    # Prevent re-wrapping if already installed.
    if [[ "${widgets[zle-line-init]}" != "user:__kimi_cli_line_init" ]]; then
      if zle -A zle-line-init __kimi_cli_prev_line_init 2>/dev/null; then
        __KIMI_CLI_HAS_PREV_LINE_INIT=1
      fi
      zle -N zle-line-init __kimi_cli_line_init
    fi

    if [[ "${widgets[zle-line-pre-redraw]}" != "user:__kimi_cli_line_pre_redraw" ]]; then
      if zle -A zle-line-pre-redraw __kimi_cli_prev_line_pre_redraw 2>/dev/null; then
        __KIMI_CLI_HAS_PREV_LINE_PRE_REDRAW=1
      fi
      zle -N zle-line-pre-redraw __kimi_cli_line_pre_redraw
    fi

    if [[ "${widgets[zle-line-finish]}" != "user:__kimi_cli_line_finish" ]]; then
      if zle -A zle-line-finish __kimi_cli_prev_line_finish 2>/dev/null; then
        __KIMI_CLI_HAS_PREV_LINE_FINISH=1
      fi
      zle -N zle-line-finish __kimi_cli_line_finish
    fi

    # Register guard widgets - these may already be wrapped by other plugins.
    __kimi_cli_register_guard_widget backward-delete-char
    __kimi_cli_register_guard_widget backward-kill-word
    __kimi_cli_register_guard_widget vi-backward-delete-char
    __kimi_cli_register_guard_widget vi-backward-kill-word

    __KIMI_CLI_WIDGETS_INSTALLED=1
  fi
fi
