package com.example.assignmentproject.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Table and column names, kept in one place so SQL and DAO code never drift apart. */
object LocationTable {
    const val TABLE = "locations"
    const val COL_ID = "id"
    const val COL_LATITUDE = "latitude"
    const val COL_LONGITUDE = "longitude"
    const val COL_ACCURACY = "accuracy"
    const val COL_TIMESTAMP = "timestamp"

    const val SQL_CREATE_TABLE = """
        CREATE TABLE $TABLE (
            $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            $COL_LATITUDE REAL NOT NULL,
            $COL_LONGITUDE REAL NOT NULL,
            $COL_ACCURACY REAL NOT NULL,
            $COL_TIMESTAMP INTEGER NOT NULL
        )
    """

    const val SQL_CREATE_TIMESTAMP_INDEX =
        "CREATE INDEX idx_${TABLE}_$COL_TIMESTAMP ON $TABLE($COL_TIMESTAMP DESC)"
}

/**
 * Owns the SQLite file. A single process-wide instance (and therefore a single
 * SQLiteDatabase connection pool) is shared by the service and the MethodChannel
 * handler, so SQLite's own locking serialises writes; WAL lets reads run while
 * the service is writing.
 */
class LocationDbHelper private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    init {
        setWriteAheadLoggingEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(LocationTable.SQL_CREATE_TABLE)
        db.execSQL(LocationTable.SQL_CREATE_TIMESTAMP_INDEX)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Migrations are applied step by step so existing rows are never dropped.
        // Example for version 2:
        // if (oldVersion < 2) {
        //     db.execSQL("ALTER TABLE ${LocationTable.TABLE} ADD COLUMN activity_type TEXT")
        // }
    }

    companion object {
        const val DB_NAME = "location_tracker.db"
        const val DB_VERSION = 1

        @Volatile
        private var instance: LocationDbHelper? = null

        fun getInstance(context: Context): LocationDbHelper =
            instance ?: synchronized(this) {
                instance ?: LocationDbHelper(context).also { instance = it }
            }
    }
}
