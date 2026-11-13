using Toybox.Lang;

// Gregorian -> Hijri date conversion.
//
// Within the table (1440..1500 AH = Sep 2018 .. 2077) this is the real
// Umm al-Qura calendar, generated from ICU: UQ_MASKS holds one 12-bit
// mask per Hijri year, bit (m-1) set when month m has 30 days (else 29).
// Outside it we fall back to the Kuwaiti tabular algorithm (30-year cycle,
// 11 leap years), which can be a day or two off Umm al-Qura.
//
// ҚМДБ announces month starts by moon sighting and can differ from Umm
// al-Qura by a day; Settings.hijriAdjust (-2..+2) shifts the date for that.
(:glance, :background)
module HijriDate {

    // Julian Day Number of 1 Muharram 1 AH = 16 July 622 CE (Julian).
    const EPOCH_JDN = 1948440;

    // Umm al-Qura table: 1 Muharram 1440 AH = 2018-09-11.
    const UQ_FIRST = 1440;
    const UQ_START_JDN = 2458373;
    const UQ_MASKS = [
        0x2BA, 0x5B5, 0x5AA, 0xD55, 0xA9A, 0x92E, 0x26E, 0x55D, 0xADA, 0x6D4,
        0x6A5, 0xB27, 0xA4D, 0x4AD, 0x56D, 0xB5A, 0x754, 0xF49, 0xE92, 0xD26,
        0xA56, 0x356, 0x6B5, 0xBAA, 0xB92, 0xB25, 0x68B, 0xA9B, 0x55A, 0xADA,
        0x5B4, 0xDA9, 0xB52, 0xA9A, 0x536, 0x276, 0x575, 0xAF2, 0x6D4, 0x6A9,
        0x555, 0x2AD, 0x4BD, 0x9BA, 0x574, 0xB69, 0xB52, 0xA95, 0x52D, 0xA5D,
        0x4DA, 0xAD9, 0x6B2, 0xE95, 0xE2A, 0xC96, 0x92E, 0xAAD, 0x56A, 0xD65,
        0xD4A
    ];

    // Returns { :year, :month (1..12), :day (1..30) } for the Gregorian
    // (year, month, day). Treats the date as civil-noon for JDN purposes
    // — the calendar boundary doesn't shift within a single day.
    function fromGregorian(year, month, day) {
        var jdNoon = _gregorianJdn(year, month, day);
        return fromJdn(jdNoon);
    }

    // The date as the user wants to see it: fromGregorian shifted by
    // Settings.hijriAdjust() days.
    function forDate(year, month, day) {
        return fromJdn(_gregorianJdn(year, month, day) + Settings.hijriAdjust());
    }

    // Same conversion starting from a Julian Day Number directly.
    function fromJdn(jdn) {
        var uq = _umAlQura(jdn - UQ_START_JDN);
        if (uq != null) { return uq; }
        return _kuwaiti(jdn);
    }

    function _umAlQura(off) {
        if (off < 0) { return null; }
        for (var i = 0; i < UQ_MASKS.size(); i++) {
            var mask = UQ_MASKS[i];
            var len = 348;                              // 12 x 29
            for (var m = 0; m < 12; m++) { len += (mask >> m) & 1; }
            if (off >= len) { off -= len; continue; }
            for (var m = 0; m < 12; m++) {
                var ml = 29 + ((mask >> m) & 1);
                if (off < ml) {
                    return { :year => UQ_FIRST + i, :month => m + 1, :day => off + 1 };
                }
                off -= ml;
            }
        }
        return null;
    }

    function _kuwaiti(jdn) {
        var n = jdn - EPOCH_JDN;            // days since epoch
        var hYear = ((30 * n + 10646) / 10631).toLong().toNumber();
        var yearStart = _yearStartJdn(hYear);
        var doy = jdn - yearStart + 1;       // 1-based day of year

        var month = 1;
        var monthDayCount;
        while (true) {
            monthDayCount = _monthLength(hYear, month);
            if (doy <= monthDayCount) { break; }
            doy -= monthDayCount;
            month += 1;
            if (month > 12) {
                // Should not happen if year boundary calc is right; guard
                // against accumulated rounding.
                month = 12;
                break;
            }
        }
        return { :year => hYear, :month => month, :day => doy };
    }

    function isLeapYear(hYear) {
        var m = (11 * hYear + 14) % 30;
        if (m < 0) { m += 30; }
        return m < 11;
    }

    // Length of (1..12) month in `hYear`. Months 1,3,5,7,9,11 = 30 days;
    // 2,4,6,8,10 = 29 days; month 12 = 30 leap / 29 common.
    function _monthLength(hYear, month) {
        if (month == 12) {
            return isLeapYear(hYear) ? 30 : 29;
        }
        return (month % 2 == 1) ? 30 : 29;
    }

    // JDN of 1 Muharram of `hYear`.
    function _yearStartJdn(hYear) {
        // Total days in years 1..hYear-1 + epoch.
        // Each 30-year cycle holds 11 * 355 + 19 * 354 = 10631 days.
        // Offset within cycle = sum of leap-year occurrences below hYear.
        var prev = hYear - 1;
        var fullCycles = (prev / 30).toLong().toNumber();
        var rem = prev - fullCycles * 30;
        var leapsInRem = 0;
        // The 11 leap positions in a 30-year cycle:
        var leapSlots = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29];
        for (var i = 0; i < leapSlots.size(); i++) {
            if (leapSlots[i] <= rem) { leapsInRem += 1; }
        }
        var days = fullCycles * 10631 + rem * 354 + leapsInRem;
        return EPOCH_JDN + days;
    }

    // Gregorian (y, m, d) -> Julian Day Number at noon. Same formula as
    // SolarMath.julianDate but returning the integer noon-JDN (no .5
    // offset) which is what calendar conversions expect.
    function _gregorianJdn(year, month, day) {
        var y = year;
        var m = month;
        if (m <= 2) {
            y -= 1;
            m += 12;
        }
        var a = (y / 100).toLong().toNumber();
        var b = 2 - a + (a / 4).toLong().toNumber();
        var jd = (365.25d * (y + 4716).toDouble()).toLong().toNumber()
               + (30.6001d * (m + 1).toDouble()).toLong().toNumber()
               + day + b - 1524;
        return jd;
    }

    // 1..12 -> localised month name. Honours Settings.language() so the
    // manual language switch overrides system locale.
    // Short on purpose: the date line sits low on a round screen, where a
    // long month name ("Jumada al-Awwal") would be cut off at the bezel.
    const _MONTHS_KK = ["Мұхаррам","Сафар","Рабиғ I","Рабиғ II","Жұмада I","Жұмада II",
        "Ражаб","Шағбан","Рамазан","Шәууал","Зұлқағда","Зұлхижжа"];
    const _MONTHS_RU = ["Мухаррам","Сафар","Раби I","Раби II","Джумада I","Джумада II",
        "Раджаб","Шаабан","Рамадан","Шавваль","Зуль-када","Зуль-хиджа"];
    const _MONTHS_EN = ["Muharram","Safar","Rabi I","Rabi II","Jumada I","Jumada II",
        "Rajab","Shaban","Ramadan","Shawwal","Dhul-Qadah","Dhul-Hijjah"];

    function monthName(month) {
        if (month < 1 || month > 12) { return ""; }
        var lang = Settings.language();
        if (lang.equals("kk")) { return PrayerNames.kz(_MONTHS_KK[month - 1]); }
        if (lang.equals("ru")) { return _MONTHS_RU[month - 1]; }
        return _MONTHS_EN[month - 1];
    }
}
