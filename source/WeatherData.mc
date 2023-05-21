import Toybox.System;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Application.Storage;

(:glance)
class WeatherData {
    static var instance = null;
    var lastData;
    var lastUpdateTime = 0;
    var view;
    var glanceBitmap = null;
    var forceRefreshOnReload = false;
    var mode = 5;

    function initialize() {
        // Get last data snapshot from application storage so we have something to show immediately on startup.
        // It will be updated once the HTTP request finishes.
        lastData = Storage.getValue("lastStationData");
        lastUpdateTime = Storage.getValue("lastWeatherDataTime");
        forceRefreshOnReload = true; // Make the widget redraw immediately when the first data fetch succeeds.
        makeRequest();
    }

    function setMode(m) {
        mode = m;
    }

    function getMode() {
        return mode;
    }

    // set up the response callback function
    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200) {
            System.println("Request Successful");                   // print success
            if (!data.isEmpty()) { 
                lastUpdateTime = Time.now().value();
                lastData = data;
                // Store data in application storage
                Storage.setValue("lastStationData", lastData);
                Storage.setValue("lastWeatherDataTime", lastUpdateTime);
                if (forceRefreshOnReload == true) {
                    mode = 5; //Make it start at the PV mode on first data load
                    forceRefreshOnReload = false;
                    WatchUi.requestUpdate();
                }
            }
        } else {
            System.println("Response: " + responseCode);            // print response code
        }
        WatchUi.requestUpdate();
    }

    public function requestUpdate() as Void{
        if (Time.now().value() > lastUpdateTime + 20) {
            makeRequest();
        }
        glanceBitmap = null;
        WatchUi.requestUpdate();
    }
    protected function makeRequest() as Void {
        var url = "https://167dgn.airforce/queryWeather";                         // set the url

        var params = {                                              // set the parameters
        };

        var options = {                                             // set the options
            :method => Communications.HTTP_REQUEST_METHOD_GET,      // set HTTP method
            :headers => {                                           // set headers
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
            // set response type
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Make the Communications.makeWebRequest() call
        Communications.makeWebRequest(url, params, options, method(:onReceive));
    }

    public function getData() as Dictionary? {
        return lastData;
    }
    public function getCurWindDirection() {
        return lastData.get("curwinddir").toNumber();
    }
    public function getCurWindSpeed() {
        return lastData.get("curwindspeed").format("%.1f");
    }
    public function getCurWindGusts() {
        return lastData.get("curwindgust").format("%.1f");
    }
    public function getCurRain() {
        return lastData.get("currain").format("%.1f");
    }
    public function getCurQNH() {
        return lastData.get("curqnh").format("%.2f");
    }
    public function getCurTemperature() {
        return lastData.get("curtemperature").format("%.1f");
    }
    public function getCurHumidity() {
        return lastData.get("curhumidity").format("%.1f");
    }
    public function getCurSolarRadiation() {
        return lastData.get("cursolarradiation").format("%.2f");
    }
    public function getWindSpeedHistogram() {
        return lastData.get("windspeeds");
    }
    public function getWindGustsHistogram() {
        return lastData.get("windgusts");
    }
    public function getRainHistogram() {
        return lastData.get("rain");
    }
    public function getTemperatureHistogram() {
        return lastData.get("temperature");
    }
/*    public function getSolarRadiationHistogram() {
        return lastData.get("solarradiation");
    }*/


    public function getGlanceBitmap() as Toybox.Graphics.BufferedBitmap? {
        return glanceBitmap;
    }

    public function setGlanceBitmap(bitmap as Toybox.Graphics.BufferedBitmap?) {
        glanceBitmap = bitmap;
    }

    public function getMaxValue (histogram as Array<Number>?) as Number? {
        var maxValue = 0;
        for (var i=0; i < histogram.size(); i++){
            if (histogram[i] > maxValue) {
                maxValue = histogram[i];
            }
        }
        return maxValue;
    }
    public function getMinValue (histogram as Array<Number>?) as Number? {
        var minValue = 0;
        for (var i=0; i < histogram.size(); i++){
            if (histogram[i] < minValue) {
                minValue = histogram[i];
            }
        }
        return minValue;
    }

    public static function getWeatherData() {
        if (WeatherData.instance == null) {
            WeatherData.instance = new WeatherData();
        }
        return WeatherData.instance;
    }

}

