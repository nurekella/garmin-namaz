using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Background;
using Toybox.Time;
using Toybox.Time.Gregorian;

// On-watch settings menu (MENU / long-press UP). Everything that exists in
// the Garmin Connect phone app is also here: plenty of people never open
// the phone app. Labels come from PrayerNames.pick so they follow the
// in-app language override; each item is addressed by id, so refresh() can
// relabel everything after a change (including a language switch).
//
// Settings are written to Application.Properties; the app re-applies via
// onSettingsChanged().
class SettingsMenu extends WatchUi.Menu2 {

    static const ITEMS = [:city, :method, :asr, :notify, :prealert, :endWarn,
                          :fasts, :jumuah, :ramadan, :hijri, :extraCard,
                          :theme, :lang, :offsets, :testNotify, :diag, :version];

    var _testSub = null;   // sub-label shown after "Test notification"

    function initialize() {
        Menu2.initialize({ :title => PrayerNames.menu(_title()) });
        for (var i = 0; i < ITEMS.size(); i++) {
            addItem(SettingsMenu.item(_label(ITEMS[i]), _sub(ITEMS[i]), ITEMS[i], null));
        }
    }

    function refresh() as Void {
        setTitle(PrayerNames.menu(_title()));
        for (var i = 0; i < ITEMS.size(); i++) {
            var item = getItem(findItemById(ITEMS[i]));
            item.setLabel(PrayerNames.menu(_label(ITEMS[i])));
            item.setSubLabel(PrayerNames.menu(_sub(ITEMS[i])));
        }
    }

    // fgOk: the instant notification was accepted; bgOk: the one in 5 min
    // was scheduled.
    function setTestResult(fgOk, bgOk) as Void {
        var err = PrayerNames.pick("қате", "ошибка", "failed");
        _testSub = PrayerNames.pick("қазір ", "сейчас ", "now ") + (fgOk ? "OK" : err)
                 + ", " + PrayerNames.pick("5 мин: ", "5 мин: ", "5 min: ") + (bgOk ? "OK" : err);
        refresh();
    }

    // "next 13:05 · bg 12:00 · <error>": what is armed, when the background
    // service last ran, and what it last threw. For reading off a real watch.
    static function diagLine() {
        var parts = "> ";
        var reg = Background.getTemporalEventRegisteredTime();
        if (reg == null) {
            parts += "--";
        } else if (reg instanceof Time.Moment) {
            parts += _clock(reg);
        } else {
            parts += "+" + (reg.value() / 60) + "m";
        }
        var run = Application.Storage.getValue(PrayerNotifier.STORAGE_KEY_BG_RUN);
        parts += " | bg " + ((run != null) ? _clock(new Time.Moment(run)) : "--");
        var err = Application.Storage.getValue(PrayerNotifier.STORAGE_KEY_BG_ERR);
        if (err == null) { err = PrayerNotifier.getLastError(); }
        if (err != null) { parts += " | " + err; }
        return parts;
    }

    // "13 14:05" (day of month + time).
    static function _clock(moment) {
        var i = Gregorian.info(moment, Time.FORMAT_SHORT);
        return i.day + " " + i.hour + ":" + ((i.min < 10) ? "0" : "") + i.min;
    }

    function _title() {
        return PrayerNames.pick("Баптаулар", "Настройки", "Settings");
    }

