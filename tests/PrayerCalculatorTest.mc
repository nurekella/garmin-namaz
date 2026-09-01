using Toybox.Test;
using Toybox.Math;
using Toybox.Lang;

module PrayerCalculatorTest {

    // ---------- helpers ----------

    function _hhmm(hoursFloat) {
        if (hoursFloat == null) { return "null"; }
        var h = hoursFloat.toNumber();
        var m = ((hoursFloat - h) * 60.0d).toNumber();
        if (m < 0) { m += 60; h -= 1; }
        if (h < 0) { h += 24; }
        if (h >= 24) { h -= 24; }
        var hStr = (h < 10) ? "0" + h : "" + h;
        var mStr = (m < 10) ? "0" + m : "" + m;
        return hStr + ":" + mStr;
    }

    function _diffMinutes(a, b) {
        var d = a - b;
        if (d < 0.0d) { d = -d; }
        return d * 60.0d;
    }

    function _within(logger, actualHours, expectedHHMM, toleranceMin, label) {
        if (actualHours == null) {
            logger.error(label + ": expected " + expectedHHMM + ", got null");
            return false;
        }
        var hh = expectedHHMM.substring(0, 2).toNumber();
        var mm = expectedHHMM.substring(3, 5).toNumber();
        var expected = hh + mm / 60.0d;
        var diffMin = _diffMinutes(actualHours, expected);
        if (diffMin > toleranceMin) {
            logger.error(label + ": expected " + expectedHHMM + " ± " + toleranceMin + " min, got "
                         + _hhmm(actualHours) + " (diff " + diffMin.format("%.2f") + " min)");
            return false;
        }
        logger.debug(label + ": " + _hhmm(actualHours) + " ~ " + expectedHHMM
                     + " (diff " + diffMin.format("%.2f") + " min)");
        return true;
    }

    // Compares all six times of one day against a muftyat.kz row.
    // Published times are rounded to the minute, so ±1.0 min is the
    // tightest tolerance that makes sense.
    function _matchDay(logger, label, lat, lon, y, m, d, ref) {
        var t = _newDumkHanafi().calculate(lat, lon, y, m, d, 5);
        var keys = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        var ok = true;
        for (var i = 0; i < keys.size(); i++) {
            ok = _within(logger, t[keys[i]], ref[i], 1.0d, label + " " + keys[i]) && ok;
        }
        return ok;
    }

    function _newDumkHanafi() {
        return new PrayerCalculator(DumkMethod.params(), 2, null);
    }

    function _newDumkStandard() {
        return new PrayerCalculator(DumkMethod.params(), 1, null);
    }

    // ---------- ҚМДБ fixture: muftyat.kz, 2026 ----------
    //
    // Values from https://api.muftyat.kz/prayer-times/2026/{lat}/{lng} for
    // the official ҚМДБ city centroids (coordinates from /cities/). The
    // model in DumkMethod / PrayerCalculator reproduces the whole 2026
    // year for all 16 regional centres within ±1 minute; these four dates
    // per city (New Year, late April, both solstices) pin it down.

    const ALMATY_LAT = 43.238293d;  const ALMATY_LON = 76.945465d;
    const ASTANA_LAT = 51.133333d;  const ASTANA_LON = 71.433333d;
    const SHYM_LAT   = 42.368009d;  const SHYM_LON   = 69.612769d;
    const PETRO_LAT  = 54.862222d;  const PETRO_LON  = 69.140833d;

    (:test)
    function testAlmaty_Muftyat_2026(logger) {
        var ok = true;
        ok = _matchDay(logger, "Almaty Jan 1",  ALMATY_LAT, ALMATY_LON, 2026,  1,  1,
                       ["05:59", "07:21", "11:59", "14:48", "16:30", "17:53"]) && ok;
        ok = _matchDay(logger, "Almaty Apr 29", ALMATY_LAT, ALMATY_LON, 2026,  4, 29,
                       ["03:20", "04:46", "11:53", "16:49", "18:54", "20:20"]) && ok;
        ok = _matchDay(logger, "Almaty Jun 21", ALMATY_LAT, ALMATY_LON, 2026,  6, 21,
                       ["02:23", "04:09", "11:57", "17:16", "19:39", "21:25"]) && ok;
        ok = _matchDay(logger, "Almaty Dec 21", ALMATY_LAT, ALMATY_LON, 2026, 12, 21,
                       ["05:55", "07:18", "11:53", "14:41", "16:23", "17:46"]) && ok;
        return ok;
    }

