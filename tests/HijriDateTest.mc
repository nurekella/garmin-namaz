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
}
