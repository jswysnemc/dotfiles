#!/usr/bin/env python3
"""
天气数据获取脚本
使用 IP 定位获取城市，然后从 wttr.in 获取天气
支持缓存功能
"""

import urllib.request
import subprocess
import json
import re
import sys
import os
from pathlib import Path
from datetime import datetime, timedelta

# 缓存配置
CACHE_DIR = Path.home() / ".cache" / "quickshell-weather"
CACHE_FILE = CACHE_DIR / "weather_cache.json"
CACHE_DURATION = 30  # 缓存有效期（分钟）

def ensure_cache_dir():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

def load_cache():
    """加载缓存数据"""
    if not CACHE_FILE.exists():
        return None
    try:
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            cache = json.load(f)
            # 检查缓存是否过期
            cached_time = datetime.fromisoformat(cache.get("_cached_at", "2000-01-01"))
            if datetime.now() - cached_time < timedelta(minutes=CACHE_DURATION):
                cache["_from_cache"] = True
                return cache
    except:
        pass
    return None

def save_cache(data):
    """保存数据到缓存"""
    ensure_cache_dir()
    try:
        now = datetime.now()
        data["_cached_at"] = now.isoformat()
        data["_last_update"] = now.strftime("%H:%M")  # 保存刷新时间
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
    except:
        pass

