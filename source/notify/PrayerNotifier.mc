using Toybox.Attention;
using Toybox.Background;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;

// Schedules a temporal event for the next obligatory-prayer time and
// fires a vibration when that event lands. The Background subsystem
// runs the registered ServiceDelegate at the requested moment even
// when the app is closed.
//
// Notes about Garmin's Background scheduling:
//   * `Background.registerForTemporalEvent` minimum interval is 5 min;
//     an imminent alert is pushed out to the 5-min floor (see pickAlert).
//   * Only one temporal event can be registered at a time. After
//     firing, BackgroundService re-registers for the next prayer.
//   * The 5 daily obligatory prayers trigger vibration. Sunrise is a
//     time marker, not a prayer — we skip it.
(:background, :glance)
module PrayerNotifier {

    const STORAGE_KEY_NEXT     = "scheduled_prayer";
    const STORAGE_KEY_ERR      = "last_schedule_err";
    const STORAGE_KEY_LASTVIBE = "last_vibrate_ts";
    const MIN_SCHEDULE_GAP_SEC = 5 * 60;

    // 4 user-selectable patterns — Settings.vibePatternIdx picks one.
    //   0 = Standard  (3 pulses × 500 ms, default)
    //   1 = Short     (1 pulse  × 600 ms)
    //   2 = Long      (5 pulses × 500 ms)
    //   3 = Double    (2 short pulses tight together)
    function getVibePattern() {
        var idx = 0;
        if (Toybox has :Application) {
            idx = Settings.vibePatternIdx();
        }
        if (idx == 1) {
            return [ new Attention.VibeProfile(100, 600) ];
        }
        if (idx == 2) {
            return [
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0,   250),
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0,   250),
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0,   250),
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0,   250),
                new Attention.VibeProfile(100, 500)
            ];
        }
        if (idx == 3) {
            return [
                new Attention.VibeProfile(100, 200),
                new Attention.VibeProfile(0,   120),
                new Attention.VibeProfile(100, 200)
            ];
        }
        // default — Standard
        return [
            new Attention.VibeProfile(100, 500),
            new Attention.VibeProfile(0,   300),
            new Attention.VibeProfile(100, 500),
            new Attention.VibeProfile(0,   300),
            new Attention.VibeProfile(100, 500)
        ];
    }

    // Stronger 5-pulse pattern for Jumu'ah (Friday Dhuhr).
    function getJumuahVibePattern() {
        return [
            new Attention.VibeProfile(100, 700),
            new Attention.VibeProfile(0,   250),
            new Attention.VibeProfile(100, 700),
            new Attention.VibeProfile(0,   250),
            new Attention.VibeProfile(100, 700),
            new Attention.VibeProfile(0,   250),
            new Attention.VibeProfile(100, 700),
            new Attention.VibeProfile(0,   250),
            new Attention.VibeProfile(100, 700)
        ];
    }

    function vibrateNow() {
        if (!(Attention has :vibrate)) { return; }
        if (!Settings.notificationsEnabled()) { return; }
        var pattern = getVibePattern();
        var rec = Storage.get(STORAGE_KEY_NEXT);
        if (rec != null && "dhuhr".equals(rec["name"])) {
            // day_of_week: 1=Sunday..7=Saturday; Friday = 6.
            var dow = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day_of_week;
            if (dow == 6) {
                pattern = getJumuahVibePattern();
            }
        }
        Attention.vibrate(pattern);
        // Record that the platform actually fired the temporal event and we
        // got here — diagnostic for when users say "no vibration".
        Storage.set(STORAGE_KEY_LASTVIBE, Time.now().value());
    }

    // Computes the next obligatory-prayer moment (skipping anything in
    // the next 5 min) and registers a temporal event for it. Returns a
    // dictionary { "name", "timestamp" } describing the registered
    // event, or null on failure / nothing schedulable.
    function schedule(calc, locationProvider) {
        var loc = locationProvider.getCurrentLocation();
        if (loc == null) { return null; }

        var target = _findNextNotifiable(calc, loc);
        if (target == null) { return null; }

        // Explicit string: Symbol.toString() yields "dhuhr" (no colon), so
        // the old ":dhuhr" comparison never matched and Jumu'ah never fired.
        var record = {
            "name"      => (target[:name] == :dhuhr) ? "dhuhr" : "other",
            "timestamp" => target[:timestampSec]
        };
        Storage.set(STORAGE_KEY_NEXT, record);

        try {
            Background.registerForTemporalEvent(new Time.Moment(target[:timestampSec]));
            Storage.remove(STORAGE_KEY_ERR);
        } catch (e) {
            // Most likely: requested time was inside another scheduled
            // event's lockout, the 5-min floor, OR Background-Service
            // permission was denied for this app. Capture the message for
            // the diagnostic line on the overview card.
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

    function getLastVibrateTs() {
        return Storage.get(STORAGE_KEY_LASTVIBE);
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

        var today = calc.calculate(loc[:lat], loc[:lon],
            nowInfo.year, nowInfo.month, nowInfo.day, loc[:tz]);
        var pick = pickAlert(today, nowH, preFajr, preOther);

        if (pick == null) {
            var tInfo = Gregorian.info(nowMoment.add(new Time.Duration(86400)), Time.FORMAT_SHORT);
            var tomorrow = calc.calculate(loc[:lat], loc[:lon],
                tInfo.year, tInfo.month, tInfo.day, loc[:tz]);
            // Tomorrow's hours measured from today's clock: shift "now" back 24h.
            pick = pickAlert(tomorrow, nowH - 24.0d, preFajr, preOther);
        }
        if (pick == null) { return null; }
        return {
            :name         => pick[:name],
            :timestampSec => nowMoment.value() + pick[:deltaSec]
        };
    }

    // Pure scheduling rule. Every obligatory prayer yields up to two alert
    // points — the pre-alert (T - pre) and the prayer itself (T) — and we
    // take the earliest one still ahead of `nowH`. An alert that falls
    // inside the platform's 5-min floor is pushed to the floor instead of
    // being dropped (a few minutes late beats a silent prayer).
    // Returns { :name => Symbol, :deltaSec => Number } or null.
    function pickAlert(times, nowH, preFajr, preOther) {
        var notifiable = [:fajr, :dhuhr, :asr, :maghrib, :isha];
        var bestSym  = null;
        var bestTime = null;
        for (var i = 0; i < notifiable.size(); i++) {
            var sym = notifiable[i];
            var t = times[sym];
            if (t == null) { continue; }
            var pre = (sym == :fajr) ? preFajr : preOther;
            var points = [t - pre / 60.0d, t];
            for (var j = 0; j < 2; j++) {
                var p = points[j];
                if (p > nowH && (bestTime == null || p < bestTime)) {
                    bestTime = p;
                    bestSym  = sym;
                }
            }
        }
        if (bestSym == null) { return null; }
        var deltaSec = ((bestTime - nowH) * 3600.0d).toNumber();
        if (deltaSec < MIN_SCHEDULE_GAP_SEC) { deltaSec = MIN_SCHEDULE_GAP_SEC; }
        return { :name => bestSym, :deltaSec => deltaSec };
    }
}
