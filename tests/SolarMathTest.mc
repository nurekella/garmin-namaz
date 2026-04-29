using Toybox.Test;
using Toybox.Math;
using Toybox.Lang;

module SolarMathTest {

    function _near(logger, actual, expected, tol, label) {
        var a = actual.toDouble();
        var e = expected.toDouble();
        var diff = a - e;
        if (diff < 0.0d) { diff = -diff; }
        if (diff > tol.toDouble()) {
            logger.error(label + ": expected " + e + " ± " + tol + ", got " + a + " (diff " + diff + ")");
            return false;
        }
        logger.debug(label + ": " + a + " ~ " + e + " OK");
        return true;
    }

    // ---------- Julian Date ----------

    (:test)
    function testJD_J2000_midnight(logger) {
        return _near(logger, SolarMath.julianDate(2000, 1, 1), 2451544.5d, 1e-6, "JD 2000-01-01 0h UT");
    }

    (:test)
    function testJD_2024_06_21(logger) {
        return _near(logger, SolarMath.julianDate(2024, 6, 21), 2460482.5d, 1e-6, "JD 2024-06-21 0h UT");
    }

    (:test)
    function testJD_2024_12_21(logger) {
        return _near(logger, SolarMath.julianDate(2024, 12, 21), 2460665.5d, 1e-6, "JD 2024-12-21 0h UT");
    }

    (:test)
    function testJD_2026_04_29(logger) {
        // verification day used in CLAUDE.md test cases
        return _near(logger, SolarMath.julianDate(2026, 4, 29), 2461159.5d, 1e-6, "JD 2026-04-29 0h UT");
    }

    (:test)
    function testJD_LeapDay_2024_02_29(logger) {
        // Feb-as-month-14-of-prior-year branch
        return _near(logger, SolarMath.julianDate(2024, 2, 29), 2460369.5d, 1e-6, "JD 2024-02-29 (leap)");
    }

    // ---------- Solar declination ----------

    (:test)
    function testDecl_SummerSolstice(logger) {
        // Around June 21 sun reaches max +23.4°
        var d = SolarMath.declination(2460482.5d);
        return _near(logger, d, 23.43d, 0.2d, "summer solstice declination");
    }

    (:test)
    function testDecl_WinterSolstice(logger) {
        var d = SolarMath.declination(2460665.5d);
        return _near(logger, d, -23.43d, 0.2d, "winter solstice declination");
    }

    (:test)
    function testDecl_J2000_midnight(logger) {
        // computed via NOAA formula at JD 2451544.5: ~ -23.07°
        var d = SolarMath.declination(2451544.5d);
        return _near(logger, d, -23.07d, 0.2d, "2000-01-01 0h UT declination");
    }

    (:test)
    function testDecl_VernalEquinox_2024(logger) {
        // March 20 2024 — declination crosses 0
        var d = SolarMath.declination(2460389.5d);
        return _near(logger, d, 0.0d, 0.5d, "vernal equinox declination near 0");
    }

    // ---------- Equation of Time ----------

    (:test)
    function testEoT_J2000_midnight(logger) {
        // NOAA formula at JD 2451544.5: ~ -3.06 min
        var eot = SolarMath.equationOfTime(2451544.5d);
        return _near(logger, eot, -3.06d, 0.5d, "2000-01-01 0h UT EoT");
    }

    (:test)
    function testEoT_SummerSolstice(logger) {
        // Around June 21 EoT is about -1 to -2 min
        var eot = SolarMath.equationOfTime(2460482.5d);
        return _near(logger, eot, -1.7d, 1.0d, "summer solstice EoT");
    }

    (:test)
    function testEoT_NovemberMaximum_2024(logger) {
        // EoT peaks ~ +16 min around Nov 3
        var jd = SolarMath.julianDate(2024, 11, 3);
        var eot = SolarMath.equationOfTime(jd);
        return _near(logger, eot, 16.4d, 1.0d, "early November EoT max");
    }

    // ---------- Hour angle ----------

    (:test)
    function testHourAngle_EquatorEquinox(logger) {
        // lat=0, decl=0, sunrise/sunset angle = 0.833° → 90.83°/15 = 6.055h
        var h = SolarMath.hourAngle(0.0d, 0.0d, 0.833d);
        if (h == null) {
            logger.error("hourAngle returned null on trivial case");
            return false;
        }
        return _near(logger, h, 6.0555d, 0.01d, "hourAngle(0,0,0.833) ≈ 6.06h");
    }

