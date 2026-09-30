using Toybox.System;
using Toybox.Background;
using Toybox.Lang;

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
        try {
            PrayerNotifier.notifyNow();
        } catch (e) {
        }

        // Re-arm for the next prayer using the user's chosen method +
        // Asr factor + offsets (NOT hardcoded DUMK — that bug shipped in
        // 1.1.0 and meant background re-arms ignored user method/offset
        // settings; alert timing was off for non-default methods).
        var location = new LocationProvider();
        Settings.applyToLocator(location);
        var calc = Settings.buildCalculator();
        PrayerNotifier.schedule(calc, location);

        Background.exit(null);
    }
}
