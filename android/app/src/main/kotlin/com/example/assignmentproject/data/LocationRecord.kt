package com.example.assignmentproject.data

/** One stored location fix. Mirrors a row of the `locations` table. */
data class LocationRecord(
    val id: Long,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    /** Epoch milliseconds (UTC) at which the fix was taken. */
    val timestamp: Long,
) {
    /** Shape sent over the MethodChannel / EventChannel (StandardMessageCodec friendly). */
    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "latitude" to latitude,
        "longitude" to longitude,
        "accuracy" to accuracy.toDouble(),
        "timestamp" to timestamp,
    )
}