    // Astana (51.13°N): 5-minute ихтият and, in June, the angle-based
    // high-latitude rule (the sun never gets 15° below the horizon).
    (:test)
    function testAstana_Muftyat_2026(logger) {
        var ok = true;
        ok = _matchDay(logger, "Astana Jan 1",  ASTANA_LAT, ASTANA_LON, 2026,  1,  1,
                       ["06:36", "08:13", "12:23", "14:36", "16:23", "18:00"]) && ok;
        ok = _matchDay(logger, "Astana Apr 29", ASTANA_LAT, ASTANA_LON, 2026,  4, 29,
                       ["02:59", "04:46", "12:17", "17:20", "19:38", "21:26"]) && ok;
        ok = _matchDay(logger, "Astana Jun 21", ASTANA_LAT, ASTANA_LON, 2026,  6, 21,
                       ["02:07", "03:54", "12:21", "17:58", "20:38", "22:25"]) && ok;
        ok = _matchDay(logger, "Astana Dec 21", ASTANA_LAT, ASTANA_LON, 2026, 12, 21,
                       ["06:32", "08:09", "12:17", "14:28", "16:14", "17:52"]) && ok;
        return ok;
    }

    (:test)
    function testShymkent_Muftyat_2026(logger) {
        var ok = true;
        ok = _matchDay(logger, "Shymkent Jan 1",  SHYM_LAT, SHYM_LON, 2026,  1,  1,
                       ["06:26", "07:48", "12:28", "15:21", "17:02", "18:24"]) && ok;
        ok = _matchDay(logger, "Shymkent Apr 29", SHYM_LAT, SHYM_LON, 2026,  4, 29,
                       ["03:53", "05:17", "12:22", "17:17", "19:22", "20:46"]) && ok;
        ok = _matchDay(logger, "Shymkent Jun 21", SHYM_LAT, SHYM_LON, 2026,  6, 21,
                       ["02:59", "04:42", "12:26", "17:44", "20:05", "21:47"]) && ok;
        ok = _matchDay(logger, "Shymkent Dec 21", SHYM_LAT, SHYM_LON, 2026, 12, 21,
                       ["06:22", "07:44", "12:23", "15:13", "16:55", "18:17"]) && ok;
        return ok;
    }

    // Petropavl (54.86°N) — northernmost regional centre; the high-latitude
    // rule is active from May to July.
    (:test)
    function testPetropavl_Muftyat_2026(logger) {
        var ok = true;
        ok = _matchDay(logger, "Petropavl Jan 1",  PETRO_LAT, PETRO_LON, 2026,  1,  1,
                       ["06:53", "08:42", "12:32", "14:24", "16:12", "18:01"]) && ok;
        ok = _matchDay(logger, "Petropavl Apr 29", PETRO_LAT, PETRO_LON, 2026,  4, 29,
                       ["02:37", "04:44", "12:26", "17:33", "19:59", "22:07"]) && ok;
        ok = _matchDay(logger, "Petropavl Jun 21", PETRO_LAT, PETRO_LON, 2026,  6, 21,
                       ["02:05", "03:40", "12:30", "18:16", "21:10", "22:45"]) && ok;
        ok = _matchDay(logger, "Petropavl Dec 21", PETRO_LAT, PETRO_LON, 2026, 12, 21,
                       ["06:50", "08:40", "12:26", "14:15", "16:02", "17:53"]) && ok;
        return ok;
    }

    // Precaution minutes switch from 3 to 5 exactly at 48.0°N: Dhuhr at
    // two points on the same meridian, 0.02° apart, differs by ~2 min.
    (:test)
    function testPrecautionThreshold48(logger) {
        var calc = _newDumkHanafi();
        var south = calc.calculate(47.99d, 70.0d, 2026, 4, 29, 5);
        var north = calc.calculate(48.01d, 70.0d, 2026, 4, 29, 5);
        var gap = (north[:dhuhr] - south[:dhuhr]) * 60.0d;
        if (gap < 1.9d || gap > 2.1d) {
            logger.error("expected ~2 min Dhuhr step across 48°N, got " + gap.format("%.2f"));
            return false;
        }
        // Fajr carries no ихтият, so it must NOT jump.
        var fGap = _diffMinutes(north[:fajr], south[:fajr]);
        if (fGap > 0.5d) {
            logger.error("Fajr should not step across 48°N, got " + fGap.format("%.2f") + " min");
            return false;
        }
        return true;
    }

