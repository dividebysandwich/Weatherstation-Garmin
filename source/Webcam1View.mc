import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Math;
import Toybox.Lang;

class Webcam1View extends WatchUi.View {
    var webcamImage = null;
    var refreshTimer = null;
    var prevResponseCode = 200;
    var aspectRatio = 1.4;

    private var _indicator as PageIndicator;

    public function initialize() {
        View.initialize();
        var size = 2;
        var selected = Graphics.COLOR_DK_GRAY;
        var notSelected = Graphics.COLOR_LT_GRAY;
        var alignment = $.ALIGN_TOP_RIGHT;
        var margin = 10;
        _indicator = new $.PageIndicator(size, selected, notSelected, alignment, margin);
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
/*        if (System.getDeviceSettings().screenHeight == 360) {
            setLayout(Rez.Layouts.MainLayout(dc));
        } else if (System.getDeviceSettings().screenHeight == 416) {
            setLayout(Rez.Layouts.MainLayout_Epix(dc));
        }*/
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        System.println("webcam1 view onUpdate");
        if (webcamImage != null) {
            // Draw the arrow
            dc.drawBitmap(0, (System.getDeviceSettings().screenHeight - (System.getDeviceSettings().screenHeight/aspectRatio)) / 2 , webcamImage); 
        } else if (prevResponseCode == 200 ){
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(System.getDeviceSettings().screenWidth / 2, 10, Graphics.FONT_SYSTEM_TINY, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(System.getDeviceSettings().screenWidth / 2, 10, Graphics.FONT_SYSTEM_TINY, "Error!", Graphics.TEXT_JUSTIFY_CENTER);
        }
        _indicator.draw(dc, 1);
    }

    
    function imageResponseCallback(responseCode as Number, data as Null or BitmapReference or BitmapResource) as Void {
        System.println("Image request response: " + responseCode.toString());
        prevResponseCode = responseCode;
        if (responseCode == 200) {
            webcamImage = data;
            WatchUi.requestUpdate();        
        } else {
            webcamImage = null;
        }
    }
    
    function requestWebcamImage() {
        var url = "https://mc-boeheimkirchen.at/webcam.php";
        var parameters = null;
        var options = {
            :maxWidth => System.getDeviceSettings().screenWidth,
            :maxHeight => (System.getDeviceSettings().screenHeight/aspectRatio).toNumber(),
            :dithering => Communications.IMAGE_DITHERING_NONE,
            :packingFormat => Communications.PACKING_FORMAT_JPG
        };
        System.println("Requesting webcam image...");

        // Make the image request
        Communications.makeImageRequest(url, parameters, options, self.method(:imageResponseCallback));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        WatchUi.requestUpdate();        
        requestWebcamImage();
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

}


class Webcam1ViewDelegate extends WatchUi.BehaviorDelegate {

    public function initialize() {
        BehaviorDelegate.initialize();
    }

    //! Handle going to the next view
    //! @return true if handled, false otherwise
    public function onNextPage() as Boolean {
        WatchUi.switchToView(new $.Webcam2View(), new $.Webcam2ViewDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! Handle going to the previous view
    //! @return true if handled, false otherwise
    public function onPreviousPage() as Boolean {
        WatchUi.switchToView(new $.WetterstationView(), new $.WetterstationViewDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }
}
