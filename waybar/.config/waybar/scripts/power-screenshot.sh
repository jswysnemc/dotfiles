#!/bin/bash

# 1. 冻结屏幕 (Wayfreeze)
# 在后台启动 wayfreeze，并记录其进程 ID (PID)
wayfreeze &
FREEZE_PID=$!

# 等待一小段时间确保 wayfreeze 已生效（可选，但在某些合成器上更稳定）
sleep 0.1

# 2. 选择区域 (Slurp)
# 获取用户选择的区域坐标
GEOMETRY=$(slurp)

# 3. 解冻屏幕
# 无论是否选择了区域，先杀掉 wayfreeze 进程
kill $FREEZE_PID 2>/dev/null

# 4. 检查是否取消
# 如果用户按了 Esc，GEOMETRY 为空，直接退出脚本
if [ -z "$GEOMETRY" ]; then
    echo "截图已取消"
    exit 0
fi

# 5. 生成临时文件路径
# 使用时间戳命名，避免文件名冲突
# 你可以将 /tmp 改为 ~/Pictures/Screenshots 等你喜欢的路径
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILEPATH="/tmp/markpix_$TIMESTAMP.png"

# 6. 截图 (Grim)
# 使用 grim 截取选中区域并保存到文件
grim -g "$GEOMETRY" "$FILEPATH"

# 7. 使用 Markpix 打开
# 根据 help 信息，直接将文件路径作为参数传递
if [ -f "$FILEPATH" ]; then
    markpix "$FILEPATH"

    # 可选：如果你希望截图后同时复制原图到剪贴板，可以取消下面这行的注释
    # wl-copy < "$FILEPATH"
else
    notify-send "截图失败" "无法保存图片文件" -u critical
fi
