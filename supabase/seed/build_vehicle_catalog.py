"""يبني كتالوج السيارات (ماركة → موديل → جيل → فئة) ويُخرج:

  supabase/seed/vehicle_catalog.json      نسخة محلية للعميل (cache)
  supabase/seed/vehicle_catalog_seed.sql  بذور idempotent لقاعدة البيانات

شغّله بعد إضافة أي تعديل على البيانات:

    python supabase/seed/build_vehicle_catalog.py

المعرّفات نصية ثابتة (slug) وليست UUID حتى تبقى مستقرة بين النسخ والتخزين
المحلي، ويمكن تحديث الصفوف بـ upsert دون كسر مراجع `vehicles`.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS_BRANDS = ROOT / "assets" / "brands"
OUT_JSON = ROOT / "supabase" / "seed" / "vehicle_catalog.json"
OUT_SQL = ROOT / "supabase" / "seed" / "vehicle_catalog_seed.sql"

CATALOG_VERSION = 1
YEAR_MAX = 2026

BODY_TYPES = {
    "sedan", "hatchback", "suv", "crossover",
    "pickup", "van", "mpv", "coupe", "wagon",
}
FUELS = {"petrol", "diesel", "hybrid", "electric", "cng"}
TRANSMISSIONS = {"manual", "automatic", "cvt", "dct"}

# key: (label_en, label_ar, slug, engine_cc, fuel, transmission, horsepower)
ENGINES = {
    "p10": ("1.0L", "1.0 لتر", "10", 998, "petrol", "automatic", 68),
    "p12": ("1.2L", "1.2 لتر", "12", 1197, "petrol", "automatic", 82),
    "p14": ("1.4L", "1.4 لتر", "14", 1399, "petrol", "automatic", 95),
    "p15": ("1.5L", "1.5 لتر", "15", 1498, "petrol", "automatic", 105),
    "p16": ("1.6L", "1.6 لتر", "16", 1598, "petrol", "automatic", 122),
    "p18": ("1.8L", "1.8 لتر", "18", 1798, "petrol", "automatic", 140),
    "p20": ("2.0L", "2.0 لتر", "20", 1998, "petrol", "automatic", 165),
    "p24": ("2.4L", "2.4 لتر", "24", 2362, "petrol", "automatic", 180),
    "p25": ("2.5L", "2.5 لتر", "25", 2487, "petrol", "automatic", 203),
    "p27": ("2.7L", "2.7 لتر", "27", 2694, "petrol", "automatic", 166),
    "p30": ("3.0L", "3.0 لتر", "30", 2995, "petrol", "automatic", 250),
    "p35": ("3.5L", "3.5 لتر", "35", 3456, "petrol", "automatic", 280),
    "p40": ("4.0L", "4.0 لتر", "40", 3956, "petrol", "automatic", 275),
    "p56": ("5.6L", "5.6 لتر", "56", 5552, "petrol", "automatic", 400),
    "m16": ("1.6L Manual", "1.6 لتر عادي", "16m", 1598, "petrol", "manual", 115),
    "t10": ("1.0L Turbo", "1.0 لتر توربو", "10t", 998, "petrol", "dct", 100),
    "t12": ("1.2L Turbo", "1.2 لتر توربو", "12t", 1199, "petrol", "automatic", 130),
    "t14": ("1.4L Turbo", "1.4 لتر توربو", "14t", 1395, "petrol", "automatic", 150),
    "t15": ("1.5L Turbo", "1.5 لتر توربو", "15t", 1498, "petrol", "cvt", 156),
    "t16": ("1.6L Turbo", "1.6 لتر توربو", "16t", 1598, "petrol", "automatic", 180),
    "t20": ("2.0L Turbo", "2.0 لتر توربو", "20t", 1998, "petrol", "automatic", 245),
    "t25": ("2.5L Turbo", "2.5 لتر توربو", "25t", 2488, "petrol", "automatic", 250),
    "t30": ("3.0L Turbo", "3.0 لتر توربو", "30t", 2998, "petrol", "automatic", 340),
    "d16": ("1.6L Diesel", "1.6 لتر ديزل", "16d", 1560, "diesel", "manual", 105),
    "d20": ("2.0L Diesel", "2.0 لتر ديزل", "20d", 1995, "diesel", "automatic", 150),
    "d22": ("2.2L Diesel", "2.2 لتر ديزل", "22d", 2199, "diesel", "automatic", 160),
    "d24": ("2.4L Diesel", "2.4 لتر ديزل", "24d", 2442, "diesel", "manual", 150),
    "d25": ("2.5L Diesel", "2.5 لتر ديزل", "25d", 2494, "diesel", "manual", 160),
    "d28": ("2.8L Diesel", "2.8 لتر ديزل", "28d", 2755, "diesel", "automatic", 204),
    "d30": ("3.0L Diesel", "3.0 لتر ديزل", "30d", 2987, "diesel", "automatic", 250),
    "h15": ("1.5L Hybrid", "1.5 لتر هايبرد", "15h", 1497, "hybrid", "cvt", 116),
    "h18": ("1.8L Hybrid", "1.8 لتر هايبرد", "18h", 1798, "hybrid", "cvt", 140),
    "h20": ("2.0L Hybrid", "2.0 لتر هايبرد", "20h", 1987, "hybrid", "cvt", 180),
    "h25": ("2.5L Hybrid", "2.5 لتر هايبرد", "25h", 2487, "hybrid", "cvt", 218),
    "e": ("Electric", "كهربائي", "ev", 0, "electric", "automatic", 204),
    "e2": ("Electric Long Range", "كهربائي مدى طويل", "ev-lr", 0, "electric", "automatic", 218),
    "ea": ("Electric AWD", "كهربائي رباعي الدفع", "ev-awd", 0, "electric", "automatic", 265),
    "cng": ("1.6L CNG", "1.6 لتر غاز طبيعي", "16cng", 1598, "cng", "manual", 110),
}

# key: (name_ar, name_en)
TIERS = {
    "std": ("ستاندرد", "Standard"),
    "base": ("أساسي", "Base"),
    "gl": ("GL", "GL"),
    "gls": ("GLS", "GLS"),
    "lx": ("LX", "LX"),
    "ex": ("EX", "EX"),
    "exl": ("EX-L", "EX-L"),
    "s": ("S", "S"),
    "sv": ("SV", "SV"),
    "sl": ("SL", "SL"),
    "se": ("SE", "SE"),
    "sel": ("SEL", "SEL"),
    "hl": ("هاي لاين", "Highline"),
    "comf": ("كومفورت", "Comfort"),
    "smart": ("سمارت", "Smart"),
    "elite": ("إيليت", "Elite"),
    "mid": ("متوسط", "Mid"),
    "full": ("كامل", "Full"),
    "premium": ("بريميوم", "Premium"),
    "luxury": ("لوكشري", "Luxury"),
    "sport": ("سبورت", "Sport"),
    "line": ("S Line", "S Line"),
    "m": ("M Sport", "M Sport"),
    "amg": ("AMG Line", "AMG Line"),
    "gti": ("GTI", "GTI"),
}

DEFAULT_SEATS = {
    "sedan": 5, "hatchback": 5, "suv": 5, "crossover": 5,
    "pickup": 5, "van": 3, "mpv": 7, "coupe": 4, "wagon": 5,
}


def b(bid, ar, en, country, color, popular, models):
    return {
        "id": bid,
        "name_ar": ar,
        "name_en": en,
        "country_code": country,
        "brand_color": color,
        "is_popular": popular,
        "models": models,
    }


def m(slug, ar, en, body, years, engines, tiers, seats=None):
    if body not in BODY_TYPES:
        raise ValueError(f"{slug}: bad body type {body}")
    spans = []
    for raw in years.split(","):
        start, _, end = raw.strip().partition("-")
        y0 = int(start)
        y1 = int(end) if end.strip() else None
        if y1 is not None and y1 < y0:
            raise ValueError(f"{slug}: bad span {raw}")
        spans.append((y0, y1))
    for key in engines:
        if key not in ENGINES:
            raise ValueError(f"{slug}: unknown engine {key}")
    for key in tiers:
        if key not in TIERS:
            raise ValueError(f"{slug}: unknown tier {key}")
    return {
        "slug": slug,
        "name_ar": ar,
        "name_en": en,
        "body_type": body,
        "seats": seats or DEFAULT_SEATS[body],
        "spans": spans,
        "engines": engines,
        "tiers": tiers,
    }


BRANDS = [
    b("toyota", "تويوتا", "Toyota", "JP", "#EB0A1E", True, [
        m("corolla", "كورولا", "Corolla", "sedan", "2014-2019,2020-2026", ["p16", "h18"], ["std", "hl", "elite"]),
        m("yaris", "ياريس", "Yaris", "hatchback", "2011-2020,2021-2026", ["p12", "p15"], ["std", "hl"]),
        m("yaris-sedan", "ياريس سيدان", "Yaris Sedan", "sedan", "2013-2022,2023-2026", ["p15", "h15"], ["std", "hl"]),
        m("camry", "كامري", "Camry", "sedan", "2012-2017,2018-2024,2025-2026", ["p25", "h25"], ["std", "hl", "elite"]),
        m("rav4", "راف فور", "RAV4", "suv", "2013-2018,2019-2026", ["p20", "h25"], ["std", "hl"]),
        m("land-cruiser", "لاند كروزر", "Land Cruiser", "suv", "2010-2021,2022-2026", ["p40", "p56"], ["std", "hl", "elite"], seats=7),
        m("hilux", "هايلكس", "Hilux", "pickup", "2011-2015,2016-2025", ["d25", "d28"], ["std", "hl"]),
        m("fortuner", "فورتشنر", "Fortuner", "suv", "2015-2026", ["p27", "d28"], ["std", "hl"], seats=7),
        m("c-hr", "سي إتش آر", "C-HR", "crossover", "2017-2023", ["p18", "h18"], ["std", "hl"]),
        m("prius", "بريوس", "Prius", "hatchback", "2012-2015,2016-2022,2023-2026", ["h18"], ["std", "hl", "elite"]),
        m("rush", "راش", "Rush", "suv", "2018-2026", ["p15"], ["std", "hl"], seats=7),
        m("hiace", "هاي إيس", "Hiace", "van", "2012-2019,2020-2026", ["d28", "p27"], ["std", "hl"]),
        m("innova", "إنوفا", "Innova", "mpv", "2016-2020,2021-2026", ["p20", "d28"], ["std", "hl"]),
    ]),
    b("hyundai", "هيونداي", "Hyundai", "KR", "#002C5F", True, [
        m("elantra", "إلنترا", "Elantra", "sedan", "2011-2015,2016-2020,2021-2026", ["p16", "p20"], ["gl", "smart", "hl"]),
        m("accent", "أكسنت", "Accent", "sedan", "2011-2017,2018-2026", ["p14", "p16"], ["std", "gl", "hl"]),
        m("tucson", "توسان", "Tucson", "suv", "2010-2015,2016-2020,2021-2026", ["p16", "t14", "h20"], ["gl", "smart", "hl"]),
        m("creta", "كريتا", "Creta", "crossover", "2015-2019,2020-2026", ["p15", "t15"], ["gl", "smart", "hl"]),
        m("santa-fe", "سانتا في", "Santa Fe", "suv", "2013-2018,2019-2023,2024-2026", ["p20", "p24", "h20"], ["gl", "smart", "hl"], seats=7),
        m("i10", "آي 10", "i10", "hatchback", "2014-2019,2020-2026", ["p10", "p12"], ["std", "gl"]),
        m("grand-i10", "جراند آي 10", "Grand i10", "hatchback", "2014-2019,2020-2026", ["p12"], ["std", "gl", "hl"]),
        m("verna", "فيرنا", "Verna", "sedan", "2010-2017,2018-2026", ["p14", "p16"], ["std", "gl"]),
        m("bayon", "بايون", "Bayon", "crossover", "2021-2026", ["p10", "t10"], ["std", "gl", "hl"]),
        m("sonata", "سوناتا", "Sonata", "sedan", "2011-2014,2015-2019,2020-2026", ["p20", "p25", "h20"], ["gl", "smart", "hl"]),
        m("staria", "ستاريا", "Staria", "mpv", "2021-2026", ["d28", "p35"], ["std", "hl"]),
        m("elantra-n", "إلنترا N", "Elantra N", "sedan", "2018-2020,2021-2026", ["t20"], ["sport"]),
    ]),
    b("nissan", "نيسان", "Nissan", "JP", "#C3002F", True, [
        m("sunny", "صني", "Sunny", "sedan", "2012-2019,2020-2026", ["p15", "m16"], ["std", "sv", "hl"]),
        m("sentra", "سنترا", "Sentra", "sedan", "2013-2019,2020-2026", ["p16", "p20"], ["s", "sv", "sl"]),
        m("altima", "ألتيما", "Altima", "sedan", "2013-2018,2019-2026", ["p25", "t20"], ["s", "sv", "sl"]),
        m("x-trail", "إكس تريل", "X-Trail", "suv", "2014-2021,2022-2026", ["p20", "p25"], ["s", "sv", "sl"], seats=7),
        m("juke", "جوك", "Juke", "crossover", "2011-2019,2020-2026", ["t10", "p16"], ["std", "hl"]),
        m("qashqai", "قشقاي", "Qashqai", "crossover", "2014-2020,2021-2026", ["p16", "t14"], ["std", "hl"]),
        m("kicks", "كيكس", "Kicks", "crossover", "2017-2026", ["p16"], ["std", "hl"]),
        m("pathfinder", "باثفايندر", "Pathfinder", "suv", "2013-2021,2022-2026", ["p35", "h25"], ["s", "sv", "sl"], seats=7),
        m("patrol", "باترول", "Patrol", "suv", "2010-2022,2023-2026", ["p40", "p56"], ["std", "hl", "elite"], seats=7),
        m("navara", "نافارا", "Navara", "pickup", "2015-2026", ["d25", "d28"], ["std", "hl"]),
        m("micra", "ميكرا", "Micra", "hatchback", "2010-2016,2017-2023", ["p12", "p15"], ["std", "hl"]),
    ]),
    b("chevrolet", "شيفروليه", "Chevrolet", "US", "#D4AF37", True, [
        m("optra", "أوبترا", "Optra", "sedan", "2010-2015,2016-2023", ["p16", "p18"], ["std", "hl"]),
        m("aveo", "أفيو", "Aveo", "sedan", "2011-2017,2018-2026", ["p14", "p16"], ["std", "hl"]),
        m("cruze", "كروز", "Cruze", "sedan", "2010-2016,2017-2023", ["p16", "t14"], ["std", "hl"]),
        m("malibu", "ماليبو", "Malibu", "sedan", "2013-2019,2020-2026", ["p20", "t20"], ["std", "hl", "elite"]),
        m("captiva", "كابتيفا", "Captiva", "suv", "2011-2018", ["p20", "p24"], ["std", "hl"], seats=7),
        m("groove", "جروف", "Groove", "crossover", "2020-2026", ["p15"], ["std", "hl"]),
        m("tracker", "تراكر", "Tracker", "crossover", "2013-2019,2020-2026", ["p14", "t10"], ["std", "hl"]),
        m("trailblazer", "ترايل بليزر", "Trailblazer", "suv", "2013-2020,2021-2026", ["p20", "p30"], ["std", "hl"], seats=7),
        m("tahoe", "تاهو", "Tahoe", "suv", "2015-2020,2021-2026", ["p56"], ["std", "hl", "elite"], seats=7),
        m("n300", "إن 300", "N300", "van", "2012-2026", ["p12"], ["std"]),
        m("spark", "سبارك", "Spark", "hatchback", "2010-2015,2016-2022", ["p10", "p12"], ["std", "hl"]),
    ]),
    b("kia", "كيا", "Kia", "KR", "#05141F", True, [
        m("cerato", "سيراتو", "Cerato", "sedan", "2010-2013,2014-2018,2019-2026", ["p16", "p20"], ["std", "hl", "elite"]),
        m("rio", "ريو", "Rio", "sedan", "2012-2017,2018-2026", ["p14", "p16"], ["std", "hl"]),
        m("sportage", "سبورتاج", "Sportage", "suv", "2011-2015,2016-2021,2022-2026", ["p20", "t16", "h20"], ["std", "hl", "elite"]),
        m("sorento", "سورينتو", "Sorento", "suv", "2013-2020,2021-2026", ["p24", "t20"], ["std", "hl", "elite"], seats=7),
        m("picanto", "بيكانتو", "Picanto", "hatchback", "2012-2017,2018-2026", ["p10", "p12"], ["std", "hl"]),
        m("carens", "كارينز", "Carens", "mpv", "2013-2022", ["p20", "d20"], ["std", "hl"]),
        m("seltos", "سيلتوس", "Seltos", "crossover", "2020-2026", ["p16", "t14"], ["std", "hl", "elite"]),
        m("k5", "كي 5", "K5", "sedan", "2011-2015,2016-2020,2021-2026", ["p20", "t20", "h20"], ["std", "hl", "elite"]),
        m("sonet", "سونيت", "Sonet", "crossover", "2021-2026", ["p12", "t10"], ["std", "hl"]),
        m("carnival", "كارنيفال", "Carnival", "mpv", "2015-2020,2021-2026", ["p35", "d28"], ["std", "hl", "elite"]),
        m("pegas", "بيجاس", "Pegas", "sedan", "2018-2026", ["p14"], ["std", "hl"]),
    ]),
    b("mg", "إم جي", "MG", "CN", "#C8102E", True, [
        m("mg5", "إم جي 5", "MG5", "sedan", "2013-2018,2020-2026", ["p15", "t15"], ["std", "hl", "elite"]),
        m("mg6", "إم جي 6", "MG6", "sedan", "2011-2018,2019-2026", ["t15", "t20"], ["std", "hl"]),
        m("mg7", "إم جي 7", "MG7", "sedan", "2023-2026", ["t20"], ["std", "hl", "elite"]),
        m("zs", "زي إس", "ZS", "crossover", "2018-2026", ["p15", "e"], ["std", "hl", "elite"]),
        m("hs", "إتش إس", "HS", "suv", "2019-2026", ["t15", "t20", "h20"], ["std", "hl", "elite"]),
        m("rx5", "آر إكس 5", "RX5", "suv", "2017-2026", ["t15", "t20"], ["std", "hl"]),
        m("gt", "جي تي", "GT", "sedan", "2020-2026", ["t20"], ["std", "hl"]),
        m("marvel-r", "مارفل آر", "Marvel R", "suv", "2021-2026", ["ea"], ["std", "hl"]),
        m("comet", "كوميت", "Comet", "hatchback", "2023-2026", ["e"], ["std", "hl"]),
        m("whale", "ويل", "Whale", "suv", "2023-2026", ["e2"], ["std", "hl"]),
    ]),
    b("chery", "شيري", "Chery", "CN", "#D6001C", True, [
        m("tiggo-3", "تيجو 3", "Tiggo 3", "suv", "2015-2026", ["p15", "p16"], ["std", "hl"]),
        m("tiggo-4", "تيجو 4", "Tiggo 4", "suv", "2018-2026", ["p15", "t15"], ["std", "hl", "elite"]),
        m("tiggo-5", "تيجو 5", "Tiggo 5", "suv", "2014-2019", ["p20"], ["std", "hl"]),
        m("tiggo-7", "تيجو 7", "Tiggo 7", "suv", "2017-2026", ["t15", "t16"], ["std", "hl", "elite"], seats=7),
        m("tiggo-8", "تيجو 8", "Tiggo 8", "suv", "2018-2026", ["t16", "t20"], ["std", "hl", "elite"], seats=7),
        m("arrizo-5", "أريزو 5", "Arrizo 5", "sedan", "2016-2026", ["p15", "t15"], ["std", "hl"]),
        m("arrizo-6", "أريزو 6", "Arrizo 6", "sedan", "2019-2026", ["t15"], ["std", "hl"]),
        m("tiggo-9", "تيجو 9", "Tiggo 9", "suv", "2023-2026", ["t20"], ["std", "hl", "elite"], seats=7),
    ]),
    b("byd", "بي واي دي", "BYD", "CN", "#C8102E", True, [
        m("f3", "إف 3", "F3", "sedan", "2010-2020", ["p15"], ["std", "hl"]),
        m("seal", "سيل", "Seal", "sedan", "2022-2026", ["e", "ea"], ["std", "hl", "elite"]),
        m("dolphin", "دولفين", "Dolphin", "hatchback", "2022-2026", ["e"], ["std", "hl"]),
        m("atto-3", "أتو 3", "Atto 3", "crossover", "2022-2026", ["e"], ["std", "hl"]),
        m("han", "هان", "Han", "sedan", "2020-2026", ["ea"], ["std", "hl", "elite"]),
        m("tang", "تانج", "Tang", "suv", "2019-2026", ["ea"], ["std", "hl"], seats=7),
        m("song-plus", "سونج بلاس", "Song Plus", "suv", "2021-2026", ["h20"], ["std", "hl"]),
        m("qin", "تشين", "Qin", "sedan", "2021-2026", ["e"], ["std", "hl"]),
        m("seagull", "سيجول", "Seagull", "hatchback", "2023-2026", ["e"], ["std", "hl"]),
    ]),
    b("renault", "رينو", "Renault", "FR", "#EFDF00", True, [
        m("logan", "لوجان", "Logan", "sedan", "2013-2020,2021-2026", ["p16", "m16"], ["std", "hl"]),
        m("sandero", "سانديرو", "Sandero", "hatchback", "2013-2020,2021-2026", ["p16"], ["std", "hl"]),
        m("duster", "داستر", "Duster", "suv", "2014-2017,2018-2024", ["p16", "p20", "d20"], ["std", "hl"]),
        m("megane", "ميجان", "Megane", "hatchback", "2010-2016,2017-2022", ["p16", "t14"], ["std", "hl"]),
        m("koleos", "كوليو", "Koleos", "suv", "2012-2016,2017-2023", ["p20", "d20"], ["std", "hl"]),
        m("captur", "كابتشر", "Captur", "crossover", "2014-2019,2020-2026", ["p12", "t10"], ["std", "hl"]),
        m("fluence", "فلوانس", "Fluence", "sedan", "2010-2016", ["p16"], ["std", "hl"]),
        m("symbol", "سيمبول", "Symbol", "sedan", "2013-2021", ["p16"], ["std", "hl"]),
        m("express", "إكسبريس", "Express", "van", "2010-2021,2022-2026", ["d20"], ["std"]),
    ]),
    b("suzuki", "سوزوكي", "Suzuki", "JP", "#003399", True, [
        m("alto", "ألتو", "Alto", "hatchback", "2010-2015,2016-2026", ["p10"], ["std", "hl"]),
        m("celerio", "سيليريو", "Celerio", "hatchback", "2015-2026", ["p10"], ["std", "hl"]),
        m("swift", "سويفت", "Swift", "hatchback", "2011-2017,2018-2026", ["p12", "p14"], ["std", "hl"]),
        m("dzire", "ديزاير", "Dzire", "sedan", "2012-2017,2018-2026", ["p12"], ["std", "hl"]),
        m("baleno", "بالينو", "Baleno", "hatchback", "2016-2026", ["p12"], ["std", "hl"]),
        m("ertiga", "إرتيجا", "Ertiga", "mpv", "2013-2018,2019-2026", ["p14"], ["std", "hl"]),
        m("vitara", "فيتارا", "Vitara", "suv", "2015-2026", ["p16", "t14"], ["std", "hl"]),
        m("jimny", "جيمني", "Jimny", "suv", "2010-2018,2019-2026", ["p15"], ["std", "hl"]),
        m("s-presso", "إس بريسو", "S-Presso", "crossover", "2020-2026", ["p10"], ["std", "hl"]),
        m("fronx", "فرونكس", "Fronx", "crossover", "2023-2026", ["p12", "t10"], ["std", "hl"]),
    ]),
    b("mitsubishi", "ميتسوبيشي", "Mitsubishi", "JP", "#E60012", True, [
        m("lancer", "لانسر", "Lancer", "sedan", "2008-2017", ["p16", "p20"], ["std", "hl"]),
        m("attrage", "أتراج", "Attrage", "sedan", "2014-2026", ["p12"], ["std", "hl"]),
        m("mirage", "ميراج", "Mirage", "hatchback", "2013-2023", ["p12"], ["std", "hl"]),
        m("eclipse-cross", "إكليبس كروس", "Eclipse Cross", "crossover", "2018-2026", ["p15", "t15", "h20"], ["std", "hl"]),
        m("outlander", "أوتلاندر", "Outlander", "suv", "2013-2021,2022-2026", ["p20", "h20"], ["std", "hl"], seats=7),
        m("pajero", "باجيرو", "Pajero", "suv", "2007-2021", ["p30", "d30"], ["std", "hl", "elite"], seats=7),
        m("xpander", "إكسباندر", "Xpander", "mpv", "2018-2026", ["p15"], ["std", "hl"]),
        m("l200", "إل 200", "L200", "pickup", "2010-2019,2020-2026", ["d24", "d25"], ["std", "hl"]),
        m("asx", "إيه إس إكس", "ASX", "crossover", "2011-2022", ["p16", "p20"], ["std", "hl"]),
    ]),
    b("fiat", "فيات", "Fiat", "IT", "#A6192E", True, [
        m("tipo", "تيبو", "Tipo", "sedan", "2016-2026", ["p14", "d20"], ["std", "hl"]),
        m("panda", "باندا", "Panda", "hatchback", "2012-2026", ["p10", "p12"], ["std", "hl"]),
        m("500", "500", "500", "hatchback", "2008-2026", ["p12", "e"], ["std", "hl"]),
        m("doblo", "دوبلو", "Doblo", "van", "2010-2022,2023-2026", ["d20", "p14"], ["std", "hl"]),
        m("punto", "بونتو", "Punto", "hatchback", "2010-2018", ["p12", "p14"], ["std", "hl"]),
    ]),
    b("honda", "هوندا", "Honda", "JP", "#CC0000", False, [
        m("civic", "سيفيك", "Civic", "sedan", "2012-2015,2016-2021,2022-2026", ["p18", "t15", "h20"], ["lx", "ex", "exl"]),
        m("city", "سيتي", "City", "sedan", "2014-2019,2020-2026", ["p15", "h18"], ["lx", "ex", "exl"]),
        m("accord", "أكورد", "Accord", "sedan", "2013-2017,2018-2022,2023-2026", ["p24", "t15", "h20"], ["lx", "ex", "exl"]),
        m("cr-v", "سي آر في", "CR-V", "suv", "2012-2016,2017-2022,2023-2026", ["p24", "t15", "h20"], ["lx", "ex", "exl"], seats=5),
        m("hr-v", "إتش آر في", "HR-V", "crossover", "2015-2021,2022-2026", ["p18", "h18"], ["lx", "ex"]),
        m("jazz", "جاز", "Jazz", "hatchback", "2009-2014,2015-2020", ["p12", "p15"], ["lx", "ex"]),
        m("odyssey", "أوديسي", "Odyssey", "mpv", "2011-2017,2018-2026", ["p35", "h25"], ["lx", "ex", "exl"], seats=7),
    ]),
    b("mazda", "مازدا", "Mazda", "JP", "#101010", False, [
        m("mazda-3", "مازدا 3", "Mazda 3", "sedan", "2011-2013,2014-2019,2020-2026", ["p16", "p20"], ["std", "hl", "elite"]),
        m("mazda-6", "مازدا 6", "Mazda 6", "sedan", "2013-2017,2018-2026", ["p20", "p25"], ["std", "hl", "elite"]),
        m("cx-3", "سي إكس 3", "CX-3", "crossover", "2015-2022", ["p20"], ["std", "hl"]),
        m("cx-5", "سي إكس 5", "CX-5", "suv", "2013-2017,2018-2026", ["p20", "p25", "d20"], ["std", "hl", "elite"]),
        m("cx-30", "سي إكس 30", "CX-30", "crossover", "2020-2026", ["p20"], ["std", "hl"]),
        m("cx-9", "سي إكس 9", "CX-9", "suv", "2013-2015,2016-2023", ["p25"], ["std", "hl", "elite"], seats=7),
        m("mx-5", "إم إكس 5", "MX-5", "coupe", "2016-2026", ["p20"], ["std", "hl"]),
    ]),
    b("peugeot", "بيجو", "Peugeot", "FR", "#003C84", False, [
        m("301", "301", "301", "sedan", "2013-2020,2021-2026", ["p16", "d20"], ["std", "hl"]),
        m("208", "208", "208", "hatchback", "2012-2019,2020-2026", ["p12", "t10", "e"], ["std", "hl"]),
        m("2008", "2008", "2008", "crossover", "2013-2019,2020-2026", ["p12", "t10", "e"], ["std", "hl"]),
        m("308", "308", "308", "hatchback", "2014-2021,2022-2026", ["t14", "d20"], ["std", "hl"]),
        m("3008", "3008", "3008", "suv", "2017-2026", ["t16", "h20"], ["std", "hl", "elite"]),
        m("5008", "5008", "5008", "suv", "2018-2026", ["t16", "d20"], ["std", "hl", "elite"], seats=7),
        m("508", "508", "508", "sedan", "2011-2018,2019-2026", ["t16", "t20"], ["std", "hl"]),
        m("partner", "بارتنر", "Partner", "van", "2010-2018,2019-2026", ["d20", "p16"], ["std", "hl"]),
    ]),
    b("volkswagen", "فولكس واجن", "Volkswagen", "DE", "#001E50", False, [
        m("golf", "جولف", "Golf", "hatchback", "2013-2019,2020-2026", ["p14", "t14", "t20"], ["std", "hl", "gti"]),
        m("passat", "باسات", "Passat", "sedan", "2011-2015,2016-2023", ["t14", "t20"], ["std", "hl", "elite"]),
        m("jetta", "جيتا", "Jetta", "sedan", "2011-2018,2019-2026", ["t14", "t20"], ["std", "hl"]),
        m("polo", "بولو", "Polo", "hatchback", "2010-2017,2018-2026", ["p14", "t10"], ["std", "hl"]),
        m("tiguan", "تيغوان", "Tiguan", "suv", "2012-2016,2017-2026", ["t14", "t20", "d20"], ["std", "hl", "elite"], seats=5),
        m("touareg", "توارق", "Touareg", "suv", "2011-2018,2019-2026", ["t20", "t30"], ["std", "hl", "elite"]),
        m("t-roc", "تي روك", "T-Roc", "crossover", "2018-2026", ["t10", "t14"], ["std", "hl"]),
        m("caddy", "كادي", "Caddy", "van", "2011-2020,2021-2026", ["d20", "t14"], ["std", "hl"]),
    ]),
    b("skoda", "سكودا", "Skoda", "CZ", "#4BA82E", False, [
        m("octavia", "أوكتافيا", "Octavia", "sedan", "2013-2020,2021-2026", ["t14", "t20"], ["std", "hl", "elite"]),
        m("fabia", "فابيا", "Fabia", "hatchback", "2015-2021,2022-2026", ["p12", "t10"], ["std", "hl"]),
        m("superb", "سوبيرب", "Superb", "sedan", "2015-2023,2024-2026", ["t16", "t20"], ["std", "hl", "elite"]),
        m("kodiaq", "كودياك", "Kodiaq", "suv", "2017-2026", ["t16", "t20", "d20"], ["std", "hl", "elite"], seats=7),
        m("karoq", "كاروق", "Karoq", "suv", "2018-2026", ["t14", "t16"], ["std", "hl"]),
        m("kushaq", "كوشاك", "Kushaq", "crossover", "2021-2026", ["t10", "t15"], ["std", "hl"]),
        m("scala", "سكالا", "Scala", "hatchback", "2019-2026", ["t10", "t14"], ["std", "hl"]),
    ]),
    b("geely", "جيلي", "Geely", "CN", "#003B71", False, [
        m("emgrand-7", "إمجراند 7", "Emgrand 7", "sedan", "2012-2020,2021-2026", ["p15", "t15"], ["std", "hl"]),
        m("coolray", "كولراي", "Coolray", "crossover", "2019-2026", ["t15"], ["std", "hl", "elite"]),
        m("tugella", "توجيلا", "Tugella", "suv", "2020-2026", ["t20"], ["std", "hl"]),
        m("okavango", "أوكافانجو", "Okavango", "suv", "2021-2026", ["t20"], ["std", "hl", "elite"], seats=7),
        m("starray", "ستاراي", "Starray", "suv", "2022-2026", ["t15", "t20"], ["std", "hl"]),
        m("emgrand-ec7", "إمجراند إي سي 7", "Emgrand EC7", "sedan", "2010-2018", ["p15"], ["std", "hl"]),
    ]),
    b("haval", "هافال", "Haval", "CN", "#C60C30", False, [
        m("jolion", "جوليون", "Jolion", "crossover", "2021-2026", ["t15", "h20"], ["std", "hl", "elite"]),
        m("h6", "إتش 6", "H6", "suv", "2012-2017,2018-2026", ["t15", "t20", "h20"], ["std", "hl", "elite"]),
        m("h9", "إتش 9", "H9", "suv", "2015-2026", ["t20", "d20"], ["std", "hl", "elite"], seats=7),
        m("dargo", "دارجو", "Dargo", "suv", "2022-2026", ["t20"], ["std", "hl"]),
        m("m6", "إم 6", "M6", "suv", "2018-2026", ["t15"], ["std", "hl"], seats=7),
    ]),
    b("changan", "تشانجان", "Changan", "CN", "#004A99", False, [
        m("eado", "إيدو", "Eado", "sedan", "2014-2019,2020-2026", ["p16", "t15"], ["std", "hl"]),
        m("alsvin", "ألسفين", "Alsvin", "sedan", "2019-2026", ["p14", "t10"], ["std", "hl"]),
        m("cs35", "سي إس 35", "CS35", "crossover", "2013-2018,2019-2026", ["p16", "t15"], ["std", "hl"]),
        m("cs55", "سي إس 55", "CS55", "suv", "2017-2026", ["t15", "t20"], ["std", "hl", "elite"]),
        m("cs75", "سي إس 75", "CS75", "suv", "2014-2019,2020-2026", ["t15", "t20"], ["std", "hl", "elite"]),
        m("uni-k", "يوني كي", "UNI-K", "suv", "2021-2026", ["t20"], ["std", "hl", "elite"]),
        m("uni-t", "يوني تي", "UNI-T", "suv", "2020-2026", ["t15", "t20"], ["std", "hl"]),
        m("hunter", "هانتر", "Hunter", "pickup", "2020-2026", ["d25", "p20"], ["std", "hl"]),
    ]),
    b("jetour", "جيتور", "Jetour", "CN", "#0D3B8E", False, [
        m("x70", "إكس 70", "X70", "suv", "2018-2026", ["t15", "t20"], ["std", "hl", "elite"], seats=7),
        m("x90", "إكس 90", "X90", "suv", "2019-2026", ["t20"], ["std", "hl", "elite"], seats=7),
        m("dashing", "داشينج", "Dashing", "suv", "2022-2026", ["t15", "t20"], ["std", "hl"]),
        m("t2", "تي 2", "T2", "suv", "2023-2026", ["t20"], ["std", "hl", "elite"], seats=7),
        m("x50", "إكس 50", "X50", "crossover", "2023-2026", ["t15"], ["std", "hl"]),
    ]),
    b("opel", "أوبل", "Opel", "DE", "#F7A600", False, [
        m("astra", "أسترا", "Astra", "hatchback", "2010-2015,2016-2021,2022-2026", ["p14", "t14"], ["std", "hl", "elite"]),
        m("corsa", "كورسا", "Corsa", "hatchback", "2011-2014,2015-2019,2020-2026", ["p12", "t10", "e"], ["std", "hl"]),
        m("insignia", "إنسيجنيا", "Insignia", "sedan", "2010-2017", ["t16", "t20"], ["std", "hl", "elite"]),
        m("mokka", "موكا", "Mokka", "crossover", "2013-2019,2020-2026", ["p16", "t10", "e"], ["std", "hl"]),
        m("crossland", "كروسلاند", "Crossland", "crossover", "2017-2026", ["p12", "t10"], ["std", "hl"]),
        m("grandland", "جراندلاند", "Grandland", "suv", "2018-2026", ["t14", "t16", "h20"], ["std", "hl", "elite"]),
        m("zafira", "زافيرا", "Zafira", "mpv", "2011-2019", ["p16", "d20"], ["std", "hl"]),
    ]),
    b("bmw", "بي إم دبليو", "BMW", "DE", "#0066B1", False, [
        m("1-series", "الفئة الأولى", "1 Series", "hatchback", "2011-2019,2020-2026", ["p16", "t20"], ["std", "sport", "m"]),
        m("3-series", "الفئة الثالثة", "3 Series", "sedan", "2012-2018,2019-2026", ["p20", "t20", "h20"], ["std", "sport", "m"]),
        m("5-series", "الفئة الخامسة", "5 Series", "sedan", "2010-2016,2017-2023,2024-2026", ["p20", "t20", "h20"], ["std", "sport", "m"]),
        m("7-series", "الفئة السابعة", "7 Series", "sedan", "2009-2015,2016-2022,2023-2026", ["p30", "t30", "ea"], ["std", "luxury", "m"]),
        m("x1", "إكس 1", "X1", "crossover", "2013-2015,2016-2022,2023-2026", ["p20", "t20"], ["std", "sport", "m"]),
        m("x3", "إكس 3", "X3", "suv", "2011-2017,2018-2026", ["p20", "t20", "h20"], ["std", "sport", "m"]),
        m("x5", "إكس 5", "X5", "suv", "2014-2018,2019-2026", ["p30", "t30", "h25"], ["std", "sport", "m"], seats=5),
        m("x6", "إكس 6", "X6", "suv", "2015-2019,2020-2026", ["p30", "t30"], ["std", "sport", "m"]),
        m("x7", "إكس 7", "X7", "suv", "2019-2026", ["p30", "t30"], ["std", "luxury", "m"], seats=7),
        m("i4", "آي 4", "i4", "sedan", "2022-2026", ["ea"], ["std", "sport", "m"]),
        m("ix3", "آي إكس 3", "iX3", "suv", "2021-2026", ["e"], ["std", "sport"]),
    ]),
    b("mercedes", "مرسيدس-بنز", "Mercedes-Benz", "DE", "#111111", False, [
        m("a-class", "الفئة A", "A-Class", "hatchback", "2013-2018,2019-2026", ["p16", "t20"], ["std", "amg"]),
        m("c-class", "الفئة C", "C-Class", "sedan", "2014-2021,2022-2026", ["p20", "t20", "h20"], ["std", "amg"]),
        m("e-class", "الفئة E", "E-Class", "sedan", "2010-2016,2017-2023,2024-2026", ["p20", "t20", "h20"], ["std", "amg"]),
        m("s-class", "الفئة S", "S-Class", "sedan", "2014-2020,2021-2026", ["p30", "t30", "h25"], ["std", "luxury", "amg"]),
        m("cla", "كلا", "CLA", "sedan", "2013-2019,2020-2026", ["p16", "t20"], ["std", "amg"]),
        m("gla", "جلا", "GLA", "crossover", "2014-2019,2020-2026", ["p20", "t20"], ["std", "amg"]),
        m("glc", "جلك", "GLC", "suv", "2015-2022,2023-2026", ["p20", "t20", "h20"], ["std", "amg"]),
        m("gle", "جلي", "GLE", "suv", "2015-2019,2020-2026", ["p30", "t30", "h25"], ["std", "amg"], seats=5),
        m("gls", "جلس", "GLS", "suv", "2016-2019,2020-2026", ["p30", "t30"], ["std", "luxury", "amg"], seats=7),
        m("sprinter", "سبرينتر", "Sprinter", "van", "2010-2018,2019-2026", ["d20", "d30"], ["std", "hl"]),
        m("vito", "فيتو", "Vito", "van", "2010-2014,2015-2026", ["d20", "d30"], ["std", "hl"]),
        m("eqe", "إي كيو إي", "EQE", "sedan", "2022-2026", ["ea"], ["std", "luxury"]),
    ]),
    b("audi", "أودي", "Audi", "DE", "#BB0A30", False, [
        m("a3", "إيه 3", "A3", "hatchback", "2013-2020,2021-2026", ["p16", "t20", "h20"], ["std", "sport", "line"]),
        m("a4", "إيه 4", "A4", "sedan", "2012-2015,2016-2023,2024-2026", ["p20", "t20"], ["std", "sport", "line"]),
        m("a6", "إيه 6", "A6", "sedan", "2011-2018,2019-2026", ["p20", "t20", "h20"], ["std", "sport", "line"]),
        m("a8", "إيه 8", "A8", "sedan", "2010-2017,2018-2026", ["p30", "t30"], ["std", "luxury", "line"]),
        m("q3", "كيو 3", "Q3", "crossover", "2012-2018,2019-2026", ["p20", "t20"], ["std", "sport", "line"]),
        m("q5", "كيو 5", "Q5", "suv", "2013-2017,2018-2026", ["p20", "t20", "h20"], ["std", "sport", "line"]),
        m("q7", "كيو 7", "Q7", "suv", "2010-2015,2016-2026", ["p30", "t30"], ["std", "sport", "line"], seats=7),
        m("q8", "كيو 8", "Q8", "suv", "2019-2026", ["p30", "t30"], ["std", "sport", "line"]),
        m("e-tron", "إي ترون", "e-tron", "suv", "2019-2026", ["ea"], ["std", "sport"]),
        m("tt", "تي تي", "TT", "coupe", "2010-2014,2015-2023", ["p20", "t20"], ["std", "sport", "line"]),
    ]),
]

COLORS = [
    ("white", "أبيض", "White", "#FFFFFF"),
    ("black", "أسود", "Black", "#111111"),
    ("silver", "فضي", "Silver", "#C0C0C0"),
    ("gray", "رمادي", "Gray", "#6B7280"),
    ("red", "أحمر", "Red", "#C62828"),
    ("blue", "أزرق", "Blue", "#1E4D8F"),
    ("navy", "كحلي", "Navy", "#16265C"),
    ("green", "أخضر", "Green", "#2E7D32"),
    ("beige", "بيج", "Beige", "#D9C7A7"),
    ("gold", "ذهبي", "Gold", "#B8860B"),
    ("brown", "بني", "Brown", "#6D4C41"),
    ("orange", "برتقالي", "Orange", "#E65100"),
    ("yellow", "أصفر", "Yellow", "#F9A825"),
]


def sql_literal(value) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def build() -> dict:
    existing_logos = {p.stem for p in ASSETS_BRANDS.glob("*.svg")}
    brands_json = []
    brand_rows, model_rows, gen_rows, trim_rows = [], [], [], []
    seen = set()

    for brand_index, brand in enumerate(BRANDS):
        bid = brand["id"]
        if bid in seen:
            raise ValueError(f"duplicate brand id {bid}")
        seen.add(bid)
        logo = f"brands/{bid}.svg" if bid in existing_logos else None
        brand_rows.append((
            bid, brand["name_ar"], brand["name_en"], brand["country_code"],
            logo, brand["brand_color"], brand["is_popular"], brand_index,
        ))
        models_json = []
        for model_index, model in enumerate(brand["models"]):
            mid = f"{bid}-{model['slug']}"
            if mid in seen:
                raise ValueError(f"duplicate model id {mid}")
            seen.add(mid)
            model_rows.append((
                mid, bid, model["name_ar"], model["name_en"],
                model["body_type"], model_index,
            ))
            gens_json = []
            for y0, y1 in model["spans"]:
                gid = f"{mid}-{y0}"
                if gid in seen:
                    raise ValueError(f"duplicate generation id {gid}")
                seen.add(gid)
                name_ar = f"{y0} – {y1}" if y1 else f"{y0} – حتى الآن"
                name_en = f"{y0} – {y1}" if y1 else f"{y0} – Present"
                gen_rows.append((gid, mid, y0, y1, name_ar, name_en, y0))
                trims_json = []
                for engine_index, engine_key in enumerate(model["engines"]):
                    label_en, label_ar, eng_slug, cc, fuel, trans, hp = ENGINES[engine_key]
                    if fuel not in FUELS or trans not in TRANSMISSIONS:
                        raise ValueError(f"{gid}: bad engine metadata {engine_key}")
                    for tier_index, tier_key in enumerate(model["tiers"]):
                        tier_ar, tier_en = TIERS[tier_key]
                        tid = f"{gid}-{eng_slug}-{tier_key}"
                        if tid in seen:
                            raise ValueError(f"duplicate trim id {tid}")
                        seen.add(tid)
                        order = engine_index * 100 + tier_index
                        trim_rows.append((
                            tid, gid, f"{tier_ar} {label_ar}", f"{tier_en} {label_en}",
                            cc, fuel, trans, hp, model["seats"], order,
                        ))
                        trims_json.append({
                            "id": tid,
                            "name_ar": f"{tier_ar} {label_ar}",
                            "name_en": f"{tier_en} {label_en}",
                            "engine_cc": cc,
                            "fuel": fuel,
                            "transmission": trans,
                            "horsepower": hp,
                            "seats": model["seats"],
                        })
                gens_json.append({
                    "id": gid,
                    "year_from": y0,
                    "year_to": y1,
                    "name_ar": name_ar,
                    "name_en": name_en,
                    "trims": trims_json,
                })
            models_json.append({
                "id": mid,
                "name_ar": model["name_ar"],
                "name_en": model["name_en"],
                "body_type": model["body_type"],
                "generations": gens_json,
            })
        brands_json.append({
            "id": bid,
            "name_ar": brand["name_ar"],
            "name_en": brand["name_en"],
            "country_code": brand["country_code"],
            "logo_asset": logo,
            "brand_color": brand["brand_color"],
            "is_popular": brand["is_popular"],
            "models": models_json,
        })

    return {
        "catalog": {
            "version": CATALOG_VERSION,
            "year_max": YEAR_MAX,
            "brands": brands_json,
            "colors": [
                {"id": cid, "name_ar": ar, "name_en": en, "hex": hexv}
                for cid, ar, en, hexv in COLORS
            ],
        },
        "brand_rows": brand_rows,
        "model_rows": model_rows,
        "gen_rows": gen_rows,
        "trim_rows": trim_rows,
    }


def write_json(catalog: dict) -> None:
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(catalog, ensure_ascii=False, indent=2)
    OUT_JSON.write_text(text + "\n", encoding="utf-8")


def upsert_sql(table: str, columns: list[str], rows: list[tuple], conflict: str,
               update: list[str], title: str) -> str:
    if not rows:
        return ""
    out = [f"-- {title}", f"insert into public.{table} ({', '.join(columns)})", "values"]
    values = [f"  ({', '.join(sql_literal(v) for v in row)})" for row in rows]
    out.append(",\n".join(values))
    out.append(f"on conflict ({conflict}) do update set")
    out.append(",\n".join(f"  {c} = excluded.{c}" for c in update) + ";")
    return "\n".join(out)


def write_sql(data: dict) -> None:
    parts = [
        "-- بذور كتالوج السيارات — مُولَّدة آليًا بـ supabase/seed/build_vehicle_catalog.py",
        "-- لا تُحرّر هذا الملف يدويًا؛ عدّل السكربت ثم أعد التوليد.",
        "-- آمنة للتكرار: كل الجدول يُحدَّث بـ upsert على المفتاح النصي.",
        "",
        "begin;",
        "",
        upsert_sql(
            "vehicle_brands",
            ["id", "name_ar", "name_en", "country_code", "logo_asset",
             "brand_color", "is_popular", "sort_order"],
            data["brand_rows"], "id",
            ["name_ar", "name_en", "country_code", "logo_asset",
             "brand_color", "is_popular", "sort_order"],
            f"الماركات ({len(data['brand_rows'])})",
        ),
        "",
        upsert_sql(
            "vehicle_models",
            ["id", "brand_id", "name_ar", "name_en", "body_type", "sort_order"],
            data["model_rows"], "id",
            ["brand_id", "name_ar", "name_en", "body_type", "sort_order"],
            f"الموديلات ({len(data['model_rows'])})",
        ),
        "",
        upsert_sql(
            "vehicle_generations",
            ["id", "model_id", "year_from", "year_to", "name_ar", "name_en", "sort_order"],
            data["gen_rows"], "id",
            ["model_id", "year_from", "year_to", "name_ar", "name_en", "sort_order"],
            f"الأجيال ({len(data['gen_rows'])})",
        ),
        "",
    ]

    # تقسيم الفئات إلى دفعات لتجنّب عبارات INSERT ضخمة جدًا.
    trims = data["trim_rows"]
    parts.append(f"-- الفئات ({len(trims)})")
    chunk = 400
    for start in range(0, len(trims), chunk):
        parts.append(upsert_sql(
            "vehicle_trims",
            ["id", "generation_id", "name_ar", "name_en", "engine_cc",
             "fuel", "transmission", "horsepower", "seats", "sort_order"],
            trims[start:start + chunk], "id",
            ["generation_id", "name_ar", "name_en", "engine_cc", "fuel",
             "transmission", "horsepower", "seats", "sort_order"],
            f"الفئات — دفعة {start // chunk + 1}",
        ))
        parts.append("")
    parts.append("")

    rows = [(cid, ar, en, hexv, i) for i, (cid, ar, en, hexv) in enumerate(COLORS)]
    parts.append(upsert_sql(
        "vehicle_colors",
        ["id", "name_ar", "name_en", "hex", "sort_order"],
        rows, "id",
        ["name_ar", "name_en", "hex", "sort_order"],
        f"الألوان ({len(rows)})",
    ))
    parts.extend(["", "commit;", ""])
    OUT_SQL.write_text("\n".join(parts), encoding="utf-8")


def summarize(catalog: dict) -> None:
    brands = catalog["brands"]
    models = sum(len(b["models"]) for b in brands)
    gens = sum(len(m["generations"]) for b in brands for m in b["models"])
    trims = sum(
        len(g["trims"]) for b in brands for m in b["models"] for g in m["generations"]
    )
    year_min = min(
        g["year_from"] for b in brands for m in b["models"] for g in m["generations"]
    )
    body_counts: dict[str, int] = {}
    for brand in brands:
        for model in brand["models"]:
            body_counts[model["body_type"]] = body_counts.get(model["body_type"], 0) + 1

    print(f"Brands : {len(brands)}  (popular: {sum(1 for x in brands if x['is_popular'])})")
    print(f"Models : {models}")
    print(f"Gens   : {gens}")
    print(f"Trims  : {trims}")
    print(f"Years  : {year_min} – {YEAR_MAX}")
    print(f"Logos  : {sum(1 for x in brands if x['logo_asset'])}/{len(brands)}")
    print("Bodies : " + ", ".join(f"{k}={v}" for k, v in sorted(body_counts.items())))
    print()
    print("Per brand:")
    for brand in brands:
        n_gens = sum(len(m["generations"]) for m in brand["models"])
        n_trims = sum(len(g["trims"]) for m in brand["models"] for g in m["generations"])
        print(f"  {brand['name_ar']:<18} {brand['name_en']:<14} "
              f"models={len(brand['models']):>2} gens={n_gens:>2} trims={n_trims:>3}"
              f"{'  ★' if brand['is_popular'] else ''}")
    print()
    sample_brand = brands[0]
    sample_model = sample_brand["models"][0]
    sample_gen = sample_model["generations"][-1]
    sample_trim = sample_gen["trims"][0]
    print("Sample chain:")
    print(f"  {sample_brand['name_ar']} / {sample_model['name_ar']} / "
          f"{sample_gen['name_ar']} / {sample_trim['name_ar']}")
    print(f"  ids: {sample_brand['id']} → {sample_model['id']} → "
          f"{sample_gen['id']} → {sample_trim['id']}")


def main() -> int:
    data = build()
    catalog = data["catalog"]
    write_json(catalog)
    write_sql(data)
    summarize(catalog)
    print()
    print(f"JSON: {OUT_JSON}")
    print(f"SQL : {OUT_SQL}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
