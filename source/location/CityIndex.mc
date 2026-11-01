// Kazakh cities beyond the 16 big ones in Cities.mc, from the official
// ҚМДБ place list (api.muftyat.kz/cities). Used for two things in the app
// UI: naming the place the GPS fix is closest to, and the manual city
// picker. Foreground only: the background process has a tight memory
// limit, so a manually chosen place travels to it as plain coordinates
// (see LocationProvider.setManualPoint).
//
// DATA is flat, 5 values per city: name_kk, name_ru, name_en, lat, lon.
module CityIndex {

    const STRIDE = 5;
    const NEAR_KM = 30.0d;      // closer than this counts as "in" the city

    const DATA = [
        "Абай", "Абай", "Abay", 49.631899d, 72.859245d,
        "Ақкөл", "Аккол", "Aqkol", 51.995855d, 70.952948d,
        "Ақсай", "Аксай", "Aqsay", 51.164945d, 53.020868d,
        "Ақсу", "Аксу", "Aqsu", 52.03789d, 76.920582d,
        "Алатау", "Алатау", "Alatau", 43.681261d, 77.116046d,
        "Алға", "Алга", "Algha", 49.89673d, 57.328586d,
        "Алтай", "Алтай", "Altay", 49.725218d, 84.273562d,
        "Арал", "Арал", "Aral", 46.797738d, 61.660792d,
        "Арқалық", "Аркалык", "Arqalyq", 50.248611d, 66.911389d,
        "Арыс", "Арыс", "Arys", 42.432744d, 68.813798d,
        "Атбасар", "Атбасар", "Atbasar", 51.815761d, 68.358335d,
        "Аягөз", "Аягоз", "Ayagoz", 47.966667d, 80.433333d,
        "Балқаш", "Балкаш", "Balqash", 46.843721d, 74.977301d,
        "Булаев", "Булаев", "Bulaev", 54.896056d, 70.448157d,
        "Державинск", "Державинск", "Derzhavinsk", 51.098685d, 66.314712d,
        "Екібастұз", "Екибастуз", "Ekibastuz", 51.729778d, 75.326583d,
        "Ембі", "Эмба", "Embi", 48.823344d, 58.148397d,
        "Ерейментау", "Ерейментау", "Ereymentau", 51.619626d, 73.102598d,
        "Есік", "Есик", "Esik", 43.365179d, 77.450893d,
        "Есіл", "Есиль", "Esil", 51.958004d, 66.406215d,
        "Жаңаөзен", "Жанаозен", "Zhanaozen", 43.343266d, 52.865792d,
        "Жаңатас", "Жанатас", "Zhanatas", 43.55465d, 69.722525d,
        "Жаркент", "Жаркент", "Zharkent", 44.169365d, 80.003842d,
        "Жезқазған", "Жезказган", "Zhezqazghan", 47.799711d, 67.71409d,
        "Жем", "Жем", "Zhem", 48.774532d, 58.072436d,
        "Жетісай", "Жетысай", "Zhetisay", 40.775278d, 68.327222d,
        "Жітіқара", "Житикара", "Zhitiqara", 52.183928d, 61.189833d,
        "Зайсан", "Зайсан", "Zaysan", 47.453008d, 84.969846d,
        "Кентау", "Кентау", "Kentau", 43.518131d, 68.504652d,
        "Көкшетау", "Кокшетау", "Kokshetau", 53.291667d, 69.391667d,
        "Курчатов", "Курчатов", "Kurchatov", 50.7549d, 78.544826d,
        "Қазалы", "Казалы", "Qazaly", 45.760633d, 62.105836d,
        "Қандыағаш", "Кандыагаш", "Qandyaghash", 49.474444d, 57.423333d,
        "Қаражал", "Каражал", "Qarazhal", 48.001042d, 70.785762d,
        "Қаратау", "Каратау", "Qaratau", 43.166667d, 70.466667d,
        "Қарқаралы", "Каркаралы", "Qarqaraly", 49.41224d, 75.470095d,
        "Қаскелең", "Каскелен", "Qaskelen", 43.202449d, 76.622278d,
        "Қонаев", "Конаев", "Qonaev", 43.883333d, 77.083333d,
        "Қосшы", "Косшы", "Qosshy", 50.970262d, 71.355366d,
        "Құлсары", "Кулсары", "Qulsary", 46.983333d, 54.016667d,
        "Ленгер", "Ленгер", "Lenger", 42.182051d, 69.88212d,
        "Лисаков", "Лисаков", "Lisakov", 52.544079d, 62.492641d,
        "Макинск", "Макинск", "Makinsk", 52.63281d, 70.417677d,
        "Мамлют", "Мамлют", "Mamlyut", 54.94112d, 68.546199d,
        "Приозёрск", "Приозёрск", "Priozyorsk", 46.028969d, 73.708027d,
        "Риддер", "Риддер", "Ridder", 50.33886d, 83.506329d,
        "Рудный", "Рудный", "Rudnyy", 52.966667d, 63.116667d,
        "Саран", "Саран", "Saran", 49.801993d, 72.828387d,
        "Сарқан", "Саркан", "Sarqan", 45.413666d, 79.916894d,
        "Сарыағаш", "Сарыагаш", "Saryaghash", 41.466667d, 69.166667d,
        "Сәтпаев", "Сатпаев", "Satpaev", 47.907455d, 67.528112d,
        "Сергеев", "Сергеев", "Sergeev", 53.888542d, 67.416271d,
        "Серебрянск", "Серебрянск", "Serebryansk", 49.679277d, 83.300651d,
        "Степногорск", "Степногорск", "Stepnogorsk", 52.346944d, 71.881667d,
        "Степняк", "Степняк", "Stepnyak", 52.832d, 70.783427d,
        "Тайынша", "Тайынша", "Tayynsha", 53.852738d, 69.782631d,
        "Талғар", "Талгар", "Talghar", 43.302813d, 77.23969d,
        "Талдықорған", "Талдыкорган", "Taldyqorghan", 45.017837d, 78.382123d,
        "Текелі", "Текели", "Tekeli", 44.863094d, 78.764266d,
        "Темір", "Темир", "Temir", 49.143142d, 57.12633d,
        "Теміртау", "Темиртау", "Temirtau", 50.058756d, 72.953424d,
        "Тобыл", "Тобыл", "Tobyl", 53.207372d, 63.705088d,
        "Үшарал", "Ушарал", "Usharal", 46.169722d, 80.939444d,
        "Үштөбе", "Уштобе", "Ushtobe", 45.251221d, 77.980827d,
        "Форт-Шевченко", "Форт-Шевченко", "Fort-Shevchenko", 44.507463d, 50.262833d,
        "Хромтау", "Хромтау", "Khromtau", 50.250278d, 58.434722d,
        "Шалқар", "Шалкар", "Shalqar", 47.831392d, 59.61929d,
        "Шар", "Шар", "Shar", 49.584964d, 81.047173d,
        "Шардара", "Шардара", "Shardara", 41.254722d, 67.969167d,
        "Шахтинск", "Шахтинск", "Shakhtinsk", 49.705868d, 72.594637d,
        "Шемонаиха", "Шемонаиха", "Shemonaikha", 50.627624d, 81.916697d,
        "Шу", "Шу", "Shu", 43.611782d, 73.760237d,
        "Щучинск", "Щучинск", "Shchuchinsk", 52.942096d, 70.21014d
    ];

