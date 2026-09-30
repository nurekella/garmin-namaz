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
        // Force the visible view to re-pull _calc and redraw.
        if (WatchUi has :requestUpdate) { WatchUi.requestUpdate(); }
    }

    // No scheduling in onStart: the background process runs it too, right
    // before onTemporalEvent, and would overwrite the record of the alert
    // being delivered (see PrayerNotifier).
    function onStop(state as Lang.Dictionary?) as Void {
        // Leave the temporal event registered — that's the whole
        // point of background scheduling. Don't clear it on stop.
    }

    function getServiceDelegate() {
        return [new BackgroundService()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        // Foreground launch only: arm the next prayer alert so it fires
        // after the app is closed. BackgroundService keeps the chain going.
        PrayerNotifier.schedule(_calculator, _location);
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
