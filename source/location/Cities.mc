using Toybox.Math;
using Toybox.Lang;

// Major Kazakh cities, coordinates from https://api.muftyat.kz/cities/
// (ҚМДБ canonical centroids). All Kazakhstan is UTC+5 since 2024-03-01.
//
// Names: :name_kk drops the "қаласы" suffix since context is always a
// city. :name_ru uses the modern transliteration; :name_en is included
// for the English UI locale.
(:glance, :background)
module Cities {

    const FALLBACK_ID = "almaty";

    const KAZAKHSTAN = [
        { :id => "almaty",     :name_kk => "Алматы",     :name_ru => "Алматы",          :name_en => "Almaty",
          :lat => 43.238293d, :lon => 76.945465d, :tz => 5 },
        { :id => "astana",     :name_kk => "Астана",     :name_ru => "Астана",          :name_en => "Astana",
          :lat => 51.133333d, :lon => 71.433333d, :tz => 5 },
        { :id => "shymkent",   :name_kk => "Шымкент",    :name_ru => "Шымкент",         :name_en => "Shymkent",
          :lat => 42.368009d, :lon => 69.612769d, :tz => 5 },
        { :id => "karaganda",  :name_kk => "Қарағанды",  :name_ru => "Караганда",       :name_en => "Karaganda",
          :lat => 49.806406d, :lon => 73.085485d, :tz => 5 },
        { :id => "aktobe",     :name_kk => "Ақтөбе",     :name_ru => "Актобе",          :name_en => "Aktobe",
          :lat => 50.300377d, :lon => 57.154555d, :tz => 5 },
        { :id => "taraz",      :name_kk => "Тараз",      :name_ru => "Тараз",           :name_en => "Taraz",
          :lat => 42.883333d, :lon => 71.366667d, :tz => 5 },
        { :id => "pavlodar",   :name_kk => "Павлодар",   :name_ru => "Павлодар",        :name_en => "Pavlodar",
          :lat => 52.315556d, :lon => 76.956389d, :tz => 5 },
        { :id => "oskemen",    :name_kk => "Өскемен",    :name_ru => "Усть-Каменогорск",:name_en => "Oskemen",
          :lat => 49.948325d, :lon => 82.627848d, :tz => 5 },
        { :id => "semey",      :name_kk => "Семей",      :name_ru => "Семей",           :name_en => "Semey",
          :lat => 50.404976d, :lon => 80.249235d, :tz => 5 },
        { :id => "atyrau",     :name_kk => "Атырау",     :name_ru => "Атырау",          :name_en => "Atyrau",
          :lat => 47.116667d, :lon => 51.883333d, :tz => 5 },
        { :id => "kostanay",   :name_kk => "Қостанай",   :name_ru => "Костанай",        :name_en => "Kostanay",
          :lat => 53.219333d, :lon => 63.634194d, :tz => 5 },
        { :id => "kyzylorda",  :name_kk => "Қызылорда",  :name_ru => "Кызылорда",       :name_en => "Kyzylorda",
          :lat => 44.842544d, :lon => 65.502563d, :tz => 5 },
        { :id => "uralsk",     :name_kk => "Орал",       :name_ru => "Уральск",         :name_en => "Uralsk",
          :lat => 51.204019d, :lon => 51.370537d, :tz => 5 },
        { :id => "petropavl",  :name_kk => "Петропавл",  :name_ru => "Петропавловск",   :name_en => "Petropavl",
          :lat => 54.862222d, :lon => 69.140833d, :tz => 5 },
        { :id => "aktau",      :name_kk => "Ақтау",      :name_ru => "Актау",           :name_en => "Aktau",
          :lat => 43.635379d, :lon => 51.169135d, :tz => 5 },
        { :id => "turkestan",  :name_kk => "Түркістан",  :name_ru => "Туркестан",       :name_en => "Turkestan",
          :lat => 43.302025d, :lon => 68.268979d, :tz => 5 }
    ];

    function all() {
        return KAZAKHSTAN;
    }

    function byId(id) {
        if (id == null) { return null; }
        for (var i = 0; i < KAZAKHSTAN.size(); i++) {
            if (KAZAKHSTAN[i][:id].equals(id)) {
                return KAZAKHSTAN[i];
            }
        }
        return null;
    }

    function fallback() {
        return byId(FALLBACK_ID);
    }

    // Returns the closest city to (lat, lon) plus the great-circle
    // distance in km. Used when a fresh GPS fix lands us in a city
    // we don't have in the table — we still want a name for the UI.
    function nearest(lat, lon) {
        var best = null;
        var bestDist = null;
        for (var i = 0; i < KAZAKHSTAN.size(); i++) {
            var c = KAZAKHSTAN[i];
            var d = haversineKm(lat, lon, c[:lat], c[:lon]);
            if (bestDist == null || d < bestDist) {
                bestDist = d;
                best = c;
            }
        }
        return { :city => best, :distanceKm => bestDist };
    }

    // Great-circle distance in km between two (lat, lon) points in degrees.
    function haversineKm(lat1, lon1, lat2, lon2) {
        var R = 6371.0d;
        var DEG = 0.017453292519943295d;
        var dLat = (lat2.toDouble() - lat1.toDouble()) * DEG;
        var dLon = (lon2.toDouble() - lon1.toDouble()) * DEG;
        var sinDLat = Math.sin(dLat / 2.0d);
        var sinDLon = Math.sin(dLon / 2.0d);
        var a = sinDLat * sinDLat
              + Math.cos(lat1.toDouble() * DEG) * Math.cos(lat2.toDouble() * DEG)
                * sinDLon * sinDLon;
        return 2.0d * R * Math.asin(Math.sqrt(a));
    }

    function localizedName(city, lang) {
        if (city == null) { return ""; }
        if (lang.equals("kk") || lang.equals("kaz")) { return city[:name_kk]; }
        if (lang.equals("ru") || lang.equals("rus")) { return city[:name_ru]; }
        return city[:name_en];
    }
}
