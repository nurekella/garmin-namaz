using Toybox.WatchUi;
using Toybox.Application;
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

    // UP — push the minimal/hero view (one prayer, big numbers).
    function onPreviousPage() as Lang.Boolean {
        if (_view != null) {
            var app = Application.getApp();
            var calc = app._calculator;
            var loc = app._location;
            WatchUi.pushView(new MinimalView(calc, loc),
                             new MinimalDelegate(),
                             WatchUi.SLIDE_LEFT);
        }
        return true;
    }

    // DOWN — toggle between today and tomorrow's schedule.
    function onNextPage() as Lang.Boolean {
        if (_view != null) {
            _view.toggleTomorrow();
        }
        return true;
    }

    // Touchscreen tap — toggle countdown HH:MM:SS <-> "NN min".
    // (Untyped param: some firmwares pass non-ClickEvent objects.)
    function onTap(clickEvent) as Lang.Boolean {
        if (_view != null) {
            _view.toggleMinutes();
        }
        return true;
    }

    // Fallback for devices where DOWN doesn't bubble through onNextPage,
    // or where the touchscreen event isn't reaching onTap. LIGHT is rarely
    // bound by the system in app context.
    function onKey(keyEvent) as Lang.Boolean {
        if (keyEvent == null || _view == null) { return false; }
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            _view.toggleTomorrow();
            return true;
        }
        if (key == WatchUi.KEY_LIGHT) {
            _view.toggleMinutes();
            return true;
        }
        return false;
    }
}
