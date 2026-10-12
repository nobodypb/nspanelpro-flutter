package nl.mennovanhout.nspanel_app

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.FileNotFoundException

/** Shell can read via android.permission.DUMP; no general app access or writes.
 * A separate lightweight process avoids starting the Flutter activity for reads.
 */
class TraceProvider : ContentProvider() {
    override fun onCreate() = true
    override fun getType(uri: Uri) = "application/x-ndjson"
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
                       selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        require(uri.path == "/files")
        val result = MatrixCursor(arrayOf("name", "bytes"))
        TraceFiles.directory(context!!.filesDir).listFiles()
            ?.filter { TraceFiles.readableFile(context!!.filesDir, it.name) != null }
            ?.sortedBy { it.name }?.forEach { result.addRow(arrayOf(it.name, it.length())) }
        return result
    }
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r" || uri.pathSegments.size != 2 || uri.pathSegments[0] != "files") {
            throw FileNotFoundException("Read-only trace file")
        }
        val file = TraceFiles.readableFile(context!!.filesDir, uri.pathSegments[1])
            ?: throw FileNotFoundException("Unknown trace file")
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw SecurityException("Read only")
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = throw SecurityException("Read only")
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = throw SecurityException("Read only")
}
