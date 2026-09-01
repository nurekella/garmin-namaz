using Toybox.Position;
using Toybox.System;
using Toybox.Time;
using Toybox.Lang;
using Toybox.Math;

// LocationProvider resolves "where is the user right now" with this
// priority chain:
//
//   1. Manual city override (Storage[:manual_city])
//   2. Cached GPS fix within TTL (default 24h) — battery-friendly
//   3. Live GPS fix from Position.getInfo() if quality is GOOD/USABLE
//   4. Fallback city (Almaty)
//
// We prefer fresh cache over re-reading GPS for two reasons: prayer-time
// calculation only needs ±a few km of position accuracy, and re-acquiring
// GPS at every UI refresh would tank battery. Any GPS fix we do see is
// written back to Storage so subsequent reads stay fast.
//
// Time zone: always the watch's own clock offset (System.getClockTime,
// DST included). Prayer times are compared against the watch clock, so
// they must be expressed in the same zone — even when a manual city in
// another zone is selected, the user still reads them off this watch.
(:glance, :background)
class LocationProvider {

    static const KEY_LAST_LOCATION = "last_location";
    static const KEY_MANUAL_CITY   = "manual_city";
    static const DEFAULT_TTL_SEC   = 86400;   // 24 hours
    static const SIGNIFICANT_KM    = 5.0d;    // movement that invalidates cache early
    static const KZ_TZ_HOURS       = 5;       // used only if the system clock is unavailable

    var _gpsActive;

    function initialize() {
        _gpsActive = false;
    }

    // Current UTC offset of the watch clock in fractional hours
    // (e.g. 5.0 for Almaty, 5.5 for India, -7.0 for PDT).
    static function systemTzHours() {
        try {
            var ct = System.getClockTime();
            if (ct != null && ct.timeZoneOffset != null) {
                return ct.timeZoneOffset.toDouble() / 3600.0d;
            }
        } catch (e) {
        }
        return KZ_TZ_HOURS.toDouble();
    }

    // Synchronous best-effort lookup. Never blocks on GPS — `requestFix`
    // is the async path for refreshing the cache. If nothing usable is
    // available, returns the Almaty fallback.
    // Result: Dictionary { :lat, :lon, :tz, :source, :cityId? }.
    function getCurrentLocation() {
        var manualId = Storage.get(KEY_MANUAL_CITY);
        if (manualId != null) {
            var c = Cities.byId(manualId);
            if (c != null) {
                return _fromCity(c, :manual);
            }
        }

        var cached = getCachedLocation();
        if (cached != null && !isLocationStale(cached, DEFAULT_TTL_SEC)) {
            return cached;
        }

        var live = _readGps();
        if (live != null) {
            saveLocation(live);
            return live;
        }

        return _fromCity(Cities.fallback(), :fallback);
    }

    // Fire a one-shot GPS request. Result lands in `callback(info)`
    // where `info` is a Position.Info. Caller is responsible for
    // calling `saveLocation(...)` from the callback if it wants the
    // fresh fix cached.
    function requestFix(callback) {
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, callback);
        _gpsActive = true;
    }

    // Switch to continuous GPS updates (battery-hungry — only call
    // while the user is on the prayer screen).
    function startContinuous(callback) {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, callback);
        _gpsActive = true;
    }

    function stopGps() {
        if (_gpsActive) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            _gpsActive = false;
        }
    }

    // Convert a raw Position.Info (from a GPS callback) into our
    // standard location dictionary. Returns null if the fix is poor —
    // we only trust QUALITY_USABLE and QUALITY_GOOD (last-known and
    // poor fixes can be hours old or hundreds of km off).
    function fromInfo(info) {
        if (info == null) { return null; }
        var pos = info.position;
        if (pos == null) { return null; }
        var acc = info.accuracy;
        if (acc == null
                || acc == Position.QUALITY_NOT_AVAILABLE
                || acc == Position.QUALITY_LAST_KNOWN
                || acc == Position.QUALITY_POOR) {
            return null;
        }
        var degs = pos.toDegrees();
        var ts = Time.now().value();
        if (info.when != null) { ts = info.when.value(); }
        return {
            :lat       => degs[0].toDouble(),
            :lon       => degs[1].toDouble(),
            :tz        => systemTzHours(),
            :timestamp => ts,
            :accuracy  => acc,
            :source    => :gps
        };
    }

    function getCachedLocation() {
        return _deserialize(Storage.get(KEY_LAST_LOCATION));
    }

    function saveLocation(loc) {
        if (loc == null) { return; }
        Storage.set(KEY_LAST_LOCATION, _serialize(loc));
    }

    function isLocationStale(loc, ttlSec) {
        if (loc == null || loc[:timestamp] == null) { return true; }
        var nowSec = Time.now().value();
        return (nowSec - loc[:timestamp]) > ttlSec;
    }

    // ---------- Storage serialization ----------
    //
    // Application.Storage rejects Symbol values, so we project our
    // Symbol-keyed dictionary onto a String-keyed one before persisting
    // and rebuild the canonical shape on read. The time zone is NOT
    // persisted — it is always re-read from the system clock.

    function _serialize(loc) {
        return {
            "lat"       => loc[:lat],
            "lon"       => loc[:lon],
            "timestamp" => loc[:timestamp],
            "accuracy"  => loc[:accuracy]
        };
    }

    function _deserialize(raw) {
        if (raw == null) { return null; }
        return {
            :lat       => raw["lat"],
            :lon       => raw["lon"],
            :tz        => systemTzHours(),
            :timestamp => raw["timestamp"],
            :accuracy  => raw["accuracy"],
            :source    => :cached
        };
    }

    function setManualCity(cityId) {
        if (cityId == null) {
            Storage.remove(KEY_MANUAL_CITY);
        } else {
            Storage.set(KEY_MANUAL_CITY, cityId);
        }
    }

    function getManualCity() {
        return Storage.get(KEY_MANUAL_CITY);
    }

    function clearCache() {
        Storage.remove(KEY_LAST_LOCATION);
    }

    // ---------- private ----------

    function _readGps() {
        try {
            return fromInfo(Position.getInfo());
        } catch (e) {
            return null;
        }
    }

    function _fromCity(city, source) {
        if (city == null) { return null; }
        return {
            :lat    => city[:lat],
            :lon    => city[:lon],
            :tz     => systemTzHours(),
            :cityId => city[:id],
            :source => source
        };
    }
}
