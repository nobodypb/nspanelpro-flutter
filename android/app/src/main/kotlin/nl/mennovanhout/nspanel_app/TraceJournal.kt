package nl.mennovanhout.nspanel_app

import java.io.File
import java.io.FileOutputStream

/** Single writer. Bounded private JSONL segments, shared read-only with the collector. */
internal class TraceJournal(
    private val directory: File,
    private val prefix: String,
    private val now: () -> Long = System::currentTimeMillis,
    private val segmentBytes: Long = 256 * 1024,
    private val maxBytes: Long = 8 * 1024 * 1024,
    private val retentionMs: Long = 3 * 86400000L,
) {
    private var index = 0
    private var current: File? = null
    private var lastPrune = 0L
    private var openedAt = 0L

    @Synchronized fun append(line: String) {
        val bytes = (line + "\n").toByteArray(Charsets.UTF_8)
        require(bytes.size <= segmentBytes) { "Trace record too large" }
        check(directory.isDirectory || directory.mkdirs())
        val stamp = now()
        var target = current
        if (target == null || !target.exists() || target.length() + bytes.size > segmentBytes || stamp - openedAt >= 3600000 || stamp < openedAt) {
            do { target = File(directory, "$prefix-${(index++).toString().padStart(5, '0')}.jsonl") }
            while (target!!.exists())
            current = target
            openedAt = stamp
        }
        if (stamp - lastPrune >= 60000 || stamp < lastPrune || target!!.length() == 0L) {
            prune(stamp, bytes.size.toLong())
            lastPrune = stamp
        }
        FileOutputStream(target, true).use { it.write(bytes); it.flush() }
    }

    private fun prune(stamp: Long, incoming: Long) {
        val files = directory.listFiles()?.filter { TraceFiles.NAME.matches(it.name) }?.sortedBy { it.lastModified() } ?: return
        var total = files.sumOf { it.length() }
        var count = files.size
        for (file in files) {
            if (file == current) continue
            if (stamp - file.lastModified() > retentionMs || total + incoming + segmentBytes > maxBytes || count >= 64) {
                val size = file.length()
                if (file.delete()) { total -= size; count-- }
            }
        }
    }

}

internal object TraceFiles {
        val NAME = Regex("trace-[0-9]{13}-[0-9a-f-]{36}-[0-9]{5,}\\.jsonl")
        fun directory(filesDir: File) = File(filesDir, "panel-trace")
        fun readableFile(filesDir: File, name: String): File? {
            if (!NAME.matches(name)) return null
            val parent = directory(filesDir).canonicalFile
            val file = File(parent, name).canonicalFile
            return file.takeIf { it.parentFile == parent && it.isFile }
        }
    }
