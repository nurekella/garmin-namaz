using Toybox.Background;
using Toybox.Notifications;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;

// Schedules a temporal event for the next obligatory-prayer time and
// posts a system notification when that event lands. The Background
// subsystem runs the registered ServiceDelegate at the requested moment
// even when the app is closed.
//
// Notes about Garmin's Background scheduling:
//   * `Background.registerForTemporalEvent` throws when the event is
//     less than 5 min after the previous run; an imminent alert is
//     pushed out to that floor (see pickAlert).
//   * Only one temporal event can be registered at a time. After
//     firing, BackgroundService re-registers for the next prayer.
//   * Toybox.Attention is NOT available to the background process —
//     even `Attention has :vibrate` throws there. So the alert is a
//     system notification; the watch buzzes per its own notification
//     settings.
//   * The background process also runs AppBase.onStart, so scheduling
//     must not happen there: it would overwrite the record of the event
//     being delivered before notifyNow reads it.
//   * The 5 daily obligatory prayers trigger an alert. Sunrise is a
//     time marker, not a prayer — we skip it.
(:background, :glance)
module PrayerNotifier {

    const STORAGE_KEY_NEXT     = "scheduled_prayer";
    const STORAGE_KEY_ERR      = "last_schedule_err";
    const MIN_SCHEDULE_GAP_SEC = 5 * 60;

    // Background-safe alert for the event recorded by schedule() or
    // scheduleTest(). Title was resolved at schedule time ("Dhuhr 13:00");
    // the simulator renders only the title, so the time lives there.
    function notifyNow() {
        var rec = Storage.get(STORAGE_KEY_NEXT);
        if (rec == null || rec["title"] == null) { return; }
        if (!Settings.notificationsEnabled() && rec["test"] != true) { return; }
        if (Toybox has :Notifications) {
            var sub = rec["sub"];
            Notifications.showNotification(rec["title"],
                (sub != null) ? sub : PrayerNames.prayerTimeLabel(),
                { :dismissPrevious => true });
        } else {
            // API < 5.1 (e.g. Venu Sq 2): system "open app?" prompt.
            Background.requestApplicationWake(rec["title"]);
        }
    }

    // Menu "Test notification": a real background alert ~5 min from now,
    // through the same path as a prayer alert. Returns false if the
    // platform refused the event.
    function scheduleTest() {
        var ts = Time.now().value() + MIN_SCHEDULE_GAP_SEC + 5;
        Storage.set(STORAGE_KEY_NEXT, {
            "title"     => PrayerNames.pick("Тексеру", "Проверка", "Test"),
            "timestamp" => ts,
            "test"      => true
        });
        try {
            Background.registerForTemporalEvent(new Time.Moment(ts));
        } catch (e) {
            return false;
        }
        return true;
    }

    // Computes the next alert (see pickAlert) and registers a temporal
    // event for it. Returns the stored record
    // { "title", "timestamp" }, or null on failure / nothing
    // schedulable.
    function schedule(calc, locationProvider) {
        // A pending test alert wins until it has fired.
        var cur = Storage.get(STORAGE_KEY_NEXT);
        if (cur != null && cur["test"] == true && cur["timestamp"] > Time.now().value()) {
            return cur;
        }

        var loc = locationProvider.getCurrentLocation();
        if (loc == null) { return null; }

        // Whatever happens below, the watch face should show the next prayer.
        FaceData.publish(calc, loc);

        var target = _findNextNotifiable(calc, loc);
        if (target == null) { return null; }

        if (target[:kind] == :extra) {
            return _register({ "title" => target[:title], "sub" => target[:sub],
                               "timestamp" => target[:timestampSec] });
        }
        var title = PrayerNames.nameOf(target[:name]);
        if (target[:kind] == :end) {
            title += " " + PrayerNames.endsWord();
        } else if (target[:name] == :dhuhr) {
            // day_of_week: 1=Sunday..7=Saturday; Friday = 6.
            var info = Gregorian.info(new Time.Moment(target[:timestampSec]), Time.FORMAT_SHORT);
            if (info.day_of_week == 6) { title = PrayerNames.jumuah(); }
        }
        return _register({
            "title"     => title + " " + TimeFormatter.hhmm(target[:time]),
            "timestamp" => target[:timestampSec]
        });
    }

    // Stores the record and arms the temporal event for it.
    function _register(record) {
        Storage.set(STORAGE_KEY_NEXT, record);

        try {
            Background.registerForTemporalEvent(new Time.Moment(record["timestamp"]));
            Storage.remove(STORAGE_KEY_ERR);
        } catch (e) {
            // Most likely: inside the 5-min floor after the last run, or
            // Background permission denied. Kept for debugging.
            var msg = "?";
            if (e != null && e has :getErrorMessage) {
                msg = e.getErrorMessage();
            }
            Storage.set(STORAGE_KEY_ERR, msg);
            return null;
        }
        return record;
    }


    function getScheduled() {
        return Storage.get(STORAGE_KEY_NEXT);
    }

    function getLastError() {
        return Storage.get(STORAGE_KEY_ERR);
    }


    function clearScheduled() {
        Storage.remove(STORAGE_KEY_NEXT);
        try {
            Background.deleteTemporalEvent();
        } catch (e) {
        }
    }

