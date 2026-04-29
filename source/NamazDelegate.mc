using Toybox.WatchUi;

class NamazDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Lang.Boolean {
        return true;
    }

    function onBack() as Lang.Boolean {
        return false;
    }

    function onMenu() as Lang.Boolean {
        return true;
    }
}
