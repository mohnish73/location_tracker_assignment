package com.example.assignmentproject.data

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Writes every stored fix to a CSV file in the app cache (shared later through FileProvider). */
class CsvExporter(private val context: Context, private val dao: LocationDao) {

    data class Export(val file: File, val rows: Int)

    fun export(): Export {
        val dir = File(context.cacheDir, EXPORT_DIR).apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() } // keep only the latest export
        val file = File(dir, "locations_${System.currentTimeMillis()}.csv")
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)

        var rows = 0
        file.bufferedWriter().use { out ->
            out.appendLine("id,latitude,longitude,accuracy,timestamp,time")
            dao.forEachChronological { r ->
                out.appendLine(
                    "${r.id},${r.latitude},${r.longitude},${r.accuracy},${r.timestamp},${iso.format(Date(r.timestamp))}",
                )
                rows++
            }
        }
        return Export(file, rows)
    }

    companion object {
        /** Must match res/xml/file_paths.xml. */
        const val EXPORT_DIR = "exports"
    }
}
