# shellcheck shell=bash

# Mark step as done
mark_done() {
    echo "$1" >> "$STATE_FILE"
}

# Check if step is done
is_done() {
    [[ -f "$STATE_FILE" ]] && grep -q "^$1$" "$STATE_FILE"
}
