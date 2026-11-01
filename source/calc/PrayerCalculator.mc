using Toybox.Lang;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Computes the five daily prayer times plus sunrise for a given date,
// location and method. Times are returned in fractional local hours
// (e.g. 13.5 = 13:30); convert to Time.Moment at the UI layer.
//
// Method parameters (see DumkMethod):
//   :fajrAngle / :ishaAngle   sun depression for Fajr / Isha
//   :ishaSymmetric            Isha = Maghrib + (Sunrise - Fajr), as ҚМДБ does
//   :nightCap                 Fajr/Isha never start farther from Sunrise/
//                             Maghrib than this fraction of the night.
//                             Without it the cap angle/60 only replaces a
//                             Fajr/Isha the sun never reaches (high
//                             latitudes in summer), so no entry is null.
//   :offsets                  minutes added to sunrise/dhuhr/asr/maghrib
//   :highLat + :offsetsHigh   a different set of offsets from that latitude
//
// User-tuned per-prayer offsets (from settings) come in via the `offsets`
// constructor argument and stack on top of the final times.
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

        var mo = _methodOffsets(latitude);
        var hSun = SolarMath.hourAngle(latitude, decl, _angleOrDefault(:sunriseAngle, 0.833d));

        // Asr: sun at altitude `asrAlt` above horizon; pass -asrAlt to hourAngle.
        var asrAlt = SolarMath.asrAngle(latitude, decl, _asrFactor);
        var hAsr   = SolarMath.hourAngle(latitude, decl, -asrAlt);

        var sunrise = (hSun != null) ? solarNoon - hSun + _off(mo, :sunrise) : null;
        var maghrib = (hSun != null) ? solarNoon + hSun + _off(mo, :maghrib) : null;
        var dhuhr   = solarNoon + _off(mo, :dhuhr);
        var asr     = (hAsr != null) ? solarNoon + hAsr + _off(mo, :asr) : null;

        // Fajr / Isha. `night` runs Maghrib -> next Sunrise (today's length
        // is a fine stand-in for the next night).
        var night = (sunrise != null && maghrib != null) ? (24.0d - maghrib) + sunrise : null;
        var fajrAngle = _params[:fajrAngle].toDouble();
        var fajrGap = _twilightGap(
            SolarMath.hourAngle(latitude, decl, fajrAngle), solarNoon, sunrise, true,
            night, fajrAngle);

        var fajr = (fajrGap != null) ? sunrise - fajrGap : null;

        // Isha — symmetric to Fajr, fixed interval after Maghrib (Umm al-Qura),
        // or its own angle. :ishaIntervalMin wins over :ishaAngle.
        var isha = null;
        var intervalMin = _params[:ishaIntervalMin];
        if (maghrib != null) {
            if (intervalMin != null) {
                isha = maghrib + intervalMin.toDouble() / 60.0d;
            } else if (_params[:ishaSymmetric] == true) {
                if (fajrGap != null) { isha = maghrib + fajrGap; }
            } else if (_params[:ishaAngle] != null) {
                var ishaAngle = _params[:ishaAngle].toDouble();
                var ishaGap = _twilightGap(
                    SolarMath.hourAngle(latitude, decl, ishaAngle), solarNoon, maghrib, false,
                    night, ishaAngle);
                if (ishaGap != null) { isha = maghrib + ishaGap; }
            }
        }

        // Reference times, not obligatory prayers. Duha: a quarter of the
        // daylight after sunrise. Tahajjud: the last third of the night that
        // ends at Fajr (tonight's Maghrib stands in for last night's).
        var duha = (hSun != null) ? solarNoon - hSun / 2.0d : null;
        var tahajjud = null;
        if (maghrib != null && fajr != null) {
            tahajjud = maghrib + ((24.0d - maghrib) + fajr) * 2.0d / 3.0d;
            if (tahajjud >= 24.0d) { tahajjud -= 24.0d; }
        }

        return {
            :duha      => duha,
            :tahajjud  => tahajjud,
            :fajr      => _withUser(fajr    != null ? fajr + _off(mo, :fajr) : null, :fajr),
            :sunrise   => _withUser(sunrise, :sunrise),
            :dhuhr     => _withUser(dhuhr,   :dhuhr),
            :asr       => _withUser(asr,     :asr),
            :maghrib   => _withUser(maghrib, :maghrib),
            :isha      => _withUser(isha != null ? isha + _off(mo, :isha) : null, :isha),
            :solarNoon => solarNoon
        };
    }

    // Hours between the twilight event and Sunrise (Fajr) / Maghrib (Isha),
    // after the night-fraction rule. null when there is no usable night.
    function _twilightGap(hAngle, solarNoon, edge, before, night, angle) {
        if (edge == null || night == null) { return null; }
        var capFrac = _params[:nightCap];
        var always = (capFrac != null);
        if (!always) { capFrac = angle / 60.0d; }
        var cap = capFrac.toDouble() * night;
        if (hAngle == null) { return cap; }            // sun never gets that low
        var gap = before ? edge - (solarNoon - hAngle) : (solarNoon + hAngle) - edge;
        return (always && gap > cap) ? cap : gap;
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

    // Next entry from `nowMoment` for `loc`, rolling over to tomorrow's
    // Fajr after Isha. Shared by the cards and the glance.
    // Result: same shape as getNextPrayer, or null (polar night).
    function nextAfter(loc, nowMoment) {
        var info = Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;
        var today = calculate(loc[:lat], loc[:lon], info.year, info.month, info.day, loc[:tz]);
        var next = getNextPrayer(today, nowH);
        if (next != null) { return next; }

        var t = Gregorian.info(nowMoment.add(new Time.Duration(86400)), Time.FORMAT_SHORT);
        var fajr = calculate(loc[:lat], loc[:lon], t.year, t.month, t.day, loc[:tz])[:fajr];
        if (fajr == null) { return null; }
        return {
            :name         => :fajr,
            :time         => fajr,
            :secondsUntil => (((24.0d - nowH) + fajr) * 3600.0d).toNumber()
        };
    }

    // The prayer whose time is running now and when it ends:
    //   Fajr -> Sunrise, Dhuhr -> Asr, Asr -> Maghrib, Maghrib -> Isha,
    //   Isha -> Fajr (the Hanafi limit; it also covers the small hours
    //   before Fajr, which still belong to yesterday's Isha).
    // Between Sunrise and Dhuhr no prayer is running -> null.
    // Result: { :name => Symbol, :until => Float (hours, may be > 24 or < 0
    // relative to the day), :secondsLeft => Number }.
    function currentWindow(loc, nowMoment) {
        var info = Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;
        var t = calculate(loc[:lat], loc[:lon], info.year, info.month, info.day, loc[:tz]);

        var starts = [:fajr, :dhuhr, :asr, :maghrib];
        var ends   = [:sunrise, :asr, :maghrib, :isha];
        for (var i = 0; i < starts.size(); i++) {
            var s = t[starts[i]];
            var e = t[ends[i]];
            if (s != null && e != null && nowH >= s && nowH < e) {
                return _window(starts[i], e, nowH);
            }
        }
        if (t[:fajr] != null && nowH < t[:fajr]) {
            return _window(:isha, t[:fajr], nowH);
        }
        if (t[:isha] != null && nowH >= t[:isha]) {
            var d = Gregorian.info(nowMoment.add(new Time.Duration(86400)), Time.FORMAT_SHORT);
            var f = calculate(loc[:lat], loc[:lon], d.year, d.month, d.day, loc[:tz])[:fajr];
            if (f != null) { return _window(:isha, f + 24.0d, nowH); }
        }
        return null;
    }

    function _window(name, untilH, nowH) {
        return {
            :name        => name,
            :until       => untilH,
            :secondsLeft => ((untilH - nowH) * 3600.0d).toNumber()
        };
    }

    function _angleOrDefault(key, fallback) {
        var v = _params[key];
        return (v != null) ? v.toDouble() : fallback;
    }

    // Offsets in effect at this latitude: :offsetsHigh from :highLat north.
    function _methodOffsets(latitude) {
        var high = _params[:highLat];
        if (high != null && latitude >= high.toDouble() && _params[:offsetsHigh] != null) {
            return _params[:offsetsHigh];
        }
        return _params[:offsets];
    }

    // Method offset for one prayer, in hours.
    function _off(offsets, key) {
        if (offsets == null || offsets[key] == null) { return 0.0d; }
        return offsets[key].toDouble() / 60.0d;
    }

    function _withUser(time, key) {
        if (time == null) { return null; }
        if (_userOffsets == null || _userOffsets[key] == null) { return time; }
        return time + _userOffsets[key].toNumber().toDouble() / 60.0d;
    }
}
