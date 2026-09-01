using Toybox.Lang;

// Қазақстан мұсылмандары діни басқармасы (ҚМДБ / DUMK) prayer-time method.
//
// Reverse-engineered from https://api.muftyat.kz/prayer-times/ using the
// full 2026 schedule for all 16 regional centres plus ~40 smaller
// settlements (see tests/PrayerCalculatorTest.mc for the fixture):
//
//   * Fajr and Isha: sun 15° below the horizon, no extra offset.
//   * Sunrise / sunset: standard 0.833° (refraction + solar radius).
//   * High latitudes: praytimes.org "angle based" rule — twilight is
//     capped at (15/60) of the night. This is what ҚМДБ publishes for
//     Astana / Petropavl / Kostanay from mid-May to end of July.
//   * Precaution (ихтият): +3 min on Dhuhr / Asr / Maghrib and -3 min on
//     sunrise for latitudes below 48°N; +5 / -5 min at 48°N and above.
//     The switch is sharp at exactly 48.0° (47.88°N -> 3, 48.00°N -> 5).
//   * Asr: Hanafi (shadow = 2× object height).
//
// With these rules the calculator matches muftyat.kz within ±1 minute
// (i.e. within their minute rounding) for every city, every day of 2026.
(:glance, :background)
module DumkMethod {

    const ID              = "DUMK";
    const FAJR_ANGLE      = 15.0d;   // sun degrees below horizon at Fajr
    const ISHA_ANGLE      = 15.0d;   // sun degrees below horizon at Isha
    const SUNRISE_ANGLE   = 0.833d;
    const DEFAULT_ASR     = 2;       // 1 = Standard, 2 = Hanafi (ҚМДБ uses Hanafi)
    const PRECAUTION_LAT  = 48.0d;   // latitude at which ихтият goes 3 -> 5 min

    function params() {
        return {
            :id           => ID,
            :fajrAngle    => FAJR_ANGLE,
            :ishaAngle    => ISHA_ANGLE,
            :sunriseAngle => SUNRISE_ANGLE,
            :highLat      => :angleBased,
            :precaution   => { :latSplit => PRECAUTION_LAT, :south => 3, :north => 5 },
            :offsets      => {}
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
            :highLat      => :angleBased,
            :offsets      => {}
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
            :highLat      => :angleBased,
            :offsets      => {}
        };
    }
}

// Islamic Society of North America.
(:glance, :background)
module IsnaMethod {
    const ID = "ISNA";
    function params() {
        return { :id => ID, :fajrAngle => 15.0d, :ishaAngle => 15.0d,
                 :sunriseAngle => 0.833d, :highLat => :angleBased, :offsets => {} };
    }
}

// University of Islamic Sciences, Karachi.
(:glance, :background)
module KarachiMethod {
    const ID = "KARACHI";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaAngle => 18.0d,
                 :sunriseAngle => 0.833d, :highLat => :angleBased, :offsets => {} };
    }
}

// Diyanet İşleri Başkanlığı, Türkiye.
(:glance, :background)
module DiyanetMethod {
    const ID = "DIYANET";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaAngle => 17.0d,
                 :sunriseAngle => 0.833d, :highLat => :angleBased,
                 :offsets => { :sunrise => -7, :dhuhr => 7, :maghrib => 9 } };
    }
}

// Umm al-Qura University, Makkah.
// Isha is a fixed 90-minute interval after Maghrib, 120 minutes during
// Ramadan (the Ramadan check uses the Hijri date of the coming night).
(:glance, :background)
module UmmAlQuraMethod {
    const ID = "UMM_AL_QURA";
    function params() {
        return { :id => ID, :fajrAngle => 18.5d,
                 :ishaIntervalMin => 90, :ishaIntervalRamadanMin => 120,
                 :sunriseAngle => 0.833d, :highLat => :angleBased, :offsets => {} };
    }
}

// Institute of Geophysics, University of Tehran (Shia).
(:glance, :background)
module TehranMethod {
    const ID = "TEHRAN";
    function params() {
        return { :id => ID, :fajrAngle => 17.7d, :ishaAngle => 14.0d,
                 :sunriseAngle => 0.833d, :highLat => :angleBased, :offsets => {} };
    }
}

// Shia Ithna-Ashari, Leva Institute, Qum (Jafari).
(:glance, :background)
module JafariMethod {
    const ID = "JAFARI";
    function params() {
        return { :id => ID, :fajrAngle => 16.0d, :ishaAngle => 14.0d,
                 :sunriseAngle => 0.833d, :highLat => :angleBased, :offsets => {} };
    }
}

// Generic fixed-interval Isha (used by some local committees).
// Fajr 18°, Isha = 90 min after Maghrib.
(:glance, :background)
module FixedIshaMethod {
    const ID = "FIXED_ISHA";
    function params() {
        return { :id => ID, :fajrAngle => 18.0d, :ishaIntervalMin => 90,
                 :sunriseAngle => 0.833d, :highLat => :angleBased, :offsets => {} };
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
