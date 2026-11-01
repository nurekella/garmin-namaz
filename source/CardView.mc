using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;

// Three cards, flipped with UP/DOWN or swipe:
//   overview  — dates, city, 5 prayers + sunrise, time left to the next one
//   countdown — next prayer with a live H:MM:SS countdown
//   week      — Fajr / Maghrib for the next 7 days (sahoor / iftar)
class CardView extends WatchUi.View {

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
        if (_order()[_idx % _order().size()] != :countdown && min == _lastMin) { return; }
        _lastMin = min;
        WatchUi.requestUpdate();
    }

    // The cards in swipe order; the Duha / Tahajjud card is opt-in.
    function _order() {
        if (Settings.extraCard() == 1) { return [:overview, :countdown, :week, :extra]; }
        return [:overview, :countdown, :week];
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
        _idx = (_idx + 1) % _order().size();
        WatchUi.requestUpdate();
    }

    function prev() as Void {
        _idx = (_idx + _order().size() - 1) % _order().size();
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

        var sym  = _order()[_idx % _order().size()];
        var loc  = _location.getCurrentLocation();
        var now  = Time.now();
        var next = _calc.nextAfter(loc, now);
        var fast = Fasting.next(_calc, loc, now);          // null outside Ramadan
        if (sym == :overview) {
            _drawOverview(dc, info, next, fast);
        } else if (sym == :countdown) {
            _drawCountdown(dc, info, next, fast, _calc.currentWindow(loc, now));
        } else if (sym == :week) {
            _drawWeek(dc, info);
        } else {
            _drawExtra(dc);
        }
        _drawPagerDots(dc);
    }

    function _drawOverview(dc as Graphics.Dc, info, next, fast) as Void {
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // ---- header: Gregorian + Hijri dates ----
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 44, Fonts.medium(), _gregStr(info), center);
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 82, Fonts.small(), _hijriStr(info), center);

        // ---- one slot: a holiday / fast worth knowing about, else the city ----
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;
        var chip = Occasions.chip(info, Gregorian.info(Time.now().add(new Time.Duration(86400)), Time.FORMAT_SHORT),
                                  nowH, _times[:maghrib], _times[:isha]);
        if (chip != null) {
            dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 116, _fitFont(dc, chip, 330), chip, center);
        } else {
            dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 116, Fonts.small(),
                        _resolveCityLabel(_location.getCurrentLocation()), center);
        }

        // ---- 5 prayers + sunrise (Friday: Dhuhr is Jumu'ah) ----
        var friday = (info.day_of_week == 6);
        var nextSym = (next != null) ? next[:name] : null;
        var prayers = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < prayers.size(); i++) {
            var sym = prayers[i];
            var t   = _times[sym];
            var y   = 146 + i * 37;

            // 28x28 icon flush-left, vertically centred on the row.
            var icon = _iconFor(sym);
            dc.drawBitmap(Theme.CENTER_X - 130, y - icon.getHeight() / 2, icon);

            var jumuah = (friday && sym == :dhuhr);
            dc.setColor(jumuah ? Theme.accent() : _colorFor(sym, nextSym, t, nowH), Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X - 90, y, Fonts.medium(), jumuah ? PrayerNames.jumuah() : PrayerNames.nameOf(sym),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(Theme.CENTER_X + 120, y, Fonts.medium(), TimeFormatter.hhmm(t),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ---- bottom line: Ramadan -> iftar / end of suhoor, else the next prayer ----
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        if (fast != null) {
            dc.drawText(Theme.CENTER_X, 368, Fonts.small(),
                        _fastLabel(fast) + " " + PrayerNames.timeLeft(TimeFormatter.hm(fast[:secondsUntil])),
                        center);
        } else if (next != null) {
            dc.drawText(Theme.CENTER_X, 368, Fonts.small(),
                        PrayerNames.timeLeft(TimeFormatter.hm(next[:secondsUntil])), center);
        }

        if (Settings.dayRing() == 1) { _drawRing(dc, nowH); }
    }

    // A smaller font when the text would not fit between the bezel edges.
    function _fitFont(dc, text, maxW) {
        return (dc.getTextWidthInPixels(text, Fonts.small()) <= maxW) ? Fonts.small() : Fonts.tiny();
    }

    // The day as a ring around the bezel: 00:00 at the top, clockwise.
    // Prayer windows are arcs (past ones dark, the running one bright, the
    // rest dim), Duha and Tahajjud white dots, "now" a big accent dot.
    function _drawRing(dc, nowH) {
        var cx = dc.getWidth() / 2;
        var r = cx - 4;
        var starts = [:fajr, :dhuhr, :asr, :maghrib];
        var ends   = [:sunrise, :asr, :maghrib, :isha];
        dc.setPenWidth(5);
        dc.setColor(0x2A2520, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cx, r);
        for (var i = 0; i < starts.size(); i++) {
            var a = _times[starts[i]];
            var b = _times[ends[i]];
            if (a == null || b == null) { continue; }
            var color = Theme.accentDim();
            if (b <= nowH) {
                color = 0x4A4036;
            } else if (a <= nowH) {
                color = Theme.accent();
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cx, r, Graphics.ARC_CLOCKWISE, 90.0d - a * 15.0d, 90.0d - b * 15.0d);
        }
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        if (_times[:duha] != null) { _ringDot(dc, cx, r, _times[:duha], 4); }
        if (_times[:tahajjud] != null) { _ringDot(dc, cx, r, _times[:tahajjud], 4); }
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        _ringDot(dc, cx, r, nowH, 8);
    }

    function _ringDot(dc, cx, r, hour, size) {
        var rad = (90.0d - hour * 15.0d) * 0.017453292519943295d;
        dc.fillCircle(cx + (r * Math.cos(rad)).toNumber(), cx - (r * Math.sin(rad)).toNumber(), size);
    }

    // Duha and Tahajjud as plain times: reference times, not obligatory
    // prayers, so they live on their own opt-in card.
    function _drawExtra(dc as Graphics.Dc) as Void {
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 60, Fonts.small(),
                    PrayerNames.pick("ҚОСЫМША", "ДОПОЛНИТЕЛЬНО", "EXTRA"), center);
        _extraRow(dc, 112, PrayerNames.pick("Духа", "Духа", "Duha"),
                  PrayerNames.pick("күн шыққаннан кейін ¼", "четверть светового дня", "a quarter after sunrise"),
                  _times[:duha]);
        _extraRow(dc, 250, PrayerNames.pick("Таһажжуд", "Тахаджуд", "Tahajjud"),
                  PrayerNames.pick("түннің соңғы үштен бірі", "последняя треть ночи", "last third of the night"),
                  _times[:tahajjud]);
    }

    function _extraRow(dc, y, name, hint, hour) {
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, y, Fonts.medium(), name, center);
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, y + 52, Graphics.FONT_NUMBER_MEDIUM, TimeFormatter.hhmm(hour), center);
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, y + 96, Fonts.xtiny(), hint, center);
    }

    // Next prayer with a live countdown. In Ramadan the hero is the fast
    // (iftar / end of suhoor) and the next prayer drops to a small line.
    // Under it: the prayer that is running now and how long it lasts.
    function _drawCountdown(dc as Graphics.Dc, info, next, fast, win) as Void {
        if (next == null) { return; }
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Current clock at top centre.
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 32, Fonts.small(),
                    _pad2(info.hour) + ":" + _pad2(info.min), center);

        var title = PrayerNames.nameOf(next[:name]);
        var secs  = next[:secondsUntil];
        var at    = next[:time];
        var sub   = PrayerNames.nextLabel();
        if (fast != null) {
            title = _fastLabel(fast);
            secs  = fast[:secondsUntil];
            at    = fast[:time];
            sub   = PrayerNames.nextLabel() + " " + PrayerNames.nameOf(next[:name])
                  + " " + TimeFormatter.hhmm(next[:time]);
        }
        dc.drawText(Theme.CENTER_X, 70, Fonts.tiny(), sub, center);

        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 120, Fonts.medium(), title, center);

        // Hero countdown — biggest number font available.
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 220, Graphics.FONT_NUMBER_THAI_HOT,
                    TimeFormatter.countdown(secs), center);

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 282, Fonts.small(),
                    PrayerNames.pick("сағат ", "в ", "at ") + TimeFormatter.hhmm(at), center);

        if (win != null) {
            dc.setColor((win[:secondsLeft] <= 20 * 60) ? Theme.COLOR_WARN : Theme.accent(),
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 312, Fonts.small(),
                        PrayerNames.windowLeft(win[:name], TimeFormatter.hm(win[:secondsLeft])), center);
        }

        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 342, Fonts.small(), _gregStr(info), center);
        dc.drawText(Theme.CENTER_X, 366, Fonts.small(), _hijriStr(info), center);
    }

    function _fastLabel(fast) {
        return fast[:iftar] ? PrayerNames.iftarLabel() : PrayerNames.suhoorLabel();
    }

    // 7 days of upcoming Fajr / Maghrib in a compact table — for planning
    // suhoor / iftar (the column headers say so in Ramadan).
    function _drawWeek(dc as Graphics.Dc, info) as Void {
        var ramadan = Fasting.isRamadan(info.year, info.month, info.day);
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
        dc.drawText(Theme.CENTER_X, 82, Fonts.xtiny(),
                    ramadan ? PrayerNames.suhoorLabel() : PrayerNames.nameOf(:fajr), center);
        dc.drawText(Theme.CENTER_X + 100, 82, Fonts.xtiny(),
                    ramadan ? PrayerNames.iftarLabel() : PrayerNames.nameOf(:maghrib), right);

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
        var hd = HijriDate.forDate(info.year, info.month, info.day);
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
        var lang = Settings.language();
        if (loc[:cityId] != null) {
            var c = CityIndex.byId(loc[:cityId]);
            if (c != null) { return Cities.localizedName(c, lang); }
        }
        if (loc[:source] == :gps || loc[:source] == :cached) {
            var near = CityIndex.nearest(loc[:lat], loc[:lon]);
            return (near != null) ? Cities.localizedName(near, lang) : "GPS";
        }
        return "";
    }

    function _drawPagerDots(dc as Graphics.Dc) as Void {
        var n = _order().size();
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
