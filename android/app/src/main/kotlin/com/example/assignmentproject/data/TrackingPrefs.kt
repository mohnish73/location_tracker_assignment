package com.example.assignmentproject.data

import android.content.Context
import androidx.core.content.edit

/**
 * Native settings store. The tracking flag lives here (not in Flutter memory) so the
 * service, the boot receiver and a freshly started UI all agree on whether tracking is ON.
 */
class TrackingPrefs(context: Context) {

    private val prefs = context.applicationContext.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    /** What the user asked for. Written synchronously so it survives an immediate process kill. */
    var isTrackingEnabled: Boolean
        get() = prefs.getBoolean(KEY_TRACKING_ENABLED, false)
        set(value) = prefs.edit(commit = true) { putBoolean(KEY_TRACKING_ENABLED, value) }

    var intervalMs: Long
        get() = prefs.getLong(KEY_INTERVAL_MS, DEFAULT_INTERVAL_MS)
        set(value) = prefs.edit(commit = true) { putLong(KEY_INTERVAL_MS, value) }

    /** Remembers that a runtime permission was requested, to tell "denied" from "permanently denied". */
    fun markPermissionRequested(permission: String) =
        prefs.edit { putBoolean(KEY_REQUESTED_PREFIX + permission, true) }

    fun wasPermissionRequested(permission: String): Boolean =
        prefs.getBoolean(KEY_REQUESTED_PREFIX + permission, false)

    companion object {
        private const val NAME = "tracking_prefs"
        private const val KEY_TRACKING_ENABLED = "tracking_enabled"
        private const val KEY_INTERVAL_MS = "interval_ms"
        private const val KEY_REQUESTED_PREFIX = "requested_"

        const val DEFAULT_INTERVAL_MS = 10_000L
        const val MIN_INTERVAL_MS = 5_000L
        const val MAX_INTERVAL_MS = 60 * 60 * 1000L
    }
}
