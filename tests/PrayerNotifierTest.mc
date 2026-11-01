using Toybox.Test;
using Toybox.Time;
using Toybox.Lang;

module PrayerNotifierTest {

    (:test)
    function testPendingTestAlertSurvivesSchedule(logger) {
        // Opening the app during the 5-min wait must not replace the
        // test alert with the next prayer.
        PrayerNotifier.clearScheduled();
        PrayerNotifier.scheduleTest();
        var lp = new LocationProvider();
        var rec = PrayerNotifier.schedule(Settings.buildCalculator(), lp);
        var ok = rec != null && rec["test"] == true;
        PrayerNotifier.clearScheduled();
        return ok;
    }

    (:test)
    function testGetScheduledStartsEmpty(logger) {
        PrayerNotifier.clearScheduled();
        return PrayerNotifier.getScheduled() == null;
    }

    (:test)
    function testStorageKeyConstant(logger) {
        // Pin the key so a future rename doesn't silently orphan
        // already-saved schedules on user devices.
        return PrayerNotifier.STORAGE_KEY_NEXT.equals("scheduled_prayer");
    }

    (:test)
    function testMinScheduleGap(logger) {
        // Garmin enforces ≥5 min between temporal events.
        return PrayerNotifier.MIN_SCHEDULE_GAP_SEC == 300;
    }

    // Float→int truncation in pickAlert can shave a second.
    function _near(a, b) {
        return a - b <= 1 && b - a <= 1;
    }

    function _pick(nowH, preFajr, preOther) {
        return _pickEnd(nowH, preFajr, preOther, 0);
    }

    function _pickEnd(nowH, preFajr, preOther, endWarn) {
        var t = { :fajr => 5.0d, :sunrise => 6.5d, :dhuhr => 13.0d,
                  :asr => 17.0d, :maghrib => 20.0d, :isha => 21.5d };
        return PrayerNotifier.pickAlert(t, nowH, preFajr, preOther, endWarn);
    }

    (:test)
    function testPickAlert(logger) {
        // No pre-alert: next prayer, sunrise ignored.
        var r = _pick(6.0d, 0, 0);
        Test.assertEqual(r[:name], :dhuhr);
        Test.assert(r[:time] == 13.0d);   // prayer time, shown in the notification
        Test.assert(_near(r[:deltaSec], 7 * 3600));

        // Pre-alert 10 min: fires at 12:50 ...
        r = _pick(12.0d, 10, 10);
        Test.assertEqual(r[:name], :dhuhr);
        Test.assert(_near(r[:deltaSec], 50 * 60));

        // ... and after it fired (a few seconds late) the prayer itself
        // is still armed, not skipped.
        r = _pick(12.0d + 50.0d / 60.0d + 5.0d / 3600.0d, 10, 10);
        Test.assertEqual(r[:name], :dhuhr);
        Test.assert(_near(r[:deltaSec], 10 * 60 - 5));

        // 5-min pre-alert fired late: prayer lands inside the 5-min floor
        // -> pushed to the floor instead of dropped.
        r = _pick(12.0d + 55.0d / 60.0d + 10.0d / 3600.0d, 5, 5);
        Test.assertEqual(r[:name], :dhuhr);
        Test.assert(_near(r[:deltaSec], 300));

        // Fajr uses its own pre-alert.
        r = _pick(4.0d, 30, 0);
        Test.assertEqual(r[:name], :fajr);
        Test.assert(_near(r[:deltaSec], 30 * 60));

        // After Isha: nothing today; tomorrow's Fajr via the -24h shift.
        Test.assert(_pick(22.0d, 0, 0) == null);
        r = _pick(22.0d - 24.0d, 0, 0);
        Test.assertEqual(r[:name], :fajr);
        Test.assert(_near(r[:deltaSec], 7 * 3600));
        return true;
    }

    // Fixture: Fajr 05:00 -> sunrise 06:30, Asr 17:00 -> Maghrib 20:00.
    (:test)
    function testEndWarningBeforeSunrise(logger) {
        // 20 min before sunrise = 06:10; ahead of Dhuhr (13:00).
        var r = _pickEnd(5.5d, 0, 0, 20);
        Test.assertEqual(r[:kind], :end);
        Test.assertEqual(r[:name], :fajr);
        Test.assert(r[:time] == 6.5d);                      // title shows when it ends
        Test.assert(_near(r[:deltaSec], 40 * 60));          // 05:30 -> 06:10

        // Before Fajr itself the start alert (05:00) comes first.
        r = _pickEnd(4.0d, 0, 0, 20);
        Test.assertEqual(r[:kind], :start);
        Test.assert(_near(r[:deltaSec], 3600));
        return true;
    }

    (:test)
    function testEndWarningAsrAndOff(logger) {
        // After Dhuhr, 40 min before Asr's end warning (19:40).
        var r = _pickEnd(17.5d, 0, 0, 20);
        Test.assertEqual(r[:kind], :end);
        Test.assertEqual(r[:name], :asr);
        Test.assert(r[:time] == 20.0d);

        // Off: the next thing is Maghrib itself, never an end warning.
        r = _pickEnd(17.5d, 0, 0, 0);
        Test.assertEqual(r[:kind], :start);
        Test.assertEqual(r[:name], :maghrib);
        return true;
    }

    (:test)
    function testEndWarningSkippedWhenTooLate(logger) {
        // 2 min before sunrise: the 5-min platform floor would fire the
        // warning after sunrise, so skip it and go on to Dhuhr.
        var r = _pickEnd(6.5d - 2.0d / 60.0d, 0, 0, 20);
        Test.assertEqual(r[:name], :dhuhr);
        Test.assertEqual(r[:kind], :start);
        return true;
    }
}