    function _label(id) {
        var p = PrayerNames;
        if (id == :city)       { return p.pick("Қала", "Город", "City"); }
        if (id == :method)     { return p.pick("Әдіс", "Метод", "Method"); }
        if (id == :asr)        { return p.nameOf(:asr); }
        if (id == :notify)     { return p.pick("Хабарламалар", "Уведомления", "Notifications"); }
        if (id == :prealert)   { return p.pick("Алдын ала", "Заранее", "Pre-alert"); }
        if (id == :endWarn)    { return p.pick("Уақыт аяқталуы", "Конец времени", "Time ending"); }
        if (id == :fasts)      { return p.pick("Ораза және мереке", "Посты и праздники", "Fasts & holidays"); }
        if (id == :jumuah)     { return p.pick("Жұма ескертуі", "Напоминание о Джума", "Jumu'ah reminder"); }
        if (id == :extraCard)  { return p.pick("Духа / Таһажжуд", "Духа / Тахаджуд", "Duha / Tahajjud"); }
        if (id == :ramadan)    { return p.pick("Рамазан режимі", "Режим Рамадана", "Ramadan mode"); }
        if (id == :hijri)      { return p.pick("Хижра түзетуі", "Поправка хиджры", "Hijri adjust"); }
        if (id == :testNotify) { return p.pick("Хабарламаны тексеру", "Проверить уведомление", "Test notification"); }
        if (id == :diag)       { return p.pick("Диагностика", "Диагностика", "Diagnostics"); }
        if (id == :offsets)    { return p.pick("Түзетулер", "Поправки", "Offsets"); }
        if (id == :lang)       { return p.pick("Тіл", "Язык", "Language"); }
        if (id == :theme)      { return p.pick("Түс", "Цвет", "Theme"); }
        return p.pick("Нұсқа", "Версия", "Version");
    }

    function _sub(id) {
        var p = PrayerNames;
        if (id == :city) {
            var idx = Settings.manualCityIdx();
            if (idx < 0) { return autoLabel() + " (GPS)"; }
            return Cities.localizedName(CityIndex.at(idx), Settings.language());
        }
        if (id == :method) {
            var v = Application.Properties.getValue("methodIdx");
            var idx = (v == null) ? 0 : v.toNumber();
            if (idx < 0 || idx >= Methods.LABELS.size()) { idx = 0; }
            return Methods.LABELS[idx];
        }
        if (id == :asr)      { return asrLabel(Settings.asrFactor()); }
        if (id == :notify)   { return onOff(Settings.notificationsEnabled()); }
        if (id == :prealert) { return minutesLabel(Settings.prealertOtherMinutes()); }
        if (id == :endWarn)  { return minutesLabel(Settings.endWarnMinutes()); }
        if (id == :fasts)    { return onOff(Settings.remindFasts() == 1); }
        if (id == :jumuah)   { return minutesLabel(Settings.jumuahBefore()); }
        if (id == :extraCard) { return onOff(Settings.extraCard() == 1); }
        if (id == :ramadan)  { return (Settings.ramadanMode() == 0) ? autoLabel() : offLabel(); }
        if (id == :hijri) {
            var a = Settings.hijriAdjust();
            return (a > 0) ? "+" + a : "" + a;
        }
        if (id == :testNotify) { return _testSub; }
        if (id == :diag)       { return diagLine(); }
        if (id == :lang)     { return LangPickerMenu.entry(Settings.langIdx()); }
        if (id == :theme)    { return ThemePickerMenu.label(Settings.themeIdx()); }
        if (id == :version)  { return Settings.VERSION; }
        return null;
    }

    static function onOff(on) {
        return on ? PrayerNames.pick("Қосулы", "Вкл", "On") : offLabel();
    }

    // A menu row whose text is safe for the system font (see PrayerNames.safe).
    static function item(label, sub, id, options) {
        return new WatchUi.MenuItem(PrayerNames.menu(label), PrayerNames.menu(sub), id, options);
    }

    static function offLabel() {
        return PrayerNames.pick("Өшірулі", "Выкл", "Off");
    }

    static function autoLabel() {
        return PrayerNames.pick("Авто", "Авто", "Auto");
    }

