#!/usr/bin/env python3
"""
Get lunar calendar info for lockscreen.
Output JSON with today's date info including lunar calendar.
"""

import json
from datetime import datetime

try:
    from lunarcalendar import Converter, Solar
    HAS_LUNAR = True
except ImportError:
    HAS_LUNAR = False

# Chinese zodiac animals
ZODIAC_ANIMALS = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

# Heavenly stems
HEAVENLY_STEMS = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]

# Earthly branches
EARTHLY_BRANCHES = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

LUNAR_MONTHS = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]

LUNAR_DAYS = [
    "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
    "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
    "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
]

# Lunar festivals
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
    (4, 5): "清明节",
    (5, 1): "劳动节",
    (6, 1): "儿童节",
    (10, 1): "国庆节",
    (12, 25): "圣诞节",
}

WEEKDAYS = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]


def get_ganzhi_year(lunar_year):
    """Get Ganzhi (干支) year name."""
    stem_index = (lunar_year - 4) % 10
    branch_index = (lunar_year - 4) % 12
    return HEAVENLY_STEMS[stem_index] + EARTHLY_BRANCHES[branch_index]


def get_zodiac(lunar_year):
    """Get Chinese zodiac animal."""
    return ZODIAC_ANIMALS[(lunar_year - 4) % 12]


def get_today_info():
    """Get detailed info for today including lunar calendar."""
    now = datetime.now()

    result = {
        "year": now.year,
        "month": now.month,
        "day": now.day,
        "hour": now.hour,
        "minute": now.minute,
        "weekday": WEEKDAYS[now.weekday()],
        "hasLunar": HAS_LUNAR,
    }

    # Solar festival
    solar_festival = SOLAR_FESTIVALS.get((now.month, now.day), "")

    if HAS_LUNAR:
        try:
            solar = Solar(now.year, now.month, now.day)
            lunar = Converter.Solar2Lunar(solar)

            lunar_month_name = LUNAR_MONTHS[lunar.month - 1]
            lunar_day_name = LUNAR_DAYS[lunar.day - 1]

            # Lunar festival
            lunar_festival = LUNAR_FESTIVALS.get((lunar.month, lunar.day), "")

            # Check for 除夕 (day before Spring Festival)
            if lunar.month == 12 and lunar.day >= 29:
                # Check if next day is 正月初一
                try:
                    next_solar = Solar(now.year, now.month, now.day + 1)
                    next_lunar = Converter.Solar2Lunar(next_solar)
                    if next_lunar.month == 1 and next_lunar.day == 1:
                        lunar_festival = "除夕"
                except:
                    pass

            result.update({
                "lunarYear": lunar.year,
                "lunarMonth": lunar.month,
                "lunarDay": lunar.day,
                "lunarMonthName": lunar_month_name + "月",
                "lunarDayName": lunar_day_name,
                "lunarFull": f"{lunar_month_name}月{lunar_day_name}",
                "ganzhiYear": get_ganzhi_year(lunar.year),
                "zodiac": get_zodiac(lunar.year),
                "isLeapMonth": lunar.isleap,
                "lunarFestival": lunar_festival,
                "solarFestival": solar_festival,
                "festival": lunar_festival or solar_festival,
            })
        except Exception as e:
            result["error"] = str(e)
    else:
        result["solarFestival"] = solar_festival
        result["festival"] = solar_festival

    return result


if __name__ == "__main__":
    print(json.dumps(get_today_info(), ensure_ascii=False))
