using Toybox.Graphics;
using Toybox.Lang;

// Custom-font factory. Garmin's built-in bitmap fonts (Graphics.FONT_*)
// don't contain Kazakh-specific Cyrillic letters (ә қ ң ғ ө ұ ү і һ),
// which renders them as � on screen. Epix Gen 2 ships RobotoRegular as
// a vector font face — that one DOES carry the full Cyrillic block
// including Kazakh extensions.
//
// We fall back to the matching Graphics.FONT_* if VectorFont API isn't
// available (older devices). Sizes were chosen to visually match the
// built-in tiers within ±2 px on the 416×416 face.
//
// Fonts are cached per size — getVectorFont allocates on every call.
//
// Also used by the glance so Kazakh letters render there too.
(:glance)
module Fonts {

    var _cache = {};

    // Faces in priority order — RobotoCondensedBold reads heaviest and
    // visually matches the built-in bitmap fonts; if a device is missing
    // it we step down to whatever is available.
    const FACES = ["RobotoCondensedBold", "Swiss721Regular", "RobotoRegular", "RobotoCondensedRegular"];

    function _vector(size, fallback) {
        if (!(Toybox.Graphics has :VectorFont)) {
            return fallback;
        }
        var key = size;
        if (_cache.hasKey(key)) {
            return _cache[key];
        }
        var f = null;
        for (var i = 0; i < FACES.size() && f == null; i++) {
            f = Graphics.getVectorFont({ :face => FACES[i], :size => size });
        }
        if (f == null) {
            f = fallback;
        }
        _cache[key] = f;
        return f;
    }

    // Sizes bumped vs the bitmap tiers because vector text renders
    // slightly smaller for the same nominal pt due to anti-aliasing.
    function xtiny()  { return _vector(22, Graphics.FONT_XTINY);  }
    function tiny()   { return _vector(26, Graphics.FONT_TINY);   }
    function small()  { return _vector(32, Graphics.FONT_SMALL);  }
    function medium() { return _vector(40, Graphics.FONT_MEDIUM); }
    function large()  { return _vector(48, Graphics.FONT_LARGE);  }
}
