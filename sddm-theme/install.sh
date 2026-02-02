#!/bin/bash

# Lunar Glass SDDM Theme Installer

set -e

THEME_NAME="lunar-glass"
THEME_DIR="/usr/share/sddm/themes/$THEME_NAME"
SDDM_CONF="/etc/sddm.conf"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Lunar Glass Theme Installer    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
echo

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 检查 SDDM 是否安装
if ! command -v sddm &> /dev/null; then
    echo -e "${RED}错误: 未检测到 SDDM，请先安装 SDDM${NC}"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 安装主题
echo -e "${YELLOW}正在安装主题...${NC}"

if [ -d "$THEME_DIR" ]; then
    echo -e "${YELLOW}检测到已存在的主题，正在备份...${NC}"
    mv "$THEME_DIR" "${THEME_DIR}.bak.$(date +%Y%m%d%H%M%S)"
fi

mkdir -p "$THEME_DIR"
cp -r "$SCRIPT_DIR"/*.qml "$THEME_DIR/"
cp -r "$SCRIPT_DIR"/*.conf "$THEME_DIR/"
cp -r "$SCRIPT_DIR"/*.desktop "$THEME_DIR/"
cp -r "$SCRIPT_DIR"/*.png "$THEME_DIR/" 2>/dev/null || true
cp -r "$SCRIPT_DIR"/*.svg "$THEME_DIR/" 2>/dev/null || true
cp -r "$SCRIPT_DIR"/icons "$THEME_DIR/" 2>/dev/null || true

echo -e "${GREEN}✓ 主题文件已复制到 $THEME_DIR${NC}"

# 配置 SDDM
echo -e "${YELLOW}正在配置 SDDM...${NC}"

if [ -f "$SDDM_CONF" ]; then
    # 备份原配置
    cp "$SDDM_CONF" "${SDDM_CONF}.bak"
    
    # 检查是否已有 Theme 段
    if grep -q "^\[Theme\]" "$SDDM_CONF"; then
        # 更新现有配置
        sed -i '/^\[Theme\]/,/^\[/ s/^Current=.*/Current='"$THEME_NAME"'/' "$SDDM_CONF"
    else
        # 添加新配置
        echo -e "\n[Theme]\nCurrent=$THEME_NAME" >> "$SDDM_CONF"
    fi
else
    # 创建新配置
    echo -e "[Theme]\nCurrent=$THEME_NAME" > "$SDDM_CONF"
fi

echo -e "${GREEN}✓ SDDM 配置已更新${NC}"

echo
echo -e "${GREEN}════════════════════════════════════${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}请重启系统或运行以下命令重启 SDDM：${NC}"
echo -e "${YELLOW}  sudo systemctl restart sddm${NC}"
echo -e "${GREEN}════════════════════════════════════${NC}"
