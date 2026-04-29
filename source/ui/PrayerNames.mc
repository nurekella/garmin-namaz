using Toybox.WatchUi;
using Toybox.Lang;

// Localised display names for prayers and supporting labels.
//
// Resolution goes through Rez.Strings so the platform's locale picker
// (strings.xml -> strings-rus.xml -> strings-kaz.xml) does the work,
// and we don't have to depend on System.LANGUAGE_* constants which
// vary between API levels.
//
// Watch-app only — glance / background binaries can't link Rez at
// runtime ("Could not access symbol 'Rez'", non-catchable). Those
// contexts hardcode English inline (see GlanceView, BackgroundService).
module PrayerNames {

    function language() {
        return WatchUi.loadResource(Rez.Strings.LangCode);
    }

    function nameOf(prayerSym) {
        if (prayerSym == :fajr)    { return WatchUi.loadResource(Rez.Strings.PrayerFajr); }
        if (prayerSym == :sunrise) { return WatchUi.loadResource(Rez.Strings.PrayerSunrise); }
        if (prayerSym == :dhuhr)   { return WatchUi.loadResource(Rez.Strings.PrayerDhuhr); }
        if (prayerSym == :asr)     { return WatchUi.loadResource(Rez.Strings.PrayerAsr); }
        if (prayerSym == :maghrib) { return WatchUi.loadResource(Rez.Strings.PrayerMaghrib); }
        if (prayerSym == :isha)    { return WatchUi.loadResource(Rez.Strings.PrayerIsha); }
        return "";
    }

    function nextLabel() {
        return WatchUi.loadResource(Rez.Strings.NextPrayer);
    }

    function prayerTimeLabel() {
        return WatchUi.loadResource(Rez.Strings.PrayerTime);
    }

    function gpsSearching() {
        return WatchUi.loadResource(Rez.Strings.GpsSearching);
    }

    function monthShort(month) {
        if (month < 1 || month > 12) { return ""; }
        var ids = [
            Rez.Strings.MonthJan, Rez.Strings.MonthFeb, Rez.Strings.MonthMar,
            Rez.Strings.MonthApr, Rez.Strings.MonthMay, Rez.Strings.MonthJun,
            Rez.Strings.MonthJul, Rez.Strings.MonthAug, Rez.Strings.MonthSep,
            Rez.Strings.MonthOct, Rez.Strings.MonthNov, Rez.Strings.MonthDec
        ];
        return WatchUi.loadResource(ids[month - 1]);
    }
}
