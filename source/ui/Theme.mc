using Toybox.Graphics;
using Toybox.Lang;

// Visual identity constants. Colours target true-black AMOLED on Epix
// Gen 2 — black background lets pixels shut off (battery + contrast).
// All non-bg colours are warm to match the "calm dawn" tone we want.
(:glance)
module Theme {

    // Background — pixels off on AMOLED.
    const COLOR_BG          = 0x000000;

    // Foreground tiers, descending salience.
    const COLOR_TEXT        = 0xF5F0E8;  // primary text — warm white
    const COLOR_TEXT_DIM    = 0x6E6860;  // secondary text — labels, dates
    const COLOR_TEXT_MUTED  = 0x3D3833;  // tertiary — passed prayers

    // Accent — bronze, for "active / next" prayer and key numerics.
    const COLOR_ACCENT      = 0xD4A574;
    const COLOR_ACCENT_DIM  = 0x8A6D4A;

    // Geometry helpers for the 416×416 round Epix Gen 2 face.
    // Other devices in the products list (Fenix 7, FR965) are also
    // 416×416 round — the same constants apply. If we add 360-class
    // devices later, override these per-device via resources.
    const SCREEN_W = 416;
    const SCREEN_H = 416;
    const CENTER_X = SCREEN_W / 2;
    const CENTER_Y = SCREEN_H / 2;
}
