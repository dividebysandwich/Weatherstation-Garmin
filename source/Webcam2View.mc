import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Math;
import Toybox.Lang;

class Webcam2View extends WatchUi.View {
    var wi = null;

    private var _indicator as PageIndicator;

    public function initialize() {
        View.initialize();
        var size = 3;
        var notSelected = Graphics.COLOR_DK_GRAY;
        var selected = Graphics.COLOR_LT_GRAY;
        var alignment = $.ALIGN_BOTTOM_CENTER;
        var margin = 3;
        _indicator = new $.PageIndicator(size, selected, notSelected, alignment, margin);
    }

    function onLayout(dc as Dc) as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        System.println("webcam2 view onUpdate");
        if (wi != null and wi.getWebcamImage2() != null) {
            // Draw the arrow
            dc.drawBitmap(0, (System.getDeviceSettings().screenHeight - (System.getDeviceSettings().screenHeight/wi.getAspectRatio())) / 2 , wi.getWebcamImage2()); 
        } else if (wi.getPrevResponseCode() == 200 or wi.getPrevResponseCode() == 101){
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(System.getDeviceSettings().screenWidth / 2, 10, Graphics.FONT_SYSTEM_TINY, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(System.getDeviceSettings().screenWidth / 2, 10, Graphics.FONT_SYSTEM_TINY, "Error "+wi.getPrevResponseCode().toString(), Graphics.TEXT_JUSTIFY_CENTER);
        }
        _indicator.draw(dc, 2);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        wi = WebcamImage.getWebcamInstance();
        WatchUi.requestUpdate();
        if (wi != null and (wi.getWebcamImage2() == null || wi.isWebcamImageCurrent() == false)) {
            wi.updateWebcamImages();
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

}


class Webcam2ViewDelegate extends WatchUi.BehaviorDelegate {

    public function initialize() {
        BehaviorDelegate.initialize();
    }

    //! Handle going to the next view
    //! @return true if handled, false otherwise
    public function onNextPage() as Boolean {
        WatchUi.switchToView(new $.WetterstationView(), new $.WetterstationViewDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! Handle going to the previous view
    //! @return true if handled, false otherwise
    public function onPreviousPage() as Boolean {
        WatchUi.switchToView(new $.Webcam1View(), new $.Webcam1ViewDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }
}
