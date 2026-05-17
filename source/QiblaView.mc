using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Position;
using Toybox.Sensor;
using Toybox.Timer;
using Toybox.Lang;

// Qibla compass — points to the Kaaba in Makkah (21.4225°N, 39.8262°E).
//
// Two angles in play:
//   * qibla_bearing — initial great-circle bearing from current location
//     to the Kaaba, measured clockwise from true north (0..360°).
//   * device_heading — magnetic heading reported by Sensor.getInfo (also
//     measured clockwise from north). Rotates as the user turns the wrist.
//
// We rotate the arrow on screen by (qibla_bearing - device_heading) so the
// arrow always physically points at Makkah no matter how the watch is held.
class QiblaView extends WatchUi.View {

    // Kaaba coordinates (Makkah, Saudi Arabia).
    static const KAABA_LAT = 21.4225d;
    static const KAABA_LON = 39.8262d;

    var _timer;
    var _location;
    var _qiblaBearing;     // degrees from true north; null until we have a location
    var _heading;          // degrees from magnetic north

    function initialize() {
        View.initialize();
        _location = new LocationProvider();
    }

    function onShow() as Void {
        _resolveQibla();
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:_tick), 200, true);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
    }

    function _tick() as Void {
        // Poll the magnetometer each tick — Sensor.Info.heading is in radians.
        var info = Sensor.getInfo();
        if (info != null && info has :heading && info.heading != null) {
            _heading = info.heading * 180.0d / Math.PI;
            if (_heading < 0.0d) { _heading += 360.0d; }
        }
        WatchUi.requestUpdate();
    }

    function _resolveQibla() as Void {
        var loc = _location.getCurrentLocation();
        if (loc == null) { return; }
        var lat1 = loc[:lat].toDouble() * Math.PI / 180.0d;
        var lat2 = KAABA_LAT * Math.PI / 180.0d;
        var dLon = (KAABA_LON - loc[:lon].toDouble()) * Math.PI / 180.0d;
        var y = Math.sin(dLon) * Math.cos(lat2);
        var x = Math.cos(lat1) * Math.sin(lat2)
              - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
        var brg = Math.atan2(y, x) * 180.0d / Math.PI;
        if (brg < 0.0d) { brg += 360.0d; }
        _qiblaBearing = brg;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.COLOR_BG, Theme.COLOR_BG);
        dc.clear();

        var cx = Theme.CENTER_X;
        var cy = Theme.CENTER_Y;

        // Title
        dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 50, Fonts.tiny(), "QIBLA",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_qiblaBearing == null) {
            dc.setColor(Theme.COLOR_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Fonts.medium(), "GPS...",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var heading = (_heading != null) ? _heading : 0.0d;
        var pointAt = _qiblaBearing - heading;
        if (pointAt < 0.0d) { pointAt += 360.0d; }

        // Outer ring with cardinal ticks (N at top of the user's facing).
        dc.setColor(Theme.COLOR_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, 150);
        // N marker — fixed relative to the *user*, so rotate inverse heading.
        var northAngle = -heading;
        _drawCardinal(dc, cx, cy, 150, northAngle, "N", Theme.COLOR_TEXT_DIM);

        // Qibla arrow.
        _drawArrow(dc, cx, cy, 130, pointAt, Theme.accent());

        // Degrees label.
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 90, Fonts.small(),
                    _qiblaBearing.toLong() + "°",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setPenWidth(1);
    }

    function _drawCardinal(dc, cx, cy, r, angleDeg, label, color) {
        var a = (angleDeg - 90.0d) * Math.PI / 180.0d;
        var lx = cx + ((r + 14) * Math.cos(a)).toNumber();
        var ly = cy + ((r + 14) * Math.sin(a)).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx, ly, Fonts.xtiny(), label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawArrow(dc, cx, cy, r, angleDeg, color) {
        // angle = 0 means straight up (north).
        var a = (angleDeg - 90.0d) * Math.PI / 180.0d;
        var tipX = cx + (r * Math.cos(a)).toNumber();
        var tipY = cy + (r * Math.sin(a)).toNumber();
        var aL = a + (160.0d * Math.PI / 180.0d);
        var aR = a - (160.0d * Math.PI / 180.0d);
        var leftX = tipX + (40 * Math.cos(aL)).toNumber();
        var leftY = tipY + (40 * Math.sin(aL)).toNumber();
        var rightX = tipX + (40 * Math.cos(aR)).toNumber();
        var rightY = tipY + (40 * Math.sin(aR)).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[tipX, tipY], [leftX, leftY], [cx, cy], [rightX, rightY]]);
    }
}

class QiblaDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
