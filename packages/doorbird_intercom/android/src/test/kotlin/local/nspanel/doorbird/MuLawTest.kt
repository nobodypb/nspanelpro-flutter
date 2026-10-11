package local.nspanel.doorbird

import org.junit.Assert.*
import org.junit.Test

class MuLawTest {
    @Test fun knownWireValues() {
        assertEquals(0, MuLaw.decode(0xff.toByte()).toInt())
        assertEquals(0, MuLaw.decode(0x7f.toByte()).toInt())
        assertEquals(32124, MuLaw.decode(0x80.toByte()).toInt())
        assertEquals(-32124, MuLaw.decode(0x00).toInt())
        assertEquals(0xff.toByte(), MuLaw.encode(0))
    }
    @Test fun everyCodeRoundTripsExceptDuplicateZero() {
        for (i in 0..255) {
            val expected = if (i == 127) 255 else i
            assertEquals(expected, MuLaw.encode(MuLaw.decode(i.toByte())).toInt() and 255)
        }
    }
    @Test fun saturationPreservesSign() {
        assertEquals(0x00, MuLaw.encode(Short.MIN_VALUE).toInt() and 255)
        assertEquals(0x80, MuLaw.encode(Short.MAX_VALUE).toInt() and 255)
    }
}
