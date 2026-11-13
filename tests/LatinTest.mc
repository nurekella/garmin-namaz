using Toybox.Test;
using Toybox.Lang;

// Kazakh Cyrillic -> new Latin alphabet (PrayerNames.toLatin).
module LatinTest {

    (:test)
    function testPrayerNames(logger) {
        var pairs = [
            ["Таң", "Taŋ"], ["Күн", "Kün"], ["Бесін", "Besın"], ["Екінті", "Ekıntı"],
            ["Ақшам", "Aqşam"], ["Құптан", "Qūptan"], ["Жұма", "Jūma"]
        ];
        return _check(logger, pairs);
    }

    (:test)
    function testAllKazakhLetters(logger) {
        var pairs = [
            ["Әә Ғғ Ңң Өө Ұұ Үү Һһ Іі", "Ää Ğğ Ŋŋ Öö Ūū Üü Hh Iı"],
            ["Ии Йй Ыы Шш Жж Ққ Хх Вв", "İi İi Yy Şş Jj Qq Hh Vv"],
            ["КЕЛЕСІ", "KELESI"],
            ["Намаз уақыты", "Namaz uaqyty"],
            ["Fajr 04:31", "Fajr 04:31"]          // already Latin: untouched
        ];
        return _check(logger, pairs);
    }

    (:test)
    function testLettersOutsideTheAlphabet(logger) {
        return _check(logger, [["Цч Щ Ёё Юю Яя ъь Ээ", "Tsch Şş Ioio Iuiu Iaia  Ee"]]);
    }

    // The system font (menus, notifications) has no Ŋ: safe() spells it "ng".
    (:test)
    function testSafeSpellsEngForSystemFont(logger) {
        Test.assert(PrayerNames.safe("Taŋ").equals("Tang"));
        Test.assert(PrayerNames.safe("ŊŊ ä").equals("NgNg ä"));
        return true;
    }

    function _check(logger, pairs) {
        for (var i = 0; i < pairs.size(); i++) {
            var got = PrayerNames.toLatin(pairs[i][0]);
            if (!got.equals(pairs[i][1])) {
                logger.error(pairs[i][0] + " -> " + got + " (want " + pairs[i][1] + ")");
                return false;
            }
        }
        return true;
    }
}
