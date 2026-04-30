using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;

// On-watch settings menu. Entered via the watch's Menu button (long-press UP).
// Surface (top-level Menu2):
//   Аср        — toggles Hanafi <-> Standard
//   Қала       — opens city picker (Auto + 16 cities)
//   Алдын-ала  — cycles Off / 5 / 10 / 15 minutes
//   Offset     — opens per-prayer offset submenu (each cycles -9..+9)
//
// Settings are written to Application.Properties; the app re-applies via
// onSettingsChanged().
class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({
            :title => WatchUi.loadResource(Rez.Strings.SettingsTitle)
        });
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingAsr),
            _asrSubLabel(), :asr, null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingCity),
            _citySubLabel(), :city, null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingPreAlert),
            _prealertSubLabel(), :prealert, null));
        addItem(new WatchUi.MenuItem(
            "Method", _methodSubLabel(), :method, null));
        addItem(new WatchUi.MenuItem(
            "Notifications", _notifySubLabel(), :notify, null));
        addItem(new WatchUi.MenuItem(
            "Language", _langSubLabel(), :lang, null));
        addItem(new WatchUi.MenuItem(
            "Offset", "", :offsets, null));
    }

    function refreshSubLabels() as Void {
        var i;
        i = getItem(0); if (i != null) { i.setSubLabel(_asrSubLabel()); }
        i = getItem(1); if (i != null) { i.setSubLabel(_citySubLabel()); }
        i = getItem(2); if (i != null) { i.setSubLabel(_prealertSubLabel()); }
        i = getItem(3); if (i != null) { i.setSubLabel(_methodSubLabel()); }
        i = getItem(4); if (i != null) { i.setSubLabel(_notifySubLabel()); }
        i = getItem(5); if (i != null) { i.setSubLabel(_langSubLabel()); }
    }

    function _methodSubLabel() as Lang.String {
        var v = Application.Properties.getValue("methodIdx");
        var idx = (v == null) ? 0 : v.toNumber();
        if (idx < 0 || idx >= Methods.LABELS.size()) { idx = 0; }
        return Methods.LABELS[idx];
    }

    function _notifySubLabel() as Lang.String {
        return Settings.notificationsEnabled() ? "On" : "Off";
    }

    function _langSubLabel() as Lang.String {
        var v = Application.Properties.getValue("langIdx");
        var idx = (v == null) ? 0 : v.toNumber();
        if (idx == 1) { return "Қазақша"; }
        if (idx == 2) { return "Русский"; }
        if (idx == 3) { return "English"; }
        return "Auto";
    }

    function _asrSubLabel() as Lang.String {
        var key = (Settings.asrFactor() == 2) ? Rez.Strings.AsrHanafi : Rez.Strings.AsrStandard;
        return WatchUi.loadResource(key);
    }

    function _citySubLabel() as Lang.String {
        var idx = _cityIdx();
        if (idx < 0) {
            return WatchUi.loadResource(Rez.Strings.CityAuto);
        }
        var lang = WatchUi.loadResource(Rez.Strings.LangCode);
        return Cities.localizedName(Cities.all()[idx], lang);
    }

    function _prealertSubLabel() as Lang.String {
        var m = Settings.prealertMinutes();
        if (m <= 0) { return WatchUi.loadResource(Rez.Strings.Off); }
        return m + " " + WatchUi.loadResource(Rez.Strings.MinutesShort);
    }

    function _cityIdx() as Lang.Number {
        var v = Application.Properties.getValue("manualCityIdx");
        if (v == null) { return -1; }
        return v.toNumber();
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    var _menu;

    function initialize(menu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item) as Void {
        var id = item.getId();
        if (id == :asr) {
            var menu = new AsrPickerMenu();
            WatchUi.pushView(menu, new AsrPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :city) {
            var menu = new CityPickerMenu();
            WatchUi.pushView(menu, new CityPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :prealert) {
            // cycle 0 -> 5 -> 10 -> 15 -> 0
            var cur = Settings.prealertMinutes();
            var next = 0;
            if (cur == 0)      { next = 5; }
            else if (cur == 5) { next = 10; }
            else if (cur == 10) { next = 15; }
            else                { next = 0; }
            Application.Properties.setValue("prealertMin", next);
            _applyAndRefresh();
        } else if (id == :method) {
            var menu = new MethodPickerMenu();
            WatchUi.pushView(menu, new MethodPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :notify) {
            var cur = Settings.notificationsEnabled();
            Application.Properties.setValue("notify", !cur);
            _applyAndRefresh();
        } else if (id == :lang) {
            var menu = new LangPickerMenu();
            WatchUi.pushView(menu, new LangPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :offsets) {
            var menu = new OffsetsMenu();
            WatchUi.pushView(menu, new OffsetsDelegate(menu), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function _applyAndRefresh() as Void {
        var app = Application.getApp();
        if (app != null && app has :onSettingsChanged) {
            app.onSettingsChanged();
        }
        _menu.refreshSubLabels();
        WatchUi.requestUpdate();
    }
}

// ---- City picker -----------------------------------------------------

class CityPickerMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({
            :title => WatchUi.loadResource(Rez.Strings.SettingCity)
        });
        var lang = WatchUi.loadResource(Rez.Strings.LangCode);

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.CityAuto), null, :auto, null));

        var cities = Cities.all();
        for (var i = 0; i < cities.size(); i++) {
            addItem(new WatchUi.MenuItem(
                Cities.localizedName(cities[i], lang), null, i, null));
        }
    }
}

class CityPickerDelegate extends WatchUi.Menu2InputDelegate {

    var _parent;

    function initialize(parent) {
        Menu2InputDelegate.initialize();
        _parent = parent;
    }

    function onSelect(item) as Void {
        var id = item.getId();
        var idx;
        if (id == :auto) {
            idx = -1;
        } else if (id instanceof Lang.Number) {
            idx = id;
        } else {
            return;
        }
        Application.Properties.setValue("manualCityIdx", idx);
        var app = Application.getApp();
        if (app != null && app has :onSettingsChanged) {
            app.onSettingsChanged();
        }
        if (_parent != null && _parent has :refreshSubLabels) {
            _parent.refreshSubLabels();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ---- Per-prayer offset submenu ---------------------------------------

class OffsetsMenu extends WatchUi.Menu2 {

    static const PRAYERS = [
        [:fajr,    "offsetFajr",    Rez.Strings.OffsetFajr],
        [:sunrise, "offsetSunrise", Rez.Strings.OffsetSunrise],
        [:dhuhr,   "offsetDhuhr",   Rez.Strings.OffsetDhuhr],
        [:asr,     "offsetAsr",     Rez.Strings.OffsetAsr],
        [:maghrib, "offsetMaghrib", Rez.Strings.OffsetMaghrib],
        [:isha,    "offsetIsha",    Rez.Strings.OffsetIsha]
    ];

    function initialize() {
        Menu2.initialize({ :title => "Offset" });
        for (var i = 0; i < PRAYERS.size(); i++) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(PRAYERS[i][2]),
                _formatVal(_read(PRAYERS[i][1])),
                PRAYERS[i][0], null));
        }
    }

    function refreshSubLabels() as Void {
        for (var i = 0; i < PRAYERS.size(); i++) {
            var item = getItem(i);
            if (item != null) {
                item.setSubLabel(_formatVal(_read(PRAYERS[i][1])));
            }
        }
    }

    function _read(key) as Lang.Number {
        var v = Application.Properties.getValue(key);
        if (v == null) { return 0; }
        return v.toNumber();
    }

    function _formatVal(v) as Lang.String {
        if (v > 0) { return "+" + v; }
        return "" + v;
    }
}

class OffsetsDelegate extends WatchUi.Menu2InputDelegate {

    var _menu;

    function initialize(menu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item) as Void {
        var sym = item.getId();
        // Find prop key for this prayer.
        var key = null;
        for (var i = 0; i < OffsetsMenu.PRAYERS.size(); i++) {
            if (OffsetsMenu.PRAYERS[i][0] == sym) {
                key = OffsetsMenu.PRAYERS[i][1];
                break;
            }
        }
        if (key == null) { return; }

        // Cycle -9 .. +9 by +1, wrap.
        var v = Application.Properties.getValue(key);
        if (v == null) { v = 0; } else { v = v.toNumber(); }
        v += 1;
        if (v > 9) { v = -9; }
        Application.Properties.setValue(key, v);

        var app = Application.getApp();
        if (app != null && app has :onSettingsChanged) {
            app.onSettingsChanged();
        }
        _menu.refreshSubLabels();
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ---- Asr picker ------------------------------------------------------

class AsrPickerMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingAsr) });
        var cur = Settings.asrFactor();
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.AsrStandard),
            (cur == 1) ? "*" : null, 1, null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.AsrHanafi),
            (cur == 2) ? "*" : null, 2, null));
    }
}

class AsrPickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void {
        var id = item.getId();
        if (!(id instanceof Lang.Number)) { return; }
        Application.Properties.setValue("asrFactor", id);
        var app = Application.getApp();
        if (app != null && app has :onSettingsChanged) { app.onSettingsChanged(); }
        if (_parent != null && _parent has :refreshSubLabels) { _parent.refreshSubLabels(); }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

// ---- Language picker -------------------------------------------------

class LangPickerMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Language" });
        var v = Application.Properties.getValue("langIdx");
        var cur = (v == null) ? 0 : v.toNumber();
        var entries = [[0, "Auto"], [1, "Kazaksha"], [2, "Russian"], [3, "English"]];
        // overwrite with localised names
        entries[1][1] = "Қазақша";
        entries[2][1] = "Русский";
        for (var i = 0; i < entries.size(); i++) {
            addItem(new WatchUi.MenuItem(
                entries[i][1],
                (cur == entries[i][0]) ? "*" : null,
                entries[i][0], null));
        }
    }
}

class LangPickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void {
        var id = item.getId();
        if (!(id instanceof Lang.Number)) { return; }
        Application.Properties.setValue("langIdx", id);
        var app = Application.getApp();
        if (app != null && app has :onSettingsChanged) { app.onSettingsChanged(); }
        if (_parent != null && _parent has :refreshSubLabels) { _parent.refreshSubLabels(); }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

// ---- Method picker ---------------------------------------------------

class MethodPickerMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Method" });
        var v = Application.Properties.getValue("methodIdx");
        var cur = (v == null) ? 0 : v.toNumber();
        for (var i = 0; i < Methods.LABELS.size(); i++) {
            addItem(new WatchUi.MenuItem(
                Methods.LABELS[i],
                (cur == i) ? "*" : null,
                i, null));
        }
    }
}

class MethodPickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void {
        var id = item.getId();
        if (!(id instanceof Lang.Number)) { return; }
        Application.Properties.setValue("methodIdx", id);
        var app = Application.getApp();
        if (app != null && app has :onSettingsChanged) { app.onSettingsChanged(); }
        if (_parent != null && _parent has :refreshSubLabels) { _parent.refreshSubLabels(); }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}
