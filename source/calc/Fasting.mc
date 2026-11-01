using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Ramadan mode: from Fajr (end of suhoor) to Maghrib (iftar) the app counts
// down to iftar; from Maghrib to the next Fajr, down to the end of suhoor.
// Shared by the main card, the countdown card and the glance.
(:glance, :background)
module Fasting {

    // Is this civil day in the Hijri month of Ramadan? Off when the user
    // switched Ramadan mode off; honours Settings.hijriAdjust.
    function isRamadan(year, month, day) {
        if (Settings.ramadanMode() == 1) { return false; }
        return HijriDate.forDate(year, month, day)[:month] == 9;
    }

    // Result: { :iftar => Boolean (false = end of suhoor), :time => hours,
    // :secondsUntil => Number }, or null outside Ramadan.
    function next(calc, loc, nowMoment) {
        var info = Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;

        if (isRamadan(info.year, info.month, info.day)) {
            var t = calc.calculate(loc[:lat], loc[:lon], info.year, info.month, info.day, loc[:tz]);
            if (t[:fajr] != null && nowH < t[:fajr]) {
                return _entry(false, t[:fajr], t[:fajr] - nowH);
            }
            if (t[:maghrib] != null && nowH < t[:maghrib]) {
                return _entry(true, t[:maghrib], t[:maghrib] - nowH);
            }
        }

        // After iftar: suhoor runs until tomorrow's Fajr, as long as
        // tomorrow still fasts (so not on the last evening of Ramadan).
        var d = Gregorian.info(nowMoment.add(new Time.Duration(86400)), Time.FORMAT_SHORT);
        if (isRamadan(d.year, d.month, d.day)) {
            var f = calc.calculate(loc[:lat], loc[:lon], d.year, d.month, d.day, loc[:tz])[:fajr];
            if (f != null) { return _entry(false, f, (24.0d - nowH) + f); }
        }
        return null;
    }

    function _entry(iftar, time, hoursLeft) {
        return {
            :iftar        => iftar,
            :time         => time,
            :secondsUntil => (hoursLeft * 3600.0d).toNumber()
        };
    }
}
