using Toybox.Lang;

(:glance, :background)
module TimeFormatter {

    // 13.5 -> "13:30". Negative or null -> "--:--".
    // Rounds to nearest minute.
    function hhmm(hoursFloat) {
        if (hoursFloat == null) { return "--:--"; }
        var h = hoursFloat.toNumber();
        var mFloat = (hoursFloat - h) * 60.0d;
        var m = mFloat.toNumber();
        if ((mFloat - m) >= 0.5d) { m += 1; }
        if (m >= 60) { m -= 60; h += 1; }
        if (h < 0)   { h += 24; }
        if (h >= 24) { h -= 24; }
        return _pad2(h) + ":" + _pad2(m);
    }

    // 3725 -> "1:02:05"; 130 -> "0:02:10"; null/<0 -> "--:--:--".
    function countdown(totalSec) {
        if (totalSec == null || totalSec < 0) { return "--:--:--"; }
        var h = totalSec / 3600;
        var m = (totalSec % 3600) / 60;
        var s = totalSec % 60;
        return h + ":" + _pad2(m) + ":" + _pad2(s);
    }

    // 3725 -> "62 min" (rounded up so 1s left still reads "1 min" not "0").
    function minutesLeft(totalSec) {
        if (totalSec == null || totalSec < 0) { return "--"; }
        var m = (totalSec + 59) / 60;
        return "" + m;
    }

    function _pad2(n) {
        if (n < 10) { return "0" + n; }
        return "" + n;
    }
}
