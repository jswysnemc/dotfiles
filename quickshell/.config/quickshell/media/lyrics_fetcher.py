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
import httpx

LRCLIB_API = "https://lrclib.net/api"


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
    """Fetch lyrics. Priority: MPRIS local -> lrclib.net API."""
    # 1. Try MPRIS local lyrics first (musicfox, etc.)
    mpris_result = fetch_mpris_lyrics(player)
    if mpris_result:
        return mpris_result

    # 2. Fallback to lrclib.net API
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
                            return {
                                "success": True,
                                "synced": True,
                                "lines": parse_lrc(synced),
                                "source": "lrclib.net"
                            }
                        elif plain:
                            return {
                                "success": True,
                                "synced": False,
                                "text": plain,
                                "source": "lrclib.net"
                            }

                return {"success": False, "error": "Lyrics not found"}

            if response.status_code != 200:
                return {"success": False, "error": f"API error: {response.status_code}"}

            data = response.json()
            synced = data.get("syncedLyrics", "")
            plain = data.get("plainLyrics", "")

            if synced:
                return {
                    "success": True,
                    "synced": True,
                    "lines": parse_lrc(synced),
                    "source": "lrclib.net"
                }
            elif plain:
                return {
                    "success": True,
                    "synced": False,
                    "text": plain,
                    "source": "lrclib.net"
                }
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
