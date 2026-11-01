using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Sunnah fasts, Islamic holidays and the Friday reminder: what is worth
// knowing about today and tomorrow. Logic follows the Windows app
// (Hijri.SunnahFast / Hijri.Year); dates come from HijriDate.forDate, so the
// user's Hijri adjustment applies.
//
// Used by the main card (a one-line chip under the date) and by the
// notifier, which runs in the background; keep the strings short.
(:background)
module Occasions {

    // ---- fasts ----------------------------------------------------------
    // Codes: 0 Arafah, 1 Ashura, 2 White days, 3 Shawwal, 4 Monday, 5 Thursday.

    // The fast recommended on a day with Hijri month `hm`, day `hd` and
    // Gregorian weekday `dow` (1 = Sunday), or null. Never in Ramadan
    // (already obligatory) and not on the Eid days (fasting is forbidden).
    function fastReason(hm, hd, dow) {
        if (hm == 9 || (hm == 10 && hd == 1) || (hm == 12 && hd >= 10 && hd <= 13)) { return null; }
        if (hm == 12 && hd == 9) { return 0; }
        if (hm == 1 && (hd == 9 || hd == 10)) { return 1; }
        if (hd >= 13 && hd <= 15) { return 2; }
        if (hm == 10 && hd >= 2 && hd <= 7) { return 3; }
        if (dow == 2) { return 4; }
        if (dow == 5) { return 5; }
        return null;
    }

    function fastName(code) {
        var p = PrayerNames;
        if (code == 0) { return p.pick("Арафат күні", "День Арафа", "Day of Arafah"); }
        if (code == 1) { return p.pick("Ашура", "Ашура", "Ashura"); }
        if (code == 2) { return p.pick("Ақ күндер", "Белые дни", "White days"); }
        if (code == 3) { return p.pick("Шәууал", "Шавваль", "Shawwal"); }
        if (code == 4) { return p.pick("Дүйсенбі", "Понедельник", "Monday"); }
        return p.pick("Бейсенбі", "Четверг", "Thursday");
    }

    // ---- holidays -------------------------------------------------------
    // Days: 0 New Year, 1 Ashura, 2 Mawlid, 3 Ramadan begins, 4 Eid al-Fitr,
    // 5 Arafah, 6 Eid al-Adha. Nights (the evening before): 7 Raghaib,
    // 8 Isra and Miraj, 9 Bara'at, 10 Night of Qadr.

    function holidayOn(hm, hd) {
        if (hm == 1 && hd == 1) { return 0; }
        if (hm == 1 && hd == 10) { return 1; }
        if (hm == 3 && hd == 12) { return 2; }
        if (hm == 9 && hd == 1) { return 3; }
        if (hm == 10 && hd == 1) { return 4; }
        if (hm == 12 && hd == 9) { return 5; }
        if (hm == 12 && hd == 10) { return 6; }
        return null;
    }

    // The holiday night that begins this evening, given tomorrow's Hijri
    // month/day and weekday (the Hijri day starts at sunset).
    function nightOn(hmTomorrow, hdTomorrow, dowTomorrow) {
        if (hmTomorrow == 7 && hdTomorrow == 27) { return 8; }
        if (hmTomorrow == 8 && hdTomorrow == 15) { return 9; }
        if (hmTomorrow == 9 && hdTomorrow == 27) { return 10; }
        // Raghaib: the night before the first Friday of Rajab.
        if (hmTomorrow == 7 && hdTomorrow <= 7 && dowTomorrow == 6) { return 7; }
        return null;
    }

    function holidayName(idx) {
        var p = PrayerNames;
        if (idx == 0)  { return p.pick("Жаңа хижра жылы", "Новый хиджры год", "Islamic New Year"); }
        if (idx == 1)  { return p.pick("Ашура күні", "День Ашура", "Day of Ashura"); }
        if (idx == 2)  { return p.pick("Мәулід", "Маулид", "Mawlid"); }
        if (idx == 3)  { return p.pick("Рамазан басталады", "Начало Рамадана", "Ramadan begins"); }
        if (idx == 4)  { return p.pick("Ораза айт", "Ураза-байрам", "Eid al-Fitr"); }
        if (idx == 5)  { return p.pick("Арафат күні", "День Арафа", "Day of Arafah"); }
        if (idx == 6)  { return p.pick("Құрбан айт", "Курбан-байрам", "Eid al-Adha"); }
        if (idx == 7)  { return p.pick("Рағаиб түні", "Ночь Рагаиб", "Night of Raghaib"); }
        if (idx == 8)  { return p.pick("Миғраж түні", "Ночь Мирадж", "Night of Miraj"); }
        if (idx == 9)  { return p.pick("Бәраәт түні", "Ночь Бараат", "Night of Bara'at"); }
        return p.pick("Қадір түні", "Ночь Кадр", "Night of Qadr");
    }

