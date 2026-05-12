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
//     events scheduled closer than that throw. We skip the imminent
//     prayer and arm for the one after.
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

    // 3 pulses x 500 ms separated by 300 ms — distinct enough from
    // notification chatter, short enough to not annoy.
    function getVibePattern() {
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
        if (rec != null && rec["name"] != null && rec["name"].equals(":dhuhr")) {
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

        var record = {
            "name"      => target[:name].toString(),
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

    // Walks today's obligatory prayer slots; if none qualifies (all
    // already past or inside the 5-min lockout), rolls to tomorrow's
    // Fajr. Returns null if even tomorrow's Fajr is unavailable
    // (e.g. polar latitudes — the watch falls back to "no schedule").
    function _findNextNotifiable(calc, loc) {
        var notifiable = [:fajr, :dhuhr, :asr, :maghrib, :isha];

        var nowMoment = Time.now();
        var nowSec    = nowMoment.value();
        var nowInfo   = Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var nowH      = nowInfo.hour + nowInfo.min / 60.0d + nowInfo.sec / 3600.0d;
        var minH      = nowH + (MIN_SCHEDULE_GAP_SEC.toDouble() / 3600.0d);

        var today = calc.calculate(loc[:lat], loc[:lon],
            nowInfo.year, nowInfo.month, nowInfo.day, loc[:tz]);

        var bestSym  = null;
        var bestTime = null;
        for (var i = 0; i < notifiable.size(); i++) {
            var sym = notifiable[i];
            var t = today[sym];
            if (t == null) { continue; }
            if (t < minH) { continue; }
            if (bestTime == null || t < bestTime) {
                bestTime = t;
                bestSym  = sym;
            }
        }

        if (bestSym != null) {
            var deltaSec = ((bestTime - nowH) * 3600.0d).toNumber();
            return {
                :name         => bestSym,
                :timestampSec => nowSec + deltaSec
            };
        }

        // Roll to tomorrow's Fajr.
        var tomMoment = nowMoment.add(new Time.Duration(86400));
        var tInfo = Gregorian.info(tomMoment, Time.FORMAT_SHORT);
        var tomTimes = calc.calculate(loc[:lat], loc[:lon],
            tInfo.year, tInfo.month, tInfo.day, loc[:tz]);
        var fajr = tomTimes[:fajr];
        if (fajr == null) { return null; }
        var hoursUntil = (24.0d - nowH) + fajr;
        var deltaSec   = (hoursUntil * 3600.0d).toNumber();
        return {
            :name         => :fajr,
            :timestampSec => nowSec + deltaSec
        };
    }
}
