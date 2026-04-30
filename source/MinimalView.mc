using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.Lang;

// Minimalist alternative to NamazView — one prayer, huge numbers,
// nothing else. Pushed from the main view via UP button. BACK pops.
//
// Layout (top-to-bottom):
//   y=70   "КЕЛЕСІ"         FONT_TINY  dim
//   y=120  Prayer name      FONT_MEDIUM accent
//   y=210  Big time HH:MM   FONT_NUMBER_THAI_HOT  white
//   y=300  Countdown        FONT_SMALL  dim
//   y=370  Hijri date       FONT_XTINY  muted
class MinimalView extends WatchUi.View {

    static const Y_LABEL    = 70;
    static const Y_NAME     = 120;
    static const Y_TIME     = 210;
    static const Y_COUNT    = 300;
    static const Y_DATE     = 370;

    var _calc;
    var _location;
    var _timer;
    var _times;
    var _today_day;

    function initialize(calc, location) {
        View.initialize();
        _calc = calc;
        _location = location;
    }

    function onShow() as Void {
        _refresh();
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:_tick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
    }

    function _tick() as Void { WatchUi.requestUpdate(); }

    function _refresh() as Void {
        var loc = _location.getCurrentLocation();
        if (loc == null) { _times = null; return; }
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        _times = _calc.calculate(loc[:lat], loc[:lon],
            info.year, info.month, info.day, loc[:tz]);
        _today_day = info.day;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (_times == null || _today_day != info.day) { _refresh(); }

        dc.setColor(Theme.COLOR_BG, Theme.COLOR_BG);
        dc.clear();

        if (_times == null) {
            dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, Theme.CENTER_Y,
                        Fonts.medium(), PrayerNames.gpsSearching(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;
        var next = _calc.getNextPrayer(_times, nowH);
        var name; var timeH; var secsLeft;
        if (next != null) {
            name = PrayerNames.nameOf(next[:name]);
            timeH = next[:time];
            secsLeft = next[:secondsUntil];
        } else {
            // Past Isha — roll to tomorrow's Fajr.
            var tMoment = Time.now().add(new Time.Duration(86400));
            var tInfo = Gregorian.info(tMoment, Time.FORMAT_SHORT);
            var loc = _location.getCurrentLocation();
            var tt = _calc.calculate(loc[:lat], loc[:lon],
                tInfo.year, tInfo.month, tInfo.day, loc[:tz]);
            var f = tt[:fajr];
            if (f == null) { return; }
            name = PrayerNames.nameOf(:fajr);
            timeH = f;
            secsLeft = (((24.0d - nowH) + f) * 3600.0d).toNumber();
        }

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Y_LABEL, Fonts.tiny(),
                    PrayerNames.nextLabel(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Y_NAME, Fonts.medium(),
                    name,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // The hero — huge prayer time.
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Y_TIME,
                    Graphics.FONT_NUMBER_THAI_HOT,
                    TimeFormatter.hhmm(timeH),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Y_COUNT, Fonts.small(),
                    "-" + TimeFormatter.countdown(secsLeft),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var hd = HijriDate.fromGregorian(info.year, info.month, info.day);
        var hStr = hd[:day] + " " + HijriDate.monthName(hd[:month]);
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Y_DATE, Fonts.xtiny(),
                    hStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class MinimalDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // UP — advance to RadialView (next prototype in the carousel).
    function onPreviousPage() as Lang.Boolean {
        var app = Application.getApp();
        WatchUi.pushView(new RadialView(app._calculator, app._location),
                         new RadialDelegate(),
                         WatchUi.SLIDE_LEFT);
        return true;
    }
}