    // ---------- internal ----------

    // Pre-alert minutes for the named prayer; reads user setting via
    // Settings (no-op when Settings module isn't available, e.g. some
    // test scopes).
    function _prealertFor(sym) {
        if (!(Toybox has :Application)) { return 0; }
        if (sym == :fajr) { return Settings.prealertFajrMinutes(); }
        return Settings.prealertOtherMinutes();
    }

    // Next alert from today's schedule, else tomorrow's. Returns null if
    // neither day has a usable time (e.g. polar latitudes).
    function _findNextNotifiable(calc, loc) {
        var nowMoment = Time.now();
        var nowInfo   = Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var nowH      = nowInfo.hour + nowInfo.min / 60.0d + nowInfo.sec / 3600.0d;
        var preFajr   = _prealertFor(:fajr);
        var preOther  = _prealertFor(:dhuhr);
        var endWarn   = Settings.endWarnMinutes();

        var today = calc.calculate(loc[:lat], loc[:lon],
            nowInfo.year, nowInfo.month, nowInfo.day, loc[:tz]);
        var tInfo = Gregorian.info(nowMoment.add(new Time.Duration(86400)), Time.FORMAT_SHORT);
        var pick = pickAlert(today, nowH, preFajr, preOther, endWarn,
                             Occasions.extras(nowInfo, today, tInfo));

        if (pick == null) {
            var tomorrow = calc.calculate(loc[:lat], loc[:lon],
                tInfo.year, tInfo.month, tInfo.day, loc[:tz]);
            // Tomorrow's hours measured from today's clock: shift "now" back 24h.
            var t2 = Gregorian.info(nowMoment.add(new Time.Duration(2 * 86400)), Time.FORMAT_SHORT);
            pick = pickAlert(tomorrow, nowH - 24.0d, preFajr, preOther, endWarn,
                             Occasions.extras(tInfo, tomorrow, t2));
        }
        if (pick == null) { return null; }
        return {
            :name         => pick[:name],
            :kind         => pick[:kind],
            :title        => pick[:title],
            :sub          => pick[:sub],
            :time         => pick[:time],
            :timestampSec => nowMoment.value() + pick[:deltaSec]
        };
    }

    // Pure scheduling rule. Every obligatory prayer yields up to three alert
    // points: the pre-alert (T - pre), the prayer itself (T) and, for the
    // two prayers you can actually miss, a warning before their time ends
    // (Fajr -> sunrise, Asr -> maghrib; endWarn minutes before). We take
    // the earliest one still ahead of nowH. An alert inside the platform
    // 5-min floor is pushed to the floor instead of being dropped (a few
    // minutes late beats a silent prayer); an end warning that the floor
    // would push past the end itself is skipped.
    // Returns { :name => Symbol, :kind => :start or :end, :time => hours
    // shown in the title, :deltaSec => Number } or null.
    // `extras` are further points [hour, title, subtitle] (Occasions.extras)
    // with their own text; they come back with :kind => :extra.
    function pickAlert(times, nowH, preFajr, preOther, endWarn, extras) {
        var notifiable = [:fajr, :dhuhr, :asr, :maghrib, :isha];
        var bestSym   = null;
        var bestKind  = null;
        var bestTime  = null;
        var bestShown = null;
        var floorH = MIN_SCHEDULE_GAP_SEC / 3600.0d;
        for (var i = 0; i < notifiable.size(); i++) {
            var sym = notifiable[i];
            var t = times[sym];
            if (t == null) { continue; }
            var pre = (sym == :fajr) ? preFajr : preOther;
            var points = [[t - pre / 60.0d, :start, t], [t, :start, t]];
            if (endWarn > 0) {
                var e = (sym == :fajr) ? times[:sunrise] : ((sym == :asr) ? times[:maghrib] : null);
                if (e != null) { points.add([e - endWarn / 60.0d, :end, e]); }
            }
            for (var j = 0; j < points.size(); j++) {
                var p = points[j];
                if (p[0] <= nowH) { continue; }
                if (p[1] == :end && nowH + floorH >= p[2]) { continue; }
                if (bestTime == null || p[0] < bestTime) {
                    bestTime  = p[0];
                    bestSym   = sym;
                    bestKind  = p[1];
                    bestShown = p[2];
                }
            }
        }
        var bestExtra = null;
        for (var k = 0; k < extras.size(); k++) {
            var x = extras[k];
            if (x[0] > nowH && (bestTime == null || x[0] < bestTime)) {
                bestTime  = x[0];
                bestExtra = x;
            }
        }
        if (bestSym == null && bestExtra == null) { return null; }
        var deltaSec = ((bestTime - nowH) * 3600.0d).toNumber();
        if (deltaSec < MIN_SCHEDULE_GAP_SEC) { deltaSec = MIN_SCHEDULE_GAP_SEC; }
        if (bestExtra != null) {
            return { :name => :extra, :kind => :extra, :time => bestExtra[0], :title => bestExtra[1],
                     :sub => bestExtra[2], :deltaSec => deltaSec };
        }
        return { :name => bestSym, :kind => bestKind, :time => bestShown, :deltaSec => deltaSec };
    }
}
