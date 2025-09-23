#!/usr/bin/env bash

# 等待几秒钟，以确保桌面环境完全加载完毕
sleep 1

# 执行你的登录脚本
# 请确保这里的路径是正确的
/home/snemc/.custom/bin/wifi_login

# 检查上一个命令（也就是 wifi_login.sh）的退出码
# $? 变量保存了上一个命令的退出码
if [ $? -eq 0 ]; then
    # 如果退出码为 0 (成功)
    notify-send -u normal -i network-wireless-online "Wi-Fi 登录成功" "已成功连接并登录校园网"
else
    # 如果退出码非 0 (失败)
    notify-send -u critical -i network-wireless-offline "Wi-Fi 登录失败" "连接校园网失败，请检查网络或脚本"
fi
