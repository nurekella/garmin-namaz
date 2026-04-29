using Toybox.Application;
using Toybox.WatchUi;

class NamazApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    function getInitialView() as Lang.Array? {
        return [new NamazView(), new NamazDelegate()] as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>;
    }
}
