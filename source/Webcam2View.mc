import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Math;
import Toybox.Lang;

class Webcam2View extends WatchUi.View {
    var refreshTimer = null;
    var prevResponseCode = 200;
    var aspectRatio = 1.4;
    var sd = null;

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
        System.println("webcam2 view onUpdate");
        if (sd != null and sd.getWebcamImage2() != null) {
            // Draw the arrow
            dc.drawBitmap(0, (System.getDeviceSettings().screenHeight - (System.getDeviceSettings().screenHeight/aspectRatio)) / 2 , sd.getWebcamImage2()); 
        } else if (prevResponseCode == 200 ){
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(System.getDeviceSettings().screenWidth / 2, 10, Graphics.FONT_SYSTEM_TINY, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(System.getDeviceSettings().screenWidth / 2, 10, Graphics.FONT_SYSTEM_TINY, "Error!", Graphics.TEXT_JUSTIFY_CENTER);
        }
        _indicator.draw(dc, 2);
    }

    
    function imageResponseCallback2(responseCode as Number, data as Null or BitmapReference or BitmapResource) as Void {
        System.println("Image request response: " + responseCode.toString());
        prevResponseCode = responseCode;
        if (responseCode == 200) {
            sd.setWebcamImage2(data);
            WatchUi.requestUpdate();        
        }
    }
    
    function requestWebcamImage() {
        var url = "https://mc-boeheimkirchen.at/webcam2.php";
        var parameters = null;
        var options = {
            :maxWidth => System.getDeviceSettings().screenWidth,
            :maxHeight => (System.getDeviceSettings().screenHeight/aspectRatio).toNumber(),
            :dithering => Communications.IMAGE_DITHERING_NONE,
            :packingFormat => Communications.PACKING_FORMAT_JPG
        };
        System.println("Requesting webcam2 image...");

        // Make the image request
        Communications.makeImageRequest(url, parameters, options, self.method(:imageResponseCallback2));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        sd = WeatherData.getWeatherData();
        WatchUi.requestUpdate();
        if (sd != null and (sd.getWebcamImage2() == null || sd.isWebcamImage2Current() == false)) {
            requestWebcamImage();
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
