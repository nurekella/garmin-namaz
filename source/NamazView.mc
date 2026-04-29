using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;

class NamazView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, 0x000000);
        dc.clear();

        var label = WatchUi.loadResource(Rez.Strings.AppName) as Lang.String;

        dc.drawText(
            w / 2,
            h / 2,
            Graphics.FONT_LARGE,
            label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function onHide() as Void {
    }
}
