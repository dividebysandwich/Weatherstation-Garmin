import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Math;
import Toybox.Lang;
import Toybox.System;

class WetterstationAdsbView extends WatchUi.View {
    var ad = null;
    var refreshTimer = null;
    var alertBlinkState = false;
    var tickCounter = 0;
    var labelFont = null;

    private var _indicator as PageIndicator;

    public function initialize() {
        View.initialize();
        var size = 5;
        var notSelected = Graphics.COLOR_DK_GRAY;
        var selected = Graphics.COLOR_LT_GRAY;
        var alignment = $.ALIGN_BOTTOM_CENTER;
        var margin = 3;
        _indicator = new $.PageIndicator(size, selected, notSelected, alignment, margin);
        labelFont = WatchUi.loadResource(Rez.Fonts.LabelFont);
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        View.onUpdate(dc);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2.0;
        var cy = dc.getHeight() / 2.0;
        var radius = cx * 0.88;
        var scaleFactor = cx / 180.0;

        // Background range rings
        dc.setPenWidth(1);
        dc.setColor(Graphics.createColor(120, 70, 70, 90), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);
        dc.drawCircle(cx, cy, radius * 0.66);
        dc.drawCircle(cx, cy, radius * 0.33);

        // Compass labels
        var fontDir = Graphics.FONT_SYSTEM_XTINY;
        var fontHeightOffset = dc.getFontHeight(fontDir) / 2.0;
        dc.setColor(Graphics.createColor(255, 150, 150, 160), Graphics.COLOR_TRANSPARENT);
        var labelRadius = radius + (8 * scaleFactor);
        dc.drawText(cx, cy - labelRadius - fontHeightOffset, fontDir, "N", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + labelRadius - fontHeightOffset, fontDir, "S", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx - labelRadius, cy - fontHeightOffset, fontDir, "W", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + labelRadius, cy - fontHeightOffset, fontDir, "E", Graphics.TEXT_JUSTIFY_CENTER);

        var snapshot = (ad != null) ? ad.getSnapshot() : null;

        if (snapshot == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var code = (ad != null) ? ad.getLastResponseCode() : 0;
            var msg;
            if (code == 0) {
                msg = "Loading ADS-B...";
            } else if (code == 200) {
                msg = "No data";
            } else {
                msg = "ADS-B error " + code.toString();
            }
            dc.drawText(cx, cy - fontHeightOffset, fontDir, msg, Graphics.TEXT_JUSTIFY_CENTER);
            _indicator.draw(dc, 1);
            return;
        }

        var center = snapshot.get("center");
        if (center == null || center.get("lat") == null || center.get("lon") == null) {
            _indicator.draw(dc, 1);
            return;
        }
        var centerLat = center.get("lat").toFloat();
        var centerLon = center.get("lon").toFloat();

        // Cap display range to the current zoom level (cycled via top-right button)
        var rangeRaw = snapshot.get("radius_nm");
        var srvRange = (rangeRaw != null) ? rangeRaw.toFloat() : 100.0;
        var displayRangeNm = ad.getZoomNm();
        if (displayRangeNm > srvRange) { displayRangeNm = srvRange; }
        var pxPerNm = radius / displayRangeNm;

        // Range label on outer ring
        dc.setColor(Graphics.createColor(180, 100, 100, 120), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 4, cy - radius - fontHeightOffset,
            fontDir, displayRangeNm.format("%.0f"),
            Graphics.TEXT_JUSTIFY_LEFT);

        // Restricted area
        var restricted = snapshot.get("restricted");
        if (restricted != null && restricted.get("lat") != null) {
            var rLat = restricted.get("lat").toFloat();
            var rLon = restricted.get("lon").toFloat();
            var rRadiusM = restricted.get("radius_m");
            var rRadiusNm = (rRadiusM != null) ? rRadiusM.toFloat() / 1852.0 : 0.27;
            var rPos = latLonToScreen(rLat, rLon, centerLat, centerLon, cx, cy, pxPerNm);
            var rPxRadius = rRadiusNm * pxPerNm;
            if (rPxRadius < 3) { rPxRadius = 3; }
            dc.setColor(Graphics.createColor(180, 200, 40, 40), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rPos[0], rPos[1], rPxRadius);
        }

        // Center station marker
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 3 * scaleFactor);