    (:test)
    function testHourAngle_Almaty_FajrSummer(logger) {
        // Almaty 43.24°N, summer solstice (decl=+23.43°), fajr at 18° below horizon.
        // Hand-derived from cos(H) = (sin(-18°) - sin(lat)·sin(decl))/(cos(lat)·cos(decl)):
        //   cos(H) = -0.8700  ->  H = 150.43°  ->  10.03 h before solar noon.
        // Sanity: short summer night at 43°N pushes fajr very early (~02:00 local).
        var h = SolarMath.hourAngle(43.2389d, 23.43d, 18.0d);
        if (h == null) {
            logger.error("hourAngle null for fajr at Almaty solstice");
            return false;
        }
        return _near(logger, h, 10.03d, 0.05d, "Almaty fajr hour angle at summer solstice");
    }

    (:test)
    function testHourAngle_Almaty_FajrWinter(logger) {
        // Almaty 43.24°N, winter solstice (decl=-23.43°), fajr 18° below horizon.
        // cos(H) = -0.0547  ->  H = 93.13°  ->  6.21 h before noon (~06:40 local).
        var h = SolarMath.hourAngle(43.2389d, -23.43d, 18.0d);
        if (h == null) {
            logger.error("hourAngle null for fajr at Almaty winter solstice");
            return false;
        }
        return _near(logger, h, 6.21d, 0.05d, "Almaty fajr hour angle at winter solstice");
    }

    (:test)
    function testHourAngle_HighLat_NoSunset(logger) {
        // 80°N at summer solstice — sun does not set, hourAngle should return null
        var h = SolarMath.hourAngle(80.0d, 23.43d, 0.833d);
        if (h != null) {
            logger.error("expected null (polar day), got " + h);
            return false;
        }
        return true;
    }

    // ---------- Asr angle ----------

    (:test)
    function testAsrAngle_Hanafi_AlmatySolstice(logger) {
        // factor=2, lat=43.24°, decl=23.43°.
        // zenith_asr = atan(2 + tan(19.81°)) = atan(2.36025) = 67.04°
        // altitude_asr = 90 - 67.04 = 22.96°
        var a = SolarMath.asrAngle(43.2389d, 23.43d, 2);
        return _near(logger, a, 22.96d, 0.3d, "Asr Hanafi altitude at Almaty solstice");
    }

    (:test)
    function testAsrAngle_Standard_AlmatySolstice(logger) {
        // factor=1, lat=43.24°, decl=23.43°.
        // zenith_asr = atan(1 + tan(19.81°)) = atan(1.36025) = 53.69°
        // altitude_asr = 90 - 53.69 = 36.31°
        var a = SolarMath.asrAngle(43.2389d, 23.43d, 1);
        return _near(logger, a, 36.31d, 0.3d, "Asr Standard altitude at Almaty solstice");
    }

    // ---------- Helpers ----------

    (:test)
    function testFixHour(logger) {
        var ok = true;
        ok = ok && _near(logger, SolarMath.fixHour(25.0d),   1.0d,  1e-9, "25h → 1h");
        ok = ok && _near(logger, SolarMath.fixHour(-1.0d),  23.0d,  1e-9, "-1h → 23h");
        ok = ok && _near(logger, SolarMath.fixHour(12.5d),  12.5d,  1e-9, "12.5h → 12.5h");
        ok = ok && _near(logger, SolarMath.fixHour(48.0d),   0.0d,  1e-9, "48h → 0h");
        ok = ok && _near(logger, SolarMath.fixHour(-25.0d), 23.0d,  1e-9, "-25h → 23h");
        return ok;
    }

    (:test)
    function testFixAngle(logger) {
        var ok = true;
        ok = ok && _near(logger, SolarMath.fixAngle(370.0d),  10.0d, 1e-9, "370° → 10°");
        ok = ok && _near(logger, SolarMath.fixAngle(-30.0d), 330.0d, 1e-9, "-30° → 330°");
        ok = ok && _near(logger, SolarMath.fixAngle(720.0d),   0.0d, 1e-9, "720° → 0°");
        return ok;
    }

    (:test)
    function testDegRadRoundtrip(logger) {
        var ok = true;
        ok = ok && _near(logger, SolarMath.rad2deg(SolarMath.deg2rad(180.0d)), 180.0d, 1e-9, "180° roundtrip");
        ok = ok && _near(logger, SolarMath.rad2deg(SolarMath.deg2rad(43.2389d)), 43.2389d, 1e-9, "Almaty lat roundtrip");
        return ok;
    }
}
