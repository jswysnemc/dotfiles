
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
