#!/usr/bin/env python3
"""
Lunar calendar script for QuickShell calendar component.
"""

import sys
import json
from datetime import datetime
import calendar

try:
    from lunarcalendar import Converter, Solar, Lunar, DateNotExist
    HAS_LUNAR = True
except ImportError:
    HAS_LUNAR = False

# Chinese lunar festivals
LUNAR_FESTIVALS = {
    (1, 1): "春节",
    (1, 15): "元宵节",
    (5, 5): "端午节",
    (7, 7): "七夕",
    (7, 15): "中元节",
    (8, 15): "中秋节",
    (9, 9): "重阳节",
    (12, 8): "腊八节",
    (12, 30): "除夕",
}

# Solar festivals
SOLAR_FESTIVALS = {
    (1, 1): "元旦",
    (2, 14): "情人节",
    (3, 8): "妇女节",
    (3, 12): "植树节",
    (4, 1): "愚人节",
    (4, 5): "清明节",
    (5, 1): "劳动节",
    (5, 4): "青年节",
    (6, 1): "儿童节",
    (7, 1): "建党节",
    (8, 1): "建军节",
    (9, 10): "教师节",
    (10, 1): "国庆节",
    (12, 24): "平安夜",
    (12, 25): "圣诞节",
}

LUNAR_MONTHS = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]

LUNAR_DAYS = [
    "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
    "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
    "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
]


def get_lunar_info(year, month, day):
    """Get lunar calendar info for a date."""
    if not HAS_LUNAR:
        return {"lunar": "", "festival": get_solar_festival(month, day)}

    try:
        solar = Solar(year, month, day)
        lunar = Converter.Solar2Lunar(solar)

        lunar_month = LUNAR_MONTHS[lunar.month - 1]
        lunar_day = LUNAR_DAYS[lunar.day - 1]

        lunar_festival = LUNAR_FESTIVALS.get((lunar.month, lunar.day), "")
        solar_festival = SOLAR_FESTIVALS.get((month, day), "")
        festival = lunar_festival or solar_festival

        display = festival if festival else lunar_day
        if lunar.day == 1:
            display = f"{lunar_month}月" if not festival else festival

        return {
            "lunar": f"{lunar_month}月{lunar_day}",
            "lunarMonth": lunar.month,
            "lunarDay": lunar.day,
            "lunarYear": lunar.year,
            "display": display,
            "festival": festival,
            "isLeapMonth": lunar.isleap
        }
    except (DateNotExist, Exception):
        return {"lunar": "", "display": "", "festival": get_solar_festival(month, day)}


def get_solar_festival(month, day):
    """Get solar festival for a date."""
    return SOLAR_FESTIVALS.get((month, day), "")


def get_month_data(year, month):
    """Get full month calendar data."""
    first_weekday, days_in_month = calendar.monthrange(year, month)
    first_weekday = (first_weekday + 1) % 7

    today = datetime.now()

    if month == 1:
        prev_month_days = calendar.monthrange(year - 1, 12)[1]
    else:
        prev_month_days = calendar.monthrange(year, month - 1)[1]

    days = []

    for i in range(first_weekday):
        day_num = prev_month_days - first_weekday + 1 + i
        prev_month = month - 1 if month > 1 else 12
        prev_year = year if month > 1 else year - 1
        lunar_info = get_lunar_info(prev_year, prev_month, day_num)
        days.append({
            "day": day_num,
            "currentMonth": False,
            "isToday": False,
            "lunar": lunar_info.get("display", ""),
            "festival": lunar_info.get("festival", ""),
            "year": prev_year,
            "month": prev_month
        })

    for day in range(1, days_in_month + 1):
        lunar_info = get_lunar_info(year, month, day)
        is_today = (year == today.year and month == today.month and day == today.day)
        days.append({
            "day": day,
            "currentMonth": True,
            "isToday": is_today,
            "lunar": lunar_info.get("display", ""),
            "festival": lunar_info.get("festival", ""),
            "year": year,
            "month": month
        })

    remaining = 42 - len(days)
    next_month = month + 1 if month < 12 else 1
    next_year = year if month < 12 else year + 1
    for day in range(1, remaining + 1):
        lunar_info = get_lunar_info(next_year, next_month, day)
        days.append({
            "day": day,
            "currentMonth": False,
            "isToday": False,
            "lunar": lunar_info.get("display", ""),
            "festival": lunar_info.get("festival", ""),
            "year": next_year,
            "month": next_month
        })

    return {
        "year": year,
        "month": month,
        "days": days,
        "hasLunar": HAS_LUNAR
    }


def get_today_info():
    """Get detailed info for today."""
    today = datetime.now()
    lunar_info = get_lunar_info(today.year, today.month, today.day)

    weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]

    return {
        "year": today.year,
        "month": today.month,
        "day": today.day,
        "weekday": weekdays[today.weekday()],
        "lunar": lunar_info.get("lunar", ""),
        "festival": lunar_info.get("festival", ""),
        "hasLunar": HAS_LUNAR
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        today = datetime.now()
        result = get_month_data(today.year, today.month)
    elif sys.argv[1] == "today":
        result = get_today_info()
    elif sys.argv[1] == "month" and len(sys.argv) >= 4:
        year = int(sys.argv[2])
        month = int(sys.argv[3])
        result = get_month_data(year, month)
    else:
        result = {"error": "Invalid arguments"}

    print(json.dumps(result, ensure_ascii=False))
