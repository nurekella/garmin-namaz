using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

// Reads user preferences from Application.Properties (managed via
// Garmin Connect Mobile / Settings on watch) and projects them onto
// the calculator + locator at app start and on every settings push.
//
// Only one consumer (NamazApp) calls this — keeps the policy in one
// place so the View / Notifier / Background-service all see the same
// applied configuration.
(:background, :glance)
module Settings {

    // "kk" / "ru" / "en" — falls back to the system Rez locale when user
    // chose "auto" or never opened settings.
    function language() {
        var v = Application.Properties.getValue("langIdx");
        var idx = (v == null) ? 0 : v.toNumber();
        if (idx == 1) { return "kk"; }
        if (idx == 2) { return "ru"; }
        if (idx == 3) { return "en"; }
        // 0 / unknown -> system locale via Rez.
        var sys = WatchUi.loadResource(Rez.Strings.LangCode);
        if (sys != null && (sys.equals("kk") || sys.equals("ru") || sys.equals("en"))) {
            return sys;
        }
        return "en";
    }

    function asrFactor() {
        var v = Application.Properties.getValue("asrFactor");
        return (v == 1) ? 1 : 2;
    }

    // -1 (or out-of-range) means auto-resolve via GPS / cache / fallback.
    function manualCityId() {
        var v = Application.Properties.getValue("manualCityIdx");
        if (v == null) { return null; }
        var idx = v.toNumber();
        if (idx < 0 || idx >= Cities.all().size()) { return null; }
        return Cities.all()[idx][:id];
    }

    function prealertMinutes() {
        var v = Application.Properties.getValue("prealertMin");
        if (v == null) { return 0; }
        return v.toNumber();
    }

    // Returns the per-prayer offset dictionary in the shape
    // PrayerCalculator expects: { :fajr => Number, ... } in minutes.
    function userOffsets() {
        return {
            :fajr    => _intProp("offsetFajr"),
            :sunrise => _intProp("offsetSunrise"),
            :dhuhr   => _intProp("offsetDhuhr"),
            :asr     => _intProp("offsetAsr"),
            :maghrib => _intProp("offsetMaghrib"),
            :isha    => _intProp("offsetIsha")
        };
    }

    // Builds a PrayerCalculator with the current method (DUMK) and
    // user-overridable Asr factor + per-prayer offsets.
    function buildCalculator() {
        return new PrayerCalculator(
            DumkMethod.params(),
            asrFactor(),
            userOffsets()
        );
    }

    // Pushes the manual-city pref into the locator. Empty / null -> auto.
    function applyToLocator(locator) {
        var id = manualCityId();
        locator.setManualCity(id);  // setManualCity(null) clears
    }

    function _intProp(key) {
        var v = Application.Properties.getValue(key);
        if (v == null) { return 0; }
        return v.toNumber();
    }
}
