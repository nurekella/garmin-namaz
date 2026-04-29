using Toybox.System;
using Toybox.Background;
using Toybox.Lang;

// Service delegate invoked by the platform at the registered temporal
// event (i.e. the next prayer time). Strict 30-second / ~32 KB limits
// on background execution — we do exactly two things:
//   1. Vibrate the wrist via PrayerNotifier.
//   2. Re-register a temporal event for the prayer after this one.
// Background.exit(null) tells the system we're done.
(:background)
class BackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        PrayerNotifier.vibrateNow();

        // Re-arm for the next prayer using freshly resolved location +
        // calculator. Both are cheap to construct so we don't bother
        // caching across runs (we run for under a second total).
        var location = new LocationProvider();
        var calc = new PrayerCalculator(
            DumkMethod.params(),
            DumkMethod.DEFAULT_ASR,
            null);
        PrayerNotifier.schedule(calc, location);

        Background.exit(null);
    }
}
