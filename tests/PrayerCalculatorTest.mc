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
        // |a - b| in minutes, both in fractional hours.
        var d = a - b;
        if (d < 0.0d) { d = -d; }
        return d * 60.0d;
    }

    function _within(logger, actualHours, expectedHHMM, toleranceMin, label) {
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

    function _newDumkHanafi() {
        return new PrayerCalculator(DumkMethod.params(), 2, null);
    }

    function _newDumkStandard() {
        return new PrayerCalculator(DumkMethod.params(), 1, null);
    }

    // ---------- core algorithm: Almaty 2026-04-29 ----------
    //
    // Reference (UTC+5, namazvakti.com cross-checked with namaztimes.kz):
    //   Fajr 03:00, Sunrise 04:43, Dhuhr ~12:00, Asr-Hanafi 16:56,
    //   Asr-Std 15:53, Maghrib 18:59, Isha 20:45.
    //
    // muftyat.kz is currently returning 500; once it's reachable, tighten
    // tolerance to ±1 min per Stage 3 acceptance criteria. For now we
    // accept ±15 min, which is loose enough to absorb method differences
    // (Dhuhr offset 0 vs 2, slightly different city centroid for lat/lon)
    // but tight enough to catch real algorithm bugs.

    (:test)
    function testAlmaty_2026_04_29_AllPrayers(logger) {
        var calc = _newDumkHanafi();
        var t = calc.calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
        var ok = true;
        ok = ok && _within(logger, t[:fajr],    "03:00", 15, "Almaty Fajr");
        ok = ok && _within(logger, t[:sunrise], "04:43", 15, "Almaty Sunrise");
        ok = ok && _within(logger, t[:dhuhr],   "12:00", 15, "Almaty Dhuhr");
        ok = ok && _within(logger, t[:asr],     "16:56", 15, "Almaty Asr (Hanafi)");
        ok = ok && _within(logger, t[:maghrib], "18:59", 15, "Almaty Maghrib");
        ok = ok && _within(logger, t[:isha],    "20:45", 15, "Almaty Isha");
        return ok;
    }

    (:test)
    function testAlmaty_2026_04_29_AsrStandard(logger) {
        var calc = _newDumkStandard();
        var t = calc.calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
        return _within(logger, t[:asr], "15:53", 15, "Almaty Asr (Standard)");
    }

    // ---------- internal sanity: ordering & monotonicity ----------

    (:test)
    function testPrayerOrdering_Almaty(logger) {
        var calc = _newDumkHanafi();
        var t = calc.calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
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

    (:test)
    function testHanafiAsrLaterThanStandard(logger) {
        var hanafi = _newDumkHanafi().calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
        var std    = _newDumkStandard().calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
        if (hanafi[:asr] <= std[:asr]) {
            logger.error("Hanafi asr (" + _hhmm(hanafi[:asr]) + ") should be later than Standard ("
                         + _hhmm(std[:asr]) + ")");
            return false;
        }
        var diffMin = _diffMinutes(hanafi[:asr], std[:asr]);
        // typical 30–80 min depending on latitude / season
        if (diffMin < 10.0d || diffMin > 120.0d) {
            logger.error("Hanafi-vs-Std Asr gap unreasonable: " + diffMin.format("%.1f") + " min");
            return false;
        }
        logger.debug("Hanafi-Std Asr gap = " + diffMin.format("%.1f") + " min");
        return true;
    }

    // ---------- edge cases ----------

    (:test)
    function testAstana_NorthernCity(logger) {
        // 51.17°N — still below the Fajr/Isha "no-twilight" threshold for late April,
        // so Fajr and Isha should be defined.
        var calc = _newDumkHanafi();
        var t = calc.calculate(51.1694d, 71.4491d, 2026, 4, 29, 5);
        if (t[:fajr] == null || t[:isha] == null) {
            logger.error("Astana late April: Fajr/Isha unexpectedly null");
            return false;
        }
        // Astana lon 71.45°E (west of Almaty 76.89°E by 5.44°) — solar noon
        // is ~22 min LATER than Almaty's. With Almaty Dhuhr ~11:52 in UTC+5,
        // Astana lands around 12:13.
        return _within(logger, t[:dhuhr], "12:13", 10, "Astana Dhuhr (sanity)");
    }

    (:test)
    function testShymkent_SouthernCity(logger) {
        var calc = _newDumkHanafi();
        var t = calc.calculate(42.3417d, 69.5901d, 2026, 4, 29, 5);
        if (t[:fajr] == null || t[:isha] == null) {
            logger.error("Shymkent: Fajr/Isha null");
            return false;
        }
        // Shymkent is further west than Almaty -> later Dhuhr.
        var almaty = _newDumkHanafi().calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
        if (t[:dhuhr] <= almaty[:dhuhr]) {
            logger.error("Shymkent Dhuhr should be LATER than Almaty (further west)");
            return false;
        }
        return true;
    }

    (:test)
    function testHighLatitude_Reykjavik_June(logger) {
        // 64.13°N around summer solstice — sun does not descend to 18° below horizon,
        // so Fajr/Isha return null and we test that gracefully.
        var calc = _newDumkHanafi();
        var t = calc.calculate(64.1466d, -21.9426d, 2026, 6, 21, 0);
        if (t[:fajr] != null) {
            logger.error("Reykjavik June 21: Fajr should be null (no twilight), got " + _hhmm(t[:fajr]));
            return false;
        }
        if (t[:isha] != null) {
            logger.error("Reykjavik June 21: Isha should be null, got " + _hhmm(t[:isha]));
            return false;
        }
        // Dhuhr and sunrise/maghrib still computable
        if (t[:dhuhr] == null || t[:sunrise] == null || t[:maghrib] == null || t[:asr] == null) {
            logger.error("Reykjavik June 21: Dhuhr/Sunrise/Maghrib/Asr should be defined");
            return false;
        }
        return true;
    }

    (:test)
    function testWinter_Almaty_2026_12_21(logger) {
        // Sanity at winter solstice: short day, late Fajr, early Isha.
        var calc = _newDumkHanafi();
        var t = calc.calculate(43.2389d, 76.8897d, 2026, 12, 21, 5);
        var dayLen = t[:maghrib] - t[:sunrise];
        // Day at 43°N on Dec 21 is ~9h 09min
        if (dayLen < 8.5d || dayLen > 9.5d) {
            logger.error("Almaty Dec 21 day length unreasonable: " + dayLen.format("%.2f") + "h");
            return false;
        }
        logger.debug("Almaty Dec 21 day length = " + dayLen.format("%.2f") + "h");
        return true;
    }

    // ---------- offsets ----------

    (:test)
    function testPerPrayerOffset_AddsMinutes(logger) {
        var base = _newDumkHanafi().calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
        var calc = new PrayerCalculator(DumkMethod.params(), 2,
            { :fajr => 5, :dhuhr => -3, :isha => 7 });
        var off = calc.calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);
        var ok = true;
        ok = ok && _diffMinutes(off[:fajr],  base[:fajr]  + 5.0d/60.0d) < 0.05d;
        ok = ok && _diffMinutes(off[:dhuhr], base[:dhuhr] - 3.0d/60.0d) < 0.05d;
        ok = ok && _diffMinutes(off[:isha],  base[:isha]  + 7.0d/60.0d) < 0.05d;
        // Untouched prayer should match base
        ok = ok && _diffMinutes(off[:sunrise], base[:sunrise]) < 0.001d;
        if (!ok) {
            logger.error("offset application incorrect");
        }
        return ok;
    }

    // ---------- getNextPrayer ----------

    (:test)
    function testGetNextPrayer_Sequence(logger) {
        var calc = _newDumkHanafi();
        var t = calc.calculate(43.2389d, 76.8897d, 2026, 4, 29, 5);

        // Before Fajr
        var n1 = calc.getNextPrayer(t, 1.0d);
        if (n1[:name] != :fajr) {
            logger.error("at 01:00 next should be fajr, got " + n1[:name]);
            return false;
        }
        // Between Sunrise and Dhuhr
        var n2 = calc.getNextPrayer(t, 8.0d);
        if (n2[:name] != :dhuhr) {
            logger.error("at 08:00 next should be dhuhr, got " + n2[:name]);
            return false;
        }
        // After Isha
        var n3 = calc.getNextPrayer(t, 23.5d);
        if (n3 != null) {
            logger.error("at 23:30 next should be null (tomorrow), got " + n3[:name]);
            return false;
        }
        // secondsUntil monotonicity check
        var n4 = calc.getNextPrayer(t, t[:dhuhr] - 0.5d);  // 30 min before dhuhr
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
