#!/usr/bin/env bash
#
# auto-archive.sh - 文件/目录自动归档脚本
# 根据文件或目录的创建日期，将其移动到对应的日期文件夹中
# 作者：GitHub Copilot
# 日期：2025-12-26
#

set -euo pipefail

# ============================================================================
# 辅助函数
# ============================================================================

# 日志输出函数（带时间戳）
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 错误输出函数
error() {
    echo "[ERROR] $*" >&2
}

# 获取文件创建时间（兼容 Linux/macOS）
# 参数: $1 = 文件路径
# 返回: YYYY-MM-DD 格式的日期
# 注意: 如果文件系统不支持创建时间，则回退到修改时间
get_file_ctime() {
    local file="$1"
    local ctime_date
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS (BSD stat) - 使用 %SB 获取 Birth time（创建时间）
        ctime_date=$(stat -f "%SB" -t "%Y-%m-%d" "$file")
    else
        # Linux (GNU stat) - 使用 %W 获取 Birth time（创建时间，epoch 格式）
        local birth_epoch
        birth_epoch=$(stat -c "%W" "$file" 2>/dev/null)
        
        # 如果返回 0 或空，说明文件系统不支持创建时间，回退到修改时间
        if [[ -z "$birth_epoch" || "$birth_epoch" == "0" || "$birth_epoch" == "-" ]]; then
            # 回退到修改时间
            ctime_date=$(stat -c "%y" "$file" | cut -d' ' -f1)
        else
            # 将 epoch 时间戳转换为 YYYY-MM-DD 格式
            ctime_date=$(date -d "@$birth_epoch" "+%Y-%m-%d")
        fi
    fi
    
    echo "$ctime_date"
}

# 获取当前时间戳（用于重名文件后缀）
get_timestamp() {
    date '+%H%M%S'
}

# ============================================================================
# 参数校验
# ============================================================================

# 检查是否提供了目标目录参数
if [[ $# -lt 1 ]]; then
    error "用法: $0 <目标目录>"
    error "示例: $0 ~/Downloads"
    exit 1
fi

TARGET_DIR="$1"

# 检查目标目录是否存在
if [[ ! -d "$TARGET_DIR" ]]; then
    error "目录不存在: $TARGET_DIR"
    exit 1
fi

# 转换为绝对路径（兼容处理）
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# ============================================================================
# 安全开关：检查配置文件
# ============================================================================

CONFIG_DIR="$TARGET_DIR/.auto-archive"
CONFIG_FILE="$CONFIG_DIR/config"

# 如果配置文件不存在，静默退出（目录未启用归档功能）
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# 读取配置文件中的变量
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# 设置归档目标根目录（如果配置中未定义，则默认在 .auto-archive 目录内）
DEST_ROOT="${DEST_ROOT:-$CONFIG_DIR}"

# 确保 DEST_ROOT 是绝对路径
if [[ "$DEST_ROOT" != /* ]]; then
    # 如果是相对路径，则相对于 CONFIG_DIR（配置目录）
    DEST_ROOT="$CONFIG_DIR/$DEST_ROOT"
fi

# ============================================================================
# 获取脚本自身的绝对路径（用于排除）
# ============================================================================

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# ============================================================================
# 获取需要排除的目录的 basename
# ============================================================================

CONFIG_DIR_NAME=".auto-archive"
# 获取 DEST_ROOT 相对于 TARGET_DIR 的目录名（如果 DEST_ROOT 在 TARGET_DIR 下）
DEST_ROOT_BASENAME="$(basename "$DEST_ROOT")"

# ============================================================================
# 主逻辑：遍历并归档文件
# ============================================================================

# 统计移动的文件数量
moved_count=0

# 遍历 TARGET_DIR 下的第一层内容
for item in "$TARGET_DIR"/*; do
    # 检查 glob 是否匹配到任何内容（防止空目录报错）
    [[ -e "$item" ]] || continue
    
    # 获取文件/文件夹名称
    item_name="$(basename "$item")"
    
    # ---------- 排除规则 ----------
    
    # 1. 跳过隐藏文件/文件夹（以 . 开头，包括 .auto-archive 配置目录）
    if [[ "$item_name" == .* ]]; then
        continue
    fi
    
    # 2. 跳过归档目标目录（如果在 TARGET_DIR 下）
    if [[ "$item_name" == "$DEST_ROOT_BASENAME" ]]; then
        continue
    fi
    
    # 5. 跳过脚本自身（如果脚本放在目标目录下）
    if [[ "$(cd "$(dirname "$item")" && pwd)/$(basename "$item")" == "$SCRIPT_PATH" ]]; then
        continue
    fi
    
    # ---------- 获取文件/目录创建日期 ----------
    
    file_date="$(get_file_ctime "$item")"
    
    # 验证日期格式（YYYY-MM-DD）
    if [[ ! "$file_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        error "无法获取文件日期: $item"
        continue
    fi
    
    # ---------- 确定目标目录并创建 ----------
    
    dest_dir="$DEST_ROOT/$file_date"
    
    # 如果日期目录不存在则创建
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi
    
    # ---------- 处理重名文件 ----------
    
    dest_file="$dest_dir/$item_name"
    
    # 如果目标文件已存在，添加时间戳后缀
    if [[ -e "$dest_file" ]]; then
        # 分离文件名和扩展名
        filename="${item_name%.*}"
        extension="${item_name##*.}"
        
        # 如果文件没有扩展名（filename == extension）
        if [[ "$filename" == "$extension" ]]; then
            extension=""
        fi
        
        # 生成带时间戳的新文件名
        timestamp="$(get_timestamp)"
        if [[ -n "$extension" ]]; then
            new_name="${filename}_${timestamp}.${extension}"
        else
            new_name="${filename}_${timestamp}"
        fi
        
        dest_file="$dest_dir/$new_name"
        
        # 极端情况：如果带时间戳的文件也存在，追加随机数
        while [[ -e "$dest_file" ]]; do
            random_suffix="$RANDOM"
            if [[ -n "$extension" ]]; then
                new_name="${filename}_${timestamp}_${random_suffix}.${extension}"
            else
                new_name="${filename}_${timestamp}_${random_suffix}"
            fi
            dest_file="$dest_dir/$new_name"
        done
        
        log "重名处理: $item_name -> $new_name"
    fi
    
    # ---------- 执行移动操作 ----------
    
    if mv "$item" "$dest_file"; then
        log "Moved: $item_name -> $file_date/"
        ((moved_count++)) || true
    else
        error "移动失败: $item"
    fi
done

# 如果有文件被移动，输出统计信息
if [[ $moved_count -gt 0 ]]; then
    log "归档完成: 共移动 $moved_count 个文件到 $DEST_ROOT"
fi

exit 0
