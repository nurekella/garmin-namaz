using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.Lang;

// Radial / sundial layout. Each of the 6 prayers sits on a 24h ring at
// its real time-of-day; midnight at the top, noon at the bottom.
//   - tick ring at the outer edge
//   - prayer dots: 5 px (past/future), 9 px and accent (next), pulse-ring
//     drawn around the next dot
//   - thin "now" pointer from centre to the rim at the current time
//   - centre stack: NEXT name, big countdown, hijri
//
// Pushed from the previous view via UP. UP again or BACK pops back.
class RadialView extends WatchUi.View {

    static const RING_R   = 168;   // dot ring radius
    static const TICK_R0  = 178;
    static const TICK_R1  = 192;
    static const NOW_R0   = 30;
    static const NOW_R1   = 152;

    var _calc;
    var _location;
    var _timer;
    var _times;
    var _today_day;
    var _pulse = 0;     // 0..255 simple sine for next-prayer halo

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

    function _tick() as Void {
        _pulse = (_pulse + 32) % 256;
        WatchUi.requestUpdate();
    }

    function _refresh() as Void {
        var loc = _location.getCurrentLocation();
        if (loc == null) { _times = null; return; }
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        _times = _calc.calculate(loc[:lat], loc[:lon],
            info.year, info.month, info.day, loc[:tz]);
        _today_day = info.day;
    }

    // Maps time-of-day (hours, 0..24) to (x, y) on the ring.
    // 0h sits at the top (12-o'clock); time advances clockwise.
    function _xyOnRing(hours, radius) {
        var angle = ((hours / 24.0d) * 2.0d * Math.PI) - (Math.PI / 2.0d);
        var x = Theme.CENTER_X + (radius * Math.cos(angle)).toNumber();
        var y = Theme.CENTER_Y + (radius * Math.sin(angle)).toNumber();
        return [x, y];
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

        _drawTicks(dc);
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;
        _drawNowPointer(dc, nowH);

        var nextEntry = _calc.getNextPrayer(_times, nowH);
        var nextSym = (nextEntry != null) ? nextEntry[:name] : null;

        var prayers = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < prayers.size(); i++) {
            var sym = prayers[i];
            var t = _times[sym];
            if (t == null) { continue; }
            _drawPrayerDot(dc, sym, t, nowH, sym == nextSym);
        }

        _drawCenter(dc, nextEntry, nowH, info);
    }

    function _drawTicks(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var h = 0; h < 24; h += 1) {
            var p0 = _xyOnRing(h.toDouble(), TICK_R0);
            var p1 = _xyOnRing(h.toDouble(), TICK_R1);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        }
        // Heavier marks at 0/6/12/18.
        dc.setPenWidth(4);
        var heavy = [0, 6, 12, 18];
        for (var i = 0; i < heavy.size(); i++) {
            var p0 = _xyOnRing(heavy[i].toDouble(), TICK_R0 - 3);
            var p1 = _xyOnRing(heavy[i].toDouble(), TICK_R1);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        }
    }

    function _drawNowPointer(dc as Graphics.Dc, nowH) as Void {
        var p0 = _xyOnRing(nowH, NOW_R0);
        var p1 = _xyOnRing(nowH, NOW_R1);
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        dc.fillCircle(p1[0], p1[1], 4);
    }

    function _drawPrayerDot(dc as Graphics.Dc, sym, hours, nowH, isNext) as Void {
        var pos = _xyOnRing(hours, RING_R);
        var color;
        var radius;
        if (isNext) {
            color = Theme.COLOR_ACCENT;
            radius = 9;
            // Pulse halo
            dc.setColor(Theme.COLOR_ACCENT_DIM, Graphics.COLOR_TRANSPARENT);
            var halo = 12 + (_pulse / 32);   // 12..19 px
            dc.drawCircle(pos[0], pos[1], halo);
        } else if (hours < nowH) {
            color = Theme.COLOR_TEXT_MUTED;
            radius = 5;
        } else {
            color = Theme.COLOR_TEXT_DIM;
            radius = 6;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pos[0], pos[1], radius);

        // Outer label — pull toward the screen edge.
        var labelPos = _xyOnRing(hours, RING_R + 26);
        dc.setColor(isNext ? Theme.COLOR_ACCENT : Theme.COLOR_TEXT_DIM,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelPos[0], labelPos[1],
                    Fonts.xtiny(), _shortName(sym),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _shortName(sym) {
        // Short forms keep the dot labels readable; full names go to centre.
        var lang = Settings.language();
        if (lang.equals("kk")) {
            if (sym == :fajr)    { return "Таң"; }
            if (sym == :sunrise) { return "Күн"; }
            if (sym == :dhuhr)   { return "Бес"; }
            if (sym == :asr)     { return "Ек"; }
            if (sym == :maghrib) { return "Ақш"; }
            if (sym == :isha)    { return "Құп"; }
        } else if (lang.equals("ru")) {
            if (sym == :fajr)    { return "Фдж"; }
            if (sym == :sunrise) { return "Вос"; }
            if (sym == :dhuhr)   { return "Зух"; }
            if (sym == :asr)     { return "Аср"; }
            if (sym == :maghrib) { return "Маг"; }
            if (sym == :isha)    { return "Иша"; }
        }
        if (sym == :fajr)    { return "Fjr"; }
        if (sym == :sunrise) { return "Sun"; }
        if (sym == :dhuhr)   { return "Dhr"; }
        if (sym == :asr)     { return "Asr"; }
        if (sym == :maghrib) { return "Mag"; }
        if (sym == :isha)    { return "Ish"; }
        return "";
    }

    function _drawCenter(dc as Graphics.Dc, nextEntry, nowH, info) as Void {
        var name; var secsLeft;
        if (nextEntry != null) {
            name = PrayerNames.nameOf(nextEntry[:name]);
            secsLeft = nextEntry[:secondsUntil];
        } else {
            // Past Isha — show countdown to tomorrow's Fajr.
            var tMoment = Time.now().add(new Time.Duration(86400));
            var tInfo = Gregorian.info(tMoment, Time.FORMAT_SHORT);
            var loc = _location.getCurrentLocation();
            var tt = _calc.calculate(loc[:lat], loc[:lon],
                tInfo.year, tInfo.month, tInfo.day, loc[:tz]);
            var f = tt[:fajr];
            if (f == null) { return; }
            name = PrayerNames.nameOf(:fajr);
            secsLeft = (((24.0d - nowH) + f) * 3600.0d).toNumber();
        }

        dc.setColor(Theme.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Theme.CENTER_Y - 26,
                    Fonts.medium(), name,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Theme.CENTER_Y + 18,
                    Graphics.FONT_NUMBER_MILD,
                    TimeFormatter.countdown(secsLeft),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var hd = HijriDate.fromGregorian(info.year, info.month, info.day);
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Theme.CENTER_Y + 60,
                    Fonts.xtiny(),
                    hd[:day] + " " + HijriDate.monthName(hd[:month]),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class RadialDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // UP — advance to CardView (next prototype in the carousel).
    function onPreviousPage() as Lang.Boolean {
        var app = Application.getApp();
        var card = new CardView(app._calculator, app._location);
        WatchUi.pushView(card, new CardDelegate(card, false), WatchUi.SLIDE_LEFT);
        return true;
    }
}
