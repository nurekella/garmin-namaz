using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Lang;

// Glance: next prayer and time left, e.g.
//   Бесін 13:05
//   1:23 қалды
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

        var h = dc.getHeight();
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var next = _calc.nextAfter(_location.getCurrentLocation(), Time.now());
        if (next == null) { return; }

        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 3 / 10, Fonts.small(),
                    PrayerNames.nameOf(next[:name]) + " " + TimeFormatter.hhmm(next[:time]), left);
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 7 / 10, Fonts.tiny(),
                    PrayerNames.timeLeft(TimeFormatter.hm(next[:secondsUntil])), left);
    }
}
