_KEYS_DIR=$HOME/.ssh/keys


export_from_file() {
    local var_name="$1"
    local file_path="$2"
    local fallback_value="${3:-""}"
    local content="$fallback_value"

    if [ -r "$file_path" ]; then
        content=$(< "$file_path")
    fi

    declare -x "$var_name=$content"
}



export_from_file "ANTHROPIC_BASE_URL" "$_KEYS_DIR/anthropic.url"
export_from_file "ANTHROPIC_API_KEY" "$_KEYS_DIR/anthropic.key"
export_from_file "OPENROUTER_API_KEY" "/home/snemc/.ssh/keys/openrouter.key"
export ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_API_KEY

# deepseek/deepseek-chat-v3.1:free
