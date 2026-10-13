package com.example.assignmentproject.util

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.PowerManager
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat

/** Read-only checks shared by the service, the boot receiver and the MethodChannel handler. */
object PermissionUtils {

    fun isGranted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    fun hasFineLocation(context: Context) = isGranted(context, Manifest.permission.ACCESS_FINE_LOCATION)

    /** Fine or approximate; either is enough for FusedLocationProviderClient to deliver fixes. */
    fun hasAnyLocation(context: Context) =
        hasFineLocation(context) || isGranted(context, Manifest.permission.ACCESS_COARSE_LOCATION)

    /** Below Android 10 foreground location implies background access. */
    fun hasBackgroundLocation(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            isGranted(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else {
            hasAnyLocation(context)
        }

    fun hasNotificationPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            isGranted(context, Manifest.permission.POST_NOTIFICATIONS)

    /**
     * Whether the device-wide location switch is on. LocationManager is used only for this
     * status check; fixes themselves come from FusedLocationProviderClient.
     */
    fun isLocationEnabled(context: Context): Boolean {
        val manager = context.getSystemService(LocationManager::class.java) ?: return false
        return LocationManagerCompat.isLocationEnabled(manager)
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val power = context.getSystemService(PowerManager::class.java) ?: return false
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }
}