    // ---- the chip under the date ------------------------------------------

    // One short line for the main card, or null. Priority: a holiday today,
    // a holiday night this evening, a fast today (before sunset), then
    // tomorrow's holiday or fast once Isha has come.
    // `tomorrow` is Gregorian.info of the next civil day.
    function chip(info, tomorrow, nowH, maghribH, ishaH) {
        var p = PrayerNames;
        var h = HijriDate.forDate(info.year, info.month, info.day);
        var hol = holidayOn(h[:month], h[:day]);
        if (hol != null) { return holidayName(hol); }

        var t = HijriDate.forDate(tomorrow.year, tomorrow.month, tomorrow.day);
        if (maghribH != null && nowH >= maghribH) {
            var night = nightOn(t[:month], t[:day], tomorrow.day_of_week);
            if (night != null) { return p.pick("Бүгін кешке: ", "Сегодня вечером: ", "Tonight: ") + holidayName(night); }
        }
        if (maghribH == null || nowH < maghribH) {
            var f = fastReason(h[:month], h[:day], info.day_of_week);
            if (f != null) { return p.pick("Бүгін ораза: ", "Сегодня пост: ", "Fast today: ") + fastName(f); }
        }
        if (ishaH != null && nowH >= ishaH) {
            var th = holidayOn(t[:month], t[:day]);
            if (th != null) { return p.pick("Ертең: ", "Завтра: ", "Tomorrow: ") + holidayName(th); }
            var tf = fastReason(t[:month], t[:day], tomorrow.day_of_week);
            if (tf != null) { return p.pick("Ертең ораза: ", "Завтра пост: ", "Fast tomorrow: ") + fastName(tf); }
        }
        return null;
    }

    // ---- notifications ------------------------------------------------------

    // Extra alert points for one civil day, in the shape PrayerNotifier.pickAlert
    // takes: [hour of day, title, subtitle]. `t` is that day's prayer times,
    // `next` is Gregorian.info of the following day.
    function extras(info, t, next) {
        var p = PrayerNames;
        var list = [];

        // Friday: get ready for Jumu'ah.
        var before = Settings.jumuahBefore();
        if (before > 0 && info.day_of_week == 6 && t[:dhuhr] != null) {
            list.add([t[:dhuhr] - before / 60.0d,
                      p.jumuah() + " " + TimeFormatter.hhmm(t[:dhuhr]),
                      p.pick(before + " мин қалды", "через " + before + " мин", "in " + before + " min")]);
        }

        if (Settings.remindFasts() == 0) { return list; }
        var h = HijriDate.forDate(next.year, next.month, next.day);

        // A holiday night starts at Maghrib.
        var night = nightOn(h[:month], h[:day], next.day_of_week);
        if (night != null && t[:maghrib] != null) {
            list.add([t[:maghrib] + 5.0d / 60.0d, holidayName(night),
                      p.pick("Бүгін кешке", "Сегодня вечером", "Tonight")]);
        }

        // 20 min after Isha: what tomorrow brings.
        if (t[:isha] != null) {
            var hol = holidayOn(h[:month], h[:day]);
            if (hol != null) {
                list.add([t[:isha] + 20.0d / 60.0d, holidayName(hol),
                          p.pick("Ертең", "Завтра", "Tomorrow")]);
            } else {
                var f = fastReason(h[:month], h[:day], next.day_of_week);
                if (f != null) {
                    list.add([t[:isha] + 20.0d / 60.0d,
                              p.pick("Ертең ораза", "Завтра пост", "Fast tomorrow"), fastName(f)]);
                }
            }
        }
        return list;
    }
}
