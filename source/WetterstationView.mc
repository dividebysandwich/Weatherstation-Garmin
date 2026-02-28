import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Math;
import Toybox.Lang;

class WetterstationView extends WatchUi.View {
    var sd = null;
    var refreshTimer = null;

    private var _indicator as PageIndicator;

    public function initialize() {
        View.initialize();
        var size = 4;
        var notSelected = Graphics.COLOR_DK_GRAY;
        var selected = Graphics.COLOR_LT_GRAY;
        var alignment = $.ALIGN_BOTTOM_CENTER;
        var margin = 3;
        _indicator = new $.PageIndicator(size, selected, notSelected, alignment, margin);
    }

    function onLayout(dc as Dc) as Void {
        if (System.getDeviceSettings().screenHeight == 360) {
            setLayout(Rez.Layouts.MainLayout(dc));
        } else if (System.getDeviceSettings().screenHeight == 416) {
            setLayout(Rez.Layouts.MainLayout_Epix(dc));
        }
    }

    function onUpdate(dc as Dc) as Void {
        View.onUpdate(dc);
        
        if (sd != null && sd.getData() != null && !sd.getData().isEmpty()) {
            var angle = Math.toRadians(sd.getCurWindDirection());
            var windspeedkmh = sd.getCurWindSpeed().toFloat();
            var windgustkmh = sd.getCurWindGusts().toFloat();
            
            // Dynamically scale layout based on screen resolution
            var cx = System.getDeviceSettings().screenWidth / 2.0;
            var cy = System.getDeviceSettings().screenHeight / 2.0;
            var scaleFactor = cx / 180.0; 
            
            // Push the ring out to use available space
            var radius = cx * 0.88; 

            // Background Rings & Compass Labels
            dc.setPenWidth(2);
            dc.setColor(Graphics.createColor(60, 100, 100, 115), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, radius);
            dc.drawCircle(cx, cy, radius * 0.7);

            var textGray = Graphics.createColor(255, 150, 150, 160);
            dc.setColor(textGray, Graphics.COLOR_TRANSPARENT);
            
            var fontDir = Graphics.FONT_SYSTEM_TINY;
            var fontHeightOffset = dc.getFontHeight(fontDir) / 2.0;
            
            // Place labels perfectly between the two circles (radius * 0.85)
            var labelRadius = radius * 0.85;
            dc.drawText(cx, cy - labelRadius - fontHeightOffset, fontDir, "N", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, cy + labelRadius - fontHeightOffset, fontDir, "S", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx - labelRadius, cy - fontHeightOffset, fontDir, "W", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + labelRadius, cy - fontHeightOffset, fontDir, "E", Graphics.TEXT_JUSTIFY_CENTER);

            // Wind Direction Heatmap
            if (sd has :getWindDirs) {
                var windDirs = sd.getWindDirs();
                if (windDirs != null && windDirs instanceof Array) {
                    dc.setPenWidth(6 * scaleFactor);
                    var heatmapColor = Graphics.createColor(105, 0, 173, 181); 
                    dc.setColor(heatmapColor, Graphics.COLOR_TRANSPARENT);

                    for (var i = 0; i < windDirs.size(); i++) {
                        var dir = windDirs[i].toFloat();
                        var startAngle = 90.0 - (dir + 5.0);
                        var endAngle = 90.0 - (dir - 5.0);
                        
                        while (startAngle < 0) { startAngle += 360.0; }
                        while (endAngle < 0) { endAngle += 360.0; }
                        
                        dc.drawArc(cx, cy, radius - (4.0 * scaleFactor), Graphics.ARC_COUNTER_CLOCKWISE, startAngle, endAngle);
                    }
                }
            }

            // Dynamic Wind Arrow
            var arrowheight = radius * 1.55; 
            var thickness = 10.0;
            var arrowColor;

            if (windgustkmh < 3) {
                thickness = 12.0 * scaleFactor;
                arrowColor = Graphics.createColor(255, 150, 150, 150);
            } else if (windgustkmh <= 6) {
                thickness = 16.0 * scaleFactor;
                arrowColor = Graphics.createColor(255, 80, 220, 100);
            } else if (windgustkmh < 20) {
                thickness = 26.0 * scaleFactor;
                arrowColor = Graphics.createColor(255, 170, 220, 50);
            } else if (windgustkmh < 25) {
                thickness = 32.0 * scaleFactor;
                arrowColor = Graphics.createColor(255, 240, 180, 50);
            } else if (windgustkmh < 30) {
                thickness = 38.0 * scaleFactor;
                arrowColor = Graphics.createColor(255, 255, 120, 50);
            } else {
                thickness = 42.0 * scaleFactor;
                arrowColor = Graphics.createColor(255, 255, 50, 50);
            }

            var coord = new [4];
            coord[0] = [0, -arrowheight / 2.0];
            coord[1] = [-thickness, arrowheight / 2.0];
            coord[2] = [0, (arrowheight / 2.0) - (12.0 * scaleFactor + (thickness / 4.0))];
            coord[3] = [thickness, arrowheight / 2.0];

            var rotatedCoords = new [4];
            for(var i=0; i<4; i++) {
                var rx = coord[i][0] * Math.cos(angle) - coord[i][1] * Math.sin(angle);
                var ry = coord[i][0] * Math.sin(angle) + coord[i][1] * Math.cos(angle);
                rotatedCoords[i] = [rx + cx, ry + cy];
            }

            dc.setColor(arrowColor, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(rotatedCoords);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for(var i=0; i<4; i++) {
                var next = (i + 1) % 4;
                dc.drawLine(rotatedCoords[i][0], rotatedCoords[i][1], rotatedCoords[next][0], rotatedCoords[next][1]);
            }

            // Bottom Dashboard Box for Wind Speed and Temperature
            var speedStr = sd.getCurWindSpeed() + " km/h";
            var tempStr = sd.getCurTemperature() + " °C";
            var fontSpd = Graphics.FONT_SYSTEM_SMALL;
            var fontTmp = Graphics.FONT_SYSTEM_XTINY;
            
            var sw = dc.getTextWidthInPixels(speedStr, fontSpd);
            var tw = dc.getTextWidthInPixels(tempStr, fontTmp);
            var boxW = (sw > tw ? sw : tw) + 24 * scaleFactor;
            var spdH = dc.getFontHeight(fontSpd);
            var tmpH = dc.getFontHeight(fontTmp);
            var boxH = spdH + tmpH - (4 * scaleFactor);
            
            // Move the dashboard box to the bottom half of the inner circle
            var boxCenterY = cy + (radius * 0.45); 

            // Draw semi-transparent background box (Alpha set to 160 for better see-through)
            dc.setColor(Graphics.createColor(160, 24, 24, 28), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - boxW/2, boxCenterY - boxH/2, boxW, boxH, 8);
            
            // Draw Text
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, boxCenterY - boxH/2 - (2 * scaleFactor), fontSpd, speedStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.createColor(255, 180, 180, 180), Graphics.COLOR_TRANSPARENT); // Light gray for temp
            dc.drawText(cx, boxCenterY - boxH/2 + spdH - (6 * scaleFactor), fontTmp, tempStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Gust Warning (Dynamic overlay if gusts are high)
            if (windgustkmh > (windspeedkmh + 10.0)) {
                var gustStr = "Gust " + sd.getCurWindGusts() + " km/h";
                var gFont = Graphics.FONT_SYSTEM_XTINY;
                var gw = dc.getTextWidthInPixels(gustStr, gFont) + 16;
                var gh = dc.getFontHeight(gFont) + 4;
                var gy = boxCenterY - boxH/2 - gh - (4 * scaleFactor); // Positioned just above the dashboard box
                
                // Slightly more opaque background for the warning
                dc.setColor(Graphics.createColor(180, 24, 24, 28), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - gw/2, gy, gw, gh, 6);
                
                dc.setColor(Graphics.createColor(255, 255, 46, 99), Graphics.COLOR_TRANSPARENT); // Neon Pink/Red
                dc.drawText(cx, gy + 2, gFont, gustStr, Graphics.TEXT_JUSTIFY_CENTER);
            }

            _indicator.draw(dc, 0);
        }
    }

    function onShow() as Void {
        var wi = WebcamImage.getWebcamInstance();
        if (wi != null and (wi.getWebcamImage2() == null || wi.isWebcamImageCurrent() == false)) {
            wi.updateWebcamImages();
        }

        sd = WeatherData.getWeatherData();
        refreshTimer = new Timer.Timer();
        refreshTimer.start(method(:timerCallback), 3000, true);
        System.println("Timer started");
    }

    function timerCallback() as Void {
        sd.requestUpdate();
    }

    function onHide() as Void {
        System.println("Timer stopping");
        if (refreshTimer != null) {
            refreshTimer.stop();
        }
    }
}

class WetterstationViewDelegate extends WatchUi.BehaviorDelegate {

    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onNextPage() as Boolean {
        WatchUi.switchToView(new $.Webcam1View(), new $.Webcam1ViewDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    public function onPreviousPage() as Boolean {
        WatchUi.switchToView(new $.Webcam3View(), new $.Webcam3ViewDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }
}