using Toybox.Lang;

// Gregorian -> Hijri date conversion.
//
// Primary: Umm al-Qura calendar (the official Saudi civil calendar, also
// what muftyat.kz prints) via a baked month-length table covering
// 1440–1470 AH (Sep 2018 – Jun 2049). Each year is a 12-bit mask,
// bit (m-1) set => month m has 30 days. The table was generated from
// the `hijridate` Python package, which implements the published
// Umm al-Qura data.
//
// Fallback outside the table: Kuwaiti tabular algorithm (30-year cycle
// with 11 leap years), accurate to ±1 day at month boundaries.
//
// Reference: https://www.staff.science.uu.nl/~gent0113/islam/ummalqura.htm
(:glance, :background)
module HijriDate {

    // Julian Day Number of 1 Muharram 1 AH = 16 July 622 CE (Julian).
    const EPOCH_JDN = 1948440;

    // ---- Umm al-Qura table ----
    const UQ_FIRST_YEAR = 1440;
    const UQ_FIRST_JDN  = 2458373;   // 1 Muharram 1440 = 11 Sep 2018
    const UQ_MASKS = [
        698, 1461, 1450, 3413, 2714, 2350, 622, 1373, 2778, 1748, 1701,
        1355, 2711, 1358, 2734, 1452, 2985, 3474, 2853, 1611, 3243, 1370,
        2901, 1746, 3749, 3658, 2709, 1325, 2733, 876, 1881
    ];

    // Returns { :year, :month (1..12), :day (1..30) } for the Gregorian
    // (year, month, day). Treats the date as civil-noon for JDN purposes
    // — the calendar boundary doesn't shift within a single day.
    function fromGregorian(year, month, day) {
        return fromJdn(_gregorianJdn(year, month, day));
    }

    // Same conversion starting from a Julian Day Number directly.
    function fromJdn(jdn) {
        var uq = _fromJdnUmmAlQura(jdn);
        if (uq != null) { return uq; }
        return _fromJdnTabular(jdn);
    }

    // True when `jdn` falls inside the Umm al-Qura table.
    function isUmmAlQuraRange(jdn) {
        return _fromJdnUmmAlQura(jdn) != null;
    }

    // ---- Umm al-Qura lookup ----

    function _uqMonthLength(mask, month) {
        return ((mask >> (month - 1)) & 1) == 1 ? 30 : 29;
    }

    function _uqYearLength(mask) {
        var days = 0;
        for (var m = 1; m <= 12; m++) { days += _uqMonthLength(mask, m); }
        return days;
    }

    function _fromJdnUmmAlQura(jdn) {
        if (jdn < UQ_FIRST_JDN) { return null; }
        var rem = jdn - UQ_FIRST_JDN;
        for (var i = 0; i < UQ_MASKS.size(); i++) {
            var mask = UQ_MASKS[i];
            var yLen = _uqYearLength(mask);
            if (rem < yLen) {
                var month = 1;
                while (month < 12) {
                    var mLen = _uqMonthLength(mask, month);
                    if (rem < mLen) { break; }
                    rem -= mLen;
                    month += 1;
                }
                return { :year => UQ_FIRST_YEAR + i, :month => month, :day => rem + 1 };
            }
            rem -= yLen;
        }
        return null;   // past the end of the table
    }

    // ---- Kuwaiti tabular fallback ----

    function _fromJdnTabular(jdn) {
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

    // JDN of 1 Muharram of `hYear` (tabular).
    function _yearStartJdn(hYear) {
        var prev = hYear - 1;
        var fullCycles = (prev / 30).toLong().toNumber();
        var rem = prev - fullCycles * 30;
        var leapsInRem = 0;
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
    const _MONTHS_KK = ["Мұхаррам","Сафар","Рабиғ-уль-әууәл","Рабиғ-уль-ахир",
        "Жұмад-уль-әууәл","Жұмад-уль-ахир","Ражаб","Шағбан","Рамазан",
        "Шәууал","Зул-қағда","Зул-хижжа"];
    const _MONTHS_RU = ["Мухаррам","Сафар","Раби-уль-авваль","Раби-уль-ахир",
        "Джумада-аль-уля","Джумада-аль-ахира","Раджаб","Шаабан","Рамадан",
        "Шавваль","Зуль-каада","Зуль-хиджа"];
    const _MONTHS_EN = ["Muharram","Safar","Rabi al-Awwal","Rabi al-Thani",
        "Jumada al-Awwal","Jumada al-Thani","Rajab","Shaban","Ramadan",
        "Shawwal","Dhul-Qadah","Dhul-Hijjah"];

    function monthName(month) {
        if (month < 1 || month > 12) { return ""; }
        var lang = Settings.language();
        if (lang.equals("kk")) { return _MONTHS_KK[month - 1]; }
        if (lang.equals("ru")) { return _MONTHS_RU[month - 1]; }
        return _MONTHS_EN[month - 1];
    }
}
