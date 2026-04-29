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
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new NamazView(_calculator, _location);
        var delegate = new NamazDelegate(view);
        return [view, delegate];
    }
}
