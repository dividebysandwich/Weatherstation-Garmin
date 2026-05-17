import Toybox.System;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;

class AdsbData {
    static var instance = null;
    var lastSnapshot = null;
    var lastUpdateTime = 0;
    var lastResponseCode = 0;
    var requestInProgress = false;
    var zoomIndex = 0;

    function initialize() {
        makeRequest();
    }

    public function getZoomNm() as Float {
        if (zoomIndex == 1) { return 10.0; }
        if (zoomIndex == 2) { return 5.0; }
        return 25.0;
    }

    public function cycleZoom() as Void {
        zoomIndex = (zoomIndex + 1) % 3;
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        requestInProgress = false;
        lastResponseCode = responseCode;
        if (responseCode == 200 && data != null) {
            lastUpdateTime = Time.now().value();
            lastSnapshot = data;
            WatchUi.requestUpdate();
        } else {
            System.println("ADS-B response: " + responseCode);
        }
    }

    public function requestUpdate() as Void {
        if (Time.now().value() > lastUpdateTime + 4) {
            makeRequest();
        }
    }

    protected function makeRequest() as Void {
        if (requestInProgress) { return; }
        requestInProgress = true;
        var url = "https://mc-boeheimkirchen.at/adsb/snapshot";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, {}, options, method(:onReceive));
    }

    public function getSnapshot() {
        return lastSnapshot;
    }

    public function getLastResponseCode() as Number {
        return lastResponseCode;
    }

    public function getLastUpdateTime() as Number {
        return lastUpdateTime;
    }

    public static function getAdsbData() {
        if (AdsbData.instance == null) {
            AdsbData.instance = new AdsbData();
        }
        return AdsbData.instance;
    }
}
