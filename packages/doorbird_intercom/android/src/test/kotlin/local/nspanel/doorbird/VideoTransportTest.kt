package local.nspanel.doorbird

import org.junit.Assert.*
import org.junit.Test

class VideoTransportTest {
    @Test fun missingUdpFramesSelectTcpForTheNextAttempt() {
        val transport = VideoTransport()
        assertFalse(transport.useTcp)
        transport.failed(receivedFrame = false)
        assertTrue(transport.useTcp)
        transport.failed(receivedFrame = true)
        assertTrue(transport.useTcp)
    }
    @Test fun aGapInWorkingUdpDoesNotSwitchBackToTcp() {
        val transport = VideoTransport()
        transport.failed(receivedFrame = true)
        assertFalse(transport.useTcp)
    }
}
