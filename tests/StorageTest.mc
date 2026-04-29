using Toybox.Test;
using Toybox.Lang;

module StorageTest {

    const TEST_KEY = "__storage_test__";

    (:test)
    function testSetGetString(logger) {
        Storage.set(TEST_KEY, "hello");
        var v = Storage.get(TEST_KEY);
        Storage.remove(TEST_KEY);
        return v != null && v.equals("hello");
    }

    (:test)
    function testSetGetNumber(logger) {
        Storage.set(TEST_KEY, 42);
        var v = Storage.get(TEST_KEY);
        Storage.remove(TEST_KEY);
        return v == 42;
    }

    (:test)
    function testSetGetDictionary(logger) {
        // Application.Storage cannot store Symbol values — Dictionary
        // keys must be strings.
        Storage.set(TEST_KEY, { "lat" => 43.5d, "lon" => 76.9d, "tz" => 5 });
        var v = Storage.get(TEST_KEY);
        Storage.remove(TEST_KEY);
        if (v == null) { return false; }
        if (v["lat"] != 43.5d) { logger.error("lat mismatch"); return false; }
        if (v["tz"]  != 5)     { logger.error("tz mismatch");  return false; }
        return true;
    }

    (:test)
    function testSetSymbolDictionaryThrows(logger) {
        // Symbol-keyed dicts must round-trip through a string-keyed shim
        // (see LocationProvider._serialize). Document the constraint here.
        var threw = false;
        try {
            Storage.set(TEST_KEY, { :lat => 1.0d });
        } catch (e) {
            threw = true;
        }
        Storage.remove(TEST_KEY);
        if (!threw) {
            logger.error("Storage accepted Symbol-keyed dict — assumption broken!");
            return false;
        }
        return true;
    }

    (:test)
    function testRemove(logger) {
        Storage.set(TEST_KEY, "x");
        Storage.remove(TEST_KEY);
        return Storage.get(TEST_KEY) == null;
    }

    (:test)
    function testGetMissingReturnsNull(logger) {
        return Storage.get("__definitely_not_set__") == null;
    }
}