    // 0 -> "Off", 15 -> "15 min".
    static function minutesLabel(m) {
        return (m <= 0) ? offLabel() : m + " " + PrayerNames.pick("мин", "мин", "min");
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
        if (id == :city) {
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
        } else if (id == :endWarn) {
            // cycle 0 -> 10 -> 20 -> 30 -> 0 minutes before Fajr / Asr run out
            var cur = Settings.endWarnMinutes();
            Application.Properties.setValue("endWarn", (cur >= 30) ? 0 : (cur / 10 + 1) * 10);
            _applyAndRefresh();
        } else if (id == :fasts) {
            Application.Properties.setValue("remindFasts", (Settings.remindFasts() == 1) ? 0 : 1);
            _applyAndRefresh();
        } else if (id == :jumuah) {
            // cycle Off -> 30 -> 60 -> Off minutes before Dhuhr on Fridays
            var cur = Settings.jumuahBefore();
            Application.Properties.setValue("jumuahBefore", (cur >= 60) ? 0 : cur + 30);
            _applyAndRefresh();
        } else if (id == :extraCard) {
            Application.Properties.setValue("extraCard", (Settings.extraCard() == 1) ? 0 : 1);
            _applyAndRefresh();
        } else if (id == :ramadan) {
            Application.Properties.setValue("ramadanMode", (Settings.ramadanMode() == 0) ? 1 : 0);
            _applyAndRefresh();
        } else if (id == :hijri) {
            var a = Settings.hijriAdjust() + 1;
            Application.Properties.setValue("hijriAdjust", (a > 2) ? -2 : a);
            _applyAndRefresh();
        } else if (id == :testNotify) {
            var fg = PrayerNotifier.notifyForeground();
            _menu.setTestResult(fg, PrayerNotifier.scheduleTest());
        } else if (id == :diag) {
            // Re-arm from scratch and show the fresh state.
            _applyAndRefresh();
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

// Auto, then the 16 big cities, then every other place alphabetically.
class CityPickerMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => PrayerNames.menu(PrayerNames.pick("Қала", "Город", "City")) });
        var cur = Settings.manualCityIdx();
        addItem(SettingsMenu.item(SettingsMenu.autoLabel() + " (GPS)", mark(cur < 0), -1, null));
        var lang = Settings.language();
        for (var i = 0; i < CityIndex.count(); i++) {
            addItem(SettingsMenu.item(
                Cities.localizedName(CityIndex.at(i), lang), mark(cur == i), i, null));
        }
        if (cur >= 0) { setFocus(cur + 1); }
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
        Menu2.initialize({ :title => PrayerNames.menu(PrayerNames.pick("Әдіс", "Метод", "Method")) });
        var v = Application.Properties.getValue("methodIdx");
        var cur = (v == null) ? 0 : v.toNumber();
        for (var i = 0; i < Methods.LABELS.size(); i++) {
            addItem(SettingsMenu.item(Methods.LABELS[i], mark(cur == i), i, null));
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
        Menu2.initialize({ :title => PrayerNames.menu(PrayerNames.nameOf(:asr)) });
        var cur = Settings.asrFactor();
        addItem(SettingsMenu.item(SettingsMenu.asrLabel(1), mark(cur == 1), 1, null));
        addItem(SettingsMenu.item(SettingsMenu.asrLabel(2), mark(cur == 2), 2, null));
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
    // 1 = Kazakh in Cyrillic on the app screens (menus still Latin),
    // 4 = Kazakh in the Latin alphabet everywhere.
    static const ENTRIES = ["Auto", "Қазақша", "Русский", "English", "Kazakh (Latin)"];

    // A language name as written in that language: never transliterated.
    static function entry(idx) {
        return (idx == 1) ? "Kazakh" : ENTRIES[idx];
    }

    function initialize() {
        Menu2.initialize({ :title => PrayerNames.menu(PrayerNames.pick("Тіл", "Язык", "Language")) });
        var cur = Settings.langIdx();
        for (var i = 0; i < ENTRIES.size(); i++) {
            addItem(new WatchUi.MenuItem(entry(i), PrayerNames.menu(mark(cur == i)), i, null));
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
        return PrayerNames.pick("Қола", "Бронза", "Bronze");
    }
    function initialize() {
        Menu2.initialize({ :title => PrayerNames.menu(PrayerNames.pick("Түс", "Цвет", "Theme")) });
        var cur = Settings.themeIdx();
        for (var i = 0; i < 3; i++) {
            addItem(SettingsMenu.item(label(i), mark(cur == i), i, null));
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
        Menu2.initialize({ :title => PrayerNames.menu(PrayerNames.pick("Түзетулер", "Поправки", "Offsets")) });
        for (var i = 0; i < PRAYERS.size(); i++) {
            addItem(SettingsMenu.item(PrayerNames.nameOf(PRAYERS[i][0]),
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
