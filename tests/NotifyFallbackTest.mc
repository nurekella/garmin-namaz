using Toybox.Test;
using Toybox.Lang;

// A crash inside showNotification leaves "pending" behind; the next check
// must switch the watch to the wake prompt for good.
module NotifyFallbackTest {

    (:test)
    function testCrashInsideTheCallSwitchesToWakePrompt(logger) {
        Storage.remove(PrayerNotifier.STORAGE_KEY_NOTIF_BAD);
        Storage.remove(PrayerNotifier.STORAGE_KEY_NOTIF_PENDING);
        try {
            // The simulator has API 5.2: notifications are allowed.
            if (!PrayerNotifier.canNotify()) { logger.error("clean state refused"); return false; }

            // As if the app died inside showNotification.
            Storage.set(PrayerNotifier.STORAGE_KEY_NOTIF_PENDING, true);
            if (PrayerNotifier.canNotify()) { logger.error("pending not taken as a failure"); return false; }
            if (Storage.get(PrayerNotifier.STORAGE_KEY_NOTIF_BAD) != true) { logger.error("bad not kept"); return false; }
            if (Storage.get(PrayerNotifier.STORAGE_KEY_NOTIF_PENDING) != null) { logger.error("pending not cleared"); return false; }

            // And it stays that way.
            if (PrayerNotifier.canNotify()) { logger.error("bad forgotten"); return false; }
        } finally {
            Storage.remove(PrayerNotifier.STORAGE_KEY_NOTIF_BAD);
            Storage.remove(PrayerNotifier.STORAGE_KEY_NOTIF_PENDING);
        }
        return true;
    }
}
