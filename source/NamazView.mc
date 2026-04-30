using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.Lang;

class NamazView extends WatchUi.View {

    // Layout — y-coordinates for the 416×416 round face. The screen
    // narrows at top and bottom; we keep critical text inside the
    // inscribed square (~y=60..356).
    static const Y_DATE         = 50;
    static const Y_DATE_HIJRI   = 88;
    static const Y_NEXT_ROW     = 130;
    static const Y_COUNTDOWN    = 185;
    static const NEXT_GAP       = 8;
    static const Y_LIST_TOP     = 268;
    static const ROW_HEIGHT     = 38;
    // Columns pulled inward — at y≈345 the round face is only ~260 px
    // wide, so text centred at x=110 / x=306 clips on "Maghrib".
    static const COL1_X         = 130;
    static const COL2_X         = 286;

    var _calc;
    var _location;
    var _timer;
    var _location_dict;
    var _today_times;
    var _today_day;          // day-of-month at last refresh, for midnight rollover detection
    var _showMinutes = false; // tap toggles countdown HH:MM:SS <-> "NN min"
    var _showTomorrow = false; // DOWN toggles list to tomorrow's schedule
    var _tomorrow_times;
    var _tomorrow_day;

    function initialize(calc, location) {
        View.initialize();
        _calc = calc;
        _location = location;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        _refreshTimes();
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        _timer.start(method(:_onTick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
        }
    }

    function _onTick() as Void {
        WatchUi.requestUpdate();
    }

    // Public so the delegate can poke us after settings/menu changes.
    function refresh() as Void {
        _refreshTimes();
        WatchUi.requestUpdate();
    }

    function toggleMinutes() as Void {
        _showMinutes = !_showMinutes;
        WatchUi.requestUpdate();
    }

    function toggleTomorrow() as Void {
        _showTomorrow = !_showTomorrow;
        if (_showTomorrow) { _ensureTomorrow(); }
        WatchUi.requestUpdate();
    }

    function _ensureTomorrow() as Void {
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (_tomorrow_times != null && _tomorrow_day == nowInfo.day) { return; }
        var tMoment = Time.now().add(new Time.Duration(86400));
        var tInfo = Gregorian.info(tMoment, Time.FORMAT_SHORT);
        _tomorrow_times = _calc.calculate(
            _location_dict[:lat], _location_dict[:lon],
            tInfo.year, tInfo.month, tInfo.day,
            _location_dict[:tz]);
        _tomorrow_day = nowInfo.day;
    }

    function _refreshTimes() as Void {
        _location_dict = _location.getCurrentLocation();
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        _today_times = _calc.calculate(
            _location_dict[:lat],
            _location_dict[:lon],
            nowInfo.year, nowInfo.month, nowInfo.day,
            _location_dict[:tz]
        );
        _today_day = nowInfo.day;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // Detect midnight rollover so the schedule advances without
        // the user re-opening the app.
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (_today_day != nowInfo.day) {
            _refreshTimes();
        }

        dc.setColor(Theme.COLOR_BG, Theme.COLOR_BG);
        dc.clear();

        if (_today_times == null) {
            _drawSearching(dc);
            return;
        }

        _drawDate(dc, nowInfo);
        _drawNextPrayer(dc, nowInfo);
        _drawPrayerList(dc, nowInfo);
    }

    function _drawSearching(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Theme.CENTER_Y,
                    Fonts.medium(), PrayerNames.gpsSearching(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawDate(dc as Graphics.Dc, nowInfo) as Void {
        var monthStr = PrayerNames.monthShort(nowInfo.month);
        var dateStr  = nowInfo.day + " " + monthStr + " " + nowInfo.year;

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Y_DATE,
                    Fonts.tiny(), dateStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var h = HijriDate.fromGregorian(nowInfo.year, nowInfo.month, nowInfo.day);
        var hStr = h[:day] + " " + HijriDate.monthName(h[:month]) + " " + h[:year];
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X, Y_DATE_HIJRI,
                    Fonts.xtiny(), hStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawNextPrayer(dc as Graphics.Dc, nowInfo) as Void {
        var nowH = nowInfo.hour + nowInfo.min / 60.0d + nowInfo.sec / 3600.0d;
        var next = _calc.getNextPrayer(_today_times, nowH);
        var secondsUntil;
        var name;

        if (next != null) {
            name = PrayerNames.nameOf(next[:name]);
            secondsUntil = next[:secondsUntil];
        } else {
            // All today's prayers are past — countdown to tomorrow's Fajr.
            var tom = _tomorrowFajr(nowInfo);
            if (tom == null) {
                return;
            }
            name = PrayerNames.nameOf(:fajr);
            secondsUntil = tom;
        }

        // "NEXT  Asr" on a single baseline. FONT_TINY and FONT_SMALL have
        // different heights, so VCENTER alone leaves them looking off — we
        // align by baseline using each font's ascent.
        var labelFont = Fonts.tiny();
        var nameFont  = Fonts.small();
        var labelH = dc.getFontHeight(labelFont);
        var nameH  = dc.getFontHeight(nameFont);
        var baselineY = Y_NEXT_ROW + nameH / 2;

        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X - NEXT_GAP, baselineY - labelH,
                    labelFont, PrayerNames.nextLabel(),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(Theme.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER_X + NEXT_GAP, baselineY - nameH,
                    nameFont, name,
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Countdown — tap toggles between HH:MM:SS and "NN min".
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        if (_showMinutes) {
            dc.drawText(Theme.CENTER_X, Y_COUNTDOWN,
                        Graphics.FONT_NUMBER_MILD,
                        TimeFormatter.minutesLeft(secondsUntil) + " min",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(Theme.CENTER_X, Y_COUNTDOWN,
                        Graphics.FONT_NUMBER_MILD, TimeFormatter.countdown(secondsUntil),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function _drawPrayerList(dc as Graphics.Dc, nowInfo) as Void {
        var times = _today_times;
        var nowH = nowInfo.hour + nowInfo.min / 60.0d + nowInfo.sec / 3600.0d;
        var nextSym = null;
        if (_showTomorrow && _tomorrow_times != null) {
            times = _tomorrow_times;
            nextSym = :fajr; // first prayer of next day reads as "next"
        } else {
            var nextEntry = _calc.getNextPrayer(_today_times, nowH);
            if (nextEntry != null) { nextSym = nextEntry[:name]; }
        }

        var entries = [
            [:fajr,    COL1_X, 0],
            [:sunrise, COL2_X, 0],
            [:dhuhr,   COL1_X, 1],
            [:asr,     COL2_X, 1],
            [:maghrib, COL1_X, 2],
            [:isha,    COL2_X, 2]
        ];

        for (var i = 0; i < entries.size(); i++) {
            var sym  = entries[i][0];
            var x    = entries[i][1];
            var row  = entries[i][2];
            var y    = Y_LIST_TOP + row * ROW_HEIGHT;
            var time = times[sym];
            var color = _showTomorrow
                ? Theme.COLOR_TEXT_DIM
                : _colorFor(sym, nextSym, time, nowH);

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y,
                        Fonts.xtiny(),
                        PrayerNames.nameOf(sym) + " " + TimeFormatter.hhmm(time),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function _colorFor(sym, nextSym, time, nowH) {
        if (time == null)        { return Theme.COLOR_TEXT_MUTED; }
        if (sym == nextSym)       { return Theme.COLOR_ACCENT; }
        if (time < nowH)          { return Theme.COLOR_TEXT_DIM; }
        return Theme.COLOR_TEXT;
    }

    function _tomorrowFajr(nowInfo) {
        var tomorrowMoment = Time.now().add(new Time.Duration(86400));
        var t = Gregorian.info(tomorrowMoment, Time.FORMAT_SHORT);
        var tt = _calc.calculate(
            _location_dict[:lat],
            _location_dict[:lon],
            t.year, t.month, t.day,
            _location_dict[:tz]
        );
        var fajr = tt[:fajr];
        if (fajr == null) { return null; }
        var nowH = nowInfo.hour + nowInfo.min / 60.0d + nowInfo.sec / 3600.0d;
        var hoursUntil = (24.0d - nowH) + fajr;
        return (hoursUntil * 3600.0d).toNumber();
    }
}
