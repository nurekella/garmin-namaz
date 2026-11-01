using Toybox.Test;
using Toybox.Time;
using Toybox.System;
using Toybox.Lang;

module FastingTest {

    // Ramadan 1447 ran 2026-02-18 .. 2026-03-19 (Umm al-Qura).
    (:test)
    function testIsRamadanDates(logger) {
        Test.assert(!Fasting.isRamadan(2026, 2, 17));
        Test.assert(Fasting.isRamadan(2026, 2, 18));
        Test.assert(Fasting.isRamadan(2026, 3, 19));
        Test.assert(!Fasting.isRamadan(2026, 3, 20));     // Eid al-Fitr
        Test.assert(!Fasting.isRamadan(2026, 10, 1));
        return true;
    }

    // Almaty, mid-Ramadan 2026. Fasts count down to iftar by day and to the
    // end of suhoor at night; nothing outside Ramadan.
    (:test)
    function testNextFastAcrossTheDay(logger) {
        var calc = new PrayerCalculator(DumkMethod.params(), 2, null);
        var loc = { :lat => 43.238293d, :lon => 76.945465d, :tz => 5 };
        // 06:00 local (01:00 UTC) = after Fajr -> iftar. The watch clock is local,
        // so this test only holds on a device whose clock is UTC+5; skip elsewhere.
        if (System.getClockTime().timeZoneOffset != 5 * 3600) { return true; }
        var f = Fasting.next(calc, loc, Time.Gregorian.moment({ :year => 2026, :month => 3, :day => 1, :hour => 1, :minute => 0 }));
        if (f == null || f[:iftar] != true) { logger.error("06:00 should count to iftar"); return false; }
        var n = Fasting.next(calc, loc, Time.Gregorian.moment({ :year => 2026, :month => 3, :day => 1, :hour => 16, :minute => 0 }));
        if (n == null || n[:iftar] != false) { logger.error("21:00 should count to end of suhoor"); return false; }
        return true;
    }

    (:test)
    function testNoFastOutsideRamadan(logger) {
        var calc = new PrayerCalculator(DumkMethod.params(), 2, null);
        var loc = { :lat => 43.238293d, :lon => 76.945465d, :tz => 5 };
        return Fasting.next(calc, loc, Time.Gregorian.moment({ :year => 2026, :month => 10, :day => 1, :hour => 7, :minute => 0 })) == null;
    }
}
