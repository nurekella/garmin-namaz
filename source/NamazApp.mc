using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Lang;

class NamazApp extends Application.AppBase {

    var _calculator;
    var _location;

    function initialize() {
        AppBase.initialize();
        _location = new LocationProvider();
        _calculator = new PrayerCalculator(
            DumkMethod.params(),
            DumkMethod.DEFAULT_ASR,
            null  // user offsets — wired up in Stage 8 (settings)
        );
    }

    function onStart(state as Lang.Dictionary?) as Void {
        // Arm the next prayer-time vibration so it fires even after the
        // app is backgrounded. PrayerNotifier handles the 5-min floor
        // and rolls past prayers within it.
        PrayerNotifier.schedule(_calculator, _location);
    }

    function onStop(state as Lang.Dictionary?) as Void {
        // Leave the temporal event registered — that's the whole
        // point of background scheduling. Don't clear it on stop.
    }

    function getServiceDelegate() {
        return [new BackgroundService()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new NamazView(_calculator, _location);
        var delegate = new NamazDelegate(view);
        return [view, delegate];
    }

    (:glance)
    function getGlanceView() {
        var location = new LocationProvider();
        var calc = new PrayerCalculator(
            DumkMethod.params(),
            DumkMethod.DEFAULT_ASR,
            null);
        return [new GlanceView(calc, location)];
    }
}
