using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;

// Glance: next prayer at a glance — label, name, time and how long is
// left. Everything here must stay cheap: glances share a small memory
// budget and get redrawn by the system on a coarse cadence (roughly
// once a minute while the carousel is open), so the countdown is shown
// in hours/minutes only. No timers, no Rez strings (unavailable in the
// glance binary) — PrayerNames / Settings carry baked translations.
// Fonts.* gives vector fonts with the Kazakh Cyrillic extensions; the
// bitmap FONT_* fallbacks kick in on devices without VectorFont.
(:glance)
class GlanceView extends WatchUi.GlanceView {

    var _calc;
    var _location;

    function initialize(calc, location) {
        GlanceView.initialize();
        _calc = calc;
        _location = location;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.COLOR_BG, Theme.COLOR_BG);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var x = 4;   // glances are left-aligned on Garmin's carousel

        var next = _nextPrayer();
        if (next == null) {
            dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, h / 2, Fonts.small(), "Namaz KZ",
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Line 1: "NEXT · Dhuhr" (accent), small.
        var line1 = PrayerNames.nextLabel() + " · " + PrayerNames.nameOf(next[:name]);
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, h * 3 / 10, Fonts.xtiny(), line1,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Line 2: "13:05   -1 h 23 min", larger.
        var line2 = TimeFormatter.hhmm(next[:time]) + "   -" + _shortCountdown(next[:secondsUntil]);
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, h * 7 / 10, Fonts.small(), line2,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Next prayer today, or tomorrow's Fajr once Isha has passed.
    // Result: { :name, :time (local hours, may exceed 24 for tomorrow), :secondsUntil }.
    function _nextPrayer() {
        if (_calc == null || _location == null) { return null; }
        var loc = _location.getCurrentLocation();
        if (loc == null) { return null; }

        var now  = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;

        var today = _calc.calculate(loc[:lat], loc[:lon],
            info.year, info.month, info.day, loc[:tz]);
        var next = _calc.getNextPrayer(today, nowH);
        if (next != null) { return next; }

        var tInfo = Gregorian.info(now.add(new Time.Duration(86400)), Time.FORMAT_SHORT);
        var tomorrow = _calc.calculate(loc[:lat], loc[:lon],
            tInfo.year, tInfo.month, tInfo.day, loc[:tz]);
        var fajr = tomorrow[:fajr];
        if (fajr == null) { return null; }
        return {
            :name         => :fajr,
            :time         => fajr,
            :secondsUntil => (((24.0d - nowH) + fajr) * 3600.0d).toNumber()
        };
    }

    // "1 h 23 min" / "23 min" using the language's short units.
    function _shortCountdown(secs) {
        var lang = Settings.language();
        var hUnit = lang.equals("kk") ? "сағ" : (lang.equals("ru") ? "ч" : "h");
        var mUnit = lang.equals("kk") ? "мин" : (lang.equals("ru") ? "мин" : "min");
        var totalMin = (secs + 59) / 60;   // round up so "0 min" never shows before the time
        var hh = totalMin / 60;
        var mm = totalMin % 60;
        if (hh > 0) { return hh + " " + hUnit + " " + mm + " " + mUnit; }
        return mm + " " + mUnit;
    }
}
