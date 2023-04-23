import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class WetterstationApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when the application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of the application here
    function getInitialView() as Array<Views or InputDelegates>? {
        return [ new WetterstationView() ] as Array<Views or InputDelegates>;
    }

    (:glance)
    function getGlanceView() {
        return [ new WetterstationGlanceView() ];
    }
}

function getApp() as WetterstationApp {
    return Application.getApp() as WetterstationApp;
}