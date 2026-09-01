using Toybox.Lang;
using Toybox.Math;

// Computes the five daily prayer times plus sunrise for a given date,
// location and method. Times are returned in fractional local hours
// (e.g. 13.5 = 13:30); convert to Time.Moment at the UI layer.
//
// Pipeline for one day:
//   1. Sun declination / equation of time at local noon -> solar noon.
//   2. First pass: every event (sunrise, sunset, fajr, isha, asr) from
//      the noon sun position.
//   3. Second pass: re-evaluate the sun position at each event's own
//      time and recompute. Declination drifts up to 0.4°/day near the
//      equinoxes, which shifts Fajr/Isha by ~1 min if evaluated at noon
//      — the refinement is what brings us inside ±1 min of muftyat.kz.
//   4. High-latitude fallback for Fajr / Isha when the sun never reaches
//      the twilight angle (params[:highLat]).
//   5. Method "precaution" (ihtiyat) minutes that depend on latitude
//      (params[:precaution]) — used by ҚМДБ.
//   6. Method-level calibration offsets (params[:offsets]) and user
//      per-prayer offsets stack on top.
//
// Tahajjud (start of the last third of the night) uses tomorrow's Fajr,
// not today's, so the night length is exact.
(:glance, :background)
class PrayerCalculator {

    var _params;          // Dictionary, e.g. DumkMethod.params()
    var _asrFactor;       // 1 = Standard, 2 = Hanafi
    var _userOffsets;     // Dictionary or null: { :fajr => Number, ... } in minutes

    function initialize(params, asrFactor, userOffsets) {
        _params       = params;
        _asrFactor    = asrFactor;
        _userOffsets  = userOffsets;
    }

    // year, month, day: integers in Gregorian local civil calendar.
    // tzOffset: hours east of UTC (including DST), e.g. 5.0 for Asia/Almaty.
    function calculate(latitude, longitude, year, month, day, tzOffset) {
        var lat = latitude.toDouble();
        var lon = longitude.toDouble();
        var tz  = tzOffset.toDouble();
        var jd0 = SolarMath.julianDate(year, month, day);   // 00:00 UT of the civil date

        var fajrAngle    = _params[:fajrAngle].toDouble();
        var sunriseAngle = _angleOrDefault(:sunriseAngle, 0.833d);
        var ishaAngle    = (_params[:ishaAngle] != null) ? _params[:ishaAngle].toDouble() : null;

        // Solar noon, refined once at its own time.
        var noon = _solarNoon(jd0, tz, lon, 12.0d);
        noon = _solarNoon(jd0, tz, lon, noon);

        var sunrise = _eventTime(jd0, tz, lat, lon, sunriseAngle, -1, noon - 6.0d);
        var sunset  = _eventTime(jd0, tz, lat, lon, sunriseAngle,  1, noon + 6.0d);
        var fajr    = _eventTime(jd0, tz, lat, lon, fajrAngle,    -1, noon - 7.0d);
        var asr     = _asrTime(jd0, tz, lat, lon, noon + 4.0d);

        // Isha — angle-based by default, but methods like Umm al-Qura use a
        // fixed interval after Maghrib. params[:ishaIntervalMin] takes
        // precedence over params[:ishaAngle] when present.
        var isha = null;
        var intervalMin = _params[:ishaIntervalMin];
        if (intervalMin != null) {
            if (sunset != null) {
                var mins = intervalMin.toNumber();
                var ramadanMin = _params[:ishaIntervalRamadanMin];
                if (ramadanMin != null && _isRamadanNight(year, month, day)) {
                    mins = ramadanMin.toNumber();
                }
                isha = sunset + mins.toDouble() / 60.0d;
            }
        } else if (ishaAngle != null) {
            isha = _eventTime(jd0, tz, lat, lon, ishaAngle, 1, noon + 7.0d);
        }

        // High-latitude fallback — only meaningful when the sun actually
        // rises and sets that day.
        var highLat = _params[:highLat];
        if (highLat != null && sunrise != null && sunset != null) {
            var night = (24.0d - sunset) + sunrise;
            var pF = _nightPortion(highLat, fajrAngle, night);
            if (fajr == null || (sunrise - fajr) > pF) { fajr = sunrise - pF; }
            if (intervalMin == null && ishaAngle != null) {
                var pI = _nightPortion(highLat, ishaAngle, night);
                if (isha == null || (isha - sunset) > pI) { isha = sunset + pI; }
            }
        }

        // Tahajjud — start of the last third of the night
        // (Maghrib today -> Fajr tomorrow).
        var tahajjud = null;
        if (sunset != null && fajr != null) {
            var fajrTomorrow = _eventTime(jd0 + 1.0d, tz, lat, lon, fajrAngle, -1, fajr);
            if (fajrTomorrow == null) { fajrTomorrow = fajr; }
            var nightLen = (24.0d - sunset) + fajrTomorrow;   // hours
            tahajjud = sunset + nightLen * 2.0d / 3.0d;
            if (tahajjud >= 24.0d) { tahajjud -= 24.0d; }
        }

        // Precaution (ihtiyat) minutes: pushed later for Dhuhr/Asr/Maghrib
        // and earlier for Sunrise. Fajr / Isha are left alone.
        var p = _precautionMinutes(lat).toDouble() / 60.0d;
        var dhuhr   = noon + p;
        var maghrib = (sunset  != null) ? sunset  + p : null;
        if (sunrise != null) { sunrise = sunrise - p; }
        if (asr     != null) { asr     = asr + p; }

        return {
            :fajr      => _withOffsets(fajr,    :fajr),
            :sunrise   => _withOffsets(sunrise, :sunrise),
            :dhuhr     => _withOffsets(dhuhr,   :dhuhr),
            :asr       => _withOffsets(asr,     :asr),
            :maghrib   => _withOffsets(maghrib, :maghrib),
            :isha      => _withOffsets(isha,    :isha),
            :tahajjud  => tahajjud,
            :solarNoon => noon
        };
    }

