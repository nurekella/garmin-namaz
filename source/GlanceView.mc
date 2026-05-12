using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

// Minimal glance: only the app title is shown (rendered by the system
// from manifest AppName). User reported the prior glance content was
// read as the launcher name and confused them — kept this stub so the
// glance carousel still works as a tap-target, no custom drawing.
(:glance)
class GlanceView extends WatchUi.GlanceView {

    function initialize(calc, location) {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.COLOR_BG, Theme.COLOR_BG);
        dc.clear();

        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                    Graphics.FONT_MEDIUM, "Namaz KZ",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
