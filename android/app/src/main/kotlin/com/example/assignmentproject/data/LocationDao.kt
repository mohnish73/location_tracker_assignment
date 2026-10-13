package com.example.assignmentproject.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.DatabaseUtils
import com.example.assignmentproject.data.LocationTable.COL_ACCURACY
import com.example.assignmentproject.data.LocationTable.COL_ID
import com.example.assignmentproject.data.LocationTable.COL_LATITUDE
import com.example.assignmentproject.data.LocationTable.COL_LONGITUDE
import com.example.assignmentproject.data.LocationTable.COL_TIMESTAMP
import com.example.assignmentproject.data.LocationTable.TABLE

/**
 * Database controller: the only class that reads or writes the `locations` table.
 * Flutter never touches the database; it reaches these methods through the MethodChannel.
 * Methods are blocking, so call them off the main thread.
 */
class LocationDao(private val helper: LocationDbHelper) {

    fun insert(latitude: Double, longitude: Double, accuracy: Float, timestamp: Long): LocationRecord {
        val values = ContentValues().apply {
            put(COL_LATITUDE, latitude)
            put(COL_LONGITUDE, longitude)
            put(COL_ACCURACY, accuracy)
            put(COL_TIMESTAMP, timestamp)
        }
        val id = helper.writableDatabase.insertOrThrow(TABLE, null, values)
        return LocationRecord(id, latitude, longitude, accuracy, timestamp)
    }

    fun getLatest(): LocationRecord? = query(limit = 1).firstOrNull()

    /** Newest first. */
    fun getHistory(limit: Int): List<LocationRecord> = query(limit = limit)

    fun count(): Long = DatabaseUtils.queryNumEntries(helper.readableDatabase, TABLE)

    fun clearAll(): Int = helper.writableDatabase.delete(TABLE, null, null)

    /** Streams every row oldest first without loading the whole table into memory. */
    fun forEachChronological(action: (LocationRecord) -> Unit) {
        helper.readableDatabase.query(
            TABLE, null, null, null, null, null, "$COL_TIMESTAMP ASC, $COL_ID ASC",
        ).use { cursor ->
            while (cursor.moveToNext()) action(cursor.toRecord())
        }
    }

    private fun query(limit: Int): List<LocationRecord> =
        helper.readableDatabase.query(
            TABLE, null, null, null, null, null,
            "$COL_TIMESTAMP DESC, $COL_ID DESC",
            limit.toString(),
        ).use { cursor ->
            buildList(cursor.count) {
                while (cursor.moveToNext()) add(cursor.toRecord())
            }
        }

    private fun Cursor.toRecord() = LocationRecord(
        id = getLong(getColumnIndexOrThrow(COL_ID)),
        latitude = getDouble(getColumnIndexOrThrow(COL_LATITUDE)),
        longitude = getDouble(getColumnIndexOrThrow(COL_LONGITUDE)),
        accuracy = getFloat(getColumnIndexOrThrow(COL_ACCURACY)),
        timestamp = getLong(getColumnIndexOrThrow(COL_TIMESTAMP)),
    )

    companion object {
        fun getInstance(context: Context) = LocationDao(LocationDbHelper.getInstance(context))
    }
}
