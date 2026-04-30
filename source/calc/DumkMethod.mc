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
(:glance, :background)
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

// Islamic Society of North America.
module IsnaMethod {
    const ID = "ISNA";
    function params() {
        return { :id => ID, :fajrAngle => 15.0d, :ishaAngle => 15.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// University of Islamic Sciences, Karachi.
module KarachiMethod {
    const ID = "KARACHI";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaAngle => 18.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Diyanet İşleri Başkanlığı, Türkiye.
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
module UmmAlQuraMethod {
    const ID = "UMM_AL_QURA";
    function params() {
        return { :id => ID, :fajrAngle => 18.5d, :ishaIntervalMin => 90,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Institute of Geophysics, University of Tehran (Shia).
module TehranMethod {
    const ID = "TEHRAN";
    function params() {
        return { :id => ID, :fajrAngle => 17.7d, :ishaAngle => 14.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Shia Ithna-Ashari, Leva Institute, Qum (Jafari).
module JafariMethod {
    const ID = "JAFARI";
    function params() {
        return { :id => ID, :fajrAngle => 16.0d, :ishaAngle => 14.0d,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// Generic fixed-interval Isha (used by some local committees).
// Fajr 18°, Isha = 90 min after Maghrib.
module FixedIshaMethod {
    const ID = "FIXED_ISHA";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaIntervalMin => 90,
                 :sunriseAngle => 0.833d, :offsets => {} };
    }
}

// All available method ids (for the on-watch settings picker).
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
