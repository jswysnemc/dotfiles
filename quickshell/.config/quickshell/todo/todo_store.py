#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from scripts.lib.i18n import I18n


DATA_DIR = Path.home() / ".local/share/quickshell"
DATA_FILE = DATA_DIR / "todos.json"
LEGACY_FILE = DATA_DIR / "notes.json"
MIGRATION_MARKER = DATA_DIR / ".todos_migrated"
WAYBAR_SIGNAL = "10"
I18N = I18n("todo")


def read_json(path):
    try:
        with path.open("r", encoding="utf-8") as file:
            return json.load(file)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError:
        return None
    except OSError:
        return None


def normalize_todo(todo):
    if not isinstance(todo, dict):
        return None

    text = str(todo.get("text", "")).strip()
    if not text:
        return None

    now = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    todo_id = todo.get("id")
    if todo_id is None:
        todo_id = int(time.time() * 1000)

    return {
        "id": todo_id,
        "text": text,
        "done": bool(todo.get("done", False)),
        "createdAt": str(todo.get("createdAt") or now),
        "completedAt": str(todo.get("completedAt") or ""),
    }


def normalize_payload(payload):
    if isinstance(payload, list):
        raw_todos = payload
    elif isinstance(payload, dict):
        raw_todos = payload.get("todos", [])
    else:
        raw_todos = []

    todos = []
    for item in raw_todos:
        todo = normalize_todo(item)
        if todo is not None:
            todos.append(todo)
    return todos


def write_todos(todos, notify=False):
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(
        prefix=".todos.",
        suffix=".json",
        dir=DATA_DIR,
        text=True,
    )

    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            json.dump({"todos": todos}, file, ensure_ascii=False, indent=2)
            file.write("\n")
        os.replace(tmp_path, DATA_FILE)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    if notify:
        notify_waybar()


def todo_key(todo):
    if todo.get("id") is not None:
        return f"id:{todo['id']}"
    return f"text:{todo.get('text', '')}|created:{todo.get('createdAt', '')}"


def merge_todos(primary, secondary):
    merged = []
    seen = set()

    for todo in primary + secondary:
        key = todo_key(todo)
        if key in seen:
            continue
        seen.add(key)
        merged.append(todo)

    return merged


def mark_migrated():
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        MIGRATION_MARKER.write_text("1\n", encoding="utf-8")
    except OSError:
        pass


def load_todos():
    current = read_json(DATA_FILE)
    current_todos = normalize_payload(current) if current is not None else []

    if not MIGRATION_MARKER.exists():
        legacy = read_json(LEGACY_FILE)
        legacy_todos = normalize_payload(legacy) if legacy is not None else []

        if legacy_todos:
            merged = merge_todos(current_todos, legacy_todos)
            if merged != current_todos or not DATA_FILE.exists():
                write_todos(merged)
            mark_migrated()
            return merged

        if current is not None:
            mark_migrated()

    return current_todos


def notify_waybar():
    try:
        subprocess.run(
            ["pkill", f"-RTMIN+{WAYBAR_SIGNAL}", "waybar"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except FileNotFoundError:
        pass


def json_output(payload):
    print(json.dumps(payload, ensure_ascii=False))


def status():
    """
    输出Waybar使用的本地化待办状态。

    :return: 无
    """
    todos = load_todos()
    done = sum(1 for todo in todos if todo.get("done"))
    pending = len(todos) - done

    todo_class = "empty"
    if pending > 0:
        todo_class = "pending"
    elif done > 0:
        todo_class = "done"

    pending_items = [todo["text"] for todo in todos if not todo.get("done")][:5]
    tooltip_lines = [
        I18N.tr("pendingLabel", {"count": pending}),
        I18N.tr("doneLabel", {"count": done}),
        I18N.tr("totalLabel", {"count": len(todos)}),
    ]
    if pending_items:
        tooltip_lines.append("")
        tooltip_lines.append(I18N.tr("pendingItems"))
        tooltip_lines.extend(f"- {item}" for item in pending_items)

    json_output(
        {
            "text": I18N.tr("statusText", {"pending": pending, "done": done}),
            "tooltip": "\n".join(tooltip_lines),
            "class": todo_class,
            "alt": todo_class,
        }
    )


def load():
    json_output({"todos": load_todos()})


def save():
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("Refusing to save invalid JSON from stdin", file=sys.stderr)
        return 1

    if not isinstance(payload, (dict, list)) or (
        isinstance(payload, dict) and "todos" not in payload
    ):
        print("Refusing to save payload without todos", file=sys.stderr)
        return 1

    todos = normalize_payload(payload)
    write_todos(todos, notify=True)
    json_output({"ok": True, "count": len(todos)})
    return 0


def save_json(raw_json):
    try:
        payload = json.loads(raw_json)
    except json.JSONDecodeError:
        print("Refusing to save invalid JSON argument", file=sys.stderr)
        return 1

    if not isinstance(payload, (dict, list)) or (
        isinstance(payload, dict) and "todos" not in payload
    ):
        print("Refusing to save payload without todos", file=sys.stderr)
        return 1

    todos = normalize_payload(payload)
    write_todos(todos, notify=True)
    json_output({"ok": True, "count": len(todos)})
    return 0


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "status"

    if command == "load":
        load()
    elif command == "save":
        return save()
    elif command == "save-json":
        if len(sys.argv) < 3:
            print("save-json requires a JSON argument", file=sys.stderr)
            return 1
        return save_json(sys.argv[2])
    elif command in {"status", "waybar"}:
        status()
    else:
        print("Usage: todo_store.py {load|save|save-json|status|waybar}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
