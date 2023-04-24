import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Math;

class WetterstationView extends WatchUi.View {
    var sd = null;
    var refreshTimer = null;

    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        if (System.getDeviceSettings().screenHeight == 360) {
            setLayout(Rez.Layouts.MainLayout(dc));
        } else if (System.getDeviceSettings().screenHeight == 416) {
            setLayout(Rez.Layouts.MainLayout_Epix(dc));
        }
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        if (sd != null && sd.getData() != null && !sd.getData().isEmpty()) {
            var angle = Math.toRadians(sd.getCurWindDirection());
            var windspeedkmh = sd.getCurWindGusts().toFloat();
            var arrowwidth = 240;
            var arrowheight = 240;
            var arrowimagewidth = 360;
            var arrowimageheight = 360;
            var thickness = 10;
            var sizefactor = 4;

            if (windspeedkmh < 3)
            {
                thickness = 7;
    	        dc.setFill(Graphics.createColor(255, 80, 80, 80));
                dc.setStroke(Graphics.createColor(255, 50, 50, 50));
            }
            else if (windspeedkmh <= 6)
            {
                thickness = 10;
    	        dc.setFill(Graphics.createColor(255, 50, 255, 50));
                dc.setStroke(Graphics.createColor(255, 30, 230, 30));
            }
            else if (windspeedkmh < 10)
            {
                thickness = 13;
    	        dc.setFill(Graphics.createColor(255, 80, 200, 50));
                dc.setStroke(Graphics.createColor(255, 60, 180, 30));
            }
            else if (windspeedkmh < 15)
            {
                thickness = 15;
    	        dc.setFill(Graphics.createColor(255, 170, 150, 50));
                dc.setStroke(Graphics.createColor(255, 150, 130, 30));
            }
            else if (windspeedkmh < 20)
            {
                thickness = 18;
    	        dc.setFill(Graphics.createColor(255, 185, 185, 50));
                dc.setStroke(Graphics.createColor(255, 155, 155, 30));
            }
            else
            {
                thickness = 20;
    	        dc.setFill(Graphics.createColor(255, 255, 50, 50));
                dc.setStroke(Graphics.createColor(255, 235, 30, 30));
            }


            // Define Arrow
            var coord = new [5];
            coord[0] = [0,-arrowheight/2];
            coord[1] = [-thickness*sizefactor,arrowheight/2];
            coord[2] = [0,(arrowheight/2)-(10+(thickness/4))*sizefactor];
            coord[3] = [+thickness*sizefactor,arrowheight/2];
            coord[4] = [0,-arrowheight/2];

            // Rotate the arrow coordinates
            var xoffset = (416-arrowimagewidth)/2;
            var yoffset = (416-arrowimageheight)/2;
            for(var i=0; i<5; i++) {
                var x = coord[i][0];
                var y = coord[i][1];
                coord[i][0] = x*Math.cos(angle) - y*Math.sin(angle) + arrowimagewidth/2 + xoffset;
                coord[i][1] = x*Math.sin(angle) + y*Math.cos(angle) + arrowimageheight/2 + yoffset;
            }

            // Draw the arrow
            dc.fillPolygon(coord);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(208, 360, Graphics.FONT_SYSTEM_TINY, sd.getCurTemperature()+" °C", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(208, 10, Graphics.FONT_SYSTEM_TINY, sd.getCurWindGusts()+" km/h", Graphics.TEXT_JUSTIFY_CENTER);

        }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        sd = WeatherData.getWeatherData();
        refreshTimer = new Timer.Timer();
        refreshTimer.start(method(:timerCallback), 3000, true);
        System.println("Timer started");

    }

    function timerCallback() {
        sd.requestUpdate();
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        System.println("Timer stopping");
        if (refreshTimer != null) {
            refreshTimer.stop();
        }
    }

}
