#!/usr/bin/env python3
"""日历计时器状态管理脚本。"""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from typing import Any


MODE_LABELS = {
    "stopwatch": "正计时",
    "countdown": "倒计时",
    "pomodoro": "番茄时钟",
}


def state_path() -> Path:
    """获取计时器运行时状态文件路径。

    Args:
        无。
    Returns:
        Path: 状态文件路径。
    """
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "quickshell"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    return runtime_dir / "timer-state.json"


def inactive_state() -> dict[str, Any]:
    """生成空闲状态。

    Args:
        无。
    Returns:
        dict[str, Any]: 空闲状态数据。
    """
    return {
        "active": False,
        "running": False,
        "mode": "stopwatch",
        "duration_seconds": 0,
        "elapsed_before": 0,
        "started_at": 0,
        "updated_at": int(time.time()),
    }


def load_state() -> dict[str, Any]:
    """读取计时器状态。

    Args:
        无。
    Returns:
        dict[str, Any]: 当前状态数据。
    """
    path = state_path()
    if not path.exists():
        return inactive_state()

    try:
        with path.open("r", encoding="utf-8") as state_file:
            state = json.load(state_file)
    except (OSError, json.JSONDecodeError):
        return inactive_state()

    if not isinstance(state, dict):
        return inactive_state()

    return {**inactive_state(), **state}


def save_state(state: dict[str, Any]) -> None:
    """写入计时器状态。

    Args:
        state: 需要保存的状态数据。
    Returns:
        None: 无返回值。
    """
    path = state_path()
    temp_path = path.with_suffix(".tmp")
    with temp_path.open("w", encoding="utf-8") as state_file:
        json.dump(state, state_file, ensure_ascii=False)
    temp_path.replace(path)


def elapsed_seconds(state: dict[str, Any], now: int | None = None) -> int:
    """计算当前已用秒数。

    Args:
        state: 当前状态数据。
        now: 当前时间戳；不传时读取系统时间。
    Returns:
        int: 已用秒数。
    """
    if now is None:
        now = int(time.time())

    elapsed = int(state.get("elapsed_before", 0))
    if state.get("active") and state.get("running"):
        elapsed += max(0, now - int(state.get("started_at", now)))

    return max(0, elapsed)


def format_duration(seconds: int) -> str:
    """格式化秒数为计时显示文本。

    Args:
        seconds: 秒数。
    Returns:
        str: 格式化后的时间文本。
    """
    seconds = max(0, int(seconds))
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    remain = seconds % 60
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{remain:02d}"
    return f"{minutes:02d}:{remain:02d}"


def icon_for_mode(mode: str) -> str:
    """获取模式图标文本。

    Args:
        mode: 计时模式。
    Returns:
        str: Nerd Font 图标字符。
    """
    if mode == "countdown":
        return "󰔟"
    if mode == "pomodoro":
        return "󰄉"
    return "󰔛"


def normalize_state(state: dict[str, Any]) -> dict[str, Any]:
    """根据当前时间规整状态并自动结束已完成的倒计时。

    Args:
        state: 当前状态数据。
    Returns:
        dict[str, Any]: 规整后的状态数据。
    """
    if not state.get("active"):
        return inactive_state()

    mode = str(state.get("mode", "stopwatch"))
    if mode not in MODE_LABELS:
        mode = "stopwatch"
        state["mode"] = mode

    duration = max(0, int(state.get("duration_seconds", 0)))
    elapsed = elapsed_seconds(state)
    if mode != "stopwatch" and duration > 0 and elapsed >= duration:
        completed = inactive_state()
        completed["mode"] = mode
        completed["duration_seconds"] = duration
        save_state(completed)
        return completed

    return state