    // Returns the next prayer entry strictly after `currentHourLocal`.
    // Result: { :name => Symbol, :time => Float (hours), :secondsUntil => Number }.
    // If all prayers for today have passed, returns null.
    function getNextPrayer(prayerTimes, currentHourLocal) {
        var order = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < order.size(); i++) {
            var name = order[i];
            var t = prayerTimes[name];
            if (t != null && t > currentHourLocal) {
                var secondsUntil = ((t - currentHourLocal) * 3600.0d).toNumber();
                return {
                    :name         => name,
                    :time         => t,
                    :secondsUntil => secondsUntil
                };
            }
        }
        return null;
    }

    // ---------- internal ----------

    // Julian date of a local civil time on the day starting at `jd0`.
    function _jdAt(jd0, tz, localHour) {
        return jd0 + (localHour - tz) / 24.0d;
    }

    function _solarNoon(jd0, tz, lon, guessHour) {
        var eqt = SolarMath.equationOfTime(_jdAt(jd0, tz, guessHour));
        return 12.0d - lon / 15.0d + tz - eqt / 60.0d;
    }

    // Time (local hours) when the sun is `angle` degrees below the
    // horizon, before (direction = -1) or after (+1) solar noon. Sun
    // position is evaluated at `guessHour`, then once more at the
    // resulting time. Returns null if the sun never reaches the angle.
    function _eventTime(jd0, tz, lat, lon, angle, direction, guessHour) {
        var t = guessHour;
        for (var pass = 0; pass < 2; pass++) {
            var jd   = _jdAt(jd0, tz, t);
            var decl = SolarMath.declination(jd);
            var eqt  = SolarMath.equationOfTime(jd);
            var noon = 12.0d - lon / 15.0d + tz - eqt / 60.0d;
            var h    = SolarMath.hourAngle(lat, decl, angle);
            if (h == null) { return null; }
            t = noon + direction.toDouble() * h;
        }
        return t;
    }

    function _asrTime(jd0, tz, lat, lon, guessHour) {
        var t = guessHour;
        for (var pass = 0; pass < 2; pass++) {
            var jd   = _jdAt(jd0, tz, t);
            var decl = SolarMath.declination(jd);
            var eqt  = SolarMath.equationOfTime(jd);
            var noon = 12.0d - lon / 15.0d + tz - eqt / 60.0d;
            var alt  = SolarMath.asrAngle(lat, decl, _asrFactor);
            var h    = SolarMath.hourAngle(lat, decl, -alt);
            if (h == null) { return null; }
            t = noon + h;
        }
        return t;
    }

    // Portion of the night (hours) allotted to twilight under the given
    // high-latitude rule (praytimes.org conventions).
    function _nightPortion(rule, angle, nightHours) {
        if (rule == :angleBased) { return nightHours * angle / 60.0d; }
        if (rule == :oneSeventh) { return nightHours / 7.0d; }
        return nightHours / 2.0d;   // :nightMiddle
    }

    // params[:precaution] = { :latSplit => Double, :south => Number, :north => Number }
    function _precautionMinutes(lat) {
        var pc = _params[:precaution];
        if (pc == null) { return 0; }
        var split = pc[:latSplit];
        if (split != null && lat >= split.toDouble()) { return pc[:north].toNumber(); }
        return pc[:south].toNumber();
    }

    // Isha of civil date D belongs to the Islamic day that begins at that
    // sunset, i.e. the Hijri date of D+1.
    function _isRamadanNight(year, month, day) {
        var jdn = (SolarMath.julianDate(year, month, day) + 0.5d).toNumber() + 1;
        return HijriDate.fromJdn(jdn)[:month] == 9;
    }

    function _angleOrDefault(key, fallback) {
        var v = _params[key];
        return (v != null) ? v.toDouble() : fallback;
    }

    function _withOffsets(time, key) {
        if (time == null) { return null; }
        var total = 0;
        var methodOffsets = _params[:offsets];
        if (methodOffsets != null && methodOffsets[key] != null) {
            total += methodOffsets[key].toNumber();
        }
        if (_userOffsets != null && _userOffsets[key] != null) {
            total += _userOffsets[key].toNumber();
        }
        if (total == 0) { return time; }
        return time + total.toDouble() / 60.0d;
    }
}
