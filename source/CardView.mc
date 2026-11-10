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
    const C = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const L = Graphics.TEXT_JUSTIFY_LEFT   | Graphics.TEXT_JUSTIFY_VCENTER;
    const R = Graphics.TEXT_JUSTIFY_RIGHT  | Graphics.TEXT_JUSTIFY_VCENTER;

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

    // ---- Material 3 building blocks ---------------------------------------

    // A filled rounded rectangle, fully rounded ("pill") by default.
    function _pill(dc, cx, cy, w, h, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - w / 2, cy - h / 2, w, h, h / 2);
    }

    function _text(dc, x, y, font, color, just, str) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, str, just);
    }

    // The largest of small / tiny / xtiny that fits `maxW` pixels.
    function _fitFont(dc, text, maxW) {
        if (dc.getTextWidthInPixels(text, Fonts.small()) <= maxW) { return Fonts.small(); }
        if (dc.getTextWidthInPixels(text, Fonts.tiny()) <= maxW) { return Fonts.tiny(); }
        return Fonts.xtiny();
    }

    function _drawOverview(dc as Graphics.Dc, info, next, fast) as Void {
        var cx = Theme.CENTER_X;

        // Headline: the date; the Hijri date in a tonal chip under it.
        _text(dc, cx, 40, Fonts.medium(), Theme.COLOR_TEXT, C, _gregStr(info));
        _pill(dc, cx, 76, 236, 28, Theme.surfaceHigh());
        _text(dc, cx, 76, Fonts.tiny(), Theme.COLOR_TEXT_DIM, C, _hijriStr(info));

        // One slot: a holiday / fast worth knowing about (filled chip), else the city.
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;
        var chip = Occasions.chip(info, Gregorian.info(Time.now().add(new Time.Duration(86400)), Time.FORMAT_SHORT),
                                  nowH, _times[:maghrib], _times[:isha]);
        if (chip != null) {
            var font = _fitFont(dc, chip, 288);
            var w = dc.getTextWidthInPixels(chip, font) + 28;
            _pill(dc, cx, 110, (w > 300) ? 300 : w, 28, Theme.container());
            _text(dc, cx, 110, font, Theme.onContainer(), C, chip);
        } else {
            _text(dc, cx, 110, Fonts.tiny(), Theme.COLOR_TEXT_DIM, C,
                  _resolveCityLabel(_location.getCurrentLocation()));
        }

        // The six rows as list items: tonal surface, the next one filled.
        var friday = (info.day_of_week == 6);
        var nextSym = (next != null) ? next[:name] : null;
        var prayers = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < prayers.size(); i++) {
            var sym = prayers[i];
            var t   = _times[sym];
            var y   = 146 + i * 37;
            var isNext = (sym == nextSym);

            _pill(dc, cx, y, 304, 32, isNext ? Theme.container() : Theme.surface());
            var icon = _iconFor(sym);
            dc.drawBitmap(cx - 144, y - icon.getHeight() / 2, icon);

            var color = Theme.COLOR_TEXT;
            if (isNext) {
                color = Theme.onContainer();
            } else if (t == null) {
                color = Theme.COLOR_TEXT_MUTED;
            } else if (t < nowH) {
                color = Theme.COLOR_TEXT_MUTED;
            }
            var name = (friday && sym == :dhuhr) ? PrayerNames.jumuah() : PrayerNames.nameOf(sym);
            _text(dc, cx - 106, y, Fonts.small(), color, L, name);
            _text(dc, cx + 138, y, Fonts.small(), color, R, TimeFormatter.hhmm(t));
        }

        // Bottom: Ramadan -> iftar / end of suhoor, else the time to the next prayer.
        var line = null;
        if (fast != null) {
            line = _fastLabel(fast) + " " + PrayerNames.timeLeft(TimeFormatter.hm(fast[:secondsUntil]));
        } else if (next != null) {
            line = PrayerNames.timeLeft(TimeFormatter.hm(next[:secondsUntil]));
        }
        if (line != null) {
            var bw = dc.getTextWidthInPixels(line, Fonts.small()) + 40;
            _pill(dc, cx, 372, (bw < 190) ? 190 : ((bw > 230) ? 230 : bw), 34, Theme.accent());
            _text(dc, cx, 372, Fonts.small(), Theme.onAccent(), C, line);
        }
    }

    // Duha and Tahajjud: reference times, not obligatory prayers, so they
    // live on their own opt-in card (two surface cards).
    function _drawExtra(dc as Graphics.Dc) as Void {
        var cx = Theme.CENTER_X;
        _pill(dc, cx, 52, 150, 30, Theme.surfaceHigh());
        _text(dc, cx, 52, Fonts.tiny(), Theme.COLOR_TEXT_DIM, C,
              PrayerNames.pick("ҚОСЫМША", "ДОПОЛНИТЕЛЬНО", "EXTRA"));
        _extraCard(dc, 80, PrayerNames.pick("Духа", "Духа", "Duha"),
                   PrayerNames.pick("күн шыққаннан кейін ¼", "четверть светового дня", "a quarter after sunrise"),
                   _times[:duha]);
        _extraCard(dc, 208, PrayerNames.pick("Таһажжуд", "Тахаджуд", "Tahajjud"),
                   PrayerNames.pick("түннің соңғы үштен бірі", "последняя треть ночи", "last third of the night"),
                   _times[:tahajjud]);
    }

    function _extraCard(dc, top, name, hint, hour) {
        var cx = Theme.CENTER_X;
        dc.setColor(Theme.surface(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 140, top, 280, 116, 28);
        _text(dc, cx, top + 15, Fonts.small(), Theme.accent(), C, name);
        _text(dc, cx, top + 62, Graphics.FONT_NUMBER_MEDIUM, Theme.COLOR_TEXT, C, TimeFormatter.hhmm(hour));
        _text(dc, cx, top + 103, Fonts.xtiny(), Theme.COLOR_TEXT_DIM, C, hint);
    }

    // Next prayer with a live countdown inside a progress ring (time since
    // the previous prayer). In Ramadan the hero is the fast (iftar / end of
    // suhoor) and the next prayer drops to a small line. A card at the
    // bottom shows the prayer that is running now and how long it lasts.
    function _drawCountdown(dc as Graphics.Dc, info, next, fast, win) as Void {
        if (next == null) { return; }
        var cx = Theme.CENTER_X;
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;

        var title = PrayerNames.nameOf(next[:name]);
        var secs  = next[:secondsUntil];
        var at    = next[:time];
        var sub   = null;
        if (fast != null) {
            title = _fastLabel(fast);
            secs  = fast[:secondsUntil];
            at    = fast[:time];
            sub   = PrayerNames.nextLabel() + " " + PrayerNames.nameOf(next[:name])
                  + " " + TimeFormatter.hhmm(next[:time]);
        }

        _drawProgressRing(dc, nowH, at);

        _text(dc, cx, 52, Fonts.small(), Theme.COLOR_TEXT_DIM, C, _pad2(info.hour) + ":" + _pad2(info.min));
        _pill(dc, cx, 100, 176, 38, Theme.container());
        _text(dc, cx, 100, Fonts.medium(), Theme.onContainer(), C, title);
        if (sub != null) { _text(dc, cx, 136, Fonts.xtiny(), Theme.COLOR_TEXT_DIM, C, sub); }

        // Hero countdown.
        _text(dc, cx, 204, Graphics.FONT_NUMBER_HOT, Theme.COLOR_TEXT, C, TimeFormatter.countdown(secs));
        _text(dc, cx, 262, Fonts.small(), Theme.COLOR_TEXT_DIM, C,
              PrayerNames.pick("сағат ", "в ", "at ") + TimeFormatter.hhmm(at));

        // What is running now (red when its time is about to run out).
        var line = (win != null)
            ? PrayerNames.windowLeft(win[:name], TimeFormatter.hm(win[:secondsLeft]))
            : _gregStr(info);
        var warn = (win != null && win[:secondsLeft] <= 20 * 60);
        _pill(dc, cx, 322, 256, 36, Theme.surface());
        _text(dc, cx, 322, Fonts.small(), warn ? Theme.COLOR_WARN : Theme.COLOR_TEXT, C, line);
    }

    // A thick arc around the bezel: how far we are from the previous prayer
    // (or last night's Isha) to the target time `target`.
    function _drawProgressRing(dc as Graphics.Dc, nowH, target) as Void {
        var cx = Theme.CENTER_X;
        var order = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        var prev = (_times[:isha] != null) ? _times[:isha] - 24.0d : 0.0d;
        for (var i = 0; i < order.size(); i++) {
            var t = _times[order[i]];
            if (t != null && t <= nowH) { prev = t; }
        }
        var end = (target < nowH) ? target + 24.0d : target;
        var frac = (end > prev) ? (nowH - prev) / (end - prev) : 0.0d;
        if (frac < 0.0d) { frac = 0.0d; }
        if (frac > 1.0d) { frac = 1.0d; }

        dc.setPenWidth(8);
        dc.setColor(Theme.surfaceHigh(), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cx, cx - 6);
        if (frac > 0.01d) {
            dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cx, cx - 6, Graphics.ARC_CLOCKWISE, 90, 90.0d - 360.0d * frac);
        }
        dc.setPenWidth(1);
    }

    function _fastLabel(fast) {
        return fast[:iftar] ? PrayerNames.iftarLabel() : PrayerNames.suhoorLabel();
    }

    // 7 days of upcoming Fajr / Maghrib in a compact table — for planning
    // suhoor / iftar (the column headers say so in Ramadan).
    function _drawWeek(dc as Graphics.Dc, info) as Void {
        var cx = Theme.CENTER_X;
        var ramadan = Fasting.isRamadan(info.year, info.month, info.day);
        var loc = _location.getCurrentLocation();

        _pill(dc, cx, 50, 130, 28, Theme.surfaceHigh());
        _text(dc, cx, 50, Fonts.tiny(), Theme.COLOR_TEXT_DIM, C, PrayerNames.pick("7 КҮН", "7 ДНЕЙ", "7 DAYS"));

        _text(dc, cx - 124, 82, Fonts.xtiny(), Theme.COLOR_TEXT_MUTED, L, PrayerNames.pick("Күн", "День", "Day"));
        _text(dc, cx + 10, 82, Fonts.xtiny(), Theme.COLOR_TEXT_MUTED, C,
              ramadan ? PrayerNames.suhoorLabel() : PrayerNames.nameOf(:fajr));
        _text(dc, cx + 130, 82, Fonts.xtiny(), Theme.COLOR_TEXT_MUTED, R,
              ramadan ? PrayerNames.iftarLabel() : PrayerNames.nameOf(:maghrib));

        for (var i = 0; i < 7; i++) {
            var di = Gregorian.info(Time.now().add(new Time.Duration(i * 86400)), Time.FORMAT_SHORT);
            var times = _calc.calculate(loc[:lat], loc[:lon], di.year, di.month, di.day, loc[:tz]);
            var y = 110 + i * 36;
            var today = (i == 0);

            _pill(dc, cx, y, 296, 31, today ? Theme.container() : Theme.surface());
            var color = today ? Theme.onContainer() : Theme.COLOR_TEXT;
            _text(dc, cx - 124, y, Fonts.tiny(), color, L, _dayLabel(di.day_of_week, i));
            _text(dc, cx + 10, y, Fonts.tiny(), color, C, TimeFormatter.hhmm(times[:fajr]));
            _text(dc, cx + 130, y, Fonts.tiny(), color, R, TimeFormatter.hhmm(times[:maghrib]));
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
