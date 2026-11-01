using Toybox.Test;
using Toybox.Lang;

module CitiesTest {

    function _near(actual, expected, tol) {
        var d = actual - expected;
        if (d < 0.0d) { d = -d; }
        return d <= tol;
    }

    (:test)
    function testByIdKnownCities(logger) {
        var ids = ["almaty", "astana", "shymkent", "karaganda", "aktobe",
                   "taraz", "pavlodar", "oskemen", "semey", "atyrau",
                   "kostanay", "kyzylorda", "uralsk", "petropavl", "aktau",
                   "turkestan"];
        for (var i = 0; i < ids.size(); i++) {
            var c = Cities.byId(ids[i]);
            if (c == null) {
                logger.error("Cities.byId('" + ids[i] + "') returned null");
                return false;
            }
            if (c[:tz] != 5) {
                logger.error(ids[i] + " tz=" + c[:tz] + " — KZ should be UTC+5");
                return false;
            }
        }
        return true;
    }

    (:test)
    function testByIdUnknown(logger) {
        if (Cities.byId("atlantis") != null) { return false; }
        if (Cities.byId(null) != null) { return false; }
        if (Cities.byId("") != null) { return false; }
        return true;
    }

    (:test)
    function testFallbackIsAlmaty(logger) {
        var c = Cities.fallback();
        return c != null && c[:id].equals("almaty");
    }

    (:test)
    function testAlmatyCanonicalCoords(logger) {
        // ҚМДБ canonical centroid — must match the calibration fixture.
        var c = Cities.byId("almaty");
        if (!_near(c[:lat], 43.238293d, 1e-5)) {
            logger.error("Almaty lat drift: " + c[:lat]); return false;
        }
        if (!_near(c[:lon], 76.945465d, 1e-5)) {
            logger.error("Almaty lon drift: " + c[:lon]); return false;
        }
        return true;
    }

    (:test)
    function testHaversineSamePoint(logger) {
        var d = Cities.haversineKm(43.24d, 76.94d, 43.24d, 76.94d);
        return d < 0.001d;
    }

    (:test)
    function testHaversineAstanaAlmaty(logger) {
        // Known great-circle distance Astana <-> Almaty ~ 970 km.
        var astana = Cities.byId("astana");
        var almaty = Cities.byId("almaty");
        var d = Cities.haversineKm(astana[:lat], astana[:lon], almaty[:lat], almaty[:lon]);
        if (d < 950.0d || d > 1000.0d) {
            logger.error("Astana-Almaty distance unreasonable: " + d.format("%.1f") + " km");
            return false;
        }
        logger.debug("Astana-Almaty = " + d.format("%.1f") + " km");
        return true;
    }

    (:test)
    function testNearestForAlmatyCenter(logger) {
        var r = Cities.nearest(43.24d, 76.94d);
        if (!r[:city][:id].equals("almaty")) {
            logger.error("Nearest to Almaty centre is " + r[:city][:id]);
            return false;
        }
        if (r[:distanceKm] > 1.0d) {
            logger.error("Distance to centre too large: " + r[:distanceKm]);
            return false;
        }
        return true;
    }

    (:test)
    function testNearestForKaragandaArea(logger) {
        // Halfway between Karaganda (49.8, 73.1) and Astana (51.1, 71.4) — closer to Karaganda.
        var r = Cities.nearest(50.4d, 72.5d);
        if (!r[:city][:id].equals("karaganda")) {
            logger.error("Expected karaganda, got " + r[:city][:id]
                         + " at " + r[:distanceKm].format("%.1f") + " km");
            return false;
        }
        return true;
    }

    (:test)
    function testLocalizedName(logger) {
        var c = Cities.byId("oskemen");
        var ok = true;
        ok = ok && c[:name_kk].equals("Өскемен")
                && Cities.localizedName(c, "kk").equals("Өскемен");
        ok = ok && Cities.localizedName(c, "ru").equals("Усть-Каменогорск");
        ok = ok && Cities.localizedName(c, "en").equals("Oskemen");
        // Unknown lang falls through to English
        ok = ok && Cities.localizedName(c, "fr").equals("Oskemen");
        if (!ok) { logger.error("localizedName mismatch for oskemen"); }
        return ok;
    }

    (:test)
    function testAllCitiesHaveAllNames(logger) {
        var cities = Cities.all();
        for (var i = 0; i < cities.size(); i++) {
            var c = cities[i];
            if (c[:name_kk] == null || c[:name_ru] == null || c[:name_en] == null) {
                logger.error("Missing name for " + c[:id]);
                return false;
            }
        }
        return true;
    }

    (:test)
    function testCityIndexCountMatchesSetting(logger) {
        // Settings.CITY_COUNT is a copy (the background cannot load CityIndex).
        if (CityIndex.count() != Settings.CITY_COUNT) {
            logger.error("CityIndex.count()=" + CityIndex.count() + " but Settings.CITY_COUNT=" + Settings.CITY_COUNT);
            return false;
        }
        return true;
    }

    (:test)
    function testCityIndexIdsRoundTrip(logger) {
        for (var i = 0; i < CityIndex.count(); i++) {
            var c = CityIndex.at(i);
            var back = CityIndex.byId(c[:id]);
            if (back == null || !back[:name_kk].equals(c[:name_kk])) {
                logger.error("id round trip failed at " + i + " (" + c[:id] + ")");
                return false;
            }
        }
        return true;
    }

    (:test)
    function testNearestNamesTheCity(logger) {
        // A fix a few km from Petropavl's centre -> Petropavl; the steppe -> nothing.
        var n = CityIndex.nearest(54.89d, 69.20d);
        if (n == null || !n[:name_kk].equals("Петропавл")) { logger.error("expected Petropavl"); return false; }
        // A place that is only in the big index: Rudnyy.
        var r = CityIndex.nearest(52.97d, 63.12d);
        if (r == null || !r[:name_en].equals("Rudnyy")) { logger.error("expected Rudnyy"); return false; }
        if (CityIndex.nearest(47.0d, 66.0d) != null) { logger.error("nothing within 30 km of the open steppe"); return false; }
        return true;
    }
}
