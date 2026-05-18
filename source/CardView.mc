using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.Lang;

// Card-deck layout. One prayer per card, full-screen. Swipe / DOWN-UP
// to flip through. Auto-opens at the next prayer.
//
// Card composition (top to bottom):
//   y=58   name          Fonts.medium  accent
//   y=170  big time      FONT_NUMBER_THAI_HOT  white
//   y=270  status row    Fonts.small   ("через 1:23:45" / "был 2 ч назад")
//   y=340  hijri         Fonts.xtiny   muted
//   y=380  position dots — current card filled
class CardView extends WatchUi.View {

    static const ORDER = [:overview, :countdown, :week, :fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha, :tahajjud];

    var _calc;
    var _location;
    var _timer;
    var _times;
    var _today_day;
    var _idx;          // currently displayed prayer index (0..5)

    function initialize(calc, location) {
        View.initialize();
        _calc = calc;
        _location = location;
    }

    function onShow() as Void {
        _refresh();
        _idx = _initialIdx();
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:_tick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
    }

    function _tick() as Void { WatchUi.requestUpdate(); }

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
        _idx = _initialIdx();
        WatchUi.requestUpdate();
    }

    function _initialIdx() {
        return 0; // always start on overview; user swipes for details
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
        if (_times == null || _today_day != info.day) {
            _refresh();
            _idx = _initialIdx();
        }
        // Re-pull calc + recompute every frame is cheap (< 1 ms);
        // ensures Asr/method changes show without a manual refresh.
        var app = Application.getApp();
        if (app != null && app._calculator != _calc) {
            _calc = app._calculator;
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
        var nowH = info.hour + info.min / 60.0d + info.sec / 3600.0d;

        if (sym == :overview) {
            _drawOverview(dc, info, nowH);
        } else if (sym == :countdown) {
            _drawCountdown(dc, info, nowH);
        } else if (sym == :week) {
            _drawWeek(dc, info);
        } else {
            _drawPrayer(dc, info, nowH, sym);
        }

        _drawPagerDots(dc);
    }

    function _drawOverview(dc as Graphics.Dc, info, nowH) as Void {
        // ---- header: Greg date + year, Hijri date + year ----
        var monthStr = PrayerNames.monthShort(info.month);
        var dateStr  = info.day + " " + monthStr + " " + info.year;
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 44,
                    Fonts.medium(), dateStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var hd = HijriDate.fromGregorian(info.year, info.month, info.day);
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 82,
                    Fonts.small(),
                    hd[:day] + " " + HijriDate.monthName(hd[:month]) + " " + hd[:year],
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ---- city name ----
        var loc = _location.getCurrentLocation();
        var cityLabel = _resolveCityLabel(loc);
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 116,
                    Fonts.small(), cityLabel,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ---- Friday Jumu'ah strip: overrides the city line once a week ----
        if (info.day_of_week == 6) {
            var lang = Settings.language();
            var jumLabel = lang.equals("kk") ? "Жұма" : (lang.equals("ru") ? "Жума" : "Jumu'ah");
            dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 116,
                        Fonts.small(), jumLabel,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ---- 6 prayers ----
        var nextEntry = _calc.getNextPrayer(_times, nowH);
        var nextSym = (nextEntry != null) ? nextEntry[:name] : null;
        // 6 rows including Sunrise (Tahajjud stays on its own swipe card).
        var prayers = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        var rowY = 148;
        var rowH = 40;
        for (var i = 0; i < prayers.size(); i++) {
            var sym = prayers[i];
            var t   = _times[sym];
            var color = _colorFor(sym, nextSym, t, nowH);
            var y = rowY + i * rowH;

            // 28x28 icon flush-left, vertically centred on the row.
            var icon = _iconFor(sym);
            if (icon != null) {
                dc.drawBitmap(Theme.CENTER_X - 130,
                              y - icon.getHeight() / 2,
                              icon);
            }

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X - 90, y,
                        Fonts.medium(), PrayerNames.nameOf(sym),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(Theme.CENTER_X + 120, y,
                        Fonts.medium(), TimeFormatter.hhmm(t),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        _drawDayProgress(dc, nowH);
    }

    // 7 days of upcoming Fajr / Maghrib in a compact table — for planning
    // sahoor / iftar without having to swipe through each day's detail.
    function _drawWeek(dc as Graphics.Dc, info) as Void {
        var loc = _location.getCurrentLocation();
        if (loc == null) { return; }

        // Header
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 50, Fonts.tiny(), "7 DAYS",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Sub-headers — Day / Fajr / Maghrib
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        var headerY = 82;
        dc.drawText(Theme.CENTER_X - 100, headerY, Fonts.xtiny(), "Day",
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(Theme.CENTER_X, headerY, Fonts.xtiny(),
                    PrayerNames.nameOf(:fajr),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(Theme.CENTER_X + 100, headerY, Fonts.xtiny(),
                    PrayerNames.nameOf(:maghrib),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        var rowY = 110;
        var rowH = 36;
        for (var i = 0; i < 7; i++) {
            var moment = Time.now().add(new Time.Duration(i * 86400));
            var di = Gregorian.info(moment, Time.FORMAT_SHORT);
            var times = _calc.calculate(loc[:lat], loc[:lon],
                di.year, di.month, di.day, loc[:tz]);
            var y = rowY + i * rowH;
            var color = (i == 0) ? Theme.accent() : Theme.COLOR_TEXT;

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X - 100, y,
                        Fonts.tiny(), _dayLabel(di.day_of_week, i),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(Theme.CENTER_X, y,
                        Fonts.tiny(), TimeFormatter.hhmm(times[:fajr]),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(Theme.CENTER_X + 100, y,
                        Fonts.tiny(), TimeFormatter.hhmm(times[:maghrib]),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function _dayLabel(dow, daysFromToday) {
        if (daysFromToday == 0) {
            var lang = Settings.language();
            if (lang.equals("kk")) { return "Бүгін"; }
            if (lang.equals("ru")) { return "Сегодня"; }
            return "Today";
        }
        var lang = Settings.language();
        if (lang.equals("kk")) {
            var kk = ["Жк", "Дс", "Сс", "Ср", "Бс", "Жм", "Сн"];
            return kk[(dow - 1) % 7];
        }
        if (lang.equals("ru")) {
            var ru = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
            return ru[(dow - 1) % 7];
        }
        var en = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return en[(dow - 1) % 7];
    }

    // Slim progress bar under the prayer rows. Maps current time onto the
    // Fajr -> Isha span — 0% at Fajr, 100% at Isha. Outside that range the
    // bar is empty (night) or full (after Isha).
    function _drawDayProgress(dc as Graphics.Dc, nowH) as Void {
        var fajr = _times[:fajr];
        var isha = _times[:isha];
        if (fajr == null || isha == null) { return; }

        var ratio;
        if (nowH < fajr)      { ratio = 0.0d; }
        else if (nowH > isha) { ratio = 1.0d; }
        else                  { ratio = (nowH - fajr) / (isha - fajr); }

        var barW = 280;
        var barX = Theme.CENTER_X - barW / 2;
        var barY = 396;
        // Track
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 4);
        // Fill — accent.
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, (barW * ratio).toNumber(), 4);
    }

    function _pad2(n) {
        if (n < 10) { return "0" + n; }
        return "" + n;
    }

    function _drawCountdown(dc as Graphics.Dc, info, nowH) as Void {
        var nextEntry = _calc.getNextPrayer(_times, nowH);
        var name; var time; var secsLeft;
        if (nextEntry != null) {
            name     = PrayerNames.nameOf(nextEntry[:name]);
            time     = nextEntry[:time];
            secsLeft = nextEntry[:secondsUntil];
        } else {
            // Past Isha — count to tomorrow's Fajr.
            var tMoment = Time.now().add(new Time.Duration(86400));
            var tInfo = Gregorian.info(tMoment, Time.FORMAT_SHORT);
            var loc = _location.getCurrentLocation();
            var tt = _calc.calculate(loc[:lat], loc[:lon],
                tInfo.year, tInfo.month, tInfo.day, loc[:tz]);
            var f = tt[:fajr];
            if (f == null) { return; }
            name     = PrayerNames.nameOf(:fajr);
            time     = f;
            secsLeft = (((24.0d - nowH) + f) * 3600.0d).toNumber();
        }

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 70,
                    Fonts.tiny(), PrayerNames.nextLabel(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 120,
                    Fonts.medium(), name,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Hero countdown — biggest number font available.
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 220,
                    Graphics.FONT_NUMBER_THAI_HOT,
                    TimeFormatter.countdown(secsLeft),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // The actual prayer time itself, smaller. Format depends on locale —
        // ru/en: "at 19:09" / kk: "сағат 19:09".
        var lang = Settings.language();
        var atLabel = lang.equals("kk") ? "сағат" : (lang.equals("ru") ? "в" : "at");
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 288,
                    Fonts.small(),
                    atLabel + " " + TimeFormatter.hhmm(time),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        _drawClockAndDate(dc, info);
    }

    function _drawPrayer(dc as Graphics.Dc, info, nowH, sym) as Void {
        var time = _times[sym];

        // Icon + name on one row near the top — icon directly left of name.
        var icon = _iconFor(sym);
        var name = PrayerNames.nameOf(sym);
        var nameFont = Fonts.medium();
        var nameW = dc.getTextWidthInPixels(name, nameFont);
        var iconW = (icon != null) ? icon.getWidth() : 0;
        var groupW = iconW + (icon != null ? 8 : 0) + nameW;
        var xStart = Theme.CENTER_X - groupW / 2;
        if (icon != null) {
            dc.drawBitmap(xStart, 90 - icon.getHeight() / 2, icon);
            xStart += iconW + 8;
        }
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(xStart, 90,
                    nameFont, name,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 170,
                    Graphics.FONT_NUMBER_THAI_HOT,
                    TimeFormatter.hhmm(time),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (time != null) {
            var deltaH = time - nowH;
            var label;
            var color;
            if (deltaH > 0) {
                color = Theme.COLOR_TEXT_DIM;
                label = "-" + TimeFormatter.countdown((deltaH * 3600.0d).toNumber());
            } else {
                color = Theme.COLOR_TEXT_MUTED;
                label = "+" + TimeFormatter.countdown((-deltaH * 3600.0d).toNumber());
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER_X, 244,
                        Fonts.small(), label,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        _drawClockAndDate(dc, info);
    }

    // Top-of-card current clock; bottom Greg + Hijri dates.
    // Shared by countdown and per-prayer detail cards.
    function _drawClockAndDate(dc as Graphics.Dc, info) as Void {
        // Current clock at top centre.
        var clockStr = _pad2(info.hour) + ":" + _pad2(info.min);
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 32,
                    Fonts.small(), clockStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom: Greg + Hijri.
        var monthStr = PrayerNames.monthShort(info.month);
        var gregStr  = info.day + " " + monthStr + " " + info.year;
        var hd = HijriDate.fromGregorian(info.year, info.month, info.day);
        var hijriStr = hd[:day] + " " + HijriDate.monthName(hd[:month]) + " " + hd[:year];

        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, 332,
                    Fonts.small(), gregStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(Theme.CENTER_X, 358,
                    Fonts.small(), hijriStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _colorFor(sym, nextSym, time, nowH) {
        if (time == null)     { return Theme.COLOR_TEXT_MUTED; }
        if (sym == nextSym)   { return Theme.accent(); }
        if (time < nowH)      { return Theme.COLOR_TEXT_DIM; }
        return Theme.COLOR_TEXT;
    }

    // (Theme.accent already replaced via global edit.)

    function _iconFor(sym) {
        if (sym == :fajr)     { return WatchUi.loadResource(Rez.Drawables.IconFajr); }
        if (sym == :sunrise)  { return WatchUi.loadResource(Rez.Drawables.IconSunrise); }
        if (sym == :dhuhr)    { return WatchUi.loadResource(Rez.Drawables.IconDhuhr); }
        if (sym == :asr)      { return WatchUi.loadResource(Rez.Drawables.IconAsr); }
        if (sym == :maghrib)  { return WatchUi.loadResource(Rez.Drawables.IconMaghrib); }
        if (sym == :isha)     { return WatchUi.loadResource(Rez.Drawables.IconIsha); }
        if (sym == :tahajjud) { return WatchUi.loadResource(Rez.Drawables.IconTahajjud); }
        return null;
    }

    function _resolveCityLabel(loc) {
        if (loc == null) { return ""; }
        var lang = Settings.language();
        if (loc[:cityId] != null) {
            var c = Cities.byId(loc[:cityId]);
            if (c != null) { return Cities.localizedName(c, lang); }
        }
        if (loc[:source] == :gps || loc[:source] == :cached) {
            return "GPS";
        }
        return "";
    }

    function _normalizePrayerName(raw) {
        // Strip leading colon from ":fajr"-style symbols.
        if (raw.find(":") == 0) {
            return raw.substring(1, raw.length());
        }
        // Map "symbol (NNN)" hash-form back to known names by comparing
        // the toString of each known symbol once. Cheap.
        var known = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < known.size(); i++) {
            if (known[i].toString().equals(raw)) {
                if (known[i] == :fajr)    { return "Fajr"; }
                if (known[i] == :sunrise) { return "Sunrise"; }
                if (known[i] == :dhuhr)   { return "Dhuhr"; }
                if (known[i] == :asr)     { return "Asr"; }
                if (known[i] == :maghrib) { return "Maghrib"; }
                if (known[i] == :isha)    { return "Isha"; }
            }
        }
        return raw;
    }

    function _drawPagerDots(dc as Graphics.Dc) as Void {
        var n = ORDER.size();
        var spacing = 16;
        var total = (n - 1) * spacing;
        var x0 = Theme.CENTER_X - total / 2;
        var y  = 380;
        for (var i = 0; i < n; i++) {
            if (i == _idx) {
                dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * spacing, y, 4);
            } else {
                dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * spacing, y, 3);
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