def get_location_from_ip():
    """通过 IP 获取城市名"""
    try:
        # 使用 ipip.net 获取位置
        req = urllib.request.Request(
            "http://myip.ipip.net",
            headers={"User-Agent": "curl/7.0"}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            text = response.read().decode("utf-8")
            # 解析：当前 IP：xxx  来自于：中国 湖北 孝感  移动
            match = re.search(r"来自于：中国\s+\S+\s+(\S+)", text)
            if match:
                return match.group(1)
    except Exception as e:
        pass
    
    # 备用：使用 ip-api.com
    try:
        req = urllib.request.Request(
            "http://ip-api.com/json/?lang=zh-CN",
            headers={"User-Agent": "curl/7.0"}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode("utf-8"))
            return data.get("city", "武汉")
    except:
        pass
    
    return "武汉"  # 默认城市

def get_weather(city):
    """获取天气数据"""
    try:
        # 使用 curl 获取数据（更可靠）
        encoded_city = urllib.request.quote(city)
        url = f"http://wttr.in/{encoded_city}?format=j1&lang=zh"
        
        result = subprocess.run(
            ["curl", "-s", "--max-time", "15", url],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0 or not result.stdout.strip():
            return {"error": "无法获取天气数据"}
        
        data = json.loads(result.stdout)
        
        current = data.get("current_condition", [{}])[0]
        area = data.get("nearest_area", [{}])[0]
        weather_list = data.get("weather", [])
        
        # 天气代码到图标的映射
        weather_code = current.get("weatherCode", "")
        icon = get_weather_icon(weather_code)
        
        # 获取中文天气描述
        lang_zh = current.get("lang_zh", [{}])
        weather_desc = lang_zh[0].get("value", "") if lang_zh else ""
        if not weather_desc:
            weather_desc = current.get("weatherDesc", [{}])[0].get("value", "")
        
        # 构建返回数据
        weather_result = {
            "city": city,
            "area": area.get("areaName", [{}])[0].get("value", city),
            "region": area.get("region", [{}])[0].get("value", ""),
            "country": area.get("country", [{}])[0].get("value", ""),
            "temp": current.get("temp_C", "0"),
            "feelsLike": current.get("FeelsLikeC", "0"),
            "humidity": current.get("humidity", "0"),
            "windSpeed": current.get("windspeedKmph", "0"),
            "windDir": current.get("winddir16Point", ""),
            "visibility": current.get("visibility", ""),
            "uvIndex": current.get("uvIndex", "0"),
            "pressure": current.get("pressure", ""),
            "weatherCode": weather_code,
            "weatherDesc": weather_desc,
            "icon": icon,
            "observationTime": current.get("localObsDateTime", ""),
            "forecast": []
        }
        
        # 添加未来几天预报
        for day in weather_list[:3]:
            astronomy = day.get("astronomy", [{}])[0]
            hourly = day.get("hourly", [])
            
            # 获取白天天气描述
            day_weather = ""
            day_icon = "󰖐"
            if hourly:
                noon = hourly[len(hourly)//2] if len(hourly) > 1 else hourly[0]
                day_lang_zh = noon.get("lang_zh", [{}])
                day_weather = day_lang_zh[0].get("value", "") if day_lang_zh else ""
                if not day_weather:
                    day_weather = noon.get("weatherDesc", [{}])[0].get("value", "")
                day_icon = get_weather_icon(noon.get("weatherCode", ""))
            
            weather_result["forecast"].append({
                "date": day.get("date", ""),
                "maxTemp": day.get("maxtempC", "0"),
                "minTemp": day.get("mintempC", "0"),
                "avgTemp": day.get("avgtempC", "0"),
                "weatherDesc": day_weather,
                "icon": day_icon,
                "sunrise": astronomy.get("sunrise", ""),
                "sunset": astronomy.get("sunset", ""),
                "moonPhase": astronomy.get("moon_phase", "")
            })
        
        return weather_result
            
    except Exception as e:
        return {"error": str(e)}

def get_weather_icon(code):
    """根据天气代码返回 Nerd Font 图标"""
    code = str(code)
    icons = {
        # 晴天
        "113": "󰖙",  # Sunny
        # 多云
        "116": "󰖐",  # Partly cloudy
        "119": "󰖐",  # Cloudy
        "122": "󰖐",  # Overcast
        # 雾
        "143": "󰖑",  # Mist
        "248": "󰖑",  # Fog
        "260": "󰖑",  # Freezing fog
        # 小雨
        "176": "󰖗",  # Patchy rain
        "263": "󰖗",  # Patchy light drizzle
        "266": "󰖗",  # Light drizzle
        "293": "󰖗",  # Patchy light rain
        "296": "󰖗",  # Light rain
        "353": "󰖗",  # Light rain shower
        # 中雨/大雨
        "299": "󰖖",  # Moderate rain
        "302": "󰖖",  # Moderate rain
        "305": "󰖖",  # Heavy rain
        "308": "󰖖",  # Heavy rain
        "356": "󰖖",  # Moderate rain shower
        "359": "󰖖",  # Torrential rain
        # 雷雨
        "200": "󰙾",  # Thundery outbreaks
        "386": "󰙾",  # Patchy light rain with thunder
        "389": "󰙾",  # Moderate/heavy rain with thunder
        # 雪
        "179": "󰖘",  # Patchy snow
        "182": "󰖘",  # Patchy sleet
        "185": "󰖘",  # Patchy freezing drizzle
        "227": "󰖘",  # Blowing snow
        "230": "󰖘",  # Blizzard
        "281": "󰖘",  # Freezing drizzle
        "284": "󰖘",  # Heavy freezing drizzle
        "311": "󰖘",  # Light freezing rain
        "314": "󰖘",  # Moderate/heavy freezing rain
        "317": "󰖘",  # Light sleet
        "320": "󰖘",  # Moderate/heavy sleet
        "323": "󰖘",  # Patchy light snow
        "326": "󰖘",  # Light snow
        "329": "󰖘",  # Patchy moderate snow
        "332": "󰖘",  # Moderate snow
        "335": "󰖘",  # Patchy heavy snow
        "338": "󰖘",  # Heavy snow
        "350": "󰖘",  # Ice pellets
        "362": "󰖘",  # Light sleet showers
        "365": "󰖘",  # Moderate/heavy sleet showers
        "368": "󰖘",  # Light snow showers
        "371": "󰖘",  # Moderate/heavy snow showers
        "374": "󰖘",  # Light showers of ice pellets
        "377": "󰖘",  # Moderate/heavy showers of ice pellets
        "392": "󰖘",  # Patchy light snow with thunder
        "395": "󰖘",  # Moderate/heavy snow with thunder
    }
    return icons.get(code, "󰖐")

def format_waybar(data):
    """格式化为 waybar 显示格式"""
    if "error" in data:
        return json.dumps({
            "text": "󰖐 --°",
            "tooltip": data.get("error", "错误"),
            "class": "error"
        }, ensure_ascii=False)
    
    icon = data.get("icon", "󰖐")
    temp = data.get("temp", "--")
    desc = data.get("weatherDesc", "")
    city = data.get("city", "")
    feels = data.get("feelsLike", "--")
    humidity = data.get("humidity", "--")
    
    # 构建 tooltip
    tooltip_lines = [
        f"{icon} {desc}  {city}",
        f"温度: {temp}°C  体感: {feels}°C",
        f"湿度: {humidity}%"
    ]
    
    # 添加预报
    forecast = data.get("forecast", [])
    if forecast:
        tooltip_lines.append("")
        for day in forecast[:3]:
            day_icon = day.get("icon", "󰖐")
            max_t = day.get("maxTemp", "--")
            min_t = day.get("minTemp", "--")
            date = day.get("date", "")[-5:]  # MM-DD
            tooltip_lines.append(f"{date}  {day_icon} {min_t}°/{max_t}°")
    
    return json.dumps({
        "text": f"{icon} {temp}°",
        "tooltip": "\n".join(tooltip_lines),
        "class": "normal"
    }, ensure_ascii=False)

if __name__ == "__main__":
    # 解析参数
    args = sys.argv[1:]
    force_refresh = "--force" in args
    cache_only = "--cache" in args
    waybar_mode = "--waybar" in args
    
    # 获取城市参数
    city = None
    for arg in args:
        if not arg.startswith("--"):
            city = arg
            break
    
    # 如果只要缓存，直接返回
    if cache_only:
        cache = load_cache()
        if cache:
            if waybar_mode:
                print(format_waybar(cache))
            else:
                print(json.dumps(cache, ensure_ascii=False))
        else:
            if waybar_mode:
                print(json.dumps({"text": "󰖐 --°", "tooltip": "加载中...", "class": "loading"}, ensure_ascii=False))
            else:
                print(json.dumps({"error": "无缓存数据", "loading": True}, ensure_ascii=False))
        sys.exit(0)
    
    # 检查缓存（非强制刷新时）
    if not force_refresh:
        cache = load_cache()
        if cache:
            if waybar_mode:
                print(format_waybar(cache))
            else:
                print(json.dumps(cache, ensure_ascii=False))
            sys.exit(0)
    
    # 获取城市
    if not city:
        city = get_location_from_ip()
    
    # 获取天气并缓存
    weather = get_weather(city)
    if "error" not in weather:
        save_cache(weather)
    
    if waybar_mode:
        print(format_waybar(weather))
    else:
        print(json.dumps(weather, ensure_ascii=False))
