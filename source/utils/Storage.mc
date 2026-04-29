using Toybox.Application;
using Toybox.Lang;

// Thin wrapper around Application.Storage. Centralising the API gives us
// a single place to add caching / migration / size tracking later, and
// keeps callers free of the chatty `Application.Storage.setValue(...)`
// boilerplate.
//
// Watch-app limit: 8 KB per key, 128 KB total. Don't pass raw objects —
// stick to primitives, Strings, Arrays, and Dictionaries of those.
(:glance, :background)
module Storage {

    function get(key) {
        return Application.Storage.getValue(key);
    }

    function set(key, value) {
        Application.Storage.setValue(key, value);
    }

    function remove(key) {
        Application.Storage.deleteValue(key);
    }

    function clear() {
        Application.Storage.clearValues();
    }
}
