using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Lang;

class NamazApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new NamazView(), new NamazDelegate()];
    }
}
