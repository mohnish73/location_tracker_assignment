package com.example.assignmentproject.service

import android.annotation.SuppressLint
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.example.assignmentproject.bridge.LocationStreamHandler
import com.example.assignmentproject.data.LocationDao
import com.example.assignmentproject.data.LocationRecord
import com.example.assignmentproject.data.TrackingPrefs
import com.example.assignmentproject.util.PermissionUtils
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * Foreground service (type "location") that owns the FusedLocationProviderClient.
 *
 * Flow for every fix: FusedLocationProvider -> [handleLocation] on a background thread
 * -> SQLite insert -> notification update -> EventChannel (only if Flutter is listening).
 *
 * It does not depend on the Flutter engine at all, so it keeps working when the UI is
 * swiped away or the activity is destroyed. START_STICKY plus the persisted tracking
 * flag let the system recreate it after the process is killed.
 */
class LocationService : Service() {

    private lateinit var fusedClient: FusedLocationProviderClient
    private lateinit var dao: LocationDao
    private lateinit var prefs: TrackingPrefs

    /** Location callbacks and DB writes run here, never on the main thread. */
    private lateinit var workerThread: HandlerThread
    private lateinit var workerHandler: Handler

    private var isRequestingUpdates = false
    private var providerReceiverRegistered = false

    @Volatile
    private var lastRecord: LocationRecord? = null

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.locations.forEach(::handleLocation)
        }
    }

    /** Reacts to the device location switch being turned off/on while tracking. */
    private val providerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val enabled = PermissionUtils.isLocationEnabled(context)
            TrackingNotification.update(context, lastRecord, enabled)
            LocationStreamHandler.emitLocationServices(enabled)
        }
    }

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        dao = LocationDao.getInstance(this)
        prefs = TrackingPrefs(this)
        workerThread = HandlerThread("LocationWorker").apply { start() }
        workerHandler = Handler(workerThread.looper)
        TrackingNotification.createChannel(this)
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTracking()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_INTERVAL -> {
                if (isRequestingUpdates) requestLocationUpdates() else stopSelf()
                return START_STICKY
            }
        }

        // ACTION_START, or a null intent when the system recreates a sticky service after a kill.
        if (intent == null && !prefs.isTrackingEnabled) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!startInForeground()) {
            stopSelf()
            return START_NOT_STICKY
        }
        prefs.isTrackingEnabled = true
        registerProviderReceiver()
        requestLocationUpdates()
        LocationStreamHandler.emitStatus(true)
        return START_STICKY
    }

    override fun onDestroy() {
        if (isRequestingUpdates) fusedClient.removeLocationUpdates(locationCallback)
        isRequestingUpdates = false
        if (providerReceiverRegistered) unregisterReceiver(providerReceiver)
        providerReceiverRegistered = false
        workerThread.quitSafely()
        isRunning = false
        LocationStreamHandler.emitStatus(false)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground(): Boolean {
        if (!PermissionUtils.hasAnyLocation(this)) {
            Log.w(TAG, "Location permission missing, cannot start tracking")
            return false
        }
        return try {
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            } else {
                0
            }
            ServiceCompat.startForeground(
                this,
                TrackingNotification.NOTIFICATION_ID,
                TrackingNotification.build(this, lastRecord, PermissionUtils.isLocationEnabled(this)),
                type,
            )
            // Show the last stored fix in the notification straight away.
            if (lastRecord == null) {
                workerHandler.post {
                    lastRecord = runCatching { dao.getLatest() }.getOrNull()
                    TrackingNotification.update(this, lastRecord, PermissionUtils.isLocationEnabled(this))
                }
            }
            true
        } catch (e: Exception) {
            // e.g. SecurityException / ForegroundServiceStartNotAllowedException on Android 12+.
            Log.e(TAG, "Unable to enter foreground", e)
            false
        }
    }

    @SuppressLint("MissingPermission") // checked via PermissionUtils.hasAnyLocation
    private fun requestLocationUpdates() {
        if (!PermissionUtils.hasAnyLocation(this)) return
        if (isRequestingUpdates) fusedClient.removeLocationUpdates(locationCallback)

        val intervalMs = prefs.intervalMs
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
            .setMinUpdateIntervalMillis(intervalMs)
            .setMinUpdateDistanceMeters(0f) // record a fix every interval, even when stationary
            .setWaitForAccurateLocation(false)
            .build()

        try {
            fusedClient.requestLocationUpdates(request, locationCallback, workerThread.looper)
                .addOnFailureListener { Log.e(TAG, "requestLocationUpdates failed", it) }
            isRequestingUpdates = true
            Log.i(TAG, "Location updates requested every ${intervalMs}ms")
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission revoked", e)
            stopTracking()
        }
    }

    /** Runs on [workerThread]. */
    private fun handleLocation(location: Location) {
        try {
            val record = dao.insert(
                latitude = location.latitude,
                longitude = location.longitude,
                accuracy = location.accuracy,
                timestamp = location.time,
            )
            lastRecord = record
            TrackingNotification.update(this, record)
            LocationStreamHandler.emitLocation(record)
        } catch (e: Exception) {
            // Never let a single bad write take down the service.
            Log.e(TAG, "Failed to persist location", e)
        }
    }

    private fun registerProviderReceiver() {
        if (providerReceiverRegistered) return
        ContextCompat.registerReceiver(
            this,
            providerReceiver,
            IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        providerReceiverRegistered = true
    }

    private fun stopTracking() {
        prefs.isTrackingEnabled = false
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    companion object {
        private const val TAG = "LocationService"

        const val ACTION_START = "com.example.assignmentproject.action.START_TRACKING"
        const val ACTION_STOP = "com.example.assignmentproject.action.STOP_TRACKING"
        const val ACTION_UPDATE_INTERVAL = "com.example.assignmentproject.action.UPDATE_INTERVAL"

        /** True while the service instance exists in this process. */
        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, LocationService::class.java).setAction(ACTION_START)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            TrackingPrefs(context).isTrackingEnabled = false
            context.stopService(Intent(context, LocationService::class.java))
        }

        /** Re-applies the saved interval to a running service. */
        fun applyInterval(context: Context) {
            if (!isRunning) return
            context.startService(
                Intent(context, LocationService::class.java).setAction(ACTION_UPDATE_INTERVAL),
            )
        }
    }
}
