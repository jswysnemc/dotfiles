if status is-interactive
    set -g __fish_start_time_ms (date +%s%3N)
    set -g fish_greeting

    function __fish_startup_timer --on-event fish_prompt
        set -l saved_status $status

        if set -q __fish_start_time_ms
            set -l now_ms (date +%s%3N)
            set -l duration_ms (math "$now_ms - $__fish_start_time_ms")

            set -gx STARSHIP_STARTUP_TIME "$duration_ms"ms
            set -gx STARSHIP_SHOW_STARTUP true
            set -e __fish_start_time_ms
            functions -e __fish_startup_timer
        end

        return $saved_status
    end

    function __fish_clear_startup_timer --on-event fish_preexec
        set -e STARSHIP_SHOW_STARTUP
        functions -e __fish_clear_startup_timer
    end

    test -f "$HOME/.config/fish/zsh-habits.fish"; and source "$HOME/.config/fish/zsh-habits.fish"
    command -q starship; and starship init fish | source
end

# string match -q "$TERM_PROGRAM" "kiro" and . (kiro --locate-shell-integration-path fish)