def build_status(state: dict[str, Any]) -> dict[str, Any]:
    """生成对 QML 和 Waybar 友好的状态输出。

    Args:
        state: 当前状态数据。
    Returns:
        dict[str, Any]: 输出状态。
    """
    state = normalize_state(state)
    if not state.get("active"):
        return {
            "active": False,
            "running": False,
            "mode": str(state.get("mode", "stopwatch")),
            "modeLabel": MODE_LABELS.get(str(state.get("mode", "stopwatch")), "正计时"),
            "display": "00:00",
            "text": "",
            "tooltip": "",
            "class": "inactive",
            "elapsedSeconds": 0,
            "remainingSeconds": 0,
            "durationSeconds": int(state.get("duration_seconds", 0)),
            "progress": 0.0,
        }

    mode = str(state.get("mode", "stopwatch"))
    duration = max(0, int(state.get("duration_seconds", 0)))
    elapsed = elapsed_seconds(state)
    remaining = max(0, duration - elapsed) if mode != "stopwatch" else 0
    display_seconds = elapsed if mode == "stopwatch" else remaining
    display = format_duration(display_seconds)
    mode_label = MODE_LABELS.get(mode, "正计时")
    progress = min(1.0, elapsed / duration) if duration > 0 and mode != "stopwatch" else 0.0
    state_class = "running" if state.get("running") else "paused"

    return {
        "active": True,
        "running": bool(state.get("running")),
        "mode": mode,
        "modeLabel": mode_label,
        "display": display,
        "text": f"{icon_for_mode(mode)} {display}",
        "tooltip": f"{mode_label} {'运行中' if state.get('running') else '已暂停'}\\n{display}",
        "class": state_class,
        "elapsedSeconds": elapsed,
        "remainingSeconds": remaining,
        "durationSeconds": duration,
        "progress": progress,
    }


def start_timer(mode: str, duration_seconds: int) -> dict[str, Any]:
    """启动新的计时任务。

    Args:
        mode: 计时模式。
        duration_seconds: 目标时长秒数。
    Returns:
        dict[str, Any]: 启动后的状态输出。
    """
    if mode not in MODE_LABELS:
        mode = "stopwatch"

    state = {
        "active": True,
        "running": True,
        "mode": mode,
        "duration_seconds": max(0, int(duration_seconds)),
        "elapsed_before": 0,
        "started_at": int(time.time()),
        "updated_at": int(time.time()),
    }
    save_state(state)
    return build_status(state)


def pause_timer() -> dict[str, Any]:
    """暂停当前计时任务。

    Args:
        无。
    Returns:
        dict[str, Any]: 暂停后的状态输出。
    """
    state = normalize_state(load_state())
    if state.get("active") and state.get("running"):
        state["elapsed_before"] = elapsed_seconds(state)
        state["running"] = False
        state["updated_at"] = int(time.time())
        save_state(state)
    return build_status(state)


def resume_timer() -> dict[str, Any]:
    """继续当前计时任务。

    Args:
        无。
    Returns:
        dict[str, Any]: 继续后的状态输出。
    """
    state = normalize_state(load_state())
    if state.get("active") and not state.get("running"):
        state["running"] = True
        state["started_at"] = int(time.time())
        state["updated_at"] = int(time.time())
        save_state(state)
    return build_status(state)


def stop_timer() -> dict[str, Any]:
    """停止当前计时任务。

    Args:
        无。
    Returns:
        dict[str, Any]: 停止后的状态输出。
    """
    state = inactive_state()
    save_state(state)
    return build_status(state)


def parse_args() -> argparse.Namespace:
    """解析命令行参数。

    Args:
        无。
    Returns:
        argparse.Namespace: 解析后的参数。
    """
    parser = argparse.ArgumentParser(description="Quickshell timer state")
    parser.add_argument("command", choices=["status", "waybar", "start", "pause", "resume", "stop", "reset"])
    parser.add_argument("--mode", choices=list(MODE_LABELS.keys()), default="stopwatch")
    parser.add_argument("--duration", type=int, default=0)
    return parser.parse_args()


def main() -> None:
    """执行计时器状态命令。

    Args:
        无。
    Returns:
        None: 无返回值。
    """
    args = parse_args()
    if args.command in {"status", "waybar"}:
        result = build_status(load_state())
    elif args.command == "start":
        result = start_timer(args.mode, args.duration)
    elif args.command == "pause":
        result = pause_timer()
    elif args.command == "resume":
        result = resume_timer()
    else:
        result = stop_timer()

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
