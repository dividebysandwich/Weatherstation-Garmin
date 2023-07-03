import Toybox.System;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Math;

class WebcamImage {
    static var instance = null;
    var webcamImage1 = null;
    var webcamImage2 = null;
    var webcamImageUpdateTime = 0;
    var prevResponseCode = 200;
    var aspectRatio = 1.4;
    var update1InProgress = false;
    var update2InProgress = false;

    function initialize() {
    }

    function imageResponseCallback1(responseCode as Number, data as Null or BitmapReference or BitmapResource) as Void {
        System.println("Image 1 request response: " + responseCode.toString());
        prevResponseCode = responseCode;
        if (responseCode == 200) {
            setWebcamImage1(data);
            WatchUi.requestUpdate();        
        }
        update1InProgress = false;
    }

    function imageResponseCallback2(responseCode as Number, data as Null or BitmapReference or BitmapResource) as Void {
        System.println("Image 2 request response: " + responseCode.toString());
        prevResponseCode = responseCode;
        if (responseCode == 200) {
            setWebcamImage2(data);
            WatchUi.requestUpdate();        
        }
        update2InProgress = false;
    }

    function requestWebcamImage(webcamID as Number) {
        var url = "https://mc-boeheimkirchen.at/webcam.php";
        if (webcamID == 2) {
            url = "https://mc-boeheimkirchen.at/webcam2.php";
        }
        var parameters = null;
        var options = {
            :maxWidth => System.getDeviceSettings().screenWidth,
            :maxHeight => (System.getDeviceSettings().screenHeight/aspectRatio).toNumber(),
            :dithering => Communications.IMAGE_DITHERING_NONE,
            :packingFormat => Communications.PACKING_FORMAT_JPG
        };
        System.println("Requesting webcam image "+webcamID.toString());

        // Make the image request
        if (webcamID == 1) {
            Communications.makeImageRequest(url, parameters, options, self.method(:imageResponseCallback1));
        } else if (webcamID == 2) { 
            Communications.makeImageRequest(url, parameters, options, self.method(:imageResponseCallback2));
        }
    }

    public function updateWebcamImages() {
        if (!update1InProgress and !update2InProgress) {
            update1InProgress = true;
            requestWebcamImage(1);
            update2InProgress = true;
            requestWebcamImage(2);
        }
    }

    public function setWebcamImage1(image as Toybox.Graphics.BufferedBitmap?) {
        webcamImage1 = image;
        webcamImageUpdateTime = Time.now().value();
    }

    public function setWebcamImage2(image as Toybox.Graphics.BufferedBitmap?) {
        webcamImage2 = image;
        webcamImageUpdateTime = Time.now().value();
    }


    public function getWebcamImage1() as Toybox.Graphics.BufferedBitmap? {
        return webcamImage1;
    }

    public function getWebcamImage2() as Toybox.Graphics.BufferedBitmap? {
        return webcamImage2;
    }

    public function isWebcamImageCurrent() as Boolean {
        if (Time.now().value() > webcamImageUpdateTime + 300) {
            return false;
        }
        return true;
    }

    public function getPrevResponseCode() as Number {
        return prevResponseCode;
    }

    public function getAspectRatio () as Number {
        return aspectRatio;
    }

    public static function getWebcamInstance() {
        if (WebcamImage.instance == null) {
            WebcamImage.instance = new WebcamImage();
        }
        return WebcamImage.instance;
    }

}

