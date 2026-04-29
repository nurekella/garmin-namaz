using Toybox.Lang;

// Қазақстан мұсылмандары діни басқармасы (ҚМДБ / DUMK) prayer-time method.
//
// Reference (when accessible): https://www.muftyat.kz/kk/prayer-times/
// Angles below mirror what Kazakh tables publish; calibrate with
// per-prayer offsets if a multi-day comparison shows systematic drift.
module DumkMethod {

    const ID              = "DUMK";
    const FAJR_ANGLE      = 18.0d;   // sun degrees below horizon at Fajr
    const ISHA_ANGLE      = 17.0d;   // sun degrees below horizon at Isha
    const MAGHRIB_OFFSET  = 0;       // minutes after astronomical sunset
    const DHUHR_OFFSET    = 2;       // minutes added to true solar noon
    const DEFAULT_ASR     = 2;       // 1 = Standard, 2 = Hanafi

    function params() {
        return {
            :id            => ID,
            :fajrAngle     => FAJR_ANGLE,
            :ishaAngle     => ISHA_ANGLE,
            :maghribOffset => MAGHRIB_OFFSET,
            :dhuhrOffset   => DHUHR_OFFSET
        };
    }
}

// Muslim World League — kept here as a convenient alternate.
module MwlMethod {

    const ID              = "MWL";
    const FAJR_ANGLE      = 18.0d;
    const ISHA_ANGLE      = 17.0d;
    const MAGHRIB_OFFSET  = 0;
    const DHUHR_OFFSET    = 0;

    function params() {
        return {
            :id            => ID,
            :fajrAngle     => FAJR_ANGLE,
            :ishaAngle     => ISHA_ANGLE,
            :maghribOffset => MAGHRIB_OFFSET,
            :dhuhrOffset   => DHUHR_OFFSET
        };
    }
}

// Egyptian General Authority of Survey.
module EgyptianMethod {

    const ID              = "EGYPT";
    const FAJR_ANGLE      = 19.5d;
    const ISHA_ANGLE      = 17.5d;
    const MAGHRIB_OFFSET  = 0;
    const DHUHR_OFFSET    = 0;

    function params() {
        return {
            :id            => ID,
            :fajrAngle     => FAJR_ANGLE,
            :ishaAngle     => ISHA_ANGLE,
            :maghribOffset => MAGHRIB_OFFSET,
            :dhuhrOffset   => DHUHR_OFFSET
        };
    }
}
