using Toybox.WatchUi;
using Toybox.Lang;

// Localised display names for prayers and supporting labels.
//
// Strategy:
//   - If user picked an explicit language in settings (Settings.language()
//     returns "kk"/"ru"/"en" non-auto), serve from baked-in tables.
//   - Otherwise resolve via Rez.Strings (system locale picker).
//
// Watch-app only — glance / background binaries can't link Rez at
// runtime. Those contexts hardcode English inline.
module PrayerNames {

    // ---- baked tables (kk/ru/en) ----

    const PRAYER_KK = {
        :fajr => "Таң", :sunrise => "Күн", :dhuhr => "Бесін",
        :asr => "Екінді", :maghrib => "Ақшам", :isha => "Құптан"
    };
    const PRAYER_RU = {
        :fajr => "Фаджр", :sunrise => "Восход", :dhuhr => "Зухр",
        :asr => "Аср", :maghrib => "Магриб", :isha => "Иша"
    };
    const PRAYER_EN = {
        :fajr => "Fajr", :sunrise => "Sunrise", :dhuhr => "Dhuhr",
        :asr => "Asr", :maghrib => "Maghrib", :isha => "Isha"
    };

    const NEXT_KK = "КЕЛЕСІ";
    const NEXT_RU = "СЛЕДУЮЩИЙ";
    const NEXT_EN = "NEXT";

    const PRAYERTIME_KK = "Намаз уақыты";
    const PRAYERTIME_RU = "Время намаза";
    const PRAYERTIME_EN = "Prayer time";

    const GPS_KK = "GPS іздеу";
    const GPS_RU = "Поиск GPS";
    const GPS_EN = "GPS searching";

    const MONTHS_KK = ["Қаң","Ақп","Нау","Сәу","Мам","Мау","Шіл","Там","Қыр","Қаз","Қар","Жел"];
    const MONTHS_RU = ["Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"];
    const MONTHS_EN = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

    function language() {
        return Settings.language();
    }

    function nameOf(prayerSym) {
        var lang = Settings.language();
        if (lang.equals("kk")) { return PRAYER_KK[prayerSym]; }
        if (lang.equals("ru")) { return PRAYER_RU[prayerSym]; }
        return PRAYER_EN[prayerSym];
    }

    function nextLabel() {
        var lang = Settings.language();
        if (lang.equals("kk")) { return NEXT_KK; }
        if (lang.equals("ru")) { return NEXT_RU; }
        return NEXT_EN;
    }

    function prayerTimeLabel() {
        var lang = Settings.language();
        if (lang.equals("kk")) { return PRAYERTIME_KK; }
        if (lang.equals("ru")) { return PRAYERTIME_RU; }
        return PRAYERTIME_EN;
    }

    function gpsSearching() {
        var lang = Settings.language();
        if (lang.equals("kk")) { return GPS_KK; }
        if (lang.equals("ru")) { return GPS_RU; }
        return GPS_EN;
    }

    function monthShort(month) {
        if (month < 1 || month > 12) { return ""; }
        var lang = Settings.language();
        if (lang.equals("kk")) { return MONTHS_KK[month - 1]; }
        if (lang.equals("ru")) { return MONTHS_RU[month - 1]; }
        return MONTHS_EN[month - 1];
    }
}
