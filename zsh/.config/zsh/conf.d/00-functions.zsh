
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


# 清除文件内容并用编辑器打开
cv() {
  if [[ -z "$1" ]]; then
    echo "Usage: cv "
    return 1
  fi

  # 检查文件是否存在，如果不存在则创建
  if [[ ! -f "$1" ]]; then
    touch "$1"
  fi

  # 清空文件内容
  echo '' > "$1"

  # 使用 $EDITOR 打开文件
  ${EDITOR:-vim} "$1"
}
