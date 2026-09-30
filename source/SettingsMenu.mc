using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;

// On-watch settings menu (MENU / long-press UP). Labels come from
// PrayerNames.pick so they follow the in-app language override; each
// item is addressed by id, so refresh() can relabel everything after a
// change (including a language switch).
//
// Settings are written to Application.Properties; the app re-applies via
// onSettingsChanged().
class SettingsMenu extends WatchUi.Menu2 {

    static const ITEMS = [:qibla, :city, :method, :asr, :notify, :prealert,
                          :testNotify, :offsets, :lang, :theme, :version];

    var _testSub = null;   // sub-label shown after "Test notification"

    function initialize() {
        Menu2.initialize({ :title => _title() });
        for (var i = 0; i < ITEMS.size(); i++) {
            addItem(new WatchUi.MenuItem(_label(ITEMS[i]), _sub(ITEMS[i]), ITEMS[i], null));
        }
    }

    function refresh() as Void {
        setTitle(_title());
        for (var i = 0; i < ITEMS.size(); i++) {
            var item = getItem(findItemById(ITEMS[i]));
            item.setLabel(_label(ITEMS[i]));
            item.setSubLabel(_sub(ITEMS[i]));
        }
    }

    function setTestResult(ok) as Void {
        _testSub = ok ? PrayerNames.pick("5 минуттан кейін", "через 5 мин", "in 5 min")
                      : PrayerNames.pick("Қате", "Ошибка", "Failed");
        refresh();
    }

    function _title() {
        return PrayerNames.pick("Баптаулар", "Настройки", "Settings");
    }

    function _label(id) {
        var p = PrayerNames;
        if (id == :qibla)      { return p.pick("Құбыла", "Кибла", "Qibla"); }
        if (id == :city)       { return p.pick("Қала", "Город", "City"); }
        if (id == :method)     { return p.pick("Әдіс", "Метод", "Method"); }
        if (id == :asr)        { return p.nameOf(:asr); }
        if (id == :notify)     { return p.pick("Хабарламалар", "Уведомления", "Notifications"); }
        if (id == :prealert)   { return p.pick("Алдын ала", "Заранее", "Pre-alert"); }
        if (id == :testNotify) { return p.pick("Хабарламаны тексеру", "Проверить уведомление", "Test notification"); }
        if (id == :offsets)    { return p.pick("Түзетулер", "Поправки", "Offsets"); }
        if (id == :lang)       { return p.pick("Тіл", "Язык", "Language"); }
        if (id == :theme)      { return p.pick("Түс", "Цвет", "Theme"); }
        return p.pick("Нұсқа", "Версия", "Version");
    }

    function _sub(id) {
        var p = PrayerNames;
        if (id == :city) {
            var idx = Settings.manualCityIdx();
            if (idx < 0) { return autoCityLabel(); }
            return Cities.localizedName(Cities.all()[idx], Settings.language());
        }
        if (id == :method) {
            var v = Application.Properties.getValue("methodIdx");
            var idx = (v == null) ? 0 : v.toNumber();
            if (idx < 0 || idx >= Methods.LABELS.size()) { idx = 0; }
            return Methods.LABELS[idx];
        }
        if (id == :asr)      { return asrLabel(Settings.asrFactor()); }
        if (id == :notify)   { return Settings.notificationsEnabled() ? p.pick("Қосулы", "Вкл", "On") : offLabel(); }
        if (id == :prealert) {
            var m = Settings.prealertOtherMinutes();
            return (m <= 0) ? offLabel() : m + " " + p.pick("мин", "мин", "min");
        }
        if (id == :testNotify) { return _testSub; }
        if (id == :lang)     { return LangPickerMenu.ENTRIES[Settings.langIdx()]; }
        if (id == :theme)    { return ThemePickerMenu.label(Settings.themeIdx()); }
        if (id == :version)  { return Settings.VERSION; }
        return null;
    }

    static function offLabel() {
        return PrayerNames.pick("Өшірулі", "Выкл", "Off");
    }

    static function autoCityLabel() {
        return PrayerNames.pick("Авто (GPS)", "Авто (GPS)", "Auto (GPS)");
    }

