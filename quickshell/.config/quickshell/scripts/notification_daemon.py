#!/usr/bin/env python3
"""
Waybar notification module interface
Communicates with QuickShell notification daemon via Unix socket
"""

import json
import os
import socket
import sys
from pathlib import Path

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SOCKET_PATH = f"{RUNTIME_DIR}/qs-notifications.sock"
STATE_FILE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "qs-notifications" / "state.json"


def load_state():
    """Load persistent state (DND mode, seen count)"""
    try:
        if STATE_FILE.exists():
            return json.loads(STATE_FILE.read_text())
    except Exception:
        pass
    return {"dnd": False, "seen_count": 0}


def save_state(state):
    """Save persistent state"""
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(json.dumps(state))
    except Exception:
        pass


def send_command(cmd: dict) -> dict:
    """Send command to notification daemon via Unix socket"""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect(SOCKET_PATH)
        sock.sendall((json.dumps(cmd) + "\n").encode())
        response = sock.recv(65536).decode()
        sock.close()
        return json.loads(response) if response else {}
    except Exception:
        return {}


def get_status():
    """Get notification status from daemon"""
    resp = send_command({"cmd": "get_history"})
    return {
        "history": resp.get("history", []),
        "dnd": resp.get("dnd", False)
    }


def format_waybar():
    """Format output for waybar"""
    status = get_status()
    history = status.get("history", [])
    dnd = status.get("dnd", False)

    state = load_state()
    seen_count = state.get("seen_count", 0)

    total = len(history)
    unseen = max(0, total - seen_count)

    # Determine icon class
    if dnd:
        if unseen > 0:
            icon_class = "dnd-notification"
        else:
            icon_class = "dnd-none"
    else:
        if unseen > 0:
            icon_class = "notification"
        else:
            icon_class = "none"

    # Build tooltip
    if total == 0:
        tooltip = "暂无通知"
    else:
        tooltip_lines = [f"通知: {total} 条"]
        if unseen > 0:
            tooltip_lines[0] += f" ({unseen} 条未读)"
        if dnd:
            tooltip_lines.append("勿扰模式已开启")

        # Show recent notifications
        tooltip_lines.append("")
        for notif in history[-5:]:
            app = notif.get("app_name", "Unknown")
            summary = notif.get("summary", "")[:30]
            if summary:
                tooltip_lines.append(f"{app}: {summary}")
            else:
                tooltip_lines.append(app)

        tooltip = "\n".join(tooltip_lines)

    output = {
        "text": "",
        "alt": icon_class,
        "tooltip": tooltip,
        "class": icon_class
    }

    print(json.dumps(output, ensure_ascii=False))


def mark_seen():
    """Mark all notifications as seen"""
    status = get_status()
    total = len(status.get("history", []))
    state = load_state()
    state["seen_count"] = total
    save_state(state)


def toggle_dnd():
    """Toggle DND mode"""
    status = get_status()
    new_dnd = not status.get("dnd", False)
    send_command({"cmd": "set_dnd", "value": new_dnd})


def main():
    args = sys.argv[1:]

    if "--waybar" in args:
        format_waybar()
    elif "--seen" in args:
        mark_seen()
    elif "--toggle-dnd" in args:
        toggle_dnd()
    elif "--status" in args:
        status = get_status()
        print(json.dumps(status, ensure_ascii=False, indent=2))
    else:
        # Default: waybar mode
        format_waybar()


if __name__ == "__main__":
    main()
