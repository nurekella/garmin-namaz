using Toybox.WatchUi;
using Toybox.Lang;

// Behaviour delegate for the main NamazView.
// v1.0 keystrokes:
//   Up / Down  — reserved for swiping between cities (Stage 11)
//   Select     — refresh (re-read GPS / cache, recompute schedule)
//   Menu       — open settings (wired in Stage 8)
//   Back       — exit app (default behaviour)
class NamazDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Lang.Boolean {
        if (_view != null) {
            _view.refresh();
        }
        return true;
    }

    function onMenu() as Lang.Boolean {
        var menu = new SettingsMenu();
        var delegate = new SettingsMenuDelegate(menu);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() as Lang.Boolean {
        return false;  // default: exit app
    }

    function onPreviousPage() as Lang.Boolean {
        return true;
    }

    function onNextPage() as Lang.Boolean {
        return true;
    }
}
