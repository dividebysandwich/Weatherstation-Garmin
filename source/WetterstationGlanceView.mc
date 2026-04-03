import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Time;

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
                var forecast = null;
                var linecolor = null;
                var gridInterval = 500;
                var maxValue = 0.1;
                var minValue = 0.0;

                if (mode <= 2) {
                    histogram = sd.getWindGustsHistogram();
                    forecast = sd.getForecastWindGusts();
                    linecolor = Graphics.COLOR_YELLOW;
                    curvalue = sd.getCurWindGusts() + " km/h";
                    gridInterval = 5;
                    maxValue = sd.getMaxValue(histogram);
                    if (maxValue < 30) { maxValue = 30; }
                } else if (mode == 3) {
                    histogram = sd.getTemperatureHistogram();
                    forecast = sd.getForecastTemperature();
                    linecolor = Graphics.COLOR_GREEN;
                    curvalue = sd.getCurTemperature() + " °C";
                    gridInterval = 5;
                    maxValue = sd.getMaxValue(histogram);
                    minValue = sd.getMinValue(histogram);
                } else if (mode == 4) {
                    curvalue = sd.getCurRain() + " mm/m²";
                    histogram = sd.getRainHistogram();
                    forecast = sd.getForecastPrecipitation();
                    linecolor = Graphics.COLOR_BLUE;
                    maxValue = sd.getMaxValue(histogram);
                    if (maxValue < 1) { maxValue = 1.0; }
                    gridInterval = 1;
                    minValue = 0;
                }

                // Trim forecast to start at the current hour
                if (forecast != null) {
                    var nowInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
                    var currentHour = nowInfo.hour;
                    if (currentHour < forecast.size()) {
                        forecast = forecast.slice(currentHour, null);
                    }
                }

                // Include sliced forecast in min/max range
                if (forecast != null) {
                    var fMax = sd.getMaxValue(forecast);
                    var fMin = sd.getMinValue(forecast);
                    if (fMax > maxValue) { maxValue = fMax; }
                    if (fMin < minValue) { minValue = fMin; }
                }

                // Apply padding for temperature mode
                if (mode == 3) {
                    if (minValue < 3) { gridInterval = 1; }
                    if (maxValue < 5) { maxValue = 5.0; }
                    if (minValue > -5) { minValue = -5.0; }
                }

                // Calculate section widths: 20% historical, 80% forecast
                var histWidth = (dc.getWidth() * 0.2).toNumber();
                var forecastWidth = dc.getWidth() - histWidth;

                var yOffset = 2;
                var totalRange = (maxValue - minValue).toFloat();
                if (totalRange == 0) { totalRange = 1.0; }

                var chartAreaHeight = dc.getHeight() - (yOffset * 2);

                // Draw the background grid lines
                bitmapDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
                var startGrid = (minValue / gridInterval).toNumber() * gridInterval;
                for (var a = startGrid; a <= maxValue; a += gridInterval) {
                    if (a == 0) { continue; }
                    var yPos = (dc.getHeight() - yOffset) - ((a - minValue) / totalRange * chartAreaHeight);
                    bitmapDc.drawLine(0, yPos.toNumber(), dc.getWidth() - 1, yPos.toNumber());
                }

                // Draw Zero Line
                var zeroY = (dc.getHeight() - yOffset) - ((0.0 - minValue) / totalRange * chartAreaHeight);
                bitmapDc.setPenWidth(1);
                bitmapDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                bitmapDc.drawLine(0, zeroY.toNumber(), dc.getWidth(), zeroY.toNumber());

                // --- Historical fill (left 20%, most recent data) ---
                if (histogram != null && histogram.size() > 0) {
                    var histZoom = 2.0;
                    var histPointsToShow = (histWidth / histZoom).toNumber();
                    if (histPointsToShow > histogram.size()) { histPointsToShow = histogram.size(); }
                    var histDataOffset = histogram.size() - histPointsToShow;
                    for (var x = 0; x < histWidth; x++) {
                        var idx = histDataOffset + (x / histZoom).toNumber();
                        if (idx >= histogram.size()) { idx = histogram.size() - 1; }
                        var alpha = (x / 3);
                        if (alpha > 120) { alpha = 120; }
                        var val = histogram[idx].toFloat();
                        var yVal = (dc.getHeight() - yOffset) - ((val - minValue) / totalRange * chartAreaHeight);

                        if (mode <= 2) {
                            bitmapDc.setFill(Graphics.createColor(alpha, 255, 255, 0));
                            bitmapDc.setStroke(Graphics.createColor(alpha, 255, 255, 0));
                        } else if (mode == 3) {
                            if (val < 0) {
                                bitmapDc.setStroke(Graphics.createColor(alpha, 0, 150, 255));
                            } else {
                                bitmapDc.setStroke(Graphics.createColor(alpha, 0, 255, 0));
                            }
                        } else if (mode == 4) {
                            bitmapDc.setFill(Graphics.createColor(alpha, 0, 0, 255));
                            bitmapDc.setStroke(Graphics.createColor(alpha, 0, 0, 255));
                        }
                        bitmapDc.drawLine(x, yVal.toNumber(), x, zeroY.toNumber());
                    }
                }

                // --- Forecast fill (right 80%) ---
                if (forecast != null && forecast.size() > 0) {
                    var forecastZoom = forecastWidth.toFloat() / forecast.size().toFloat();
                    for (var x = 0; x < forecastWidth; x++) {
                        var idx = (x / forecastZoom).toNumber();
                        if (idx >= forecast.size()) { idx = forecast.size() - 1; }
                        var alpha = ((x + histWidth) / 3);
                        if (alpha > 60) { alpha = 60; }
                        var val = forecast[idx].toFloat();
                        var yVal = (dc.getHeight() - yOffset) - ((val - minValue) / totalRange * chartAreaHeight);

                        if (mode <= 2) {
                            bitmapDc.setFill(Graphics.createColor(alpha, 255, 255, 0));
                            bitmapDc.setStroke(Graphics.createColor(alpha, 255, 255, 0));
                        } else if (mode == 3) {
                            if (val < 0) {
                                bitmapDc.setStroke(Graphics.createColor(alpha, 0, 150, 255));
                            } else {
                                bitmapDc.setStroke(Graphics.createColor(alpha, 0, 255, 0));
                            }
                        } else if (mode == 4) {
                            bitmapDc.setFill(Graphics.createColor(alpha, 0, 0, 255));
                            bitmapDc.setStroke(Graphics.createColor(alpha, 0, 0, 255));
                        }
                        bitmapDc.drawLine(x + histWidth, yVal.toNumber(), x + histWidth, zeroY.toNumber());
                    }
                }

                // Re-draw Zero Line on top of fill
                bitmapDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                bitmapDc.drawLine(0, zeroY.toNumber(), dc.getWidth(), zeroY.toNumber());

                // Draw separator line between historical and forecast
                bitmapDc.setPenWidth(1);
                bitmapDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                bitmapDc.drawLine(histWidth, 0, histWidth, dc.getHeight());

                // Draw dotted time marker lines in the forecast section
                if (forecast != null && forecast.size() > 0) {
                    var forecastZoomMarker = forecastWidth.toFloat() / forecast.size().toFloat();
                    var nowInfo2 = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
                    var curHour = nowInfo2.hour;

                    // Check noon and midnight markers across the forecast range
                    // Forecast index = targetHour - curHour, where targetHour is hours since midnight today
                    var markers = [12, 24, 36, 48]; // noon today, midnight, noon tomorrow, midnight+1
                    for (var m = 0; m < markers.size(); m++) {
                        var idx = markers[m] - curHour;
                        if (idx > 0 && idx < forecast.size()) {
                            var xPos = histWidth + (idx * forecastZoomMarker).toNumber();
                            var isNoon = (markers[m] == 12 || markers[m] == 36);
                            if (isNoon) {
                                bitmapDc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                            } else {
                                bitmapDc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
                            }
                            // Draw dotted vertical line
                            for (var y = 0; y < dc.getHeight(); y += 4) {
                                bitmapDc.drawLine(xPos, y, xPos, y + 1);
                            }
                        }
                    }
                }

                // --- Historical curve line (left 20%, most recent data) ---
                bitmapDc.setPenWidth(2);
                bitmapDc.setColor(linecolor, Graphics.COLOR_BLACK);
                if (histogram != null && histogram.size() > 1) {
                    var histZoom = 2.0;
                    var histPointsToShow = (histWidth / histZoom).toNumber();
                    if (histPointsToShow > histogram.size()) { histPointsToShow = histogram.size(); }
                    var histDataOffset = histogram.size() - histPointsToShow;
                    for (var x = 2; x < histWidth; x += 2) {
                        var idxPrev = histDataOffset + ((x - 2) / histZoom).toNumber();
                        var idxCurr = histDataOffset + (x / histZoom).toNumber();
                        if (idxPrev >= histogram.size()) { idxPrev = histogram.size() - 1; }
                        if (idxCurr >= histogram.size()) { idxCurr = histogram.size() - 1; }
                        var valPrev = histogram[idxPrev].toFloat();
                        var valCurr = histogram[idxCurr].toFloat();
                        var yPrev = (dc.getHeight() - yOffset) - ((valPrev - minValue) / totalRange * chartAreaHeight);
                        var yCurr = (dc.getHeight() - yOffset) - ((valCurr - minValue) / totalRange * chartAreaHeight);
                        bitmapDc.drawLine(x - 2, yPrev.toNumber(), x, yCurr.toNumber());
                    }
                }

                // --- Forecast curve line (right 80%) ---
                bitmapDc.setColor(linecolor, Graphics.COLOR_BLACK);
                if (forecast != null && forecast.size() > 1) {
                    var forecastZoom = forecastWidth.toFloat() / forecast.size().toFloat();
                    for (var x = 2; x < forecastWidth; x += 2) {
                        var idxPrev = ((x - 2) / forecastZoom).toNumber();
                        var idxCurr = (x / forecastZoom).toNumber();
                        if (idxPrev >= forecast.size()) { idxPrev = forecast.size() - 1; }
                        if (idxCurr >= forecast.size()) { idxCurr = forecast.size() - 1; }
                        var valPrev = forecast[idxPrev].toFloat();
                        var valCurr = forecast[idxCurr].toFloat();
                        var yPrev = (dc.getHeight() - yOffset) - ((valPrev - minValue) / totalRange * chartAreaHeight);
                        var yCurr = (dc.getHeight() - yOffset) - ((valCurr - minValue) / totalRange * chartAreaHeight);
                        bitmapDc.drawLine(x + histWidth - 2, yPrev.toNumber(), x + histWidth, yCurr.toNumber());
                    }
                }

                var dim = bitmapDc.getTextDimensions(curvalue, Graphics.FONT_SYSTEM_TINY);
                bitmapDc.setFill(Graphics.createColor(160, 0, 0, 0));
                bitmapDc.fillRectangle(15, 58, dim[0]+6, dim[1]);
                // Draw text for current value
                bitmapDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
                bitmapDc.drawText(18+1, 58+1, Graphics.FONT_SYSTEM_TINY, curvalue, Graphics.TEXT_JUSTIFY_LEFT);
                bitmapDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                bitmapDc.drawText(18, 58, Graphics.FONT_SYSTEM_TINY, curvalue, Graphics.TEXT_JUSTIFY_LEFT);

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
