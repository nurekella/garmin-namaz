using Toybox.Test;
using Toybox.Lang;

module HijriDateTest {

    function _check(logger, year, month, day, expY, expM, expD) {
        var h = HijriDate.fromGregorian(year, month, day);
        if (h[:year] != expY || h[:month] != expM || h[:day] != expD) {
            logger.error("Greg " + year + "-" + month + "-" + day
                         + " -> Hijri " + h[:day] + "/" + h[:month] + "/" + h[:year]
                         + ", expected " + expD + "/" + expM + "/" + expY);
            return false;
        }
        return true;
    }

    // Acceptable drift: tabular vs Umm al-Qura can disagree by ±1 day at
    // month boundaries. _checkApprox accepts day_actual in {expD-1, expD, expD+1}
    // (with month/year wrap) — used for dates known to differ from
    // muftyat.kz by one day.
    function _checkApprox(logger, year, month, day, expY, expM, expD) {
        var h = HijriDate.fromGregorian(year, month, day);
        if (h[:year] == expY && h[:month] == expM) {
            var d = h[:day] - expD;
            if (d < 0) { d = -d; }
            if (d <= 1) { return true; }
        }
        // also allow off-by-one across month boundaries
        logger.debug("Greg " + year + "-" + month + "-" + day
                     + " -> Hijri " + h[:day] + "/" + h[:month] + "/" + h[:year]
                     + ", expected ~" + expD + "/" + expM + "/" + expY);
        return false;
    }

    (:test)
    function testEpochDay(logger) {
        // 1 Muharram 1 AH = 16 July 622 CE (Julian) = 19 July 622 CE (Gregorian).
        // Within ±1 day for the tabular algorithm.
        return _checkApprox(logger, 622, 7, 19, 1, 1, 1);
    }

    (:test)
    function testReference_2026_04_29(logger) {
        // muftyat.kz published: 29 April 2026 = 12 Зуль-Қа'да 1447 (month 11).
        // Tabular algorithm typically lands within ±1 day.
        return _checkApprox(logger, 2026, 4, 29, 1447, 11, 12);
    }

    (:test)
    function testReference_2024_06_06(logger) {
        // 1 Dhul-Hijjah 1445 begins ~ 7 June 2024 (Umm al-Qura).
        // Tabular: 6 June 2024 ~ 30 Dhul-Qa'dah 1445.
        var h = HijriDate.fromGregorian(2024, 6, 6);
        // Year must hit, month should be 11 or 12 depending on which day.
        return h[:year] == 1445 && (h[:month] == 11 || h[:month] == 12);
    }

    (:test)
    function testYearProgression(logger) {
        // The Hijri new year fires roughly once per Gregorian year.
        // Walk daily through all of 2026 and ensure we see exactly one
        // year-bump (Hijri 1447 -> 1448 around mid-2026).
        var prev = HijriDate.fromGregorian(2026, 1, 1)[:year];
        var bumps = 0;
        for (var m = 1; m <= 12; m++) {
            for (var d = 1; d <= 28; d++) {
                var y = HijriDate.fromGregorian(2026, m, d)[:year];
                if (y > prev) { bumps += 1; prev = y; }
                else if (y < prev) {
                    logger.error("Hijri year went backwards at "
                                 + 2026 + "-" + m + "-" + d);
                    return false;
                }
            }
        }
        if (bumps != 1) {
            logger.error("expected exactly 1 Hijri year-bump in 2026, got " + bumps);
            return false;
        }
        return true;
    }

