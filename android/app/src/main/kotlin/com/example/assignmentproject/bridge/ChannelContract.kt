package com.example.assignmentproject.bridge

/**
 * The single MethodChannel + single EventChannel contract shared with Dart
 * (mirrored in lib/app/data/tracker_channel.dart). Documented in README.md.
 */
object ChannelContract {
    const val METHOD_CHANNEL = "com.example.assignmentproject/tracker"
    const val EVENT_CHANNEL = "com.example.assignmentproject/location_stream"

    object Methods {
        const val START_TRACKING = "startTracking"
        const val STOP_TRACKING = "stopTracking"
        const val GET_TRACKING_STATUS = "getTrackingStatus"
        const val SET_TRACKING_INTERVAL = "setTrackingInterval"
        const val GET_LAST_LOCATION = "getLastLocation"
        const val GET_HISTORY = "getHistory"
        const val GET_RECORD_COUNT = "getRecordCount"
        const val CLEAR_HISTORY = "clearHistory"
        const val EXPORT_CSV = "exportCsv"
        const val GET_PERMISSION_STATUS = "getPermissionStatus"
        const val REQUEST_LOCATION_PERMISSION = "requestLocationPermission"
        const val REQUEST_BACKGROUND_LOCATION_PERMISSION = "requestBackgroundLocationPermission"
        const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"
        const val REQUEST_IGNORE_BATTERY_OPTIMIZATIONS = "requestIgnoreBatteryOptimizations"
        const val OPEN_APP_SETTINGS = "openAppSettings"
        const val OPEN_LOCATION_SETTINGS = "openLocationSettings"
    }

    /** Codes returned through MethodChannel.Result.error(code, message, details). */
    object Errors {
        const val PERMISSION_DENIED = "PERMISSION_DENIED"
        const val LOCATION_DISABLED = "LOCATION_DISABLED"
        const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
        const val DATABASE_ERROR = "DATABASE_ERROR"
        const val SERVICE_ERROR = "SERVICE_ERROR"
        const val EXPORT_FAILED = "EXPORT_FAILED"
        const val REQUEST_IN_PROGRESS = "REQUEST_IN_PROGRESS"
        const val SETTINGS_UNAVAILABLE = "SETTINGS_UNAVAILABLE"
        const val UNEXPECTED = "UNEXPECTED"
    }

    object PermissionStatus {
        const val GRANTED = "granted"
        const val DENIED = "denied"
        const val PERMANENTLY_DENIED = "permanentlyDenied"
        const val NOT_REQUIRED = "notRequired"
    }
}
