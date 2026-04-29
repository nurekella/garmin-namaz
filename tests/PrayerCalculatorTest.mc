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

    // ---------- ҚМДБ calibration: muftyat.kz reference fixture ----------
    //
    // Values fetched from https://api.muftyat.kz/prayer-times/2026/{lat}/{lng}
    // for the official ҚМДБ city centroids on 2026-04-29 (snapshot baked
    // into the test so the watch never needs network).
    // Coordinates also come from that API's /cities/?search=... lookup.
    //
    // Tolerance 4 min reflects the residual we measured during calibration
    // across Almaty / Astana / Shymkent at 4 dates (Jan/Apr/Jun/Dec).
    // Mean residual is ~1.5 min; latitude-driven drift accounts for the
    // bigger Astana case. Tighten to ±1 min once we add observer-altitude
    // / city-specific maghrib offset (v1.1).
    //
    // Almaty 43.238293°N, 76.945465°E  (city id 72, tz=5)
    (:test)
    function testAlmaty_Muftyat_2026_04_29(logger) {
        var t = _newDumkHanafi().calculate(43.238293d, 76.945465d, 2026, 4, 29, 5);
        var ok = true;
        ok = ok && _within(logger, t[:fajr],    "03:20", 4, "Almaty Fajr");
        ok = ok && _within(logger, t[:sunrise], "04:46", 4, "Almaty Sunrise");
        ok = ok && _within(logger, t[:dhuhr],   "11:53", 4, "Almaty Dhuhr");
        ok = ok && _within(logger, t[:asr],     "16:49", 4, "Almaty Asr (Hanafi)");
        ok = ok && _within(logger, t[:maghrib], "18:54", 4, "Almaty Maghrib");
        ok = ok && _within(logger, t[:isha],    "20:20", 4, "Almaty Isha");
        return ok;
    }

    (:test)
    function testAlmaty_Muftyat_2026_01_01(logger) {
        var t = _newDumkHanafi().calculate(43.238293d, 76.945465d, 2026, 1, 1, 5);
        var ok = true;
        ok = ok && _within(logger, t[:fajr],    "05:59", 4, "Almaty Fajr Jan 1");
        ok = ok && _within(logger, t[:sunrise], "07:21", 4, "Almaty Sunrise Jan 1");
        ok = ok && _within(logger, t[:dhuhr],   "11:59", 4, "Almaty Dhuhr Jan 1");
        ok = ok && _within(logger, t[:asr],     "14:48", 4, "Almaty Asr Jan 1");
        ok = ok && _within(logger, t[:maghrib], "16:30", 4, "Almaty Maghrib Jan 1");
        ok = ok && _within(logger, t[:isha],    "17:53", 4, "Almaty Isha Jan 1");
        return ok;
    }

    (:test)
    function testAlmaty_Muftyat_2026_06_21(logger) {
        // Summer solstice — short night, very early Fajr
        var t = _newDumkHanafi().calculate(43.238293d, 76.945465d, 2026, 6, 21, 5);
        var ok = true;
        ok = ok && _within(logger, t[:fajr],    "02:23", 4, "Almaty Fajr Jun 21");
        ok = ok && _within(logger, t[:sunrise], "04:09", 4, "Almaty Sunrise Jun 21");
        ok = ok && _within(logger, t[:dhuhr],   "11:57", 4, "Almaty Dhuhr Jun 21");
        ok = ok && _within(logger, t[:asr],     "17:16", 4, "Almaty Asr Jun 21");
        ok = ok && _within(logger, t[:maghrib], "19:39", 4, "Almaty Maghrib Jun 21");
        ok = ok && _within(logger, t[:isha],    "21:25", 4, "Almaty Isha Jun 21");
        return ok;
    }

    (:test)
    function testAlmaty_Muftyat_2026_12_21(logger) {
        // Winter solstice — long night
        var t = _newDumkHanafi().calculate(43.238293d, 76.945465d, 2026, 12, 21, 5);
        var ok = true;
        ok = ok && _within(logger, t[:fajr],    "05:55", 4, "Almaty Fajr Dec 21");
        ok = ok && _within(logger, t[:sunrise], "07:18", 4, "Almaty Sunrise Dec 21");
        ok = ok && _within(logger, t[:dhuhr],   "11:53", 4, "Almaty Dhuhr Dec 21");
        ok = ok && _within(logger, t[:asr],     "14:41", 4, "Almaty Asr Dec 21");
        ok = ok && _within(logger, t[:maghrib], "16:23", 4, "Almaty Maghrib Dec 21");
        ok = ok && _within(logger, t[:isha],    "17:46", 4, "Almaty Isha Dec 21");
        return ok;
    }

    // Astana 51.133333°N, 71.433333°E (city id 3, tz=5).
    // Larger latitude drives bigger residual; tolerance bumped to 6 min.
    (:test)
    function testAstana_Muftyat_2026_04_29(logger) {
        var t = _newDumkHanafi().calculate(51.133333d, 71.433333d, 2026, 4, 29, 5);
        var ok = true;
        ok = ok && _within(logger, t[:fajr],    "02:59", 6, "Astana Fajr");
        ok = ok && _within(logger, t[:sunrise], "04:46", 6, "Astana Sunrise");
        ok = ok && _within(logger, t[:dhuhr],   "12:17", 6, "Astana Dhuhr");
        ok = ok && _within(logger, t[:asr],     "17:20", 6, "Astana Asr");
        ok = ok && _within(logger, t[:maghrib], "19:38", 6, "Astana Maghrib");
        ok = ok && _within(logger, t[:isha],    "21:26", 6, "Astana Isha");
        return ok;
    }

    // Shymkent 42.368009°N, 69.612769°E (city id 57, tz=5)
    (:test)
    function testShymkent_Muftyat_2026_04_29(logger) {
        var t = _newDumkHanafi().calculate(42.368009d, 69.612769d, 2026, 4, 29, 5);
        var ok = true;
        ok = ok && _within(logger, t[:fajr],    "03:53", 4, "Shymkent Fajr");
        ok = ok && _within(logger, t[:sunrise], "05:17", 4, "Shymkent Sunrise");
        ok = ok && _within(logger, t[:dhuhr],   "12:22", 4, "Shymkent Dhuhr");
        ok = ok && _within(logger, t[:asr],     "17:17", 4, "Shymkent Asr");
        ok = ok && _within(logger, t[:maghrib], "19:22", 4, "Shymkent Maghrib");
        ok = ok && _within(logger, t[:isha],    "20:46", 4, "Shymkent Isha");
        return ok;
    }

    // Asr Standard for Almaty 2026-04-29: muftyat publishes Hanafi only,
    // so this test just confirms Std lands meaningfully earlier than Hanafi.
    (:test)
    function testAlmaty_AsrStandard_VsHanafi(logger) {
        var hanafi = _newDumkHanafi().calculate(43.238293d, 76.945465d, 2026, 4, 29, 5);
        var std    = _newDumkStandard().calculate(43.238293d, 76.945465d, 2026, 4, 29, 5);
        var diffMin = (hanafi[:asr] - std[:asr]) * 60.0d;
        if (diffMin < 30.0d || diffMin > 120.0d) {
            logger.error("Std-vs-Hanafi Asr gap unreasonable: " + diffMin.format("%.1f") + " min");
            return false;
        }
        logger.debug("Std " + _hhmm(std[:asr]) + " | Hanafi " + _hhmm(hanafi[:asr])
                     + " | gap " + diffMin.format("%.1f") + " min");
        return true;
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
