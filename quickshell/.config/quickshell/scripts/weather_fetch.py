#!/usr/bin/env python3
"""
Waybar 天气模块脚本
与 QuickShell 天气组件共享配置和缓存
使用 Open-Meteo API
"""

import json
import sys
import os
import urllib.request
from pathlib import Path
from datetime import datetime

# 路径配置 - 与 QuickShell 天气组件共享
XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
XDG_CACHE_HOME = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
CONFIG_PATH = Path(XDG_DATA_HOME) / "quickshell/weather/config.json"
CACHE_PATH = Path(XDG_CACHE_HOME) / "quickshell/weather/cache.json"
CACHE_MAX_AGE = 30 * 60 * 1000  # 30 minutes in ms

# 默认位置
DEFAULT_LAT = 39.9042
DEFAULT_LON = 116.4074
DEFAULT_LOCATION = "Beijing"

def load_config():
    """加载配置"""
    try:
        if CONFIG_PATH.exists():
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
    except:
        pass
    return {
        "latitude": DEFAULT_LAT,
        "longitude": DEFAULT_LON,
        "locationName": DEFAULT_LOCATION,
        "useCelsius": True
    }

def load_cache():
    """加载缓存"""
    try:
        if CACHE_PATH.exists():
            with open(CACHE_PATH, "r", encoding="utf-8") as f:
                cache = json.load(f)
                # 检查缓存是否有效
                now = int(datetime.now().timestamp() * 1000)
                if cache.get("time") and (now - cache["time"]) < CACHE_MAX_AGE:
                    return cache.get("data")
    except:
        pass
    return None

def save_cache(data, lat, lon):
    """保存缓存"""
    try:
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        cache = {
            "data": data,
            "lat": lat,
            "lon": lon,
            "time": int(datetime.now().timestamp() * 1000)
        }
        with open(CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False)
    except:
        pass

def fetch_weather(lat, lon):
    """从 Open-Meteo API 获取天气"""
    try:
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max&timezone=auto&forecast_days=7"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception as e:
        return None

def get_weather_icon(code):
    """根据天气代码返回 Nerd Font 图标"""
    if code == 0:
        return "󰖙"  # 晴朗
    elif code <= 3:
        return "󰖐"  # 多云
    elif code <= 48:
        return "󰖑"  # 雾
    elif code <= 57:
        return "󰖗"  # 毛毛雨
    elif code <= 67:
        return "󰖖"  # 雨
    elif code <= 77:
        return "󰖘"  # 雪
    elif code <= 86:
        return "󰖘"  # 阵雪
    else:
        return "󰙾"  # 雷暴

def get_weather_desc(code):
    """根据天气代码返回中文描述"""
    if code == 0:
        return "晴朗"
    elif code <= 3:
        return "多云"
    elif code <= 48:
        return "有雾"
    elif code <= 57:
        return "毛毛雨"
    elif code <= 67:
        return "小雨"
    elif code <= 77:
        return "小雪"
    elif code <= 86:
        return "阵雪"
    else:
        return "雷暴"

def format_temp(temp, use_celsius=True):
    """格式化温度"""
    if not use_celsius:
        temp = temp * 9 / 5 + 32
    return f"{round(temp)}"

def get_day_name(date_str, idx):
    """获取星期名称"""
    if idx == 0:
        return "今天"
    if idx == 1:
        return "明天"
    day = datetime.strptime(date_str, "%Y-%m-%d").weekday()
    names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    return names[day]

def format_waybar(data, config):
    """格式化为 waybar JSON 输出"""
    if not data or "current" not in data:
        return json.dumps({
            "text": " --",
            "tooltip": "无法获取天气数据",
            "class": "error"
        }, ensure_ascii=False)

    current = data["current"]
    daily = data.get("daily", {})
    use_celsius = config.get("useCelsius", True)
    location = config.get("locationName", "Unknown")

    code = current.get("weather_code", 0)
    temp = current.get("temperature_2m", 0)
    wind = current.get("wind_speed_10m", 0)
    humidity = current.get("relative_humidity_2m", 0)
    feels_like = current.get("apparent_temperature", temp)

    icon = get_weather_icon(code)
    desc = get_weather_desc(code)
    temp_str = format_temp(temp, use_celsius)
    feels_str = format_temp(feels_like, use_celsius)
    unit = "C" if use_celsius else "F"

    # 构建 tooltip
    tooltip_lines = [
        f"{icon} {desc}  {location}",
        f"",
        f"{temp_str}°{unit}  体感 {feels_str}°{unit}",
        f"湿度 {humidity}%  风速 {round(wind)} km/h"
    ]

    # 今日最高/最低
    if daily.get("temperature_2m_max") and daily.get("temperature_2m_min"):
        max_t = format_temp(daily["temperature_2m_max"][0], use_celsius)
        min_t = format_temp(daily["temperature_2m_min"][0], use_celsius)
        tooltip_lines.append(f"最高 {max_t}° / 最低 {min_t}°")

    # 日出日落
    if daily.get("sunrise") and daily.get("sunset"):
        sunrise = daily["sunrise"][0].split("T")[1] if "T" in daily["sunrise"][0] else daily["sunrise"][0]
        sunset = daily["sunset"][0].split("T")[1] if "T" in daily["sunset"][0] else daily["sunset"][0]
        tooltip_lines.append(f"日出 {sunrise}  日落 {sunset}")

    # 未来预报
    if daily.get("time"):
        tooltip_lines.append("")
        tooltip_lines.append("7 天预报")
        for i in range(min(7, len(daily["time"]))):
            day_name = get_day_name(daily["time"][i], i)
            day_icon = get_weather_icon(daily["weather_code"][i])
            day_max = format_temp(daily["temperature_2m_max"][i], use_celsius)
            day_min = format_temp(daily["temperature_2m_min"][i], use_celsius)
            precip = daily.get("precipitation_probability_max", [0] * 7)[i]
            precip_str = f" {precip}%" if precip > 0 else ""
            tooltip_lines.append(f"{day_name}  {day_icon}  {day_min}° ~ {day_max}°{precip_str}")

    return json.dumps({
        "text": f"{icon} {temp_str}°",
        "tooltip": "\n".join(tooltip_lines),
        "class": get_weather_class(code)
    }, ensure_ascii=False)

def get_weather_class(code):
    """根据天气代码返回 CSS class"""
    if code == 0:
        return "sunny"
    elif code <= 3:
        return "cloudy"
    elif code <= 48:
        return "foggy"
    elif code <= 77:
        return "rainy"
    else:
        return "stormy"

def main():
    args = sys.argv[1:]
    force_refresh = "--force" in args
    waybar_mode = "--waybar" in args

    config = load_config()
    lat = config.get("latitude", DEFAULT_LAT)
    lon = config.get("longitude", DEFAULT_LON)

    # 尝试使用缓存
    data = None
    if not force_refresh:
        data = load_cache()

    # 如果没有缓存或强制刷新，获取新数据
    if not data:
        data = fetch_weather(lat, lon)
        if data:
            save_cache(data, lat, lon)

    if waybar_mode:
        print(format_waybar(data, config))
    else:
        print(json.dumps(data or {"error": "无法获取天气"}, ensure_ascii=False))

if __name__ == "__main__":
    main()
