using Toybox.Lang;
using Toybox.WatchUi;

// Gregorian -> Hijri date conversion using the Kuwaiti tabular algorithm
// (also called "civil Islamic calendar"). 30-year cycle with 11 leap
// years (2,5,7,10,13,16,18,21,24,26,29). Months alternate 30/29 days
// for months 1..11; month 12 is 29 days in common years, 30 in leap.
//
// Drift versus Umm al-Qura: most days agree exactly, occasional ±1 day
// differences appear at month boundaries because Umm al-Qura uses
// astronomical observation calibrations that the tabular algorithm
// cannot capture without a per-year override table. For prayer-time
// app context (a date label on the home screen) ±1 day is acceptable
// in v1.0; v1.1 can swap in a Umm al-Qura override map for the years
// the app actually targets.
//
// Reference: https://www.staff.science.uu.nl/~gent0113/islam/ummalqura.htm
//            (Kuwaiti algorithm formulas)
module HijriDate {

    // Julian Day Number of 1 Muharram 1 AH = 16 July 622 CE (Julian).
    const EPOCH_JDN = 1948440;

    // Returns { :year, :month (1..12), :day (1..30) } for the Gregorian
    // (year, month, day). Treats the date as civil-noon for JDN purposes
    // — the calendar boundary doesn't shift within a single day.
    function fromGregorian(year, month, day) {
        var jdNoon = _gregorianJdn(year, month, day);
        return fromJdn(jdNoon);
    }

    // Same conversion starting from a Julian Day Number directly.
    function fromJdn(jdn) {
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