    // ---------- Asr ----------

    (:test)
    function testHanafiAsrLaterThanStandard(logger) {
        var hanafi = _newDumkHanafi().calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);
        var std    = _newDumkStandard().calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);
        if (hanafi[:asr] <= std[:asr]) {
            logger.error("Hanafi asr (" + _hhmm(hanafi[:asr]) + ") should be later than Standard ("
                         + _hhmm(std[:asr]) + ")");
            return false;
        }
        var diffMin = _diffMinutes(hanafi[:asr], std[:asr]);
        // typical 30–80 min depending on latitude / season
        if (diffMin < 30.0d || diffMin > 120.0d) {
            logger.error("Hanafi-vs-Std Asr gap unreasonable: " + diffMin.format("%.1f") + " min");
            return false;
        }
        logger.debug("Hanafi-Std Asr gap = " + diffMin.format("%.1f") + " min");
        return true;
    }

    // ---------- ordering ----------

    (:test)
    function testPrayerOrdering_Almaty(logger) {
        var t = _newDumkHanafi().calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);
        var prev = -1.0d;
        var order = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < order.size(); i++) {
            var name = order[i];
            var v = t[name];
            if (v == null) {
                logger.error("expected non-null prayer " + name + " for Almaty");
                return false;
            }
            if (v <= prev) {
                logger.error("prayer order broken at " + name + ": " + v + " <= prev " + prev);
                return false;
            }
            prev = v;
        }
        return true;
    }

    // ---------- high latitude ----------

    (:test)
    function testHighLatitude_AngleBased_Reykjavik(logger) {
        // 64.13°N at the summer solstice — sun never reaches 15° below the
        // horizon. With the angle-based rule Fajr/Isha still exist and
        // sit (15/60) of the (very short) night away from sunrise/sunset.
        var t = _newDumkHanafi().calculate(64.1466d, -21.9426d, 2026, 6, 21, 0);
        if (t[:fajr] == null || t[:isha] == null) {
            logger.error("Reykjavik: angle-based rule should yield Fajr/Isha");
            return false;
        }
        if (t[:sunrise] == null || t[:maghrib] == null || t[:asr] == null) {
            logger.error("Reykjavik: Sunrise/Maghrib/Asr should be defined");
            return false;
        }
        if (!(t[:fajr] < t[:sunrise] && t[:maghrib] < t[:isha])) {
            logger.error("Reykjavik: Fajr must precede sunrise, Isha follow Maghrib");
            return false;
        }
        return true;
    }

    (:test)
    function testHighLatitude_NoRule_ReturnsNull(logger) {
        // Same place, method without a high-latitude rule -> null twilight.
        var params = { :fajrAngle => 18.0d, :ishaAngle => 17.0d,
                       :sunriseAngle => 0.833d, :offsets => {} };
        var t = new PrayerCalculator(params, 2, null).calculate(64.1466d, -21.9426d, 2026, 6, 21, 0);
        if (t[:fajr] != null || t[:isha] != null) {
            logger.error("without :highLat Fajr/Isha should be null, got "
                         + _hhmm(t[:fajr]) + " / " + _hhmm(t[:isha]));
            return false;
        }
        return t[:dhuhr] != null && t[:sunrise] != null && t[:maghrib] != null;
    }

    // ---------- fixed-interval Isha / Ramadan ----------

    (:test)
    function testUmmAlQura_IshaInterval_Ramadan(logger) {
        var calc = new PrayerCalculator(UmmAlQuraMethod.params(), 1, null);
        // 2026-03-01 is 12 Ramadan 1447 -> 120 min after Maghrib.
        var ram = calc.calculate(21.4225d, 39.8262d, 2026, 3, 1, 3);
        var gapR = (ram[:isha] - ram[:maghrib]) * 60.0d;
        // 2026-04-29 is 12 Dhul-Qadah 1447 -> 90 min.
        var norm = calc.calculate(21.4225d, 39.8262d, 2026, 4, 29, 3);
        var gapN = (norm[:isha] - norm[:maghrib]) * 60.0d;
        if (_absDiff(gapR, 120.0d) > 0.01d || _absDiff(gapN, 90.0d) > 0.01d) {
            logger.error("Umm al-Qura Isha interval: Ramadan " + gapR.format("%.1f")
                         + " (want 120), normal " + gapN.format("%.1f") + " (want 90)");
            return false;
        }
        // Night boundary: 2026-02-17 is 29 Shaban, but its Isha belongs
        // to the night of 1 Ramadan -> already 120.
        var eve = calc.calculate(21.4225d, 39.8262d, 2026, 2, 17, 3);
        var gapE = (eve[:isha] - eve[:maghrib]) * 60.0d;
        if (_absDiff(gapE, 120.0d) > 0.01d) {
            logger.error("eve of Ramadan should use 120 min, got " + gapE.format("%.1f"));
            return false;
        }
        return true;
    }

    function _absDiff(a, b) {
        var d = a - b;
        return (d < 0.0d) ? -d : d;
    }

    // ---------- tahajjud ----------

    (:test)
    function testTahajjud_LastThirdOfNight(logger) {
        var calc = _newDumkHanafi();
        var today = calc.calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);
        var tomorrow = calc.calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 30, 5);
        // Night runs from astronomical sunset (Maghrib minus 3-min ихтият)
        // to tomorrow's Fajr; Tahajjud starts at two thirds of it.
        var sunset = today[:maghrib] - 3.0d / 60.0d;
        var night = (24.0d - sunset) + tomorrow[:fajr];
        var expected = sunset + night * 2.0d / 3.0d - 24.0d;
        var diff = _diffMinutes(today[:tahajjud], expected);
        if (diff > 0.2d) {
            logger.error("tahajjud " + _hhmm(today[:tahajjud]) + " expected " + _hhmm(expected)
                         + " (diff " + diff.format("%.2f") + " min)");
            return false;
        }
        return true;
    }

    // ---------- offsets ----------

    (:test)
    function testPerPrayerOffset_AddsMinutes(logger) {
        var base = _newDumkHanafi().calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);
        var calc = new PrayerCalculator(DumkMethod.params(), 2,
            { :fajr => 5, :dhuhr => -3, :isha => 7 });
        var off = calc.calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);
        var ok = true;
        ok = ok && _diffMinutes(off[:fajr],  base[:fajr]  + 5.0d/60.0d) < 0.05d;
        ok = ok && _diffMinutes(off[:dhuhr], base[:dhuhr] - 3.0d/60.0d) < 0.05d;
        ok = ok && _diffMinutes(off[:isha],  base[:isha]  + 7.0d/60.0d) < 0.05d;
        ok = ok && _diffMinutes(off[:sunrise], base[:sunrise]) < 0.001d;
        if (!ok) {
            logger.error("offset application incorrect");
        }
        return ok;
    }

    // ---------- time zone ----------

    (:test)
    function testTimezoneShiftsAllTimes(logger) {
        // Same place, tz 5 vs tz 6 -> every time moves by exactly 60 min.
        var a = _newDumkHanafi().calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);
        var b = _newDumkHanafi().calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 6);
        var keys = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < keys.size(); i++) {
            var d = (b[keys[i]] - a[keys[i]]) * 60.0d;
            if (_absDiff(d, 60.0d) > 0.1d) {
                logger.error(keys[i] + ": tz+1 should add 60 min, got " + d.format("%.2f"));
                return false;
            }
        }
        return true;
    }

    // ---------- getNextPrayer ----------

    (:test)
    function testGetNextPrayer_Sequence(logger) {
        var calc = _newDumkHanafi();
        var t = calc.calculate(ALMATY_LAT, ALMATY_LON, 2026, 4, 29, 5);

        var n1 = calc.getNextPrayer(t, 1.0d);
        if (n1[:name] != :fajr) {
            logger.error("at 01:00 next should be fajr, got " + n1[:name]);
            return false;
        }
        var n2 = calc.getNextPrayer(t, 8.0d);
        if (n2[:name] != :dhuhr) {
            logger.error("at 08:00 next should be dhuhr, got " + n2[:name]);
            return false;
        }
        var n3 = calc.getNextPrayer(t, 23.5d);
        if (n3 != null) {
            logger.error("at 23:30 next should be null (tomorrow), got " + n3[:name]);
            return false;
        }
        var n4 = calc.getNextPrayer(t, t[:dhuhr] - 0.5d);
        if (n4[:name] != :dhuhr) {
            logger.error("just before dhuhr, next should be dhuhr");
            return false;
        }
        if (n4[:secondsUntil] < 1700 || n4[:secondsUntil] > 1900) {
            logger.error("secondsUntil dhuhr should be ~1800, got " + n4[:secondsUntil]);
            return false;
        }
        return true;
    }
}
