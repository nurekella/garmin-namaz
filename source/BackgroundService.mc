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
        try {
            PrayerNotifier.notifyNow();
            Storage.remove(PrayerNotifier.STORAGE_KEY_BG_ERR);
        } catch (e) {
            _keepError("N", e);
        }

        // Re-arm for the next prayer using the user's chosen method +
        // Asr factor + offsets (NOT hardcoded DUMK — that bug shipped in
        // 1.1.0 and meant background re-arms ignored user method/offset
        // settings; alert timing was off for non-default methods).
        try {
            var location = new LocationProvider();
            Settings.applyToLocator(location);
            var calc = Settings.buildCalculator();
            PrayerNotifier.schedule(calc, location);
        } catch (e) {
            _keepError("S", e);
        }

        Background.exit(null);
    }

    function _keepError(where, e) {
        var msg = "?";
        if (e != null && e has :getErrorMessage && e.getErrorMessage() != null) { msg = e.getErrorMessage(); }
        try { Storage.set(PrayerNotifier.STORAGE_KEY_BG_ERR, where + ": " + msg); } catch (x) { }
    }
}