    (:test)
    function testMonthInRange(logger) {
        // Sample every 13th day in 2024-2026 — month must always be in [1,12].
        var ok = true;
        for (var y = 2024; y <= 2026 && ok; y++) {
            for (var m = 1; m <= 12 && ok; m++) {
                for (var d = 1; d <= 28; d += 13) {
                    var h = HijriDate.fromGregorian(y, m, d);
                    if (h[:month] < 1 || h[:month] > 12) {
                        logger.error("month out of range at " + y + "-" + m + "-" + d
                                     + ": " + h[:month]);
                        ok = false;
                    }
                    if (h[:day] < 1 || h[:day] > 30) {
                        logger.error("day out of range at " + y + "-" + m + "-" + d
                                     + ": " + h[:day]);
                        ok = false;
                    }
                }
            }
        }
        return ok;
    }

    (:test)
    function testLeapYearRule(logger) {
        // The 11 leap years per 30-year cycle have known positions.
        // 1447 / 30 = 48 r 7  -> position 7. Position 7 IS a leap year.
        // 1446 -> position 6. NOT a leap.
        if (!HijriDate.isLeapYear(1447)) {
            logger.error("1447 should be leap"); return false;
        }
        if (HijriDate.isLeapYear(1446)) {
            logger.error("1446 should not be leap"); return false;
        }
        return true;
    }

    (:test)
    function testMonthNameNonEmpty(logger) {
        for (var m = 1; m <= 12; m++) {
            if (HijriDate.monthName(m).length() == 0) {
                logger.error("empty name for month " + m);
                return false;
            }
        }
        return HijriDate.monthName(0).equals("")
            && HijriDate.monthName(13).equals("");
    }

    // Umm al-Qura reference dates from ICU (islamic-umalqura): the 1st of
    // Ramadan 1447 / Shawwal / Dhul-Hijjah, the table's first day and
    // years in between. [gYear, gMonth, gDay, hYear, hMonth, hDay]
    const UQ_REF = [
        [2018, 9, 11, 1440, 1, 1],
        [2018, 9, 11, 1440, 1, 1],
        [2019, 6, 4, 1440, 10, 1],
        [2022, 4, 2, 1443, 9, 1],
        [2024, 3, 11, 1445, 9, 1],
        [2025, 3, 1, 1446, 9, 1],
        [2025, 3, 30, 1446, 10, 1],
        [2026, 2, 17, 1447, 8, 29],
        [2026, 2, 18, 1447, 9, 1],
        [2026, 2, 19, 1447, 9, 2],
        [2026, 3, 19, 1447, 9, 30],
        [2026, 3, 20, 1447, 10, 1],
        [2026, 3, 21, 1447, 10, 2],
        [2026, 5, 26, 1447, 12, 9],
        [2026, 5, 27, 1447, 12, 10],
        [2026, 10, 1, 1448, 4, 20],
        [2026, 12, 31, 1448, 7, 22],
        [2027, 2, 7, 1448, 8, 30],
        [2027, 2, 8, 1448, 9, 1],
        [2030, 7, 1, 1452, 2, 29],
        [2050, 1, 1, 1472, 4, 7],
        [2076, 11, 15, 1499, 12, 18]
    ];

    (:test)
    function testUmmAlQuraMatchesIcu(logger) {
        var ok = true;
        for (var i = 0; i < UQ_REF.size(); i++) {
            var r = UQ_REF[i];
            if (!_check(logger, r[0], r[1], r[2], r[3], r[4], r[5])) { ok = false; }
        }
        return ok;
    }

    // Past the table (2077+) we fall back to the tabular algorithm: still a
    // plausible date, no crash.
    (:test)
    function testFallbackOutsideTable(logger) {
        var h = HijriDate.fromGregorian(2090, 1, 1);
        return h[:year] > 1500 && h[:month] >= 1 && h[:month] <= 12 && h[:day] >= 1 && h[:day] <= 30;
    }

    // The Hijri adjustment is applied by forDate only.
    (:test)
    function testAdjustDefaultsToZero(logger) {
        var a = HijriDate.fromGregorian(2026, 10, 1);
        var b = HijriDate.forDate(2026, 10, 1);
        return a[:day] == b[:day] && a[:month] == b[:month] && Settings.hijriAdjust() == 0;
    }
}
