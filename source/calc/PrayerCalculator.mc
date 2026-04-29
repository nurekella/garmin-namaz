using Toybox.Lang;
using Toybox.Math;

// Computes the five daily prayer times plus sunrise for a given date,
// location and method. Times are returned in fractional local hours
// (e.g. 13.5 = 13:30); convert to Time.Moment at the UI layer.
//
// Method-level calibration offsets live in params[:offsets].
// User-tuned per-prayer offsets (from settings) come in via the `offsets`
// constructor argument and stack on top.
//
// At very high latitudes (typically > 48° in winter / > 60° in summer)
// the sun may not reach the Fajr/Isha angles; in that case the entry is
// `null`. A high-latitude correction layer can be added later (v1.1).
(:glance)
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
    // tzOffset: hours east of UTC, e.g. 5.0 for Asia/Almaty (post-2024-03).
    function calculate(latitude, longitude, year, month, day, tzOffset) {
        var jd   = SolarMath.julianDate(year, month, day);
        var decl = SolarMath.declination(jd);
        var eqt  = SolarMath.equationOfTime(jd);

        // True solar noon expressed in local civil hours.
        var solarNoon = 12.0d
                      - longitude.toDouble() / 15.0d
                      + tzOffset.toDouble()
                      - eqt / 60.0d;

        var fajrAngle    = _params[:fajrAngle].toDouble();
        var ishaAngle    = _params[:ishaAngle].toDouble();
        var sunriseAngle = _angleOrDefault(:sunriseAngle, 0.833d);

        var hSun  = SolarMath.hourAngle(latitude, decl, sunriseAngle);
        var hFajr = SolarMath.hourAngle(latitude, decl, fajrAngle);
        var hIsha = SolarMath.hourAngle(latitude, decl, ishaAngle);

        // Asr: sun at altitude `asrAlt` above horizon; pass -asrAlt to hourAngle.
        var asrAlt = SolarMath.asrAngle(latitude, decl, _asrFactor);
        var hAsr   = SolarMath.hourAngle(latitude, decl, -asrAlt);

        var fajr    = (hFajr != null) ? solarNoon - hFajr : null;
        var sunrise = (hSun  != null) ? solarNoon - hSun  : null;
        var dhuhr   = solarNoon;
        var asr     = (hAsr  != null) ? solarNoon + hAsr  : null;
        var maghrib = (hSun  != null) ? solarNoon + hSun  : null;
        var isha    = (hIsha != null) ? solarNoon + hIsha : null;

        return {
            :fajr      => _withOffsets(fajr,    :fajr),
            :sunrise   => _withOffsets(sunrise, :sunrise),
            :dhuhr     => _withOffsets(dhuhr,   :dhuhr),
            :asr       => _withOffsets(asr,     :asr),
            :maghrib   => _withOffsets(maghrib, :maghrib),
            :isha      => _withOffsets(isha,    :isha),
            :solarNoon => solarNoon
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
