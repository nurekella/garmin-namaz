using Toybox.Math;
using Toybox.Lang;

(:glance, :background)
module SolarMath {

    const RAD2DEG = 57.29577951308232d;
    const DEG2RAD = 0.017453292519943295d;

    function deg2rad(deg) {
        return deg.toDouble() * DEG2RAD;
    }

    function rad2deg(rad) {
        return rad.toDouble() * RAD2DEG;
    }

    function fixHour(h) {
        var hd = h.toDouble();
        return hd - 24.0d * Math.floor(hd / 24.0d).toDouble();
    }

    function fixAngle(a) {
        var ad = a.toDouble();
        return ad - 360.0d * Math.floor(ad / 360.0d).toDouble();
    }

    function julianDate(year, month, day) {
        var y = year;
        var m = month;
        if (m <= 2) {
            y -= 1;
            m += 12;
        }
        var aDiv = y / 100;
        var bCorr = 2 - aDiv + aDiv / 4;
        var sumYears = (365.25d * (y + 4716).toDouble()).toLong().toDouble();
        var sumMonths = (30.6001d * (m + 1).toDouble()).toLong().toDouble();
        return sumYears + sumMonths + day.toDouble() + bCorr.toDouble() - 1524.5d;
    }

    function julianCentury(jd) {
        return (jd.toDouble() - 2451545.0d) / 36525.0d;
    }

    function declination(jd) {
        var t = julianCentury(jd);
        var l0 = fixAngle(280.46646d + 36000.76983d * t + 0.0003032d * t * t);
        var m  = fixAngle(357.52911d + 35999.05029d * t - 0.0001537d * t * t);
        var c  = Math.sin(deg2rad(m))       * (1.914602d - 0.004817d * t - 0.000014d * t * t)
               + Math.sin(deg2rad(2.0d * m)) * (0.019993d - 0.000101d * t)
               + Math.sin(deg2rad(3.0d * m)) * 0.000289d;
        var sunLon = l0 + c;
        var omega  = 125.04d - 1934.136d * t;
        var lambda = sunLon - 0.00569d - 0.00478d * Math.sin(deg2rad(omega));
        var eps0   = 23.4392911d - 0.0130042d * t - 0.00000016d * t * t;
        var eps    = eps0 + 0.00256d * Math.cos(deg2rad(omega));
        var sinDecl = Math.sin(deg2rad(eps)) * Math.sin(deg2rad(lambda));
        if (sinDecl > 1.0d)  { sinDecl = 1.0d; }
        if (sinDecl < -1.0d) { sinDecl = -1.0d; }
        return rad2deg(Math.asin(sinDecl));
    }

    function equationOfTime(jd) {
        var t = julianCentury(jd);
        var l0 = fixAngle(280.46646d + 36000.76983d * t + 0.0003032d * t * t);
        var m  = fixAngle(357.52911d + 35999.05029d * t - 0.0001537d * t * t);
        var e  = 0.016708634d - 0.000042037d * t - 0.0000001267d * t * t;
        var omega = 125.04d - 1934.136d * t;
        var eps0  = 23.4392911d - 0.0130042d * t - 0.00000016d * t * t;
        var eps   = eps0 + 0.00256d * Math.cos(deg2rad(omega));
        var y = Math.tan(deg2rad(eps) / 2.0d);
        y = y * y;
        var l0Rad = deg2rad(l0);
        var mRad  = deg2rad(m);
        var sin2L = Math.sin(2.0d * l0Rad);
        var sinM  = Math.sin(mRad);
        var cos2L = Math.cos(2.0d * l0Rad);
        var sin4L = Math.sin(4.0d * l0Rad);
        var sin2M = Math.sin(2.0d * mRad);
        var etime = y * sin2L
                  - 2.0d * e * sinM
                  + 4.0d * e * y * sinM * cos2L
                  - 0.5d * y * y * sin4L
                  - 1.25d * e * e * sin2M;
        return rad2deg(etime) * 4.0d;
    }

    // Returns hours from solar noon for the sun to reach `angle` below horizon.
    // Returns null at high latitudes when the sun never reaches that angle.
    function hourAngle(latitude, decl, angle) {
        var latRad  = deg2rad(latitude);
        var declRad = deg2rad(decl);
        var aRad    = deg2rad(angle);
        var num = -Math.sin(aRad) - Math.sin(latRad) * Math.sin(declRad);
        var den = Math.cos(latRad) * Math.cos(declRad);
        if (den == 0.0d) { return null; }
        var cosH = num / den;
        if (cosH > 1.0d || cosH < -1.0d) { return null; }
        return rad2deg(Math.acos(cosH)) / 15.0d;
    }

    // Sun altitude (degrees above horizon) at which Asr begins.
    // Hanafi: factor=2; Standard (Shafi/Maliki/Hanbali): factor=1.
    //
    // Derivation: shadow at Asr = noon-shadow + factor * height
    //   tan(zenith_asr) = factor + tan(|lat - decl|)
    //   altitude_asr   = arccot(...) = atan(1/(factor + tan(|lat-decl|)))
    //
    // Returned altitude is suitable for `hourAngle(lat, decl, -altitude)`
    // since hourAngle takes degrees BELOW horizon.
    function asrAngle(latitude, decl, factor) {
        var diff = latitude.toDouble() - decl.toDouble();
        if (diff < 0.0d) { diff = -diff; }
        var t = factor.toDouble() + Math.tan(deg2rad(diff));
        return rad2deg(Math.atan(1.0d / t));
    }
}
