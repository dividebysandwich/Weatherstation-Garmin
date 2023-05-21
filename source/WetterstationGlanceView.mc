import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;

(:glance)
class WetterstationGlanceView extends WatchUi.GlanceView {
    var sd = null;
    var refreshTimer = null;

    function initialize() {
        GlanceView.initialize();
        sd = WeatherData.getWeatherData();
        sd.setMode(5);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        GlanceView.onUpdate(dc);
        if (sd != null && sd.getData() != null && !sd.getData().isEmpty()) {
            
            // If we don't have a cached buffer bitmap, redraw and cache it
            if (sd.getGlanceBitmap() == null) {
                var mode = sd.getMode();
                mode++;
                if (mode > 4) {
                    mode = 1;
                }
                sd.setMode(mode);

//                if (sd.getCurRain().toFloat() > 0.0) {
//                    GlanceView.setGlanceBitmap(GlanceView.findDrawableById("RainIcon"));
//                }

                // Create image buffer
                var bitmapOpts = {
                    :width => dc.getWidth(),
                    :height => dc.getHeight()
                };
                var bitmap = Graphics has :createBufferedBitmap ?
                    Graphics.createBufferedBitmap(bitmapOpts).get() as BufferedBitmap :
                new Graphics.BufferedBitmap(bitmapOpts);
                var bitmapDc = bitmap.getDc();
                bitmapDc.clearClip();
                bitmapDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                bitmapDc.clear();

                // Prepare data
                var temperature = sd.getCurTemperature();
                var curvalue = 0;
                var histogram = null;
                var linecolor = null;
                var gridInterval = 500;
                var maxValue = 0.1;
                var minValue = 0;
                if (mode <= 2) {
                    histogram = sd.getWindGustsHistogram();
                    linecolor = Graphics.COLOR_YELLOW;
                    curvalue = sd.getCurWindGusts() + " km/h";
                    gridInterval = 5;
                    maxValue = sd.getMaxValue(histogram);
                    if (maxValue < 30) {
                        maxValue = 30;
                    }
                } else if (mode == 3) {
                    histogram = sd.getTemperatureHistogram();
                    linecolor = Graphics.COLOR_GREEN;
                    curvalue = sd.getCurTemperature() + " °C";
                    gridInterval = 5;
                    maxValue = sd.getMaxValue(histogram);
                    minValue = sd.getMinValue(histogram).abs();
                    if (maxValue < minValue) {
                        maxValue = minValue;
                    }
                } else if (mode == 4) {
                    curvalue = sd.getCurRain() + " mm/m²";
                    histogram = sd.getRainHistogram();
                    linecolor = Graphics.COLOR_BLUE;
                    maxValue = sd.getMaxValue(histogram);
                    if (maxValue < 1) {
                        maxValue = 1.0;
                    }
                    gridInterval = 1;
                    //Only show the negative axis of the graph if there was energy flowing back to the grid
                }

                if (maxValue == 0) {
                    maxValue = 0.01;
                }

                //Draw the background grid lines
                var offset = 0;
                var dataoffset = 0;
           	    bitmapDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
                for (var a = gridInterval; a < maxValue; a+=gridInterval) {
                    var y = a.toFloat() / maxValue.toFloat() * (dc.getHeight() - 2);
                    bitmapDc.drawLine(offset, dc.getHeight() - 2 - y, dc.getWidth()-1, dc.getHeight() - 2 - y);
                }

                //Axis line
           	    bitmapDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
      	        bitmapDc.drawLine(offset, dc.getHeight()-1, dc.getWidth(), dc.getHeight()-1);
       	        bitmapDc.setFill(Graphics.createColor(30 , 255, 255, 255));
                bitmapDc.setStroke(Graphics.createColor(30, 255, 255, 255));
                for (var x = offset; x < dc.getWidth(); x+=20) {
                    bitmapDc.drawLine(x, 0, x, dc.getHeight());
                }

                // Fill shaded area under the curve
                for (var x = 0; x < histogram.size()*2-dataoffset; x++) {
                    var alpha = 30 + (x/2);
                    if (mode <= 2) {
               	        bitmapDc.setFill(Graphics.createColor(alpha, 255, 255, 0));
       	                bitmapDc.setStroke(Graphics.createColor(alpha, 255, 255, 0));
                    } else if (mode == 3) {
               	        bitmapDc.setFill(Graphics.createColor(alpha, 0, 255, 0));
       	                bitmapDc.setStroke(Graphics.createColor(alpha, 0, 255, 0));
                    } else if (mode == 4) {
               	        bitmapDc.setFill(Graphics.createColor(alpha, 0, 0, 255));
       	                bitmapDc.setStroke(Graphics.createColor(alpha, 0, 0, 255));
                    }
                    var height = histogram[(x+dataoffset)/2].toFloat() / maxValue.toFloat() * (dc.getHeight().toFloat() - 2.0f);
                    if (height < 0) {
                        height = 0;
                    }
                    bitmapDc.drawLine(x+1+offset, dc.getHeight()-1-height.toNumber(), x+1+offset, dc.getHeight()-1);
                }

                // Draw the curve itself
                bitmapDc.setPenWidth(2);
        	    bitmapDc.setColor(linecolor, Graphics.COLOR_BLACK);

                for (var x = 1; x < histogram.size()*2-dataoffset; x+=2) {
                    var heightprev = histogram[(x+dataoffset-2)/2].toFloat() / maxValue.toFloat() * (dc.getHeight().toFloat() - 2.0f);
                    var height = histogram[(x+dataoffset)/2].toFloat() / maxValue.toFloat() * dc.getHeight().toFloat() - 2.0f;
                    if (heightprev < 0) {
                        heightprev = 0;
                    }
                    if (height < 0) {
                        height = 0;
                    }
                    bitmapDc.drawLine(x+offset, dc.getHeight()-1-heightprev.toNumber(), x+1+offset, dc.getHeight()-1-height.toNumber());

                }

                var dim = bitmapDc.getTextDimensions(curvalue, Graphics.FONT_SYSTEM_TINY);
       	        bitmapDc.setFill(Graphics.createColor(160, 0, 0, 0));
                bitmapDc.fillRectangle(15, 58, dim[0]+6, dim[1]);
                // Draw text for Temperature
                bitmapDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
                bitmapDc.drawText(18+1, 58+1, Graphics.FONT_SYSTEM_TINY, curvalue, Graphics.TEXT_JUSTIFY_LEFT);
//                bitmapDc.drawText(dc.getWidth()-5+1, 66+1, Graphics.FONT_SYSTEM_XTINY, curvalue, Graphics.TEXT_JUSTIFY_RIGHT);
                bitmapDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                bitmapDc.drawText(18, 58, Graphics.FONT_SYSTEM_TINY, curvalue, Graphics.TEXT_JUSTIFY_LEFT);
//                bitmapDc.drawText(dc.getWidth()-5, 66, Graphics.FONT_SYSTEM_XTINY, curvalue, Graphics.TEXT_JUSTIFY_RIGHT);

                // Battery SOC bar
/*                for (var y = dc.getHeight(); y > dc.getHeight() - (soc.toFloat()/100.0f * dc.getHeight()); y-=1) {
                    var alpha = 255 - y + 180;
                    bitmapDc.setFill(Graphics.createColor(alpha, 0, 0, 255));
                    bitmapDc.setStroke(Graphics.createColor(alpha, 0, 0, 255));
                    bitmapDc.drawLine(0, y, 10, y);
                }*/

                // Cache image so we don't redraw all the time
                sd.setGlanceBitmap(bitmap);
            }

            // Draw buffer bitmap on screen
            dc.drawBitmap(0, 0, sd.getGlanceBitmap());
        }
    }


    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        sd = WeatherData.getWeatherData();
        refreshTimer = new Timer.Timer();
        refreshTimer.start(method(:timerCallback), 2000, true);
        System.println("Timer started");

    }

    function timerCallback() as Void{
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
