using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.Lang;
using Toybox.Position;
using Toybox.System;

// Three cards, flipped with UP/DOWN or swipe:
//   overview  — dates, city, 5 prayers + sunrise, time left to the next one
//   countdown — next prayer with a live H:MM:SS countdown
//   week      — Fajr / Maghrib for the next 7 days (sahoor / iftar)
class CardView extends WatchUi.View {

    static const ORDER = [:overview, :countdown, :week];
    static const DOTS_Y = 398;

    var _calc;
    var _location;
    var _timer;
    var _times;
    var _today_day;
    var _idx;          // index into ORDER
    var _lastMin;      // minute of the last tick-driven redraw
    var _icons = {};   // sym -> loaded bitmap

    function initialize(calc, location) {
        View.initialize();
        _calc = calc;
        _location = location;
    }

    function onShow() as Void {
        _refresh();
        _idx = 0;
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:_tick), 1000, true);
        // Nothing else ever turns GPS on — without this, "auto" users only
        // get a position if another activity happened to leave a good fix.
        if (_location.getManualCity() == null) {
            _location.startContinuous(method(:onPosition));
        }
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
        _location.stopGps();
    }

    // First usable fix: cache it, stop GPS, recompute and re-arm the alarm.
    function onPosition(info as Position.Info) as Void {
        var loc = _location.fromInfo(info);
        if (loc == null) { return; }   // keep listening until a usable fix
        _location.stopGps();
        _location.saveLocation(loc);
        _refresh();
        PrayerNotifier.schedule(_calc, _location);
        WatchUi.requestUpdate();
    }

    // Only the countdown card shows seconds; the others redraw once a minute.
    function _tick() as Void {
        var min = System.getClockTime().min;
        if (ORDER[_idx] != :countdown && min == _lastMin) { return; }
        _lastMin = min;
        WatchUi.requestUpdate();
    }

    function _refresh() as Void {
        // Re-pull calculator from the app — settings changes (Asr, method,
        // offsets) replace app._calculator wholesale, our cached reference
        // would otherwise show stale times.
        var app = Application.getApp();
        if (app != null) { _calc = app._calculator; }

        var loc = _location.getCurrentLocation();
        if (loc == null) { _times = null; return; }
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        _times = _calc.calculate(loc[:lat], loc[:lon],
            info.year, info.month, info.day, loc[:tz]);
        _today_day = info.day;
    }

    function refresh() as Void {
        _refresh();
        _idx = 0;
        WatchUi.requestUpdate();
    }

    function next() as Void {
        _idx = (_idx + 1) % ORDER.size();
        WatchUi.requestUpdate();
    }

    function prev() as Void {
        _idx = (_idx + ORDER.size() - 1) % ORDER.size();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var app = Application.getApp();
        if (_times == null || _today_day != info.day
                || (app != null && app._calculator != _calc)) {
            _refresh();
        }

        dc.setColor(Theme.COLOR_BG, Theme.COLOR_BG);
        dc.clear();

        if (_times == null) {
            dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, Theme.CENTER_Y,
                        Fonts.medium(), PrayerNames.gpsSearching(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var sym  = ORDER[_idx];
        var next = _calc.nextAfter(_location.getCurrentLocation(), Time.now());
        if (sym == :overview) {
            _drawOverview(dc, info, next);
        } else if (sym == :countdown) {
            _drawCountdown(dc, info, next);
        } else {
            _drawWeek(dc);
        }
        _drawPagerDots(dc);
    }

    function _drawOverview(dc as Graphics.Dc, info, next) as Void {
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // ---- header: Gregorian + Hijri dates ----
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 44, Fonts.medium(), _gregStr(info), center);
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 82, Fonts.small(), _hijriStr(info), center);

        // ---- city, or Jumu'ah on Fridays (day_of_week 6) ----
        if (info.day_of_week == 6) {
            dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 116, Fonts.small(), PrayerNames.jumuah(), center);
        } else {
            dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 116, Fonts.small(),
                        _resolveCityLabel(_location.getCurrentLocation()), center);
        }

        // ---- 5 prayers + sunrise ----
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;
        var nextSym = (next != null) ? next[:name] : null;
        var prayers = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < prayers.size(); i++) {
            var sym = prayers[i];
            var t   = _times[sym];
            var y   = 146 + i * 37;

            // 28x28 icon flush-left, vertically centred on the row.
            var icon = _iconFor(sym);
            dc.drawBitmap(Theme.CENTER_X - 130, y - icon.getHeight() / 2, icon);

            dc.setColor(_colorFor(sym, nextSym, t, nowH), Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X - 90, y, Fonts.medium(), PrayerNames.nameOf(sym),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(Theme.CENTER_X + 120, y, Fonts.medium(), TimeFormatter.hhmm(t),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ---- time left to the highlighted row ----
        if (next != null) {
            dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 368, Fonts.small(),
                        PrayerNames.timeLeft(TimeFormatter.hm(next[:secondsUntil])), center);
        }
    }

    function _drawCountdown(dc as Graphics.Dc, info, next) as Void {
        if (next == null) { return; }
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Current clock at top centre.
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 32, Fonts.small(),
                    _pad2(info.hour) + ":" + _pad2(info.min), center);
        dc.drawText(Theme.CENTER_X, 70, Fonts.tiny(), PrayerNames.nextLabel(), center);

        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 120, Fonts.medium(), PrayerNames.nameOf(next[:name]), center);

        // Hero countdown — biggest number font available.
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 220, Graphics.FONT_NUMBER_THAI_HOT,
                    TimeFormatter.countdown(next[:secondsUntil]), center);

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 288, Fonts.small(),
                    PrayerNames.pick("сағат ", "в ", "at ") + TimeFormatter.hhmm(next[:time]), center);

        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 332, Fonts.small(), _gregStr(info), center);
        dc.drawText(Theme.CENTER_X, 358, Fonts.small(), _hijriStr(info), center);
    }

    // 7 days of upcoming Fajr / Maghrib in a compact table — for planning
    // sahoor / iftar.
    function _drawWeek(dc as Graphics.Dc) as Void {
        var loc = _location.getCurrentLocation();
        var left   = Graphics.TEXT_JUSTIFY_LEFT   | Graphics.TEXT_JUSTIFY_VCENTER;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var right  = Graphics.TEXT_JUSTIFY_RIGHT  | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 50, Fonts.tiny(),
                    PrayerNames.pick("7 КҮН", "7 ДНЕЙ", "7 DAYS"), center);

        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X - 100, 82, Fonts.xtiny(),
                    PrayerNames.pick("Күн", "День", "Day"), left);
        dc.drawText(Theme.CENTER_X, 82, Fonts.xtiny(), PrayerNames.nameOf(:fajr), center);
        dc.drawText(Theme.CENTER_X + 100, 82, Fonts.xtiny(), PrayerNames.nameOf(:maghrib), right);

        for (var i = 0; i < 7; i++) {
            var di = Gregorian.info(Time.now().add(new Time.Duration(i * 86400)), Time.FORMAT_SHORT);
            var times = _calc.calculate(loc[:lat], loc[:lon], di.year, di.month, di.day, loc[:tz]);
            var y = 110 + i * 36;

            dc.setColor((i == 0) ? Theme.accent() : Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X - 100, y, Fonts.tiny(), _dayLabel(di.day_of_week, i), left);
            dc.drawText(Theme.CENTER_X, y, Fonts.tiny(), TimeFormatter.hhmm(times[:fajr]), center);
            dc.drawText(Theme.CENTER_X + 100, y, Fonts.tiny(), TimeFormatter.hhmm(times[:maghrib]), right);
        }
    }

    function _dayLabel(dow, daysFromToday) {
        if (daysFromToday == 0) {
            return PrayerNames.pick("Бүгін", "Сегодня", "Today");
        }
        var names = PrayerNames.pick(
            ["Жк", "Дс", "Сс", "Ср", "Бс", "Жм", "Сн"],
            ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"],
            ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]);
        return names[(dow - 1) % 7];
    }

    function _gregStr(info) {
        return info.day + " " + PrayerNames.monthShort(info.month) + " " + info.year;
    }

    function _hijriStr(info) {
        var hd = HijriDate.fromGregorian(info.year, info.month, info.day);
        return hd[:day] + " " + HijriDate.monthName(hd[:month]) + " " + hd[:year];
    }

    function _pad2(n) {
        return (n < 10) ? "0" + n : "" + n;
    }

    function _colorFor(sym, nextSym, time, nowH) {
        if (time == null)     { return Theme.COLOR_TEXT_MUTED; }
        if (sym == nextSym)   { return Theme.accent(); }
        if (time < nowH)      { return Theme.COLOR_TEXT_DIM; }
        return Theme.COLOR_TEXT;
    }

    // Loaded once per sym.
    function _iconFor(sym) {
        var icon = _icons[sym];
        if (icon != null) { return icon; }
        var rez = Rez.Drawables.IconFajr;
        if (sym == :sunrise)  { rez = Rez.Drawables.IconSunrise; }
        if (sym == :dhuhr)    { rez = Rez.Drawables.IconDhuhr; }
        if (sym == :asr)      { rez = Rez.Drawables.IconAsr; }
        if (sym == :maghrib)  { rez = Rez.Drawables.IconMaghrib; }
        if (sym == :isha)     { rez = Rez.Drawables.IconIsha; }
        icon = WatchUi.loadResource(rez);
        _icons[sym] = icon;
        return icon;
    }

    function _resolveCityLabel(loc) {
        if (loc == null) { return ""; }
        if (loc[:cityId] != null) {
            var c = Cities.byId(loc[:cityId]);
            if (c != null) { return Cities.localizedName(c, Settings.language()); }
        }
        if (loc[:source] == :gps || loc[:source] == :cached) {
            return "GPS";
        }
        return "";
    }

    function _drawPagerDots(dc as Graphics.Dc) as Void {
        var n = ORDER.size();
        var spacing = 16;
        var x0 = Theme.CENTER_X - (n - 1) * spacing / 2;
        for (var i = 0; i < n; i++) {
            if (i == _idx) {
                dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * spacing, DOTS_Y, 4);
            } else {
                dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * spacing, DOTS_Y, 3);
            }
        }
    }
}

class CardDelegate extends WatchUi.BehaviorDelegate {

    var _view;
    var _isRoot;   // entry view exits app on BACK; pushed instances pop

    function initialize(view, isRoot) {
        BehaviorDelegate.initialize();
        _view = view;
        _isRoot = isRoot;
    }

    function onBack() as Lang.Boolean {
        if (_isRoot) {
            return false;  // default behaviour exits the app
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() as Lang.Boolean {
        if (_view != null) { _view.next(); }
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (_view != null) { _view.prev(); }
        return true;
    }

    function onSelect() as Lang.Boolean {
        if (_view != null) { _view.refresh(); }
        return true;
    }

    function onMenu() as Lang.Boolean {
        var menu = new SettingsMenu();
        WatchUi.pushView(menu, new SettingsMenuDelegate(menu), WatchUi.SLIDE_LEFT);
        return true;
    }

    // Swipe left/right also flips cards on touch devices.
    function onSwipe(swipeEvent) as Lang.Boolean {
        if (_view == null || swipeEvent == null) { return false; }
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_LEFT)  { _view.next(); return true; }
        if (dir == WatchUi.SWIPE_RIGHT) { _view.prev(); return true; }
        return false;
    }
}