    static function asrLabel(factor) {
        return (factor == 2) ? PrayerNames.pick("Ханафи", "Ханафи", "Hanafi")
                             : PrayerNames.pick("Стандарт", "Стандарт", "Standard");
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
        if (id == :qibla) {
            WatchUi.pushView(new QiblaView(), new QiblaDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :city) {
            WatchUi.pushView(new CityPickerMenu(), new CityPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :method) {
            WatchUi.pushView(new MethodPickerMenu(), new MethodPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :asr) {
            WatchUi.pushView(new AsrPickerMenu(), new AsrPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :notify) {
            Application.Properties.setValue("notify", !Settings.notificationsEnabled());
            _applyAndRefresh();
        } else if (id == :prealert) {
            // cycle 0 -> 5 -> 10 -> 15 -> 0, applied to all prayers;
            // per-prayer fine-tuning lives in the Connect app settings.
            var cur = Settings.prealertOtherMinutes();
            var next = (cur >= 15) ? 0 : (cur / 5 + 1) * 5;
            Application.Properties.setValue("prealertFajr", next);
            Application.Properties.setValue("prealertOther", next);
            _applyAndRefresh();
        } else if (id == :testNotify) {
            _menu.setTestResult(PrayerNotifier.scheduleTest());
        } else if (id == :offsets) {
            var menu = new OffsetsMenu();
            WatchUi.pushView(menu, new OffsetsDelegate(menu), WatchUi.SLIDE_LEFT);
        } else if (id == :lang) {
            WatchUi.pushView(new LangPickerMenu(), new LangPickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        } else if (id == :theme) {
            WatchUi.pushView(new ThemePickerMenu(), new ThemePickerDelegate(_menu), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function _applyAndRefresh() as Void {
        Application.getApp().onSettingsChanged();
        _menu.refresh();
        WatchUi.requestUpdate();
    }
}

// ---- Pickers -----------------------------------------------------------
// Each picker writes one property, re-applies settings, refreshes the
// parent menu and pops itself.

function applyPicked(key, value, parent) as Void {
    Application.Properties.setValue(key, value);
    Application.getApp().onSettingsChanged();
    parent.refresh();
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
}

// "*" marks the current choice.
function mark(isCurrent) {
    return isCurrent ? "*" : null;
}

class CityPickerMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => PrayerNames.pick("Қала", "Город", "City") });
        var cur = Settings.manualCityIdx();
        addItem(new WatchUi.MenuItem(SettingsMenu.autoCityLabel(), mark(cur < 0), -1, null));
        var cities = Cities.all();
        for (var i = 0; i < cities.size(); i++) {
            addItem(new WatchUi.MenuItem(
                Cities.localizedName(cities[i], Settings.language()), mark(cur == i), i, null));
        }
    }
}

class CityPickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void { applyPicked("manualCityIdx", item.getId(), _parent); }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class MethodPickerMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => PrayerNames.pick("Әдіс", "Метод", "Method") });
        var v = Application.Properties.getValue("methodIdx");
        var cur = (v == null) ? 0 : v.toNumber();
        for (var i = 0; i < Methods.LABELS.size(); i++) {
            addItem(new WatchUi.MenuItem(Methods.LABELS[i], mark(cur == i), i, null));
        }
    }
}

class MethodPickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void { applyPicked("methodIdx", item.getId(), _parent); }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class AsrPickerMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => PrayerNames.nameOf(:asr) });
        var cur = Settings.asrFactor();
        addItem(new WatchUi.MenuItem(SettingsMenu.asrLabel(1), mark(cur == 1), 1, null));
        addItem(new WatchUi.MenuItem(SettingsMenu.asrLabel(2), mark(cur == 2), 2, null));
    }
}

class AsrPickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void { applyPicked("asrFactor", item.getId(), _parent); }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class LangPickerMenu extends WatchUi.Menu2 {
    // Index = langIdx property. Language names in their own language.
    static const ENTRIES = ["Auto", "Қазақша", "Русский", "English"];
    function initialize() {
        Menu2.initialize({ :title => PrayerNames.pick("Тіл", "Язык", "Language") });
        var cur = Settings.langIdx();
        for (var i = 0; i < ENTRIES.size(); i++) {
            addItem(new WatchUi.MenuItem(ENTRIES[i], mark(cur == i), i, null));
        }
    }
}

class LangPickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void { applyPicked("langIdx", item.getId(), _parent); }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class ThemePickerMenu extends WatchUi.Menu2 {
    static function label(idx) {
        if (idx == 1) { return PrayerNames.pick("Жалбыз", "Мята", "Mint"); }
        if (idx == 2) { return PrayerNames.pick("Аспан", "Небо", "Sky"); }
        if (idx == 3) { return PrayerNames.pick("Моно", "Моно", "Mono"); }
        return PrayerNames.pick("Қола", "Бронза", "Bronze");
    }
    function initialize() {
        Menu2.initialize({ :title => PrayerNames.pick("Түс", "Цвет", "Theme") });
        var cur = Settings.themeIdx();
        for (var i = 0; i < 4; i++) {
            addItem(new WatchUi.MenuItem(label(i), mark(cur == i), i, null));
        }
    }
}

class ThemePickerDelegate extends WatchUi.Menu2InputDelegate {
    var _parent;
    function initialize(parent) { Menu2InputDelegate.initialize(); _parent = parent; }
    function onSelect(item) as Void { applyPicked("themeIdx", item.getId(), _parent); }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

// ---- Per-prayer offsets (each select cycles -9..+9) --------------------

class OffsetsMenu extends WatchUi.Menu2 {

    static const PRAYERS = [
        [:fajr,    "offsetFajr"],
        [:sunrise, "offsetSunrise"],
        [:dhuhr,   "offsetDhuhr"],
        [:asr,     "offsetAsr"],
        [:maghrib, "offsetMaghrib"],
        [:isha,    "offsetIsha"]
    ];

    function initialize() {
        Menu2.initialize({ :title => PrayerNames.pick("Түзетулер", "Поправки", "Offsets") });
        for (var i = 0; i < PRAYERS.size(); i++) {
            addItem(new WatchUi.MenuItem(PrayerNames.nameOf(PRAYERS[i][0]),
                _formatVal(Settings.intProp(PRAYERS[i][1])), i, null));
        }
    }

    function refreshSubLabels() as Void {
        for (var i = 0; i < PRAYERS.size(); i++) {
            getItem(i).setSubLabel(_formatVal(Settings.intProp(PRAYERS[i][1])));
        }
    }

    function _formatVal(v) as Lang.String {
        return (v > 0) ? "+" + v : "" + v;
    }
}

class OffsetsDelegate extends WatchUi.Menu2InputDelegate {

    var _menu;

    function initialize(menu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item) as Void {
        var key = OffsetsMenu.PRAYERS[item.getId() as Lang.Number][1];
        var v = Settings.intProp(key) + 1;
        if (v > 9) { v = -9; }
        Application.Properties.setValue(key, v);
        Application.getApp().onSettingsChanged();
        _menu.refreshSubLabels();
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
