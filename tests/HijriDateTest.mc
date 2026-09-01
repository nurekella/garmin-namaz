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

    // ---- Umm al-Qura (exact) ----

    (:test)
    function testUmmAlQura_TableStart(logger) {
        // 1 Muharram 1440 = 11 September 2018 — first row of the table.
        if (!_check(logger, 2018, 9, 11, 1440, 1, 1)) { return false; }
        // Day before the table: tabular fallback, ±1 day (UQ says 30/12/1439).
        var h = HijriDate.fromGregorian(2018, 9, 10);
        return h[:year] == 1439 && h[:month] == 12 && h[:day] >= 29;
    }

    (:test)
    function testUmmAlQura_Ramadan1445(logger) {
        // 1 Ramadan 1445 = 11 March 2024; Eid al-Fitr (1 Shawwal) = 10 April 2024.
        return _check(logger, 2024, 3, 11, 1445, 9, 1)
            && _check(logger, 2024, 4, 10, 1445, 10, 1);
    }

    (:test)
    function testUmmAlQura_NewYear1447(logger) {
        // 1 Muharram 1447 = 26 June 2025.
        return _check(logger, 2025, 6, 26, 1447, 1, 1)
            && _check(logger, 2025, 6, 25, 1446, 12, 29);
    }

    (:test)
    function testUmmAlQura_Ramadan1447(logger) {
        // 1 Ramadan 1447 = 18 February 2026; 1 Shawwal 1447 = 20 March 2026.
        return _check(logger, 2026, 2, 18, 1447, 9, 1)
            && _check(logger, 2026, 2, 17, 1447, 8, 29)
            && _check(logger, 2026, 3, 20, 1447, 10, 1);
    }

    (:test)
    function testUmmAlQura_Misc(logger) {
        // 29 April 2026 = 12 Dhul-Qadah 1447 (muftyat.kz).
        // 1 September 2026 = 19 Rabi al-Awwal 1448.
        // 1 January 2030 = 26 Shaban 1451.
        return _check(logger, 2026, 4, 29, 1447, 11, 12)
            && _check(logger, 2026, 9, 1, 1448, 3, 19)
            && _check(logger, 2030, 1, 1, 1451, 8, 26);
    }

    (:test)
    function testUmmAlQura_RangeFlag(logger) {
        var inside  = HijriDate.fromGregorian(2026, 1, 1);
        var jdnIn   = HijriDate._gregorianJdn(2026, 1, 1);
        var jdnOut  = HijriDate._gregorianJdn(2000, 1, 1);
        if (!HijriDate.isUmmAlQuraRange(jdnIn) || HijriDate.isUmmAlQuraRange(jdnOut)) {
            logger.error("range flag wrong");
            return false;
        }
        return inside[:year] == 1447;
    }

    // ---- Tabular fallback ----

    (:test)
    function testFallback_Epoch(logger) {
        // 1 Muharram 1 AH = 16 July 622 CE (Julian) = 19 July 622 CE (Gregorian).
        var h = HijriDate.fromGregorian(622, 7, 19);
        if (h[:year] != 1 || h[:month] != 1) {
            logger.error("epoch -> " + h[:day] + "/" + h[:month] + "/" + h[:year]);
            return false;
        }
        return h[:day] >= 1 && h[:day] <= 2;
    }

    (:test)
    function testFallback_2000(logger) {
        // 1 January 2000 = 24 Ramadan 1420 (Umm al-Qura); tabular is
        // within ±1 day.
        var h = HijriDate.fromGregorian(2000, 1, 1);
        if (h[:year] != 1420 || h[:month] != 9) {
            logger.error("2000-01-01 -> " + h[:day] + "/" + h[:month] + "/" + h[:year]);
            return false;
        }
        var d = h[:day] - 24;
        if (d < 0) { d = -d; }
        return d <= 1;
    }

    (:test)
    function testLeapYearRule(logger) {
        // 1447 % 30 = 7 -> leap position; 1446 % 30 = 6 -> common.
        if (!HijriDate.isLeapYear(1447)) {
            logger.error("1447 should be leap"); return false;
        }
        if (HijriDate.isLeapYear(1446)) {
            logger.error("1446 should not be leap"); return false;
        }
        return true;
    }

    // ---- invariants ----

    (:test)
    function testDailyContinuity(logger) {
        // Walk every day of 2024-2027: the day counter must advance by 1
        // or reset to 1 with a month step, months stay 1..12, days 1..30.
        var prev = HijriDate.fromGregorian(2023, 12, 31);
        var dim = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        for (var y = 2024; y <= 2027; y++) {
            for (var m = 1; m <= 12; m++) {
                var days = dim[m - 1];
                if (m == 2 && y % 4 != 0) { days = 28; }
                for (var d = 1; d <= days; d++) {
                    var h = HijriDate.fromGregorian(y, m, d);
                    if (h[:month] < 1 || h[:month] > 12 || h[:day] < 1 || h[:day] > 30) {
                        logger.error("out of range at " + y + "-" + m + "-" + d);
                        return false;
                    }
                    var sameMonth = (h[:year] == prev[:year] && h[:month] == prev[:month]
                                     && h[:day] == prev[:day] + 1);
                    var nextMonth = (h[:day] == 1 && prev[:day] >= 29
                                     && ((h[:month] == prev[:month] + 1 && h[:year] == prev[:year])
                                         || (h[:month] == 1 && prev[:month] == 12
                                             && h[:year] == prev[:year] + 1)));
                    if (!sameMonth && !nextMonth) {
                        logger.error("discontinuity at " + y + "-" + m + "-" + d + ": "
                                     + prev[:day] + "/" + prev[:month] + "/" + prev[:year] + " -> "
                                     + h[:day] + "/" + h[:month] + "/" + h[:year]);
                        return false;
                    }
                    prev = h;
                }
            }
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
