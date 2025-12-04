#!/bin/bash

# 启动 swww 守护进程 (如果还没运行)
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon &
fi

# 等待一下确保 daemon 启动完毕
sleep 0.5

# 设置壁纸，带有炫酷的过渡效果
# --transition-type: grow, outer, center, simple, wipe, wave 等
# --transition-fps: 帧率
swww img "$HOME/.cache/current_wallpaper" \
    --transition-type grow \
    --transition-pos 0.854,0.977 \
    --transition-step 90 \
    --transition-fps 60
