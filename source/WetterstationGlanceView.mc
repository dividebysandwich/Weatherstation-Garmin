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
                var curvalue = 0;
                var histogram = null;
                var linecolor = null;
                var gridInterval = 500;
                var maxValue = 0.1;
                var minValue = 0.0;
                var dataoffset = 0;
                var offset = 0;

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
                    minValue = sd.getMinValue(histogram);
                    
                    // Ensure we have some padding and include 0 in the range
                    if (maxValue < 5) { maxValue = 5.0; }
                    if (minValue > -5) { minValue = -5.0; }
                } else if (mode == 4) {
                    curvalue = sd.getCurRain() + " mm/m²";
                    histogram = sd.getRainHistogram();
                    linecolor = Graphics.COLOR_BLUE;
                    maxValue = sd.getMaxValue(histogram);
                    if (maxValue < 1) { maxValue = 1.0; }
                    gridInterval = 1;
                    minValue = 0;
                }

                var yOffset = 2;
                var totalRange = (maxValue - minValue).toFloat();
                if (totalRange == 0) { totalRange = 1.0; } 
                
                var chartAreaHeight = dc.getHeight() - (yOffset * 2);

                //Draw the background grid lines
           	    bitmapDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
                for (var a = gridInterval; a < maxValue; a+=gridInterval) {
                    var y = a.toFloat() / maxValue.toFloat() * (dc.getHeight() - 2);
                    bitmapDc.drawLine(offset, dc.getHeight() - 2 - y, dc.getWidth()-1, dc.getHeight() - 2 - y);
                }

                // Calculate the Y coordinate for the 0-degree line
                // We use the ratio: (Value - Min) / TotalRange
                var zeroY = (dc.getHeight() - yOffset) - ((0.0 - minValue) / totalRange * chartAreaHeight);

                // --- 2. Draw the Zero Line (The Axis) ---
                bitmapDc.setPenWidth(1);
                bitmapDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                bitmapDc.drawLine(0, zeroY.toNumber(), dc.getWidth(), zeroY.toNumber());

                // --- 3. Fill shaded area (Filling to zeroY) ---
                var zoomFactor = 2.0;
                if (System.getDeviceSettings().screenHeight > 416) { zoomFactor = 2.27; }

                for (var x = 0; x < (histogram.size() * zoomFactor) - dataoffset; x++) {
                    var alpha = 30 + (x / 2);
                    if (alpha > 90) { alpha = 90; }

                    var val = histogram[((x + dataoffset) / zoomFactor).toNumber()].toFloat();
                    // Map the temperature value to a screen Y coordinate
                    var yVal = (dc.getHeight() - yOffset) - ((val - minValue) / totalRange * chartAreaHeight);
                    
                    if (mode <= 2) {
               	        bitmapDc.setFill(Graphics.createColor(alpha, 255, 255, 0));
       	                bitmapDc.setStroke(Graphics.createColor(alpha, 255, 255, 0));
                    } else if (mode == 3) {
                        // Dynamic color: Blue for freezing, Green for warm
                        if (val < 0) {
                            bitmapDc.setStroke(Graphics.createColor(alpha, 0, 150, 255));
                        } else {
                            bitmapDc.setStroke(Graphics.createColor(alpha, 0, 255, 0));
                        }
                    } else if (mode == 4) {
               	        bitmapDc.setFill(Graphics.createColor(alpha, 0, 0, 255));
       	                bitmapDc.setStroke(Graphics.createColor(alpha, 0, 0, 255));
                    }

                    // DRAWING THE FILL: Vertical line from the curve point to the Zero Line
                    bitmapDc.drawLine(x + offset, yVal.toNumber(), x + offset, zeroY.toNumber());
                }

                // --- 4. Re-draw Zero Line on top of fill for clarity ---
                bitmapDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                bitmapDc.drawLine(0, zeroY.toNumber(), dc.getWidth(), zeroY.toNumber());

                // --- 5. Draw the Curve Line ---
                bitmapDc.setPenWidth(2);
                bitmapDc.setColor(linecolor, Graphics.COLOR_BLACK);
                for (var x = 2; x < (histogram.size() * zoomFactor) - dataoffset; x += 2) {
                    var valPrev = histogram[((x + dataoffset - 2) / zoomFactor).toNumber()].toFloat();
                    var valCurr = histogram[((x + dataoffset) / zoomFactor).toNumber()].toFloat();
                    
                    var yPrev = (dc.getHeight() - yOffset) - ((valPrev - minValue) / totalRange * chartAreaHeight);
                    var yCurr = (dc.getHeight() - yOffset) - ((valCurr - minValue) / totalRange * chartAreaHeight);
                    
                    bitmapDc.drawLine(x + offset - 2, yPrev.toNumber(), x + offset, yCurr.toNumber());
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
