using Toybox.Test;
using Toybox.Lang;

module TimeFormatterTest {

    (:test)
    function testHhmm_NoonExact(logger) {
        return TimeFormatter.hhmm(12.0d).equals("12:00");
    }

    (:test)
    function testHhmm_HalfHour(logger) {
        return TimeFormatter.hhmm(13.5d).equals("13:30");
    }

    (:test)
    function testHhmm_RoundsToNearestMinute(logger) {
        // 12.504h = 12:30:14.4 -> 12:30
        var a = TimeFormatter.hhmm(12.504d);
        // 12.508h = 12:30:28.8 -> 12:30
        var b = TimeFormatter.hhmm(12.508d);
        // 12.509h = 12:30:32.4 -> 12:31
        var c = TimeFormatter.hhmm(12.509d);
        if (!a.equals("12:30")) { logger.error("12.504 -> " + a); return false; }
        if (!b.equals("12:30")) { logger.error("12.508 -> " + b); return false; }
        if (!c.equals("12:31")) { logger.error("12.509 -> " + c); return false; }
        return true;
    }

    (:test)
    function testHhmm_RoundUpAcrossHour(logger) {
        // 12.999h = 12:59:56 -> rounds to 13:00
        return TimeFormatter.hhmm(12.999d).equals("13:00");
    }

    (:test)
    function testHhmm_PadsLeadingZero(logger) {
        return TimeFormatter.hhmm(3.05d).equals("03:03");
    }

    (:test)
    function testHhmm_NullReturnsDashes(logger) {
        return TimeFormatter.hhmm(null).equals("--:--");
    }

    (:test)
    function testCountdown_HoursMinutesSeconds(logger) {
        // 1h 2m 5s = 3725s
        return TimeFormatter.countdown(3725).equals("1:02:05");
    }

    (:test)
    function testCountdown_LessThanAnHour(logger) {
        return TimeFormatter.countdown(130).equals("0:02:10");
    }

    (:test)
    function testCountdown_Zero(logger) {
        return TimeFormatter.countdown(0).equals("0:00:00");
    }

    (:test)
    function testCountdown_NullAndNegative(logger) {
        if (!TimeFormatter.countdown(null).equals("--:--:--")) { return false; }
        if (!TimeFormatter.countdown(-1).equals("--:--:--"))   { return false; }
        return true;
    }

}

module PrayerNamesTest {

    (:test)
    function testNameOfAllPrayers(logger) {
        // We can't force a system language inside the test, so just
        // check every prayer symbol returns a non-empty string.
        var syms = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha];
        for (var i = 0; i < syms.size(); i++) {
            var name = PrayerNames.nameOf(syms[i]);
            if (name == null || name.length() == 0) {
                logger.error("nameOf " + syms[i] + " was empty");
                return false;
            }
        }
        return true;
    }

    (:test)
    function testNameOfUnknownReturnsEmpty(logger) {
        return PrayerNames.nameOf(:atlantis).equals("");
    }

    (:test)
    function testLanguageReturnsKnownCode(logger) {
        var l = PrayerNames.language();
        return l.equals("kk") || l.equals("ru") || l.equals("en");
    }

    (:test)
    function testNextLabelNonEmpty(logger) {
        return PrayerNames.nextLabel().length() > 0;
    }
}
