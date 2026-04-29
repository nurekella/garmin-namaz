using Toybox.Test;
using Toybox.Time;
using Toybox.Lang;

module LocationProviderTest {

    function _resetStorage() {
        Storage.remove(LocationProvider.KEY_LAST_LOCATION);
        Storage.remove(LocationProvider.KEY_MANUAL_CITY);
    }

    (:test)
    function testFallbackWhenNoManualNoCacheNoGps(logger) {
        _resetStorage();
        var lp = new LocationProvider();
        var loc = lp.getCurrentLocation();
        // In the test environment Position.getInfo() returns no fix —
        // so we expect the Almaty fallback.
        if (loc == null) { logger.error("loc null"); return false; }
        if (loc[:source] != :fallback) {
            logger.error("expected :fallback source, got " + loc[:source]);
            return false;
        }
        if (!loc[:cityId].equals("almaty")) {
            logger.error("fallback should be Almaty, got " + loc[:cityId]);
            return false;
        }
        return true;
    }

    (:test)
    function testManualCityOverrides(logger) {
        _resetStorage();
        var lp = new LocationProvider();
        lp.setManualCity("shymkent");
        var loc = lp.getCurrentLocation();
        if (loc[:source] != :manual) {
            logger.error("expected :manual, got " + loc[:source]); return false;
        }
        if (!loc[:cityId].equals("shymkent")) {
            logger.error("expected shymkent, got " + loc[:cityId]); return false;
        }
        var sh = Cities.byId("shymkent");
        if (loc[:lat] != sh[:lat] || loc[:lon] != sh[:lon]) {
            logger.error("manual city coords mismatch"); return false;
        }
        _resetStorage();
        return true;
    }

    (:test)
    function testManualCityCleared(logger) {
        _resetStorage();
        var lp = new LocationProvider();
        lp.setManualCity("astana");
        lp.setManualCity(null);
        if (lp.getManualCity() != null) {
            logger.error("manual city not cleared"); return false;
        }
        var loc = lp.getCurrentLocation();
        if (loc[:source] == :manual) {
            logger.error("source still :manual after clear"); return false;
        }
        return true;
    }

    (:test)
    function testManualCityIgnoresUnknownId(logger) {
        _resetStorage();
        var lp = new LocationProvider();
        lp.setManualCity("atlantis");
        var loc = lp.getCurrentLocation();
        // Unknown manual id → fall through chain (no GPS, no cache → fallback)
        if (loc[:source] != :fallback) {
            logger.error("expected :fallback for unknown manual, got " + loc[:source]);
            return false;
        }
        _resetStorage();
        return true;
    }

    (:test)
    function testCacheHitWithinTtl(logger) {
        _resetStorage();
        var lp = new LocationProvider();
        var nowSec = Time.now().value();
        var fresh = {
            :lat       => 50.0d,
            :lon       => 70.0d,
            :tz        => 5,
            :timestamp => nowSec - 3600,  // 1h old
            :accuracy  => 4,
            :source    => :gps
        };
        lp.saveLocation(fresh);
        var loc = lp.getCurrentLocation();
        // Storage round-trip relabels source as :cached.
        if (loc[:source] != :cached) {
            logger.error("expected :cached, got " + loc[:source]); return false;
        }
        if (loc[:lat] != 50.0d) {
            logger.error("cached lat mismatch"); return false;
        }
        _resetStorage();
        return true;
    }

    (:test)
    function testCacheMissWhenStale(logger) {
        _resetStorage();
        var lp = new LocationProvider();
        var nowSec = Time.now().value();
        var stale = {
            :lat       => 50.0d,
            :lon       => 70.0d,
            :tz        => 5,
            :timestamp => nowSec - 86400 - 1, // 24h + 1s old
            :accuracy  => 4,
            :source    => :gps
        };
        lp.saveLocation(stale);
        var loc = lp.getCurrentLocation();
        if (loc[:source] == :gps) {
            logger.error("expected fallback on stale cache, still :gps"); return false;
        }
        if (loc[:source] != :fallback) {
            logger.error("expected :fallback, got " + loc[:source]); return false;
        }
        _resetStorage();
        return true;
    }

    (:test)
    function testIsLocationStale(logger) {
        var lp = new LocationProvider();
        var nowSec = Time.now().value();
        if (lp.isLocationStale(null, 100)) {
            // null is stale — good
        } else {
            logger.error("null should be stale"); return false;
        }
        if (!lp.isLocationStale({ :timestamp => nowSec - 200 }, 100)) {
            logger.error("200s old with 100s ttl should be stale"); return false;
        }
        if (lp.isLocationStale({ :timestamp => nowSec - 50 }, 100)) {
            logger.error("50s old with 100s ttl should be fresh"); return false;
        }
        return true;
    }

    (:test)
    function testSaveAndClear(logger) {
        _resetStorage();
        var lp = new LocationProvider();
        lp.saveLocation({ :lat => 1.0d, :lon => 2.0d, :tz => 5, :timestamp => 1234567890 });
        if (lp.getCachedLocation() == null) {
            logger.error("save not persisted"); return false;
        }
        lp.clearCache();
        if (lp.getCachedLocation() != null) {
            logger.error("clearCache failed"); return false;
        }
        return true;
    }

    (:test)
    function testFromInfoHandlesNull(logger) {
        var lp = new LocationProvider();
        if (lp.fromInfo(null) != null) {
            logger.error("fromInfo(null) should be null"); return false;
        }
        return true;
    }

    (:test)
    function testManualCityOverridesEvenWhenCacheFresh(logger) {
        // If the user has explicitly chosen a city, GPS / cache must not
        // silently overrule them.
        _resetStorage();
        var lp = new LocationProvider();
        lp.saveLocation({
            :lat       => 50.0d,
            :lon       => 70.0d,
            :tz        => 5,
            :timestamp => Time.now().value(),
            :accuracy  => 4,
            :source    => :gps
        });
        lp.setManualCity("turkestan");
        var loc = lp.getCurrentLocation();
        if (loc[:source] != :manual || !loc[:cityId].equals("turkestan")) {
            logger.error("manual must beat fresh cache; got " + loc[:source]
                         + " " + loc[:cityId]);
            return false;
        }
        _resetStorage();
        return true;
    }
}
