using Toybox.System;
using Toybox.Background;
using Toybox.Lang;
using Toybox.Time;

// Service delegate invoked by the platform at the registered temporal
// event (i.e. the next prayer time). Strict 30-second / ~32 KB limits
// on background execution — we do exactly two things:
//   1. Post the prayer notification via PrayerNotifier.
//   2. Re-register a temporal event for the prayer after this one.
// Background.exit(null) tells the system we're done.
(:background)
class BackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        // A throw here must not skip the re-arm below, or every later
        // prayer stays silent until the user happens to open the app.
        // Every run and every failure is kept for the "Diagnostics" row in
        // the watch menu: the only way to see what happened on a real watch.
        Storage.set(PrayerNotifier.STORAGE_KEY_BG_RUN, Time.now().value());
        // The alert being delivered now; schedule() below overwrites it.
        var rec = PrayerNotifier.getScheduled();
        // Delivered: drop it, so a test alert firing a little early cannot
        // make schedule() keep it and leave nothing armed.
        Storage.remove(PrayerNotifier.STORAGE_KEY_NEXT);

        // Re-arm FIRST, for the next prayer, with the user's method + Asr
        // factor + offsets. Some firmware kills the process inside the
        // notification call (uncatchable); re-arming first keeps the chain
        // of alerts alive even then.
        try {
            var location = new LocationProvider();
            Settings.applyToLocator(location);
            var calc = Settings.buildCalculator();
            PrayerNotifier.schedule(calc, location);
        } catch (e) {
            _keepError("S", e);
        }

        try {
            PrayerNotifier.notifyNow(rec);
            Storage.remove(PrayerNotifier.STORAGE_KEY_BG_ERR);
        } catch (e) {
            _keepError("N", e);
        }

        Background.exit(null);
    }

    function _keepError(where, e) {
        var msg = "?";
        if (e != null && e has :getErrorMessage && e.getErrorMessage() != null) { msg = e.getErrorMessage(); }
        try { Storage.set(PrayerNotifier.STORAGE_KEY_BG_ERR, where + ": " + msg); } catch (x) { }
    }
}
