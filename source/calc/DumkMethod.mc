using Toybox.Lang;

// Қазақстан мұсылмандары діни басқармасы (ҚМДБ / DUMK) prayer-time method.
//
// Reverse-engineered from the official tables (api.muftyat.kz/prayer-times)
// of 36 places across Kazakhstan, every day of 2026. The model below is
// within 1 min of the official minute for ~97% of Fajr, 100% of sunrise,
// Dhuhr and Asr, and 95% / 86% of Maghrib / Isha; the worst Fajr/Isha
// miss is 3.3 min (right at the summer switch to the night-fraction rule).
//
//   * Sunrise/Maghrib: sun 1.0° below the horizon; Dhuhr/Asr are noon and
//     Hanafi Asr. ҚМДБ adds whole precaution minutes, and they step up at
//     48° N: +3 Dhuhr, -2 Sunrise, +2 Maghrib, +3 Asr (south), but
//     +5, -4, +4, +5 from 48° north.
//   * Fajr: sun 15.0° below the horizon, no extra minutes.
//   * Isha mirrors Fajr: Isha - Maghrib = Sunrise - Fajr.
//   * In summer in the north that angle is unreachable or too far from the
//     horizon; ҚМДБ then caps the twilight at ~24.2% of the night
//     (Sunrise -> Maghrib), which is what :nightCap does.
//
// User-level per-prayer offsets (from settings) are applied on top by
// PrayerCalculator and do not replace these.
(:glance, :background)
module DumkMethod {

    const ID              = "DUMK";
    const FAJR_ANGLE      = 15.0d;   // sun degrees below horizon at Fajr (Isha mirrors it)
    const SUNRISE_ANGLE   = 1.0d;    // refraction + disk rim convention used by ҚМДБ
    const NIGHT_CAP       = 0.2417d; // max twilight, as a fraction of the night
    const HIGH_LAT        = 48.0d;   // offsets step up from this latitude
    const DEFAULT_ASR     = 2;       // 1 = Standard, 2 = Hanafi (ҚМДБ uses Hanafi)

    function params() {
        return {
            :id            => ID,
            :fajrAngle     => FAJR_ANGLE,
            :ishaSymmetric => true,
            :nightCap      => NIGHT_CAP,
            :sunriseAngle  => SUNRISE_ANGLE,
            :highLat       => HIGH_LAT,
            :offsets       => { :sunrise => -2, :dhuhr => 3, :asr => 3, :maghrib => 2 },
            :offsetsHigh   => { :sunrise => -4, :dhuhr => 5, :asr => 5, :maghrib => 4 }
        };
    }
}

// Muslim World League — kept for users who prefer it.
(:glance, :background)
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
(:glance, :background)
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

// Islamic Society of North America.
(:glance, :background)
module IsnaMethod {
    const ID = "ISNA";
    function params() {
        return { :id => ID, :fajrAngle => 15.0d, :ishaAngle => 15.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// University of Islamic Sciences, Karachi.
(:glance, :background)
module KarachiMethod {
    const ID = "KARACHI";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaAngle => 18.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Diyanet İşleri Başkanlığı, Türkiye.
(:glance, :background)
module DiyanetMethod {
    const ID = "DIYANET";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaAngle => 17.0d,
                 :sunriseAngle => 0.833d,
                 :offsets => { :sunrise => -7, :dhuhr => 7, :maghrib => 9 } };
    }
}

// Umm al-Qura University, Makkah.
// Isha is a fixed 90-minute interval after Maghrib (120 in Ramadan;
// we don't track Ramadan in v1 so 90 stands year-round).
(:glance, :background)
module UmmAlQuraMethod {
    const ID = "UMM_AL_QURA";
    function params() {
        return { :id => ID, :fajrAngle => 18.5d, :ishaIntervalMin => 90,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Institute of Geophysics, University of Tehran (Shia).
(:glance, :background)
module TehranMethod {
    const ID = "TEHRAN";
    function params() {
        return { :id => ID, :fajrAngle => 17.7d, :ishaAngle => 14.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Shia Ithna-Ashari, Leva Institute, Qum (Jafari).
(:glance, :background)
module JafariMethod {
    const ID = "JAFARI";
    function params() {
        return { :id => ID, :fajrAngle => 16.0d, :ishaAngle => 14.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Generic fixed-interval Isha (used by some local committees).
// Fajr 18°, Isha = 90 min after Maghrib.
(:glance, :background)
module FixedIshaMethod {
    const ID = "FIXED_ISHA";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaIntervalMin => 90,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// All available method ids (for the on-watch settings picker).
(:glance, :background)
module Methods {
    const IDS = ["DUMK", "MWL", "DIYANET", "EGYPT", "ISNA", "KARACHI",
                 "JAFARI", "UMM_AL_QURA", "TEHRAN", "FIXED_ISHA"];
    const LABELS = ["QMDB (KZ)", "MWL", "Diyanet (TR)", "Egyptian", "ISNA",
                    "Karachi", "Jafari", "Umm al-Qura", "Tehran", "Fixed Isha"];

    function paramsFor(id) {
        if (id == null || id.equals("DUMK"))         { return DumkMethod.params(); }
        if (id.equals("MWL"))                         { return MwlMethod.params(); }
        if (id.equals("EGYPT"))                       { return EgyptianMethod.params(); }
        if (id.equals("ISNA"))                        { return IsnaMethod.params(); }
        if (id.equals("KARACHI"))                     { return KarachiMethod.params(); }
        if (id.equals("DIYANET"))                     { return DiyanetMethod.params(); }
        if (id.equals("UMM_AL_QURA"))                 { return UmmAlQuraMethod.params(); }
        if (id.equals("TEHRAN"))                      { return TehranMethod.params(); }
        if (id.equals("JAFARI"))                      { return JafariMethod.params(); }
        if (id.equals("FIXED_ISHA"))                  { return FixedIshaMethod.params(); }
        return DumkMethod.params();
    }
}
