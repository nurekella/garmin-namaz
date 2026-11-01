using Toybox.Complications;
using Toybox.Time;
using Toybox.Lang;

// Publishes the next prayer as a complication, so a watch face that has
// "Namaz" in one of its data slots shows e.g. "Dhuhr 13:05" without
// opening the app. Called whenever the schedule is recomputed: at app
// start, on settings changes and from the background service after every
// prayer alert, which is exactly when the "next prayer" changes.
//
// Labels stay Latin on purpose: watch-face fonts and Face It do not
// reliably draw Cyrillic.
(:background)
module FaceData {

    const STORAGE_KEY_ERR = "face_err";

    function publish(calc, loc) {
        if (!(Toybox has :Complications)) { return; }
        try {
            var next = calc.nextAfter(loc, Time.now());
            if (next == null) { return; }
            Complications.updateComplication(0, {
                :value      => TimeFormatter.hhmm(next[:time]),
                :shortLabel => _short(next[:name])
            });
            Storage.remove(STORAGE_KEY_ERR);
        } catch (e) {
            // Kept for debugging: the first thing to check when a face
            // slot stays empty.
            var msg = "?";
            if (e != null && e has :getErrorMessage) { msg = e.getErrorMessage(); }
            Storage.set(STORAGE_KEY_ERR, msg);
        }
    }

    // Five characters at most.
    function _short(sym) {
        if (sym == :fajr)    { return "Fajr"; }
        if (sym == :sunrise) { return "Sun"; }
        if (sym == :dhuhr)   { return "Dhuhr"; }
        if (sym == :asr)     { return "Asr"; }
        if (sym == :maghrib) { return "Magh"; }
        return "Isha";
    }
}
