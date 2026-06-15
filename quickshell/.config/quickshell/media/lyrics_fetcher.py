#!/usr/bin/env python3
"""
Lyrics fetcher for QuickShell media player.
Supports:
  1. MPRIS local lyrics (xesam:asText) - for musicfox, etc.
  2. lrclib.net API - online fallback
"""

import sys
import json
import re
import subprocess
import hashlib
import os
import time
from pathlib import Path

import httpx

LRCLIB_API = "https://lrclib.net/api"
LYRICS_CACHE_TTL_SECONDS = 60 * 60 * 24 * 30


def lyrics_cache_dir() -> Path:
    """获取歌词缓存目录。

    Args:
        无。
    Returns:
        Path: 歌词缓存目录。
    """
    base_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    cache_dir = base_dir / "quickshell" / "media-lyrics"
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir


def lyrics_cache_key(title: str, artist: str = "", album: str = "", duration: float = 0, player: str = "") -> str:
    """生成歌词缓存键。

    Args:
        title: 曲目标题。
        artist: 艺术家名称。
        album: 专辑名称。
        duration: 曲目时长，单位为秒；该参数保留用于兼容调用方。
        player: playerctl 播放器名称；该参数保留用于兼容调用方。
    Returns:
        str: 缓存键。
    """
    raw_key = "||".join([title.strip(), artist.strip(), album.strip()])
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


def lyrics_cache_path(title: str, artist: str = "", album: str = "", duration: float = 0, player: str = "") -> Path:
    """获取歌词缓存文件路径。

    Args:
        title: 曲目标题。
        artist: 艺术家名称。
        album: 专辑名称。
        duration: 曲目时长，单位为秒。
        player: playerctl 播放器名称。
    Returns:
        Path: 缓存文件路径。
    """
    return lyrics_cache_dir() / f"{lyrics_cache_key(title, artist, album, duration, player)}.json"


def load_cached_lyrics(title: str, artist: str = "", album: str = "", duration: float = 0, player: str = "") -> dict | None:
    """读取歌词缓存。

    Args:
        title: 曲目标题。
        artist: 艺术家名称。
        album: 专辑名称。
        duration: 曲目时长，单位为秒。
        player: playerctl 播放器名称。
    Returns:
        dict | None: 缓存命中时返回歌词结果，否则返回 None。
    """
    path = lyrics_cache_path(title, artist, album, duration, player)
    if not path.exists():
        return None

    try:
        with path.open("r", encoding="utf-8") as cache_file:
            payload = json.load(cache_file)
    except (OSError, json.JSONDecodeError):
        return None

    if not isinstance(payload, dict):
        return None

    cached_at = float(payload.get("cached_at", 0) or 0)
    if time.time() - cached_at > LYRICS_CACHE_TTL_SECONDS:
        return None

    result = payload.get("result")
    if not isinstance(result, dict) or not result.get("success"):
        return None

    result = dict(result)
    result["cached"] = True
    return result


def save_cached_lyrics(title: str, artist: str, album: str, duration: float, player: str, result: dict) -> None:
    """保存歌词缓存。

    Args:
        title: 曲目标题。
        artist: 艺术家名称。
        album: 专辑名称。
        duration: 曲目时长，单位为秒。
        player: playerctl 播放器名称。
        result: 歌词请求结果。
    Returns:
        None: 无返回值。
    """
    if not result.get("success"):
        return

    path = lyrics_cache_path(title, artist, album, duration, player)
    temp_path = path.with_suffix(".tmp")
    payload = {
        "cached_at": time.time(),
        "result": result,
    }
    with temp_path.open("w", encoding="utf-8") as cache_file:
        json.dump(payload, cache_file, ensure_ascii=False)
    temp_path.replace(path)


def parse_lrc(lrc_content: str) -> list[dict]:
    """Parse LRC format lyrics into list of {time, text} dicts."""
    if not lrc_content:
        return []

    lines = []
    pattern = re.compile(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$')

    for line in lrc_content.split('\n'):
        line = line.strip()
        if not line:
            continue

        match = pattern.match(line)
        if match:
            minutes = int(match.group(1))
            seconds = int(match.group(2))
            ms_str = match.group(3)
            if len(ms_str) == 2:
                ms = int(ms_str) * 10
            else:
                ms = int(ms_str)

            time_sec = minutes * 60 + seconds + ms / 1000
            text = match.group(4).strip()

            if text:
                lines.append({
                    "time": round(time_sec, 2),
                    "text": text
                })

    lines.sort(key=lambda x: x["time"])
    return lines


def fetch_mpris_lyrics(player: str = "") -> dict | None:
    """Fetch lyrics from MPRIS xesam:asText metadata (musicfox, etc.)."""
    try:
        cmd = ["playerctl"]
        if player:
            cmd.extend(["-p", player])
        cmd.extend(["metadata", "xesam:asText"])

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=2)

        if result.returncode == 0 and result.stdout.strip():
            lrc_content = result.stdout.strip()
            # Check if it looks like LRC format
            if "[" in lrc_content and "]" in lrc_content:
                lines = parse_lrc(lrc_content)
                if lines:
                    return {
                        "success": True,
                        "synced": True,
                        "lines": lines,
                        "source": "mpris"
                    }
        return None
    except Exception:
        return None


