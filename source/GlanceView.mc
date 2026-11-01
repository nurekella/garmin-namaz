using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Lang;

// Glance: next prayer and time left (iftar / end of suhoor in Ramadan), e.g.
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
        var loc = _location.getCurrentLocation();
        var now = Time.now();

        // In Ramadan the glance shows iftar / end of suhoor instead.
        var label;
        var at;
        var secs;
        var fast = Fasting.next(_calc, loc, now);
        if (fast != null) {
            label = fast[:iftar] ? PrayerNames.iftarLabel() : PrayerNames.suhoorLabel();
            at = fast[:time];
            secs = fast[:secondsUntil];
        } else {
            var next = _calc.nextAfter(loc, now);
            if (next == null) { return; }
            label = PrayerNames.nameOf(next[:name]);
            at = next[:time];
            secs = next[:secondsUntil];
        }

        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 3 / 10, Fonts.small(), label + " " + TimeFormatter.hhmm(at), left);
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 7 / 10, Fonts.tiny(), PrayerNames.timeLeft(TimeFormatter.hm(secs)), left);
    }
}