        // Aircraft
        var aircraft = snapshot.get("aircraft");
        if (aircraft != null && aircraft instanceof Array) {
            for (var i = 0; i < aircraft.size(); i++) {
                var ac = aircraft[i];
                if (ac == null) { continue; }
                var aLat = ac.get("lat");
                var aLon = ac.get("lon");
                if (aLat == null || aLon == null) { continue; }
                var pos = latLonToScreen(aLat.toFloat(), aLon.toFloat(),
                    centerLat, centerLon, cx, cy, pxPerNm);
                var dx = pos[0] - cx;
                var dy = pos[1] - cy;
                if (Math.sqrt(dx * dx + dy * dy) > radius) { continue; }

                var color = altitudeColor(ac.get("alt_baro"));

                // Trail dots
                var trail = ac.get("mc_history");
                if (trail != null && trail instanceof Array && trail.size() > 0) {
                    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                    for (var t = 0; t < trail.size(); t++) {
                        var pt = trail[t];
                        if (pt == null || !(pt instanceof Array) || pt.size() < 2) { continue; }
                        var tPos = latLonToScreen(pt[0].toFloat(), pt[1].toFloat(),
                            centerLat, centerLon, cx, cy, pxPerNm);
                        dc.fillCircle(tPos[0], tPos[1], 1);
                    }
                }

                // Heading tick
                var track = ac.get("track");
                var gs = ac.get("gs");
                if (track != null && gs != null) {
                    var tRad = Math.toRadians(track.toFloat());
                    var tickLen = 10 * scaleFactor;
                    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                    dc.setPenWidth(2);
                    dc.drawLine(pos[0], pos[1],
                        pos[0] + tickLen * Math.sin(tRad),
                        pos[1] - tickLen * Math.cos(tRad));
                }

                // Aircraft dot
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(pos[0], pos[1], 3 * scaleFactor);

                // Alert highlight
                var alert = ac.get("mc_alert");
                var labelColor = Graphics.COLOR_WHITE;
                var labelBg = Graphics.createColor(100, 0, 0, 0);
                if (alert != null) {
                    if (alertBlinkState) {
                        labelBg = Graphics.createColor(160, 200, 40, 40);
                        labelColor = Graphics.COLOR_WHITE;
                    } else {
                        labelBg = Graphics.createColor(160, 255, 255, 255);
                        labelColor = Graphics.COLOR_RED;
                    }
                    dc.setPenWidth(2);
                    dc.setColor(alertBlinkState ? Graphics.COLOR_RED : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(pos[0], pos[1], 8 * scaleFactor);
                }

                // Label: callsign on line 1, alert details on line 2 (when alerting)
                var lines = [];
                var flight = ac.get("flight");
                if (flight != null) {
                    var label = trimSpaces(flight.toString());
                    if (label.length() > 0) { lines.add(label); }
                }
                if (alert != null) {
                    var eta = alert.get("eta_s");
                    var minD = alert.get("min_distance_m");
                    if (eta != null && minD != null) {
                        lines.add(eta.toFloat().format("%.0f") + "s/" +
                            minD.toFloat().format("%.0f") + "m");
                    }
                }
                if (lines.size() > 0) {
                    var lineH = dc.getFontHeight(labelFont);
                    var maxWidth = 0;
                    for (var li = 0; li < lines.size(); li++) {
                        var w = dc.getTextWidthInPixels(lines[li], labelFont);
                        if (w > maxWidth) { maxWidth = w; }
                    }
                    var totalH = lineH * lines.size();
                    var lx = pos[0] + 14 * scaleFactor;
                    var ly = pos[1] - totalH / 2;
                    dc.setColor(labelBg, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(lx, ly, maxWidth, totalH);
                    dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
                    for (var li = 0; li < lines.size(); li++) {
                        dc.drawText(lx, ly + li * lineH, labelFont, lines[li], Graphics.TEXT_JUSTIFY_LEFT);
                    }
                }
            }
        }

        // Footer: aircraft count + range
        var total = snapshot.get("total");
        var footer = (total != null ? total.toString() : "?") + " AC / " +
            displayRangeNm.format("%.0f") + "nm";
        dc.setColor(Graphics.createColor(100, 0, 0, 0), Graphics.COLOR_TRANSPARENT);
        var fdim = dc.getTextDimensions(footer, fontDir);
        var footerY = cy + radius * 0.6;
        dc.fillRectangle(cx - fdim[0] / 2 - 3, footerY, fdim[0] + 6, fdim[1]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footerY, fontDir, footer, Graphics.TEXT_JUSTIFY_CENTER);

        _indicator.draw(dc, 1);
    }

    function altitudeColor(alt) as Number {
        if (alt == null) { return Graphics.COLOR_LT_GRAY; }
        if (alt instanceof String) { return Graphics.COLOR_DK_GREEN; }
        var a = alt.toFloat();
        if (a < 2000) { return Graphics.COLOR_YELLOW; }
        if (a < 5000) { return Graphics.COLOR_BLUE; }
        return Graphics.COLOR_WHITE;
    }

    function trimSpaces(s as String) as String {
        var end = s.length();
        while (end > 0 && s.substring(end - 1, end).equals(" ")) {
            end--;
        }
        return s.substring(0, end);
    }

    function latLonToScreen(lat, lon, centerLat, centerLon, cx, cy, pxPerNm) as Array {
        var R = 3440.065; // Earth radius in nautical miles
        var phi1 = Math.toRadians(centerLat);
        var phi2 = Math.toRadians(lat);
        var dPhi = Math.toRadians(lat - centerLat);
        var dLambda = Math.toRadians(lon - centerLon);
        var a = Math.sin(dPhi / 2) * Math.sin(dPhi / 2) +
                Math.cos(phi1) * Math.cos(phi2) *
                Math.sin(dLambda / 2) * Math.sin(dLambda / 2);
        var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        var distance = R * c;
        var y = Math.sin(dLambda) * Math.cos(phi2);
        var x = Math.cos(phi1) * Math.sin(phi2) - Math.sin(phi1) * Math.cos(phi2) * Math.cos(dLambda);
        var bearingRad = Math.atan2(y, x);
        var screenX = cx + distance * pxPerNm * Math.sin(bearingRad);
        var screenY = cy - distance * pxPerNm * Math.cos(bearingRad);
        return [screenX, screenY];
    }

    function onShow() as Void {
        ad = AdsbData.getAdsbData();
        WatchUi.requestUpdate();
        refreshTimer = new Timer.Timer();
        refreshTimer.start(method(:timerCallback), 1000, true);
    }

    function timerCallback() as Void {
        if (ad != null) { ad.requestUpdate(); }
        tickCounter++;
        alertBlinkState = (tickCounter % 2 == 0);
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        if (refreshTimer != null) {
            refreshTimer.stop();
            refreshTimer = null;
        }
    }
}

class WetterstationAdsbViewDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onNextPage() as Boolean {
        WatchUi.switchToView(new $.Webcam1View(), new $.Webcam1ViewDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    public function onPreviousPage() as Boolean {
        WatchUi.switchToView(new $.WetterstationView(), new $.WetterstationViewDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }

    public function onSelect() as Boolean {
        AdsbData.getAdsbData().cycleZoom();
        WatchUi.requestUpdate();
        return true;
    }
}
