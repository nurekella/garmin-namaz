using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;

// Compact glance shown when the user swipes left/right from the watch
// face. We get a thin horizontal strip — typically ~416 × 80 on Epix
// Gen 2 — and limited memory. Layout:
//
//   [LABEL  ASR]   17:48
//                   1:23:45
//
// Glance binary runs in an isolated scope where the auto-generated
// Rez symbol is unavailable. PrayerNames + HijriDate are now baked-
// table-only (no Rez), so we can localise glance without crashing.
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
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Theme.COLOR_BG, Theme.COLOR_BG);
        dc.clear();

        var loc = _location.getCurrentLocation();
        if (loc == null) {
            _drawCentered(dc, w, h, PrayerNames.gpsSearching(), Theme.COLOR_TEXT_DIM);
            return;
        }

        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var times = _calc.calculate(
            loc[:lat], loc[:lon],
            nowInfo.year, nowInfo.month, nowInfo.day,
            loc[:tz]);
        var nowH = nowInfo.hour + nowInfo.min / 60.0d + nowInfo.sec / 3600.0d;
        var next = _calc.getNextPrayer(times, nowH);

        if (next == null) {
            // After Isha — roll to tomorrow's Fajr.
            var tMoment = Time.now().add(new Time.Duration(86400));
            var tInfo = Gregorian.info(tMoment, Time.FORMAT_SHORT);
            var tt = _calc.calculate(
                loc[:lat], loc[:lon],
                tInfo.year, tInfo.month, tInfo.day,
                loc[:tz]);
            var fajr = tt[:fajr];
            if (fajr != null) {
                var hoursUntil = (24.0d - nowH) + fajr;
                next = {
                    :name         => :fajr,
                    :time         => fajr,
                    :secondsUntil => (hoursUntil * 3600.0d).toNumber()
                };
            }
        }

        if (next == null) {
            _drawCentered(dc, w, h, PrayerNames.gpsSearching(), Theme.COLOR_TEXT_DIM);
            return;
        }

        // Left column — label + name.
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, h / 2 - 18,
                    Graphics.FONT_XTINY, PrayerNames.nextLabel(),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, h / 2 + 12,
                    Graphics.FONT_MEDIUM, PrayerNames.nameOf(next[:name]),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Right column — time + countdown + small Hijri row.
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 8, h / 2 - 22,
                    Graphics.FONT_TINY, TimeFormatter.hhmm(next[:time]),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 8, h / 2 + 4,
                    Graphics.FONT_TINY, TimeFormatter.countdown(next[:secondsUntil]),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        var hd = HijriDate.fromGregorian(nowInfo.year, nowInfo.month, nowInfo.day);
        var hStr = hd[:day] + " " + HijriDate.monthName(hd[:month]);
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 8, h / 2 + 26,
                    Graphics.FONT_XTINY, hStr,
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawCentered(dc as Graphics.Dc, w, h, text, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, Graphics.FONT_TINY, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
