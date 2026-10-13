package com.example.assignmentproject

import com.example.assignmentproject.bridge.ChannelContract
import com.example.assignmentproject.bridge.LocationStreamHandler
import com.example.assignmentproject.bridge.TrackerMethodHandler
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
