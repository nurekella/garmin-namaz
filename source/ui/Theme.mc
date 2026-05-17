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

    // Accent palettes — selectable via Settings.themeIdx.
    const ACCENT_BRONZE     = 0xD4A574;
    const ACCENT_BRONZE_DIM = 0x8A6D4A;
    const ACCENT_MINT       = 0x6FE0B5;
    const ACCENT_MINT_DIM   = 0x3F9579;
    const ACCENT_SKY        = 0x6EB4FF;
    const ACCENT_SKY_DIM    = 0x3F73B5;
    const ACCENT_MONO       = 0xE8E0D4;
    const ACCENT_MONO_DIM   = 0x9E9890;

    // Legacy constants — kept so existing call sites still compile.
    // New code should use accent() / accentDim() to honour the user's pick.
    const COLOR_ACCENT      = ACCENT_BRONZE;
    const COLOR_ACCENT_DIM  = ACCENT_BRONZE_DIM;

    function accent() {
        var idx = Settings.themeIdx();
        if (idx == 1) { return ACCENT_MINT; }
        if (idx == 2) { return ACCENT_SKY; }
        if (idx == 3) { return ACCENT_MONO; }
        return ACCENT_BRONZE;
    }

    function accentDim() {
        var idx = Settings.themeIdx();
        if (idx == 1) { return ACCENT_MINT_DIM; }
        if (idx == 2) { return ACCENT_SKY_DIM; }
        if (idx == 3) { return ACCENT_MONO_DIM; }
        return ACCENT_BRONZE_DIM;
    }

    // Geometry helpers for the 416×416 round Epix Gen 2 face.
    // Other devices in the products list (Fenix 7, FR965) are also
    // 416×416 round — the same constants apply. If we add 360-class
    // devices later, override these per-device via resources.
    const SCREEN_W = 416;
    const SCREEN_H = 416;
    const CENTER_X = SCREEN_W / 2;
    const CENTER_Y = SCREEN_H / 2;
}
