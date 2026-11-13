using Toybox.Lang;

// Localised display names for prayers and supporting labels.
// All three locales come from baked tables here — no Rez calls — so
// the module is safe to use from glance / background binaries.
(:glance, :background)
module PrayerNames {

    // ---- baked tables (kk/ru/en) ----

    const PRAYER_KK = {
        :fajr => "Таң", :sunrise => "Күн", :dhuhr => "Бесін",
        :asr => "Екінті", :maghrib => "Ақшам", :isha => "Құптан"
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
        var table = PRAYER_EN;
        if (lang.equals("kk")) { table = PRAYER_KK; }
        if (lang.equals("ru")) { table = PRAYER_RU; }
        var name = table[prayerSym];
        return (name != null) ? kz(name) : "";
    }

    // Localized one-off label; honours the in-app language override
    // (Rez strings only follow the system language).
    function pick(kk, ru, en) {
        var lang = Settings.language();
        if (lang.equals("kk")) { return kz(kk); }
        if (lang.equals("ru")) { return ru; }
        return en;
    }

    // Kazakh text as the user wants to read it: Cyrillic as written, or the
    // new Latin alphabet (2021: Ä Ğ İ I/ı Ŋ Ö Q Ş Ū Ü Y) when chosen.
    function kz(text) {
        if (!Settings.latin()) { return text; }
        if (text instanceof Lang.String) { return toLatin(text); }
        if (text instanceof Lang.Array) {
            var out = [];
            for (var i = 0; i < text.size(); i++) { out.add(kz(text[i])); }
            return out;
        }
        return text;
    }

    // Letter-by-letter Cyrillic -> Kazakh Latin. Letters outside the
    // Kazakh alphabet (Ц Ч Щ Ё Ю Я Ъ Ь Э) get the usual spelling.
    const _CYR = "АаӘәБбВвГгҒғДдЕеЁёЖжЗзИиЙйКкҚқЛлМмНнҢңОоӨөПпРрСсТтУуҰұҮүФфХхҺһЦцЧчШшЩщЪъЫыІіЬьЭэЮюЯя";
    const _LAT = ["A","a","Ä","ä","B","b","V","v","G","g","Ğ","ğ","D","d","E","e","Io","io","J","j","Z","z",
        "İ","i","İ","i","K","k","Q","q","L","l","M","m","N","n","Ŋ","ŋ","O","o","Ö","ö","P","p","R","r",
        "S","s","T","t","U","u","Ū","ū","Ü","ü","F","f","H","h","H","h","Ts","ts","Ch","ch","Ş","ş",
        "Şş","şş","","","Y","y","I","ı","","","E","e","Iu","iu","Ia","ia"];

    function toLatin(text) {
        var out = "";
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toString();
            var k = _CYR.find(c);
            out += (k != null) ? _LAT[k] : c;
        }
        return out;
    }

    // The watch's system font has no Kazakh-only letters (they show as "?"
    // in notifications and system menus; Garmin has no Kazakh system
    // language). Text that the OS draws goes through here: those nine
    // letters become the nearest Russian ones. Our own screens are drawn
    // with a vector font that has them and keep the real spelling.
    const _KZ_FROM = "ӘәҒғҚқҢңӨөҰұҮүҺһІі";
    const _KZ_TO   = "АаГгКкНнОоУуУуХхИи";

    function safe(text) {
        if (text == null) { return null; }
        var out = "";
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toString();
            var k = _KZ_FROM.find(c);
            if (k != null) {
                out += _KZ_TO.substring(k, k + 1);
            } else if (c.equals("Ŋ")) {
                out += "Ng";     // Latin Kazakh: the system font has no Ŋ either
            } else if (c.equals("ŋ")) {
                out += "ng";
            } else {
                out += c;
            }
        }
        return out;
    }

    function jumuah() {
        return pick("Жұма", "Жума", "Jumu'ah");
    }

    // "1:23" -> "1:23 қалды" / "через 1:23" / "in 1:23".
    function timeLeft(hm) {
        return pick(hm + " қалды", "через " + hm, "in " + hm);
    }

    // Notification title: "Fajr ends 05:46".
    function endsWord() {
        return pick("аяқталады", "заканчивается", "ends");
    }

    // Ramadan: the two countdown targets.
    function iftarLabel() {
        return pick("Ауызашар", "Ифтар", "Iftar");
    }

    function suhoorLabel() {
        return pick("Сәресі", "Сухур", "Suhoor");
    }

    // Running prayer + what is left of its time: "Asr: 0:42 left".
    function windowLeft(sym, hm) {
        return nameOf(sym) + ": " + pick(hm + " қалды", "ещё " + hm, hm + " left");
    }

    function nextLabel() {
        var lang = Settings.language();
        if (lang.equals("kk")) { return kz(NEXT_KK); }
        if (lang.equals("ru")) { return NEXT_RU; }
        return NEXT_EN;
    }

    function prayerTimeLabel() {
        var lang = Settings.language();
        if (lang.equals("kk")) { return kz(PRAYERTIME_KK); }
        if (lang.equals("ru")) { return PRAYERTIME_RU; }
        return PRAYERTIME_EN;
    }

    function gpsSearching() {
        var lang = Settings.language();
        if (lang.equals("kk")) { return kz(GPS_KK); }
        if (lang.equals("ru")) { return GPS_RU; }
        return GPS_EN;
    }

    function monthShort(month) {
        if (month < 1 || month > 12) { return ""; }
        var lang = Settings.language();
        if (lang.equals("kk")) { return kz(MONTHS_KK[month - 1]); }
        if (lang.equals("ru")) { return MONTHS_RU[month - 1]; }
        return MONTHS_EN[month - 1];
    }
}
