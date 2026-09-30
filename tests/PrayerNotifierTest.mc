using Toybox.Test;
using Toybox.Attention;
using Toybox.Lang;

module PrayerNotifierTest {

    (:test)
    function testVibePatternShape(logger) {
        var p = PrayerNotifier.getVibePattern();
        // 3 pulses + 2 silences = 5 entries.
        if (p.size() != 5) {
            logger.error("expected 5 vibe entries, got " + p.size());
            return false;
        }
        // Pulses at index 0, 2, 4 — silences at 1, 3.
        // Each VibeProfile has dutyCycle and duration fields per the
        // Garmin API; we can't introspect them portably, but the
        // count and instance type are enough to pin behaviour.
        for (var i = 0; i < p.size(); i++) {
            if (!(p[i] instanceof Attention.VibeProfile)) {
                logger.error("entry " + i + " is not a VibeProfile");
                return false;
            }
        }
        return true;
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
        var t = { :fajr => 5.0d, :sunrise => 6.5d, :dhuhr => 13.0d,
                  :asr => 17.0d, :maghrib => 20.0d, :isha => 21.5d };
        return PrayerNotifier.pickAlert(t, nowH, preFajr, preOther);
    }

    (:test)
    function testPickAlert(logger) {
        // No pre-alert: next prayer, sunrise ignored.
        var r = _pick(6.0d, 0, 0);
        Test.assertEqual(r[:name], :dhuhr);
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
}
