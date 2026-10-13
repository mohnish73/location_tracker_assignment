package com.example.assignmentproject.bridge

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import com.example.assignmentproject.bridge.ChannelContract.Errors
import com.example.assignmentproject.bridge.ChannelContract.Methods
import com.example.assignmentproject.bridge.ChannelContract.PermissionStatus
import com.example.assignmentproject.data.CsvExporter
import com.example.assignmentproject.data.LocationDao
import com.example.assignmentproject.data.TrackingPrefs
import com.example.assignmentproject.service.LocationService
import com.example.assignmentproject.util.PermissionUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Handles every call on the MethodChannel. Each call either succeeds with a value or
 * fails with a structured error (code from [ChannelContract.Errors], human-readable message).
 * Database work runs on a background executor and replies on the main thread.
 */
class TrackerMethodHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val context = activity.applicationContext
    private val prefs = TrackingPrefs(context)
    private val dao = LocationDao.getInstance(context)
    private val io: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Only one runtime-permission dialog can be on screen at a time. */
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRequestCode = NO_REQUEST

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                Methods.START_TRACKING -> startTracking(result)
                Methods.STOP_TRACKING -> stopTracking(result)
                Methods.GET_TRACKING_STATUS -> result.success(trackingStatus())
                Methods.SET_TRACKING_INTERVAL -> setTrackingInterval(call, result)
                Methods.GET_LAST_LOCATION -> runDb(result) { dao.getLatest()?.toMap() }
                Methods.GET_HISTORY -> getHistory(call, result)
                Methods.GET_RECORD_COUNT -> runDb(result) { dao.count() }
                Methods.CLEAR_HISTORY -> runDb(result) { dao.clearAll() }
                Methods.EXPORT_CSV -> exportCsv(result)
                Methods.GET_PERMISSION_STATUS -> result.success(permissionSnapshot())
                Methods.REQUEST_LOCATION_PERMISSION -> requestLocationPermission(result)
                Methods.REQUEST_BACKGROUND_LOCATION_PERMISSION -> requestBackgroundPermission(result)
                Methods.REQUEST_NOTIFICATION_PERMISSION -> requestNotificationPermission(result)
                Methods.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS -> requestIgnoreBatteryOptimizations(result)
                Methods.OPEN_APP_SETTINGS -> openAppSettings(result)
                Methods.OPEN_LOCATION_SETTINGS ->
                    openSettings(result, Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(Errors.UNEXPECTED, e.message ?: "Unexpected native error", e.javaClass.simpleName)
        }
    }

    // region Tracking

    private fun startTracking(result: MethodChannel.Result) {
        if (!PermissionUtils.hasAnyLocation(context)) {
            result.error(Errors.PERMISSION_DENIED, "Location permission is required to start tracking.", null)
            return
        }
        if (!PermissionUtils.isLocationEnabled(context)) {
            result.error(Errors.LOCATION_DISABLED, "Location services are turned off.", null)
            return
        }
        try {
            // The service itself persists the "tracking ON" flag once it is in the foreground.
            LocationService.start(context)
            result.success(trackingStatus(isRunning = true, trackingEnabled = true))
        } catch (e: Exception) {
            result.error(Errors.SERVICE_ERROR, "Could not start the tracking service: ${e.message}", null)
        }
    }

    private fun stopTracking(result: MethodChannel.Result) {
        LocationService.stop(context)
        result.success(trackingStatus(isRunning = false, trackingEnabled = false))
    }

    private fun setTrackingInterval(call: MethodCall, result: MethodChannel.Result) {
        val intervalMs = call.argument<Number>("intervalMs")?.toLong()
        if (intervalMs == null || intervalMs !in TrackingPrefs.MIN_INTERVAL_MS..TrackingPrefs.MAX_INTERVAL_MS) {
            result.error(
                Errors.INVALID_ARGUMENT,
                "intervalMs must be between ${TrackingPrefs.MIN_INTERVAL_MS} and ${TrackingPrefs.MAX_INTERVAL_MS}.",
                null,
            )
            return
        }
        prefs.intervalMs = intervalMs
        LocationService.applyInterval(context)
        result.success(trackingStatus())
    }

    /**
     * isRunning: the service instance is alive right now.
     * trackingEnabled: the user's persisted choice (lets the UI resume tracking if an OEM killed us).
     */
    private fun trackingStatus(
        isRunning: Boolean = LocationService.isRunning,
        trackingEnabled: Boolean = prefs.isTrackingEnabled,
    ): Map<String, Any> = mapOf(
        "isRunning" to isRunning,
        "trackingEnabled" to trackingEnabled,
        "intervalMs" to prefs.intervalMs,
    )

    // endregion

    // region Database

    private fun getHistory(call: MethodCall, result: MethodChannel.Result) {
        val limit = (call.argument<Number>("limit")?.toInt() ?: DEFAULT_HISTORY_LIMIT)
        if (limit !in 1..MAX_HISTORY_LIMIT) {
            result.error(Errors.INVALID_ARGUMENT, "limit must be between 1 and $MAX_HISTORY_LIMIT.", null)
            return
        }
        runDb(result) { dao.getHistory(limit).map { it.toMap() } }
    }

    private fun exportCsv(result: MethodChannel.Result) {
        io.execute {
            try {
                val export = CsvExporter(context, dao).export()
                mainHandler.post {
                    try {
                        shareCsv(export.file)
                        result.success(mapOf("rows" to export.rows, "path" to export.file.absolutePath))
                    } catch (e: Exception) {
                        result.error(Errors.EXPORT_FAILED, "Could not open the share sheet: ${e.message}", null)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post { result.error(Errors.EXPORT_FAILED, e.message ?: "CSV export failed", null) }
            }
        }
    }

    private fun shareCsv(file: java.io.File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val send = Intent(Intent.ACTION_SEND)
            .setType("text/csv")
            .putExtra(Intent.EXTRA_STREAM, uri)
            .putExtra(Intent.EXTRA_SUBJECT, "Location history")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(Intent.createChooser(send, "Export location history"))
    }

    /** Runs [block] on the IO thread and replies on the main thread (Result is not thread-safe). */
    private fun runDb(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error(Errors.DATABASE_ERROR, e.message ?: "Database error", null) }
            }
        }
    }

    // endregion

    // region Permissions

    private fun permissionSnapshot(): Map<String, Any> = mapOf(
        "location" to statusOf(Manifest.permission.ACCESS_FINE_LOCATION),
        "backgroundLocation" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            statusOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else {
            PermissionStatus.NOT_REQUIRED
        },
        "notification" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            statusOf(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            PermissionStatus.NOT_REQUIRED
        },
        "locationServicesEnabled" to PermissionUtils.isLocationEnabled(context),
        "ignoringBatteryOptimizations" to PermissionUtils.isIgnoringBatteryOptimizations(context),
        "sdkInt" to Build.VERSION.SDK_INT,
    )

    /**
     * After a denial Android stops showing the dialog once the user picks "Don't ask again"
     * (or denies twice). We detect that as: requested before + no rationale to show.
     */
    private fun statusOf(permission: String): String = when {
        PermissionUtils.isGranted(context, permission) -> PermissionStatus.GRANTED
        prefs.wasPermissionRequested(permission) &&
            !ActivityCompat.shouldShowRequestPermissionRationale(activity, permission) ->
            PermissionStatus.PERMANENTLY_DENIED
        else -> PermissionStatus.DENIED
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (PermissionUtils.hasFineLocation(context)) {
            result.success(permissionSnapshot())
            return
        }
        requestPermissions(
            result,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            REQUEST_LOCATION,
        )
    }

    /** Must be a separate step: Android 11+ ignores it if requested together with foreground location. */
    private fun requestBackgroundPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || PermissionUtils.hasBackgroundLocation(context)) {
            result.success(permissionSnapshot())
            return
        }
        if (!PermissionUtils.hasAnyLocation(context)) {
            result.error(Errors.PERMISSION_DENIED, "Grant location access before background access.", null)
            return
        }
        requestPermissions(result, arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), REQUEST_BACKGROUND)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || PermissionUtils.hasNotificationPermission(context)) {
            result.success(permissionSnapshot())
            return
        }
        requestPermissions(result, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATION)
    }

    private fun requestPermissions(result: MethodChannel.Result, permissions: Array<String>, requestCode: Int) {
        if (pendingPermissionResult != null) {
            result.error(Errors.REQUEST_IN_PROGRESS, "Another permission request is already showing.", null)
            return
        }
        permissions.forEach(prefs::markPermissionRequested)
        pendingPermissionResult = result
        pendingRequestCode = requestCode
        ActivityCompat.requestPermissions(activity, permissions, requestCode)
    }

    /** Forwarded from MainActivity.onRequestPermissionsResult. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != pendingRequestCode) return false
        val result = pendingPermissionResult ?: return false
        pendingPermissionResult = null
        pendingRequestCode = NO_REQUEST
        result.success(permissionSnapshot())
        return true
    }

    @SuppressLint("BatteryLife") // Continuous tracking is this app's core purpose.
    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        if (PermissionUtils.isIgnoringBatteryOptimizations(context)) {
            result.success(true)
            return
        }
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:${context.packageName}"))
        try {
            activity.startActivity(direct)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            openSettings(result, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    private fun openAppSettings(result: MethodChannel.Result) =
        openSettings(
            result,
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")),
        )

    private fun openSettings(result: MethodChannel.Result, intent: Intent) {
        try {
            activity.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error(Errors.SETTINGS_UNAVAILABLE, "This settings screen is not available on this device.", null)
        }
    }

    // endregion

    fun dispose() {
        pendingPermissionResult = null
        pendingRequestCode = NO_REQUEST
        io.shutdown()
    }

    private companion object {
        const val NO_REQUEST = -1
        const val REQUEST_LOCATION = 7001
        const val REQUEST_BACKGROUND = 7002
        const val REQUEST_NOTIFICATION = 7003
        const val DEFAULT_HISTORY_LIMIT = 50
        const val MAX_HISTORY_LIMIT = 500
    }
}
