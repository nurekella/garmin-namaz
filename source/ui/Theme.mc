using Toybox.Graphics;
using Toybox.Lang;

// Visual identity constants. Colours target true-black AMOLED on Epix
// Gen 2 — black background lets pixels shut off (battery + contrast).
// All non-bg colours are warm to match the "calm dawn" tone we want.
(:glance, :background)
module Theme {

    // Background — pixels off on AMOLED.
    const COLOR_BG          = 0x000000;

    // Foreground tiers, descending salience.
    const COLOR_TEXT        = 0xFFFFFF;  // primary text — pure white for max contrast on AMOLED
    const COLOR_TEXT_DIM    = 0xA8A29A;  // secondary text — labels, dates
    const COLOR_TEXT_MUTED  = 0x6E6860;  // tertiary — passed prayers
    const COLOR_WARN        = 0xFF7A66;  // a prayer's time is about to run out

    // Material 3 dark scheme, one tonal set per accent (Settings.themeIdx):
    //   accent       primary, for filled buttons and highlights
    //   onAccent     text on the accent
    //   container    primary container, the highlighted row / chip
    //   onContainer  text on the container
    //   surface      list rows and cards (surface container)
    //   surfaceHigh  chips, tracks (surface container highest)
    // Index 0 bronze (default), 1 mint, 2 sky.
    const PALETTES = [
        [0xF1BE7E, 0x2A1700, 0x5C4220, 0xFFDDB2, 0x1C1814, 0x2D2620],
        [0x6FE0B5, 0x00382A, 0x0F4F3B, 0xB6F2DB, 0x121A17, 0x1F2B26],
        [0x6EB4FF, 0x00315C, 0x1E4B7A, 0xCFE5FF, 0x121820, 0x1F2A36]
    ];

    function _p(i) { return PALETTES[Settings.themeIdx()][i]; }

    function accent()      { return _p(0); }
    function onAccent()    { return _p(1); }
    function container()   { return _p(2); }
    function onContainer() { return _p(3); }
    function surface()     { return _p(4); }
    function surfaceHigh() { return _p(5); }

    // Geometry helpers for the 416×416 round Epix Gen 2 face.
    // Other devices in the products list (Fenix 7, FR965) are also
    // 416×416 round — the same constants apply. If we add 360-class
    // devices later, override these per-device via resources.
    const SCREEN_W = 416;
    const SCREEN_H = 416;
    const CENTER_X = SCREEN_W / 2;
    const CENTER_Y = SCREEN_H / 2;
}
