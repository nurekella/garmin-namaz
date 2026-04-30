using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Lang;

class NamazApp extends Application.AppBase {

    var _calculator;
    var _location;

    function initialize() {
        AppBase.initialize();
        _location = new LocationProvider();
        _applySettings();
    }

    // Re-read Properties and rebuild the calculator. Called at start
    // and whenever GCM pushes new settings. Cheap — calculator and
    // locator hold no state worth preserving across rebuilds.
    function _applySettings() as Void {
        Settings.applyToLocator(_location);
        _calculator = Settings.buildCalculator();
    }

    function onSettingsChanged() as Void {
        _applySettings();
        // Re-arm the temporal event with the new schedule.
        PrayerNotifier.schedule(_calculator, _location);
        WatchUi.requestUpdate();
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
        var view = new CardView(_calculator, _location);
        var delegate = new CardDelegate(view, true);
        return [view, delegate];
    }

    (:glance)
    function getGlanceView() {
        var location = new LocationProvider();
        Settings.applyToLocator(location);
        var calc = Settings.buildCalculator();
        return [new GlanceView(calc, location)];
    }
}
