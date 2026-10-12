package local.nspanel.doorbird

import org.junit.Assert.*
import org.junit.Test

class VideoRecoveryTest {
    @Test fun startupAndStalledFrameHaveSeparateTimeouts() {
        val video = VideoRecovery(); video.started(1000)
        assertFalse(video.stalled(10999)); assertTrue(video.stalled(11000))
        video.frame(11000)
        assertFalse(video.stalled(15999)); assertTrue(video.stalled(16000))
    }
    @Test fun bufferingGetsBoundedRecoveryTimeWithoutMaskingDecoderStalls() {
        val video = VideoRecovery(); video.started(0); video.frame(100)
        assertTrue(video.stalled(6100))
        assertFalse(video.stalled(6100, buffering = true))
        video.frame(8100)
        assertFalse(video.stalled(9000))
        assertFalse(video.stalled(18099, buffering = true))
        assertTrue(video.stalled(18100, buffering = true))
    }
    @Test fun aRecoveredBufferGapDoesNotCountAsContinuousHealthyVideo() {
        val video = VideoRecovery(); video.failed(0); video.started(1000)
        video.frame(1001); video.frame(9001); video.frame(12001)
        assertEquals(2000L, video.failed(12002))
    }
    @Test fun retriesBackOffAndOnlyBecomeDueOnce() {
        val video = VideoRecovery()
        for (delay in longArrayOf(1000, 2000, 5000, 10000, 15000, 15000)) {
            video.started(0)
            assertEquals(delay, video.failed(100))
            assertFalse(video.takeDue(100 + delay - 1))
            assertTrue(video.takeDue(100 + delay))
            assertFalse(video.takeDue(100 + delay))
        }
    }
    @Test fun oneFrameDoesNotResetBackoffButStableVideoDoes() {
        val video = VideoRecovery()
        video.failed(0); video.started(1000); video.frame(1001)
        assertEquals(2000L, video.failed(1002))
        video.started(5000)
        for (at in 5001L..15001L step 100L) video.frame(at)
        assertEquals(1000L, video.failed(16000))
    }
    @Test fun sessionCloseCancelsPendingRetry() {
        val video = VideoRecovery(); video.failed(0); video.cancel()
        assertFalse(video.takeDue(100000))
    }
}
