#!/usr/bin/env python3
"""
QuickShell Notification Daemon
Implements org.freedesktop.Notifications D-Bus interface
"""

import asyncio
import json
import os
import sys
import traceback
from pathlib import Path
from datetime import datetime
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method, signal as dbus_signal
from dbus_next import Variant, BusType

# Paths
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SOCKET_PATH = f"{RUNTIME_DIR}/qs-notifications.sock"
HISTORY_FILE = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "qs-notifications" / "history.json"
LOG_FILE = Path(os.environ.get("QS_NOTIFICATIONS_LOG", "/tmp/qs-notifications.log"))

# State
notifications = {}
history = []
next_id = 1
dnd_mode = False


def log(message: str):
    line = f"{datetime.now().isoformat(timespec='seconds')} {message}"
    print(line, file=sys.stderr, flush=True)
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def log_exception(context: str):
    log(f"{context}:\n{traceback.format_exc().rstrip()}")


def hint_value(hints: dict, key: str, default=None):
    value = hints.get(key, default)
    if isinstance(value, Variant):
        return value.value
    return value


def load_history():
    global history
    # Clear history on daemon start
    history = []
    try:
        if HISTORY_FILE.exists():
            HISTORY_FILE.unlink()
    except Exception:
        pass


def save_history():
    try:
        HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
        HISTORY_FILE.write_text(json.dumps(history[-100:], ensure_ascii=False))
    except Exception as e:
        print(f"Failed to save history: {e}", file=sys.stderr)


async def show_popup(notif: dict):
    """Launch popup process to show notification"""
    import subprocess
    popup_path = Path(__file__).parent / "popup.qml"
    env = os.environ.copy()
    env["QS_NOTIF_DATA"] = json.dumps(notif, ensure_ascii=False)
    try:
        output_json = subprocess.check_output(
            ["niri", "msg", "--json", "focused-output"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=0.3,
        )
        env["QS_TARGET_OUTPUT"] = json.loads(output_json).get("name", "")
    except Exception:
        log_exception("Failed to resolve focused output")

    try:
        popup_log = open("/tmp/qs-notification-popup.log", "ab", buffering=0)
        subprocess.Popen(
            ["quickshell", "-p", str(popup_path)],
            env=env,
            stdout=popup_log,
            stderr=popup_log,
            close_fds=True,
        )
    except Exception:
        log_exception("Failed to launch notification popup")


class NotificationService(ServiceInterface):
    def __init__(self):
        super().__init__("org.freedesktop.Notifications")

    @method()
    def GetCapabilities(self) -> "as":
        return ["body", "body-markup", "actions", "icon-static", "persistence"]

    @method()
    def GetServerInformation(self) -> "ssss":
        return ["qs-notifications", "quickshell", "1.0", "1.2"]

    @method()
    async def Notify(
        self,
        app_name: "s",
        replaces_id: "u",
        app_icon: "s",
        summary: "s",
        body: "s",
        actions: "as",
        hints: "a{sv}",
        expire_timeout: "i",
    ) -> "u":
        global next_id, notifications, history, dnd_mode

        nid = replaces_id if replaces_id > 0 else next_id
        try:
            if replaces_id == 0:
                next_id += 1

            # Parse actions into pairs
            action_list = []
            for i in range(0, len(actions) - 1, 2):
                action_list.append({"id": actions[i], "label": actions[i + 1]})

            try:
                urgency = int(hint_value(hints, "urgency", 1) or 1)
            except (TypeError, ValueError):
                urgency = 1

            notif = {
                "id": nid,
                "app_name": app_name,
                "app_icon": app_icon,
                "summary": summary,
                "body": body,
                "actions": action_list,
                "timestamp": datetime.now().isoformat(),
                "urgency": urgency,
            }

            notifications[nid] = notif
            history.append(notif)
            save_history()

            if not dnd_mode:
                await show_popup(notif)
        except Exception:
            log_exception("Notify failed")

        return nid

    @method()
    def CloseNotification(self, id: "u"):
        if id in notifications:
            del notifications[id]
        self.NotificationClosed(id, 3)

    @dbus_signal()
    def NotificationClosed(self, id, reason) -> "uu":
        return [id, reason]

    @dbus_signal()
    def ActionInvoked(self, id, action_key) -> "us":
        return [id, action_key]


# Global service reference
service = None


async def handle_control(reader, writer):
    """Handle control commands from QML"""
    global dnd_mode, history, service
    try:
        data = await reader.readline()
        if not data:
            return
        msg = json.loads(data.decode())
        cmd = msg.get("cmd")

        if cmd == "get_history":
            resp = {"history": history, "dnd": dnd_mode}
        elif cmd == "set_dnd":
            dnd_mode = msg.get("value", False)
            resp = {"ok": True, "dnd": dnd_mode}
        elif cmd == "clear_history":
            history = []
            save_history()
            resp = {"ok": True}
        elif cmd == "delete":
            nid = msg.get("id")
            history = [n for n in history if n["id"] != nid]
            save_history()
            resp = {"ok": True}
        elif cmd == "action":
            nid = int(msg.get("id", 0))
            action = str(msg.get("action", ""))
            if service and nid > 0:
                print(f"Invoking action: id={nid}, action={action}", file=sys.stderr)
                service.ActionInvoked(nid, action)
            resp = {"ok": True}
        elif cmd == "close":
            nid = msg.get("id")
            if service:
                service.CloseNotification(nid)
            resp = {"ok": True}
        else:
            resp = {"error": "unknown command"}

        writer.write((json.dumps(resp) + "\n").encode())
        await writer.drain()
    except Exception as e:
        log(f"Control error: {e}")
    finally:
        writer.close()


async def main():
    global service
    load_history()

    # Remove old socket
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)

    # Start control server
    ctrl_server = await asyncio.start_unix_server(handle_control, SOCKET_PATH)
    log(f"Control socket: {SOCKET_PATH}")

    # Connect to D-Bus
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    service = NotificationService()
    bus.export("/org/freedesktop/Notifications", service)

    await bus.request_name("org.freedesktop.Notifications")
    log("Notification daemon started")

    await ctrl_server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nShutdown")
