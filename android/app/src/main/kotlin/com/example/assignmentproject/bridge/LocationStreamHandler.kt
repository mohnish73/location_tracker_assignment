package com.example.assignmentproject.bridge

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.assignmentproject.data.LocationRecord
import io.flutter.plugin.common.EventChannel

/**
 * Process-wide bridge between the service and the Flutter UI.
 *
 * The service always writes to SQLite first and then calls [emitLocation]. If no Flutter
 * engine is listening (UI closed or killed) [sink] is null and the event is simply dropped;
 * the UI catches up by reading SQLite through the MethodChannel when it starts or resumes.
 *
 * Every event is a map with a "type" key:
 *  - "location":         id, latitude, longitude, accuracy, timestamp
 *  - "status":           isRunning
 *  - "locationServices": enabled
 */
object LocationStreamHandler : EventChannel.StreamHandler {

    private const val TAG = "LocationStream"

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /** Called when the Flutter engine is torn down so we never post into a dead engine. */
    fun detach() {
        sink = null
    }

    fun emitLocation(record: LocationRecord) = emit(record.toMap() + ("type" to "location"))

    fun emitStatus(isRunning: Boolean) = emit(mapOf("type" to "status", "isRunning" to isRunning))

    fun emitLocationServices(enabled: Boolean) =
        emit(mapOf("type" to "locationServices", "enabled" to enabled))

    /** EventSink must be used on the platform (main) thread; callers may be on any thread. */
    private fun emit(event: Map<String, Any>) {
        if (sink == null) return
        mainHandler.post {
            try {
                sink?.success(event)
            } catch (e: Exception) {
                Log.w(TAG, "Dropping event, Flutter side unavailable", e)
            }
        }
    }
}
