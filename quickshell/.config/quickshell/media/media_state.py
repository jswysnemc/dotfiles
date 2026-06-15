#!/usr/bin/env python3
"""媒体组件后台状态管理脚本。"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from lyrics_fetcher import fetch_lyrics, get_current_line


STATE_VERSION = 1
POLL_INTERVAL_SECONDS = 0.5
IDLE_EXIT_SECONDS = 180


def runtime_dir() -> Path:
    """获取媒体状态运行时目录。

    Args:
        无。
    Returns:
        Path: 运行时目录路径。
    """
    base_dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "quickshell"
    base_dir.mkdir(parents=True, exist_ok=True)
    return base_dir


def state_path() -> Path:
    """获取媒体状态快照文件路径。

    Args:
        无。
    Returns:
        Path: 状态快照文件路径。
    """
    return runtime_dir() / "media-state.json"


def pid_path() -> Path:
    """获取后台状态脚本 PID 文件路径。

    Args:
        无。
    Returns:
        Path: PID 文件路径。
    """
    return runtime_dir() / "media-state.pid"


def inactive_state(error: str = "") -> dict[str, Any]:
    """生成空闲媒体状态。

    Args:
        error: 需要暴露给调用方的错误信息。
    Returns:
        dict[str, Any]: 空闲状态数据。
    """
    return {
        "success": not bool(error),
        "version": STATE_VERSION,
        "active": False,
        "track": {},
        "playback": {},
        "lyrics": {
            "loaded": False,
            "loading": False,
            "error": error,
            "synced": False,
            "lines": [],
            "current_index": -1,
            "current_text": "",
            "next_text": "",
        },
        "updated_at": time.time(),
    }


def read_json_file(path: Path) -> dict[str, Any] | None:
    """读取 JSON 文件。

    Args:
        path: JSON 文件路径。
    Returns:
        dict[str, Any] | None: JSON 对象；读取失败时返回 None。
    """
    if not path.exists():
        return None

    try:
        with path.open("r", encoding="utf-8") as state_file:
            data = json.load(state_file)
    except (OSError, json.JSONDecodeError):
        return None

    if not isinstance(data, dict):
        return None

    return data


def write_json_file(path: Path, data: dict[str, Any]) -> None:
    """原子写入 JSON 文件。

    Args:
        path: JSON 文件路径。
        data: 需要写入的数据。
    Returns:
        None: 无返回值。
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(".tmp")
    with temp_path.open("w", encoding="utf-8") as state_file:
        json.dump(data, state_file, ensure_ascii=False)
    temp_path.replace(path)


def load_state() -> dict[str, Any]:
    """读取当前媒体状态快照。

    Args:
        无。
    Returns:
        dict[str, Any]: 当前状态快照。
    """
    data = read_json_file(state_path())
    if data is None:
        return inactive_state()
    return {**inactive_state(), **data}


def save_state(data: dict[str, Any]) -> None:
    """保存当前媒体状态快照。

    Args:
        data: 当前状态快照。
    Returns:
        None: 无返回值。
    """
    data["updated_at"] = time.time()
    write_json_file(state_path(), data)


