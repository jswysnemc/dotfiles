#!/bin/bash

#
# aggregate_dotfiles.sh
#
# 用法:
#   ./aggregate_dotfiles.sh <清单文件>
#
# 描述:
#   此脚本根据清单文件将指定的配置文件或目录聚合到 ~/.dotfiles 目录中。
#
# 清单文件格式:
#   - 每一行应为: 目标名称:源路径
#     - '目标名称' 是将在 ~/.dotfiles 中创建的顶级目录的名称。
#     - '源路径' 是要复制的原始文件或目录的路径。
#   - 文件中可以用一个空行分隔两部分。
#   - 空行之后的所有条目在复制时将使用 'sudo'，用于需要提升权限的文件。
#
# 示例清单文件 (manifest.txt):
#   starship:~/.config/starship/starship.toml
#   tmux:~/.config/tmux
#   zsh:~/.config/zsh
#
#   system:/etc/nsswitch.conf
#

set -euo pipefail

# ------------------------------------------------------------------------------
# 主函数
# ------------------------------------------------------------------------------
main() {
  # 检查是否提供了清单文件
  if [ -z "$1" ]; then
    echo "错误: 未提供清单文件。" >&2
    echo "用法: $0 <清单文件>" >&2
    exit 1
  fi

  local manifest_file="$1"
  local dotfiles_dir="$HOME/.dotfiles"

  # 检查清单文件是否存在
  if [ ! -f "$manifest_file" ]; then
    echo "错误: 清单文件 '$manifest_file' 未找到。" >&2
    exit 1
  fi

  # 确保 ~/.dotfiles 目录存在
  mkdir -p "$dotfiles_dir"

  # 逐行处理清单文件
  local needs_sudo=false
  while IFS= read -r line || [[ -n "$line" ]]; do
    # 跳过注释行和纯空格行
    if [[ "$line" =~ ^\s*# ]] || [[ "$line" =~ ^\s*$ ]]; then
      # 如果遇到空行，则切换到 sudo 模式
      if [[ "$line" =~ ^\s*$ ]]; then
        if ! $needs_sudo; then
          echo "--------------------------------------------------"
          echo "切换到需要SUDO权限的条目..."
          echo "--------------------------------------------------"
          needs_sudo=true
        fi
      fi
      continue
    fi

    process_line "$line" "$dotfiles_dir" "$needs_sudo"

  done < "$manifest_file"

  echo
  echo "✅ 配置文件聚合完成。"
}

# ------------------------------------------------------------------------------
# 处理清单中的单行
# ------------------------------------------------------------------------------
process_line() {
  local line="$1"
  local dotfiles_dir="$2"
  local use_sudo="$3"

  # 解析行 -> 'dest_name:source_path'
  if ! [[ "$line" =~ (.+):(.+) ]]; then
    echo "⚠️  格式无效，跳过此行: '$line'"
    return
  fi

  local dest_name="${BASH_REMATCH[1]}"
  local source_path="${BASH_REMATCH[2]}"

  # 展开波浪号 ~
  local expanded_source="${source_path/#\~/$HOME}"

  # 定义命令
  local cmd_prefix=""
  if [ "$use_sudo" = true ]; then
    cmd_prefix="sudo"
  fi

  # 检查源文件或目录是否存在
  if ! $cmd_prefix [ -e "$expanded_source" ]; then
    echo "❌ 源不存在，跳过: '$expanded_source'"
    return
  fi

  # 移除路径中的 HOME 或根目录前缀以创建相对路径
  local relative_path
  if [[ "$expanded_source" == "$HOME"* ]]; then
    relative_path="${expanded_source#$HOME/}"
  else
    relative_path="${expanded_source#/}"
  fi

  # 获取源路径的父目录
  local source_parent_dir
  source_parent_dir=$(dirname "$relative_path")

  # 构建最终的目标目录
  local dest_dir="$dotfiles_dir/$dest_name/$source_parent_dir"

  # 创建目标目录结构
  echo "📁 正在处理: $source_path"
  if ! $cmd_prefix mkdir -p "$dest_dir"; then
    echo "❌ 无法创建目录 '$dest_dir'，跳过。"
    return
  fi

  # 复制文件或目录
  if ! $cmd_prefix cp -r "$expanded_source" "$dest_dir/"; then
    echo "❌ 无法复制 '$expanded_source'，跳过。"
    return
  fi
}

# ------------------------------------------------------------------------------
# 脚本入口
# ------------------------------------------------------------------------------
main "$@"
