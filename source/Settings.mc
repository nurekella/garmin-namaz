using Toybox.Application;
using Toybox.Lang;
using Toybox.System;

// Reads user preferences from Application.Properties (managed via
// Garmin Connect Mobile / Settings on watch) and projects them onto
// the calculator + locator at app start and on every settings push.
//
// Only one consumer (NamazApp) calls this — keeps the policy in one
// place so the View / Notifier / Background-service all see the same
// applied configuration.
(:background, :glance)
module Settings {

    // Hardcoded mirror of manifest.xml version="..." — Connect IQ doesn't
    // expose manifest values at runtime, so the on-watch settings menu
    // shows this constant. Bump in lockstep with the manifest.
    const VERSION = "1.6.0";

    // "kk" / "ru" / "en" — falls back to the system Rez locale when user
    // chose "auto" or never opened settings.
    // Returns "kk" / "ru" / "en". Works in app, glance, and background
    // scopes — uses System.getDeviceSettings (Rez is unavailable in
    // glance/background binaries).
    function language() {
        var v = Application.Properties.getValue("langIdx");
        var idx = (v == null) ? 0 : v.toNumber();
        if (idx == 1) { return "kk"; }
        if (idx == 2) { return "ru"; }
        if (idx == 3) { return "en"; }
        // Auto — resolve from system locale.
        var sys = System.getDeviceSettings().systemLanguage;
        if (System has :LANGUAGE_KAZ && sys == System.LANGUAGE_KAZ) { return "kk"; }
        if (System has :LANGUAGE_RUS && sys == System.LANGUAGE_RUS) { return "ru"; }
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

    function prealertFajrMinutes() {
        var v = Application.Properties.getValue("prealertFajr");
        if (v == null) { return prealertMinutes(); }   // legacy fallback
        return v.toNumber();
    }

    function prealertOtherMinutes() {
        var v = Application.Properties.getValue("prealertOther");
        if (v == null) { return prealertMinutes(); }
        return v.toNumber();
    }

    function vibePatternIdx() {
        var v = Application.Properties.getValue("vibePattern");
        if (v == null) { return 0; }
        return v.toNumber();
    }

    function themeIdx() {
        var v = Application.Properties.getValue("themeIdx");
        if (v == null) { return 0; }
        var idx = v.toNumber();
        if (idx < 0 || idx > 3) { return 0; }
        return idx;
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

    function methodId() {
        var v = Application.Properties.getValue("methodIdx");
        var idx = (v == null) ? 0 : v.toNumber();
        if (idx < 0 || idx >= Methods.IDS.size()) { return "DUMK"; }
        return Methods.IDS[idx];
    }

    function notificationsEnabled() {
        var v = Application.Properties.getValue("notify");
        if (v == null) { return true; }
        return v;
    }

    // Builds a PrayerCalculator from the user's chosen method + Asr factor
    // + per-prayer offsets.
    function buildCalculator() {
        return new PrayerCalculator(
            Methods.paramsFor(methodId()),
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
