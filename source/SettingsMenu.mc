using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;

// On-watch quick-settings menu. Entered via the watch's Menu button.
// v1.0 carries only the Asr-method toggle (Hanafi <-> Standard) since
// the full settings surface (city, offsets, pre-alert) is comfortably
// edited via Garmin Connect Mobile, and the watch's vertical list
// is awkward for a 16-city dropdown.
class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({
            :title => WatchUi.loadResource(Rez.Strings.SettingsTitle)
        });
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingAsr),
            _asrSubLabel(),
            :asr,
            null
        ));
    }

    function refreshAsrSubLabel() as Void {
        var item = getItem(0);
        if (item != null) {
            item.setSubLabel(_asrSubLabel());
        }
    }

    function _asrSubLabel() as Lang.String {
        var key = (Settings.asrFactor() == 2)
            ? Rez.Strings.AsrHanafi
            : Rez.Strings.AsrStandard;
        return WatchUi.loadResource(key);
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    var _menu;

    function initialize(menu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item) as Void {
        if (item.getId() == :asr) {
            var current = Settings.asrFactor();
            Application.Properties.setValue("asrFactor", current == 2 ? 1 : 2);
            // Properties.setValue does NOT auto-fire onSettingsChanged
            // (that is GCM-only). Push the change through manually.
            var app = Application.getApp();
            if (app != null && app has :onSettingsChanged) {
                app.onSettingsChanged();
            }
            _menu.refreshAsrSubLabel();
            WatchUi.requestUpdate();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
