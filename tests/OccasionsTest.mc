using Toybox.Test;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;

module OccasionsTest {

    // Gregorian day (noon, UTC-neutral enough for day_of_week / year / month / day).
    function _info(y, m, d) {
        return Gregorian.info(Gregorian.moment({ :year => y, :month => m, :day => d, :hour => 12 }), Time.FORMAT_SHORT);
    }

    function _calc() {
        return new PrayerCalculator(DumkMethod.params(), 2, null);
    }

    function _times(info) {
        return _calc().calculate(43.238293d, 76.945465d, info.year, info.month, info.day, 5);
    }

    (:test)
    function testFastReasons(logger) {
        // (hm, hd, dow 1=Sun) -> code
        Test.assert(Occasions.fastReason(12, 9, 3) == 0);       // Arafah
        Test.assert(Occasions.fastReason(1, 9, 3) == 1);        // Ashura, 9th
        Test.assert(Occasions.fastReason(1, 10, 3) == 1);       // Ashura, 10th
        Test.assert(Occasions.fastReason(5, 14, 3) == 2);       // white days
        Test.assert(Occasions.fastReason(10, 4, 3) == 3);       // six days of Shawwal
        Test.assert(Occasions.fastReason(4, 20, 2) == 4);       // Monday
        Test.assert(Occasions.fastReason(4, 20, 5) == 5);       // Thursday
        Test.assert(Occasions.fastReason(4, 20, 3) == null);    // an ordinary Tuesday
        return true;
    }

    (:test)
    function testNoFastWhenForbiddenOrObligatory(logger) {
        Test.assert(Occasions.fastReason(9, 14, 2) == null);    // Ramadan: already obligatory
        Test.assert(Occasions.fastReason(10, 1, 2) == null);    // Eid al-Fitr
        Test.assert(Occasions.fastReason(12, 10, 5) == null);   // Eid al-Adha
        Test.assert(Occasions.fastReason(12, 12, 2) == null);   // days of tashriq
        return true;
    }

    (:test)
    function testHolidaysAndNights(logger) {
        Test.assert(Occasions.holidayOn(10, 1) == 4);           // Eid al-Fitr
        Test.assert(Occasions.holidayOn(9, 1) == 3);            // Ramadan begins
        Test.assert(Occasions.holidayOn(5, 5) == null);
        Test.assert(Occasions.nightOn(9, 27, 3) == 10);         // Night of Qadr
        Test.assert(Occasions.nightOn(7, 27, 3) == 8);          // Miraj
        Test.assert(Occasions.nightOn(8, 15, 3) == 9);          // Bara'at
        Test.assert(Occasions.nightOn(7, 3, 6) == 7);           // Raghaib: tomorrow is the first Friday of Rajab
        Test.assert(Occasions.nightOn(7, 3, 5) == null);
        Test.assert(Occasions.nightOn(7, 10, 6) == null);       // not the first Friday
        return true;
    }

    // Friday 2026-11-06: a reminder before Dhuhr (default 60 min).
    (:test)
    function testFridayReminder(logger) {
        var fri = _info(2026, 11, 6);
        var t = _times(fri);
        var list = Occasions.extras(fri, t, _info(2026, 11, 7));
        for (var i = 0; i < list.size(); i++) {
            var d = list[i][0] - (t[:dhuhr] - 1.0d);
            if (d < 0.0d) { d = -d; }
            if (d < 0.001d) {
                Test.assert(list[i][1].find(PrayerNames.jumuah()) == 0);
                return true;
            }
        }
        logger.error("no Jumu'ah reminder among " + list.size() + " extras");
        return false;
    }

    // Sunday 2026-11-01: tomorrow is a Monday -> "fast tomorrow" 20 min after Isha.
    (:test)
    function testFastTomorrowAlert(logger) {
        var sun = _info(2026, 11, 1);
        var t = _times(sun);
        var list = Occasions.extras(sun, t, _info(2026, 11, 2));
        var want = t[:isha] + 20.0d / 60.0d;
        for (var i = 0; i < list.size(); i++) {
            var d = list[i][0] - want;
            if (d < 0.0d) { d = -d; }
            if (d < 0.001d) {
                Test.assert(list[i][1].equals(PrayerNames.pick("Ертең ораза", "Завтра пост", "Fast tomorrow")));
                Test.assert(list[i][2].equals(Occasions.fastName(4)));
                return true;
            }
        }
        logger.error("no fast-tomorrow alert among " + list.size() + " extras");
        return false;
    }

    // Tuesday: nothing to say tomorrow (Wednesday), and it is not Friday.
    (:test)
    function testQuietDay(logger) {
        var tue = _info(2026, 11, 3);
        var list = Occasions.extras(tue, _times(tue), _info(2026, 11, 4));
        if (list.size() != 0) { logger.error("expected no extras, got " + list.size()); return false; }
        return true;
    }

    (:test)
    function testExtrasWinWhenEarlierThanPrayers(logger) {
        var t = { :fajr => 5.0d, :sunrise => 6.5d, :dhuhr => 13.0d, :asr => 17.0d,
                  :maghrib => 20.0d, :isha => 21.5d };
        // 21:40, Isha has passed, the extra at 21:50 is next.
        var r = PrayerNotifier.pickAlert(t, 21.6d, 0, 0, 0, [[21.8d, "Title", "Sub"]]);
        Test.assertEqual(r[:kind], :extra);
        Test.assert(r[:title].equals("Title") && r[:sub].equals("Sub"));
        // An earlier prayer beats a later extra.
        r = PrayerNotifier.pickAlert(t, 20.5d, 0, 0, 0, [[22.5d, "Title", "Sub"]]);
        Test.assertEqual(r[:name], :isha);
        return true;
    }

    (:test)
    function testDuhaAndTahajjud(logger) {
        var info = _info(2026, 11, 1);
        var t = _times(info);
        // Duha: a quarter of the daylight after sunrise.
        if (!(t[:duha] > t[:sunrise] && t[:duha] < t[:dhuhr])) { logger.error("Duha out of range"); return false; }
        var want = t[:sunrise] + (t[:maghrib] - t[:sunrise]) / 4.0d;
        var d = t[:duha] - want;
        if (d < 0.0d) { d = -d; }
        if (d * 60.0d > 6.0d) { logger.error("Duha is off by " + (d * 60.0d) + " min"); return false; }
        // Tahajjud: early hours, before Fajr, after the middle of the night.
        if (!(t[:tahajjud] > 0.0d && t[:tahajjud] < t[:fajr])) { logger.error("Tahajjud out of range: " + t[:tahajjud]); return false; }
        return true;
    }
}
