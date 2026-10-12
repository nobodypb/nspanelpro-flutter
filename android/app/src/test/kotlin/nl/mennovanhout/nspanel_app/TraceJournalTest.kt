package nl.mennovanhout.nspanel_app

import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.junit.Rule
import org.junit.rules.TemporaryFolder

class TraceJournalTest {
    @get:Rule val tmp = TemporaryFolder()
    private val prefix = "trace-1791800000000-12345678-1234-1234-1234-123456789abc"

    @Test fun rotationStaysBoundedAndSurvivesNewWriter() {
        val root=tmp.newFolder()
        val store=TraceJournal(root,prefix,segmentBytes=100,maxBytes=400)
        repeat(100) { store.append("{\"seq\":$it,\"value\":123456789}") }
        assertTrue(root.listFiles()!!.sumOf { it.length() }<=400)
        val last=root.listFiles()!!.sortedBy { it.name }.last().readText()
        assertTrue(last.contains("\"seq\":99"))
        val restarted=TraceJournal(root,prefix,segmentBytes=100,maxBytes=400)
        restarted.append("{\"seq\":100}")
        assertTrue(root.listFiles()!!.any { it.readText().contains("\"seq\":100") })
    }

    @Test fun agesOutOldSegmentsAndNeverReadsOutsideDirectory() {
        val files=tmp.newFolder(); val dir=TraceFiles.directory(files)
        var now=System.currentTimeMillis()
        val store=TraceJournal(dir,prefix,now={now},retentionMs=1000)
        store.append("{\"seq\":1}")
        val old=dir.listFiles()!!.single()
        old.setLastModified(now-5000)
        now+=3600001
        store.append("{\"seq\":2}")
        assertFalse(old.exists())
        assertNotNull(TraceFiles.readableFile(files,dir.listFiles()!!.single().name))
        assertNull(TraceFiles.readableFile(files,"../shared_prefs/private.xml"))
        assertNull(TraceFiles.readableFile(files,"private.xml"))
    }

    @Test fun manyProcessSessionsCannotCreateUnboundedTinySegments() {
        val dir=tmp.newFolder()
        repeat(100) { i ->
            TraceJournal(dir,"trace-${1791800000000L+i}-12345678-1234-1234-1234-123456789abc").append("{}")
        }
        assertTrue(dir.listFiles()!!.size<=64)
    }
}
