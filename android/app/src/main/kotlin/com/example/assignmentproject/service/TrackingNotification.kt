package com.example.assignmentproject.service

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.assignmentproject.R
import com.example.assignmentproject.data.LocationRecord
import com.example.assignmentproject.util.PermissionUtils
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Builds and updates the persistent foreground-service notification. */
object TrackingNotification {

    const val CHANNEL_ID = "location_tracking"
    const val NOTIFICATION_ID = 1001

    private const val REQUEST_OPEN_APP = 10
    private const val REQUEST_STOP = 11

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Location tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the latest recorded location while tracking is on"
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    fun build(context: Context, record: LocationRecord?, locationServicesOn: Boolean = true): Notification {
        val text: String
        val details: String
        when {
            !locationServicesOn -> {
                text = "Location services are off. Turn them on to resume."
                details = text
            }
            record == null -> {
                text = "Waiting for the first location fix…"
                details = text
            }
            else -> {
                val time = formatTime(record.timestamp)
                text = "%.6f, %.6f at %s".format(Locale.US, record.latitude, record.longitude, time)
                details = buildString {
                    appendLine("Latitude: %.6f".format(Locale.US, record.latitude))
                    appendLine("Longitude: %.6f".format(Locale.US, record.longitude))
                    appendLine("Accuracy: ±%.0f m".format(Locale.US, record.accuracy))
                    append("Time: $time")
                }
            }
        }

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_location)
            .setContentTitle("Location tracking is on")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(details))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setShowWhen(record != null)
            .setWhen(record?.timestamp ?: System.currentTimeMillis())
            .setContentIntent(openAppIntent(context))
            .addAction(0, "Stop tracking", stopIntent(context))
            .build()
    }

    /** Re-posting with the same id replaces the existing notification in place. */
    @SuppressLint("MissingPermission")
    fun update(context: Context, record: LocationRecord?, locationServicesOn: Boolean = true) {
        if (!PermissionUtils.hasNotificationPermission(context)) return
        NotificationManagerCompat.from(context)
            .notify(NOTIFICATION_ID, build(context, record, locationServicesOn))
    }

    private fun openAppIntent(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP }
            ?: return null
        return PendingIntent.getActivity(
            context, REQUEST_OPEN_APP, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stopIntent(context: Context): PendingIntent {
        val intent = Intent(context, LocationService::class.java).setAction(LocationService.ACTION_STOP)
        return PendingIntent.getService(
            context, REQUEST_STOP, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun formatTime(epochMs: Long): String =
        SimpleDateFormat("dd MMM yyyy, HH:mm:ss", Locale.getDefault()).format(Date(epochMs))
}
