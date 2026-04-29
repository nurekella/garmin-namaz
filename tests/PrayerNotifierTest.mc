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
}
