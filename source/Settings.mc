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
    const VERSION = "1.8.0";

    // "kk" / "ru" / "en" — falls back to the system Rez locale when user
    // chose "auto" or never opened settings.
    // Returns "kk" / "ru" / "en". Works in app, glance, and background
    // scopes — uses System.getDeviceSettings (Rez is unavailable in
    // glance/background binaries).
    function language() {
        var idx = langIdx();
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

    // 0 = auto, 1 = kk, 2 = ru, 3 = en.
    function langIdx() {
        var idx = intProp("langIdx");
        return (idx < 0 || idx > 3) ? 0 : idx;
    }

    // Pickable places: the big 16 in Cities.all(), then CityIndex.DATA.
    // Mirrors CityIndex.count() (asserted in a test) because the background
    // process must not load the big table.
    const CITY_COUNT = 89;

    // Index into the city list, or -1 = auto (GPS / cache / fallback).
    function manualCityIdx() {
        var idx = intProp("manualCityIdx");
        if (Application.Properties.getValue("manualCityIdx") == null) { idx = -1; }
        return (idx < 0 || idx >= CITY_COUNT) ? -1 : idx;
    }

    // Background-safe: the big 16 resolve through Cities; any other place
    // is only kept if the foreground stored its coordinates (CityIndex.sync).
    function applyToLocator(locator) {
        var idx = manualCityIdx();
        var big = Cities.all();
        if (idx < 0) {
            locator.setManualCity(null);
        } else if (idx < big.size()) {
            locator.setManualCity(big[idx][:id]);
        } else {
            locator.keepManualPoint(idx);
        }
    }

    function prealertFajrMinutes() {
        return intProp("prealertFajr");
    }

    function prealertOtherMinutes() {
        return intProp("prealertOther");
    }

    // Minutes before the time of Fajr (sunrise) and Asr (sunset) runs out
    // at which to warn; 0 = off.
    function endWarnMinutes() {
        return intProp("endWarn");
    }

    // 0 = Ramadan mode switches on by itself in the Hijri month Ramadan,
    // 1 = never.
    function ramadanMode() {
        return intProp("ramadanMode") == 1 ? 1 : 0;
    }

    // Days to shift the Hijri date (-2..+2): ҚМДБ announces the month
    // start by moon sighting, so it can differ from Umm al-Qura by a day.
    function hijriAdjust() {
        var v = intProp("hijriAdjust");
        return (v < -2) ? -2 : ((v > 2) ? 2 : v);
    }

    function themeIdx() {
        var v = Application.Properties.getValue("themeIdx");
        if (v == null) { return 0; }
        var idx = v.toNumber();
        if (idx < 0 || idx > 2) { return 0; }
        return idx;
    }

    // Returns the per-prayer offset dictionary in the shape
    // PrayerCalculator expects: { :fajr => Number, ... } in minutes.
    function userOffsets() {
        return {
            :fajr    => intProp("offsetFajr"),
            :sunrise => intProp("offsetSunrise"),
            :dhuhr   => intProp("offsetDhuhr"),
            :asr     => intProp("offsetAsr"),
            :maghrib => intProp("offsetMaghrib"),
            :isha    => intProp("offsetIsha")
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

    function intProp(key) {
        var v = Application.Properties.getValue(key);
        if (v == null) { return 0; }
        return v.toNumber();
    }
}
