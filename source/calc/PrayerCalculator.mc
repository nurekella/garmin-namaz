using Toybox.Lang;
using Toybox.Math;

// Computes the five daily prayer times plus sunrise for a given date,
// location and method. Times are returned in fractional local hours
// (e.g. 13.5 = 13:30); convert to Time.Moment at the UI layer.
//
// At very high latitudes (typically > 48°N) the sun may not reach the
// Fajr/Isha angles; in that case the corresponding entry is `null`.
// A high-latitude correction layer can be added later (Stage 11 / v1.1).
class PrayerCalculator {

    var _params;     // Dictionary, e.g. DumkMethod.params()
    var _asrFactor;  // 1 = Standard, 2 = Hanafi
    var _offsets;    // Dictionary or null: { :fajr=>Number, :dhuhr=>..., ... } (minutes)

    function initialize(params, asrFactor, offsets) {
        _params    = params;
        _asrFactor = asrFactor;
        _offsets   = offsets;
    }

    // year, month, day: integers in Gregorian local civil calendar.
    // tzOffset: hours east of UTC, e.g. 5.0 for Asia/Almaty.
    function calculate(latitude, longitude, year, month, day, tzOffset) {
        var jd   = SolarMath.julianDate(year, month, day);
        var decl = SolarMath.declination(jd);
        var eqt  = SolarMath.equationOfTime(jd);

        // True solar noon expressed in local civil hours.
        var solarNoon = 12.0d
                      - longitude.toDouble() / 15.0d
                      + tzOffset.toDouble()
                      - eqt / 60.0d;

        var fajrAngle = _params[:fajrAngle].toDouble();
        var ishaAngle = _params[:ishaAngle].toDouble();
        var hSunset   = SolarMath.hourAngle(latitude, decl, 0.833d);
        var hFajr     = SolarMath.hourAngle(latitude, decl, fajrAngle);
        var hIsha     = SolarMath.hourAngle(latitude, decl, ishaAngle);

        // Asr: sun at altitude `asrAlt` above horizon -> pass -asrAlt to hourAngle.
        var asrAlt = SolarMath.asrAngle(latitude, decl, _asrFactor);
        var hAsr   = SolarMath.hourAngle(latitude, decl, -asrAlt);

        var dhuhr   = solarNoon + _params[:dhuhrOffset].toDouble() / 60.0d;
        var sunrise = (hSunset != null) ? solarNoon - hSunset : null;
        var maghrib = (hSunset != null)
                      ? solarNoon + hSunset + _params[:maghribOffset].toDouble() / 60.0d
                      : null;
        var fajr    = (hFajr != null) ? solarNoon - hFajr : null;
        var isha    = (hIsha != null) ? solarNoon + hIsha : null;
        var asr     = (hAsr  != null) ? solarNoon + hAsr  : null;

        return {
            :fajr      => _withOffset(fajr,    :fajr),
            :sunrise   => _withOffset(sunrise, :sunrise),
            :dhuhr     => _withOffset(dhuhr,   :dhuhr),
            :asr       => _withOffset(asr,     :asr),
            :maghrib   => _withOffset(maghrib, :maghrib),
            :isha      => _withOffset(isha,    :isha),
            :solarNoon => solarNoon
        };
    }

    // Returns the next prayer entry strictly after `currentHourLocal`.
    // Result: { :name => Symbol, :time => Float (hours), :secondsUntil => Number }.
    // If all prayers for today have passed, returns null (caller schedules
    // tomorrow's Fajr separately).
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

    function _withOffset(time, key) {
        if (time == null || _offsets == null) { return time; }
        var off = _offsets[key];
        if (off == null) { return time; }
        return time + off.toDouble() / 60.0d;
    }
}