def fetch_lyrics(title: str, artist: str = "", album: str = "", duration: float = 0, player: str = "") -> dict:
    """获取歌词，优先使用缓存和本地 MPRIS，再回退到 lrclib.net。

    Args:
        title: 曲目标题。
        artist: 艺术家名称。
        album: 专辑名称。
        duration: 曲目时长，单位为秒。
        player: playerctl 播放器名称。
    Returns:
        dict: 歌词请求结果。
    """
    cached_result = load_cached_lyrics(title, artist, album, duration, player)
    if cached_result:
        return cached_result

    # 1. 优先读取 MPRIS 本地歌词，适配 musicfox 等播放器
    mpris_result = fetch_mpris_lyrics(player)
    if mpris_result:
        save_cached_lyrics(title, artist, album, duration, player, mpris_result)
        return mpris_result

    # 2. 本地歌词不可用时再请求 lrclib.net
    try:
        params = {
            "track_name": title,
        }
        if artist:
            params["artist_name"] = artist
        if album:
            params["album_name"] = album
        if duration > 0:
            params["duration"] = int(duration)

        with httpx.Client(timeout=10) as client:
            response = client.get(f"{LRCLIB_API}/get", params=params)

            if response.status_code == 404:
                response = client.get(f"{LRCLIB_API}/search", params={"q": f"{artist} {title}"})
                if response.status_code == 200:
                    results = response.json()
                    if results and len(results) > 0:
                        best = results[0]
                        synced = best.get("syncedLyrics", "")
                        plain = best.get("plainLyrics", "")

                        if synced:
                            result = {
                                "success": True,
                                "synced": True,
                                "lines": parse_lrc(synced),
                                "source": "lrclib.net"
                            }
                            save_cached_lyrics(title, artist, album, duration, player, result)
                            return result
                        elif plain:
                            result = {
                                "success": True,
                                "synced": False,
                                "text": plain,
                                "source": "lrclib.net"
                            }
                            save_cached_lyrics(title, artist, album, duration, player, result)
                            return result

                return {"success": False, "error": "Lyrics not found"}

            if response.status_code != 200:
                return {"success": False, "error": f"API error: {response.status_code}"}

            data = response.json()
            synced = data.get("syncedLyrics", "")
            plain = data.get("plainLyrics", "")

            if synced:
                result = {
                    "success": True,
                    "synced": True,
                    "lines": parse_lrc(synced),
                    "source": "lrclib.net"
                }
                save_cached_lyrics(title, artist, album, duration, player, result)
                return result
            elif plain:
                result = {
                    "success": True,
                    "synced": False,
                    "text": plain,
                    "source": "lrclib.net"
                }
                save_cached_lyrics(title, artist, album, duration, player, result)
                return result
            else:
                return {"success": False, "error": "No lyrics in response"}

    except httpx.TimeoutException:
        return {"success": False, "error": "Request timeout"}
    except Exception as e:
        return {"success": False, "error": str(e)}


def get_current_line(lines: list[dict], position: float) -> dict:
    """Get current lyric line based on playback position."""
    if not lines:
        return {"index": -1, "text": "", "next_text": ""}

    current_idx = -1
    for i, line in enumerate(lines):
        if line["time"] <= position:
            current_idx = i
        else:
            break

    if current_idx >= 0:
        current_text = lines[current_idx]["text"]
        next_text = lines[current_idx + 1]["text"] if current_idx + 1 < len(lines) else ""
        return {
            "index": current_idx,
            "text": current_text,
            "next_text": next_text,
            "time": lines[current_idx]["time"]
        }
    elif lines:
        return {
            "index": -1,
            "text": "",
            "next_text": lines[0]["text"],
            "time": 0
        }

    return {"index": -1, "text": "", "next_text": ""}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "error": "Usage: lyrics_fetcher.py <command> [args]"}))
        sys.exit(1)

    command = sys.argv[1]

    if command == "fetch":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing title"}))
            sys.exit(1)

        title = sys.argv[2]
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        album = sys.argv[4] if len(sys.argv) > 4 else ""
        duration = float(sys.argv[5]) if len(sys.argv) > 5 else 0
        player = sys.argv[6] if len(sys.argv) > 6 else ""

        result = fetch_lyrics(title, artist, album, duration, player)
        print(json.dumps(result, ensure_ascii=False))

    elif command == "mpris":
        # Direct MPRIS fetch without online fallback
        player = sys.argv[2] if len(sys.argv) > 2 else ""
        result = fetch_mpris_lyrics(player)
        if result:
            print(json.dumps(result, ensure_ascii=False))
        else:
            print(json.dumps({"success": False, "error": "No MPRIS lyrics available"}))

    elif command == "line":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Missing arguments"}))
            sys.exit(1)

        try:
            lines = json.loads(sys.argv[2])
            position = float(sys.argv[3])
            result = get_current_line(lines, position)
            print(json.dumps(result, ensure_ascii=False))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))

    else:
        print(json.dumps({"success": False, "error": f"Unknown command: {command}"}))
