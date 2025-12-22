#!/usr/bin/env python3
"""
通知监听守护进程 - 监听 DBus 通知并提供 waybar 集成
运行方式: python3 notification_daemon.py [--waybar]
"""

import subprocess
import json
import re
import os
import sys
import signal
import argparse
import time
from pathlib import Path
from datetime import datetime
from threading import Thread, Lock

CACHE_DIR = Path.home() / ".cache" / "quickshell-notifications"
CACHE_FILE = CACHE_DIR / "notifications.json"
STATE_FILE = CACHE_DIR / "state.json"
MAX_NOTIFICATIONS = 100

state_lock = Lock()

def ensure_cache_dir():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

def load_notifications():
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE) as f:
                return json.load(f)
        except:
            return []
    return []

def save_notifications(notifications):
    ensure_cache_dir()
    notifications = notifications[:MAX_NOTIFICATIONS]
    with open(CACHE_FILE, "w") as f:
        json.dump(notifications, f, ensure_ascii=False, indent=2)

def load_state():
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE) as f:
                return json.load(f)
        except:
            pass
    return {"unread": 0, "dnd": False, "seen": False}

def save_state(state):
    ensure_cache_dir()
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

def get_waybar_output():
    """生成 waybar 兼容的 JSON 输出"""
    state = load_state()
    unread = state.get("unread", 0)
    dnd = state.get("dnd", False)
    
    if dnd:
        if unread > 0:
            icon = "dnd-notification"
        else:
            icon = "dnd-none"
    else:
        if unread > 0:
            icon = "notification"
        else:
            icon = "none"
    
    output = {
        "text": str(unread) if unread > 0 else "",
        "alt": icon,
        "tooltip": f"通知: {unread}" if unread > 0 else ("勿扰模式" if dnd else "无新通知"),
        "class": icon
    }
    return json.dumps(output)

def clear_history():
    """清除历史通知"""
    save_notifications([])
    with state_lock:
        state = load_state()
        state["unread"] = 0
        state["seen"] = True
        save_state(state)

def mark_seen():
    """标记为已查看（清除红点）"""
    with state_lock:
        state = load_state()
        state["unread"] = 0
        state["seen"] = True
        save_state(state)

def toggle_dnd():
    """切换勿扰模式"""
    with state_lock:
        state = load_state()
        state["dnd"] = not state.get("dnd", False)
        save_state(state)
        # 同步到 mako
        if state["dnd"]:
            subprocess.run(["makoctl", "mode", "-a", "do-not-disturb"], capture_output=True)
        else:
            subprocess.run(["makoctl", "mode", "-r", "do-not-disturb"], capture_output=True)
    return state["dnd"]

def signal_handler(sig, frame):
    print("守护进程退出", file=sys.stderr)
    sys.exit(0)

def waybar_mode():
    """Waybar 订阅模式 - 持续输出状态"""
    while True:
        print(get_waybar_output(), flush=True)
        time.sleep(1)

def listen_notifications():
    """监听通知"""
    notification_id = 1000
    
    proc = subprocess.Popen(
        ["dbus-monitor", "interface='org.freedesktop.Notifications',member='Notify'"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )
    
    buffer = []
    in_notify = False
    
    for line in proc.stdout:
        line = line.rstrip()
        
        if "member=Notify" in line:
            in_notify = True
            buffer = []
            continue
        
        if in_notify:
            buffer.append(line)
            
            if len(buffer) >= 8:
                try:
                    strings = []
                    for b in buffer:
                        if 'string "' in b:
                            match = re.search(r'string "(.*)"', b)
                            if match:
                                strings.append(match.group(1))
                    
                    if len(strings) >= 4:
                        app_name = strings[0] if strings else "Unknown"
                        summary = strings[2] if len(strings) > 2 else ""
                        body = strings[3] if len(strings) > 3 else ""
                        
                        # 检查勿扰模式
                        state = load_state()
                        if state.get("dnd", False):
                            in_notify = False
                            buffer = []
                            continue
                        
                        notifications = load_notifications()
                        notification_id += 1
                        
                        notification = {
                            "id": notification_id,
                            "app": app_name,
                            "summary": summary,
                            "body": body[:500],
                            "time": datetime.now().strftime("%H:%M"),
                            "timestamp": datetime.now().isoformat()
                        }
                        
                        # 避免重复
                        if notifications:
                            last = notifications[0]
                            if last.get("summary") == summary and last.get("body") == body:
                                in_notify = False
                                buffer = []
                                continue
                        
                        notifications.insert(0, notification)
                        save_notifications(notifications)
                        
                        # 更新未读数
                        with state_lock:
                            state = load_state()
                            state["unread"] = state.get("unread", 0) + 1
                            state["seen"] = False
                            save_state(state)
                        
                        print(f"通知: [{app_name}] {summary}", file=sys.stderr)
                    
                except Exception as e:
                    print(f"解析错误: {e}", file=sys.stderr)
                
                in_notify = False
                buffer = []

def main():
    parser = argparse.ArgumentParser(description="通知守护进程")
    parser.add_argument("--waybar", action="store_true", help="Waybar 订阅模式")
    parser.add_argument("--clear", action="store_true", help="清除所有通知")
    parser.add_argument("--seen", action="store_true", help="标记为已查看")
    parser.add_argument("--toggle-dnd", action="store_true", help="切换勿扰模式")
    parser.add_argument("--status", action="store_true", help="输出当前状态")
    args = parser.parse_args()
    
    ensure_cache_dir()
    
    if args.clear:
        clear_history()
        print("已清除所有通知")
        return
    
    if args.seen:
        mark_seen()
        print("已标记为已查看")
        return
    
    if args.toggle_dnd:
        dnd = toggle_dnd()
        print(f"勿扰模式: {'开启' if dnd else '关闭'}")
        return
    
    if args.status:
        print(get_waybar_output())
        return
    
    if args.waybar:
        waybar_mode()
        return
    
    # 默认：监听模式
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # 开机清除历史
    clear_history()
    print("通知守护进程已启动（已清除历史）", file=sys.stderr)
    
    listen_notifications()

if __name__ == "__main__":
    main()
