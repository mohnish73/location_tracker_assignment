package com.example.assignmentproject

import android.util.Log
import com.example.assignmentproject.bridge.ChannelContract
import com.example.assignmentproject.bridge.LocationStreamHandler
import com.example.assignmentproject.bridge.TrackerMethodHandler
import com.example.assignmentproject.data.TrackingPrefs
import com.example.assignmentproject.service.LocationService
import com.example.assignmentproject.util.PermissionUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Registers our own MethodChannel (commands) and EventChannel (live locations). */
class MainActivity : FlutterActivity() {

    private var methodHandler: TrackerMethodHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val handler = TrackerMethodHandler(this)
        MethodChannel(messenger, ChannelContract.METHOD_CHANNEL).setMethodCallHandler(handler)
        EventChannel(messenger, ChannelContract.EVENT_CHANNEL).setStreamHandler(LocationStreamHandler)
        methodHandler = handler
    }

    override fun onResume() {
        super.onResume()
        refreshTrackingFromForeground()
    }

    /**
     * A location FGS started from the background (boot, app update, system restart after a
     * kill) gets no while-in-use location access on Android 11+, so fixes are throttled and
     * the notification may not show. Re-starting it while the activity is visible restores
     * full access. ACTION_START on a running service just re-enters the foreground and
     * re-requests updates, so this is safe to call on every resume.
     */
    private fun refreshTrackingFromForeground() {
        if (!TrackingPrefs(this).isTrackingEnabled) return
        if (!PermissionUtils.hasAnyLocation(this) || !PermissionUtils.isLocationEnabled(this)) return
        try {
            LocationService.start(this)
        } catch (e: Exception) {
            Log.w("MainActivity", "Could not refresh tracking service", e)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The service may keep running; make sure it stops pushing into this engine.
        LocationStreamHandler.detach()
        methodHandler?.dispose()
        methodHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        methodHandler?.onRequestPermissionsResult(requestCode)
    }
}
