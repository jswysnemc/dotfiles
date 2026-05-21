#!/usr/bin/env python3
"""
World clock data for the QuickShell calendar popup.
"""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, tzinfo
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


DEFAULT_ZONES = [
    ("Asia/Shanghai", "上海", "中国"),
    ("Asia/Tokyo", "东京", "日本"),
    ("Asia/Singapore", "新加坡", "新加坡"),
    ("Asia/Dubai", "迪拜", "阿联酋"),
    ("Europe/London", "伦敦", "英国"),
    ("Europe/Berlin", "柏林", "德国"),
    ("America/New_York", "纽约", "美国"),
    ("America/Los_Angeles", "洛杉矶", "美国"),
]

WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def local_timezone_name() -> str:
    """Return the IANA timezone name when the system exposes it."""
    tz_env = os.environ.get("TZ")
    if tz_env:
        return tz_env.lstrip(":")

    try:
        localtime = os.path.realpath("/etc/localtime")
        marker = "/zoneinfo/"
        if marker in localtime:
            return localtime.split(marker, 1)[1]
    except OSError:
        pass

    return time.tzname[0] if time.tzname else "Local"


def safe_zoneinfo(name: str) -> tzinfo:
    try:
        return ZoneInfo(name)
    except ZoneInfoNotFoundError:
        return datetime.now().astimezone().tzinfo or ZoneInfo("UTC")


def format_offset(dt: datetime) -> str:
    offset = dt.utcoffset()
    if offset is None:
        return "+00:00"

    total_minutes = int(offset.total_seconds() // 60)
    sign = "+" if total_minutes >= 0 else "-"
    total_minutes = abs(total_minutes)
    hours, minutes = divmod(total_minutes, 60)
    return f"{sign}{hours:02d}:{minutes:02d}"


def build_zone(now: datetime, zone_name: str, city: str, country: str, local_date, is_local: bool = False) -> dict:
    zone = safe_zoneinfo(zone_name)
    current = now.astimezone(zone)
    seconds = current.hour * 3600 + current.minute * 60 + current.second

    return {
        "zone": zone_name,
        "city": city,
        "country": country,
        "time": current.strftime("%H:%M"),
        "dateText": f"{current.month}月{current.day}日 {WEEKDAYS[current.weekday()]}",
        "offset": format_offset(current),
        "dayDelta": (current.date() - local_date).days,
        "dayProgress": round(seconds / 86400, 4),
        "timezoneLabel": zone_name,
        "isLocal": is_local,
    }


def main() -> None:
    local_zone_name = local_timezone_name()
    local_zone = safe_zoneinfo(local_zone_name)
    now = datetime.now(local_zone)
    local_date = now.date()

    zones = []
    has_local = any(zone_name == local_zone_name for zone_name, _, _ in DEFAULT_ZONES)

    if not has_local:
        zones.append(build_zone(now, local_zone_name, "本地", local_zone_name, local_date, True))

    for zone_name, city, country in DEFAULT_ZONES:
        zones.append(build_zone(now, zone_name, city, country, local_date, zone_name == local_zone_name))

    local_info = build_zone(now, local_zone_name, "本地", local_zone_name, local_date, True)

    print(json.dumps({
        "updatedAt": now.isoformat(),
        "local": local_info,
        "zones": zones,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
