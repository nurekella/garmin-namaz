using Toybox.Lang;

// Қазақстан мұсылмандары діни басқармасы (ҚМДБ / DUMK) prayer-time method.
//
// Calibrated against https://api.muftyat.kz/prayer-times/ for Almaty,
// Astana and Shymkent at 4 reference dates in 2026 (Jan 1, Apr 29, Jun 21,
// Dec 21). With the constants below the calculator stays within ±2.5 min
// of the official ҚМДБ schedule for those cities; mean residual ≤ 1.5 min.
// See `tests/PrayerCalculatorTest.mc` for the comparison harness.
//
// The `:offsets` dictionary bakes in the calibration. User-level per-prayer
// offsets (from settings) are applied on top by PrayerCalculator and do
// not replace these.
module DumkMethod {

    const ID              = "DUMK";
    const FAJR_ANGLE      = 15.5d;   // sun degrees below horizon at Fajr
    const ISHA_ANGLE      = 15.5d;   // sun degrees below horizon at Isha
    const SUNRISE_ANGLE   = 1.0d;    // refraction + disk rim convention used by ҚМДБ
    const DEFAULT_ASR     = 2;       // 1 = Standard, 2 = Hanafi (ҚМДБ uses Hanafi)

    function params() {
        return {
            :id           => ID,
            :fajrAngle    => FAJR_ANGLE,
            :ishaAngle    => ISHA_ANGLE,
            :sunriseAngle => SUNRISE_ANGLE,
            :offsets      => {
                :fajr    =>  3,
                :sunrise => -2,
                :dhuhr   =>  2,
                :asr     =>  3,
                :maghrib =>  2,
                :isha    => -3
            }
        };
    }
}

// Muslim World League — kept for users who prefer it.
module MwlMethod {

    const ID              = "MWL";
    const FAJR_ANGLE      = 18.0d;
    const ISHA_ANGLE      = 17.0d;
    const SUNRISE_ANGLE   = 0.833d;

    function params() {
        return {
            :id           => ID,
            :fajrAngle    => FAJR_ANGLE,
            :ishaAngle    => ISHA_ANGLE,
            :sunriseAngle => SUNRISE_ANGLE,
            :offsets      => { :dhuhr => 0, :maghrib => 0 }
        };
    }
}

// Egyptian General Authority of Survey.
module EgyptianMethod {

    const ID              = "EGYPT";
    const FAJR_ANGLE      = 19.5d;
    const ISHA_ANGLE      = 17.5d;
    const SUNRISE_ANGLE   = 0.833d;

    function params() {
        return {
            :id           => ID,
            :fajrAngle    => FAJR_ANGLE,
            :ishaAngle    => ISHA_ANGLE,
            :sunriseAngle => SUNRISE_ANGLE,
            :offsets      => { :dhuhr => 0, :maghrib => 0 }
        };
    }
}