def run_playerctl(args: list[str], timeout: float = 2) -> subprocess.CompletedProcess[str] | None:
    """执行 playerctl 命令。

    Args:
        args: 传给 playerctl 的参数。
        timeout: 命令超时时间，单位为秒。
    Returns:
        subprocess.CompletedProcess[str] | None: 命令结果；执行失败时返回 None。
    """
    try:
        return subprocess.run(
            ["playerctl", *args],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (FileNotFoundError, subprocess.SubprocessError):
        return None


def normalize_text(value: str) -> str:
    """规整 playerctl 输出文本。

    Args:
        value: 原始输出文本。
    Returns:
        str: 去除空白并合并多行后的文本。
    """
    parts = [line.strip() for line in value.splitlines() if line.strip()]
    return ", ".join(parts)


def list_players() -> list[str]:
    """列出当前可用的 MPRIS 播放器。

    Args:
        无。
    Returns:
        list[str]: 播放器名称列表。
    """
    result = run_playerctl(["-l"])
    if result is None or result.returncode != 0:
        return []

    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def player_status(player: str) -> str:
    """读取播放器播放状态。

    Args:
        player: playerctl 播放器名称。
    Returns:
        str: 播放状态文本。
    """
    result = run_playerctl(["-p", player, "status"])
    if result is None or result.returncode != 0:
        return ""
    return normalize_text(result.stdout)


def active_player() -> str:
    """选择当前媒体组件应该展示的播放器。

    Args:
        无。
    Returns:
        str: 播放器名称；没有可用播放器时返回空字符串。
    """
    players = list_players()
    if not players:
        return ""

    # 【媒体组件】【播放器选择】1. 优先选择正在播放的播放器，避免暂停实例抢占状态
    for player in players:
        if player_status(player).lower() == "playing":
            return player

    # 【媒体组件】【播放器选择】2. 没有播放中的实例时保留第一个可用播放器状态
    return players[0]


def metadata_value(player: str, key: str) -> str:
    """读取播放器元数据字段。

    Args:
        player: playerctl 播放器名称。
        key: MPRIS 元数据键名。
    Returns:
        str: 元数据文本。
    """
    result = run_playerctl(["-p", player, "metadata", key])
    if result is None or result.returncode != 0:
        return ""
    return normalize_text(result.stdout)


def float_command_value(args: list[str]) -> float:
    """读取浮点数命令输出。

    Args:
        args: 传给 playerctl 的参数。
    Returns:
        float: 浮点数结果；读取失败时返回 0。
    """
    result = run_playerctl(args)
    if result is None or result.returncode != 0:
        return 0

    try:
        return float(result.stdout.strip())
    except ValueError:
        return 0


def playback_position(player: str) -> float:
    """读取当前播放进度。

    Args:
        player: playerctl 播放器名称。
    Returns:
        float: 当前播放进度，单位为秒。
    """
    return float_command_value(["-p", player, "position"])


def playback_length(player: str) -> float:
    """读取当前曲目总时长。

    Args:
        player: playerctl 播放器名称。
    Returns:
        float: 曲目总时长，单位为秒。
    """
    raw_length = metadata_value(player, "mpris:length")
    try:
        return float(raw_length) / 1_000_000
    except ValueError:
        return 0


def track_key(title: str, artist: str, album: str, player: str) -> str:
    """生成与 QML 控制器一致的曲目标识。

    Args:
        title: 曲目标题。
        artist: 艺术家名称。
        album: 专辑名称。
        player: playerctl 播放器名称。
    Returns:
        str: 曲目标识。
    """
    return f"{title}||{artist}||{album}||{player}"


def read_track(player: str) -> dict[str, Any]:
    """读取当前播放器的曲目信息。

    Args:
        player: playerctl 播放器名称。
    Returns:
        dict[str, Any]: 曲目信息。
    """
    title = metadata_value(player, "xesam:title")
    artist = metadata_value(player, "xesam:artist")
    album = metadata_value(player, "xesam:album")
    length = playback_length(player)
    return {
        "key": track_key(title, artist, album, player),
        "title": title,
        "artist": artist,
        "album": album,
        "length": length,
        "player": player,
    }


def lyrics_loading_state() -> dict[str, Any]:
    """生成歌词加载中状态。

    Args:
        无。
    Returns:
        dict[str, Any]: 歌词加载中状态。
    """
    return {
        "loaded": False,
        "loading": True,
        "error": "",
        "synced": False,
        "lines": [],
        "current_index": -1,
        "current_text": "",
        "next_text": "",
    }


def build_lyrics_state(result: dict[str, Any], position: float) -> dict[str, Any]:
    """根据歌词请求结果构建展示状态。

    Args:
        result: 歌词请求结果。
        position: 当前播放进度，单位为秒。
    Returns:
        dict[str, Any]: 可供 QML 直接应用的歌词状态。
    """
    if not result.get("success"):
        return {
            "loaded": False,
            "loading": False,
            "error": str(result.get("error", "获取失败")),
            "synced": False,
            "lines": [],
            "current_index": -1,
            "current_text": "",
            "next_text": "",
        }

    if result.get("synced") and isinstance(result.get("lines"), list):
        line_state = get_current_line(result["lines"], position)
        return {
            "loaded": True,
            "loading": False,
            "error": "",
            "synced": True,
            "lines": result["lines"],
            "current_index": int(line_state.get("index", -1)),
            "current_text": str(line_state.get("text", "")),
            "next_text": str(line_state.get("next_text", "")),
        }

    return {
        "loaded": True,
        "loading": False,
        "error": "",
        "synced": False,
        "lines": [],
        "text": str(result.get("text", "")),
        "current_index": -1,
        "current_text": "无同步歌词",
        "next_text": "",
    }


def base_snapshot(player: str, track: dict[str, Any], position: float, status: str) -> dict[str, Any]:
    """生成不含歌词结果的媒体状态快照。

    Args:
        player: playerctl 播放器名称。
        track: 曲目信息。
        position: 当前播放进度，单位为秒。
        status: 播放状态文本。
    Returns:
        dict[str, Any]: 媒体状态快照。
    """
    return {
        "success": True,
        "version": STATE_VERSION,
        "active": bool(player and track.get("title")),
        "track": track,
        "playback": {
            "player": player,
            "state": status,
            "playing": status.lower() == "playing",
            "position": position,
            "length": float(track.get("length", 0) or 0),
        },
        "lyrics": lyrics_loading_state(),
        "updated_at": time.time(),
    }


def snapshot_for_current_player(last_lyrics: dict[str, Any] | None = None) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """读取当前播放器并生成状态快照。

    Args:
        last_lyrics: 上一次曲目的歌词状态缓存。
    Returns:
        tuple[dict[str, Any], dict[str, Any] | None]: 状态快照和可复用歌词缓存。
    """
    player = active_player()
    if not player:
        return inactive_state(), None

    status = player_status(player)
    position = playback_position(player)
    track = read_track(player)
    snapshot = base_snapshot(player, track, position, status)
    if not snapshot["active"]:
        return snapshot, None

    if last_lyrics and last_lyrics.get("track_key") == track["key"]:
        snapshot["lyrics"] = build_lyrics_state(last_lyrics["result"], position)
        return snapshot, last_lyrics

    # 【媒体组件】【歌词状态】1. 先写入加载中快照，使新打开的组件不会立即重复发起请求
    save_state(snapshot)
    result = fetch_lyrics(
        track["title"],
        track["artist"],
        track["album"],
        float(track.get("length", 0) or 0),
        player,
    )
    last_lyrics = {
        "track_key": track["key"],
        "result": result,
    }
    snapshot["lyrics"] = build_lyrics_state(result, position)
    return snapshot, last_lyrics


def read_pid() -> int:
    """读取后台脚本 PID。

    Args:
        无。
    Returns:
        int: PID；读取失败时返回 0。
    """
    data = read_json_file(pid_path())
    if not data:
        return 0
    try:
        return int(data.get("pid", 0))
    except (TypeError, ValueError):
        return 0


def process_alive(pid: int) -> bool:
    """判断进程是否仍然存在。

    Args:
        pid: 进程 ID。
    Returns:
        bool: 进程存在时返回 True。
    """
    if pid <= 0:
        return False

    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def write_pid() -> None:
    """写入当前进程 PID。

    Args:
        无。
    Returns:
        None: 无返回值。
    """
    write_json_file(pid_path(), {"pid": os.getpid(), "updated_at": time.time()})


def ensure_daemon() -> dict[str, Any]:
    """确保媒体状态后台脚本正在运行。

    Args:
        无。
    Returns:
        dict[str, Any]: 启动结果。
    """
    existing_pid = read_pid()
    if process_alive(existing_pid):
        return {"success": True, "running": True, "pid": existing_pid}

    script_path = Path(__file__).resolve()
    with Path(os.devnull).open("w", encoding="utf-8") as devnull:
        process = subprocess.Popen(
            [sys.executable, str(script_path), "daemon"],
            cwd=str(script_path.parent),
            stdout=devnull,
            stderr=devnull,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )

    return {"success": True, "running": True, "pid": process.pid}


def daemon_loop() -> None:
    """运行媒体状态后台同步循环。

    Args:
        无。
    Returns:
        None: 无返回值。
    """
    write_pid()
    last_lyrics: dict[str, Any] | None = None
    idle_started_at = 0.0

    while True:
        snapshot, last_lyrics = snapshot_for_current_player(last_lyrics)
        save_state(snapshot)

        if snapshot.get("active") and snapshot.get("playback", {}).get("playing"):
            idle_started_at = 0.0
        else:
            if idle_started_at <= 0:
                idle_started_at = time.time()
            if time.time() - idle_started_at >= IDLE_EXIT_SECONDS:
                break

        time.sleep(POLL_INTERVAL_SECONDS)


def stop_daemon() -> dict[str, Any]:
    """停止媒体状态后台脚本。

    Args:
        无。
    Returns:
        dict[str, Any]: 停止结果。
    """
    pid = read_pid()
    if not process_alive(pid):
        return {"success": True, "stopped": True, "pid": 0}

    try:
        os.kill(pid, 15)
    except OSError as error:
        return {"success": False, "error": str(error), "pid": pid}

    return {"success": True, "stopped": True, "pid": pid}


def print_json(data: dict[str, Any]) -> None:
    """输出 JSON 数据。

    Args:
        data: 需要输出的数据。
    Returns:
        None: 无返回值。
    """
    print(json.dumps(data, ensure_ascii=False))


def parse_args() -> argparse.Namespace:
    """解析命令行参数。

    Args:
        无。
    Returns:
        argparse.Namespace: 命令行参数对象。
    """
    parser = argparse.ArgumentParser(description="QuickShell media state helper")
    parser.add_argument(
        "command",
        choices=["ensure-daemon", "daemon", "snapshot", "stop"],
        help="需要执行的命令",
    )
    return parser.parse_args()


def main() -> None:
    """执行命令行入口。

    Args:
        无。
    Returns:
        None: 无返回值。
    """
    args = parse_args()
    if args.command == "ensure-daemon":
        print_json(ensure_daemon())
        return

    if args.command == "daemon":
        daemon_loop()
        return

    if args.command == "snapshot":
        print_json(load_state())
        return

    if args.command == "stop":
        print_json(stop_daemon())
        return


if __name__ == "__main__":
    main()