    // Total pickable places: the big 16, then DATA.
    function count() {
        return Cities.all().size() + DATA.size() / STRIDE;
    }

    // idx 0..15 are the big cities; 16.. are DATA in order. Same shape as
    // Cities.all() entries, with a stable string id.
    function at(idx) {
        var big = Cities.all();
        if (idx < big.size()) { return big[idx]; }
        return _entry((idx - big.size()) * STRIDE);
    }

    function byId(id) {
        if (id == null) { return null; }
        if (id.find("k:") == 0) {
            var name = id.substring(2, id.length());
            for (var i = 0; i < DATA.size(); i += STRIDE) {
                if (DATA[i].equals(name)) { return _entry(i); }
            }
            return null;
        }
        return Cities.byId(id);
    }

    // The place closest to (lat, lon), or null if none within NEAR_KM.
    function nearest(lat, lon) {
        var best = null;
        var bestKm = NEAR_KM;
        var big = Cities.all();
        for (var i = 0; i < big.size(); i++) {
            var km = Cities.haversineKm(lat, lon, big[i][:lat], big[i][:lon]);
            if (km < bestKm) { bestKm = km; best = big[i]; }
        }
        var bestOff = -1;
        for (var j = 0; j < DATA.size(); j += STRIDE) {
            var d = Cities.haversineKm(lat, lon, DATA[j + 3], DATA[j + 4]);
            if (d < bestKm) { bestKm = d; bestOff = j; best = null; }
        }
        return (bestOff >= 0) ? _entry(bestOff) : best;
    }

    // Foreground: make the locator match the manualCityIdx setting, storing
    // the coordinates of places outside the big 16 for the background.
    function sync(locator) {
        var idx = Settings.manualCityIdx();
        if (idx < 0) {
            locator.setManualCity(null);
            return;
        }
        var c = at(idx);
        if (idx < Cities.all().size()) {
            locator.setManualCity(c[:id]);
        } else {
            locator.setManualPoint(idx, c[:id], c[:lat], c[:lon]);
        }
    }

    function _entry(off) {
        return {
            :id      => "k:" + DATA[off],
            :name_kk => DATA[off],
            :name_ru => DATA[off + 1],
            :name_en => DATA[off + 2],
            :lat     => DATA[off + 3],
            :lon     => DATA[off + 4],
            :tz      => 5
        };
    }
}
