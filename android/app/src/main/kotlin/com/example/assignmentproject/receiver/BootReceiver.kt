package com.example.assignmentproject.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.assignmentproject.data.TrackingPrefs
import com.example.assignmentproject.service.LocationService
import com.example.assignmentproject.util.PermissionUtils

/** Restarts tracking after a reboot (or an app update) if the user had left it ON. */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in HANDLED_ACTIONS) return
        if (!TrackingPrefs(context).isTrackingEnabled) return

        // Starting a location FGS from the background needs "Allow all the time".
        if (!PermissionUtils.hasBackgroundLocation(context)) {
            Log.w(TAG, "Tracking was ON but background location is not granted; not restarting")
            return
        }
        try {
            LocationService.start(context)
        } catch (e: Exception) {
            Log.e(TAG, "Could not restart tracking after ${intent.action}", e)
        }
    }

    private companion object {
        const val TAG = "BootReceiver"
        val HANDLED_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON", // some OEM fast-boot modes
        )
    }
}
