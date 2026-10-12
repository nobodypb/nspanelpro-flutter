package local.nspanel.doorbird

import org.junit.Assert.*
import org.junit.Test

class RingMixerTest {
    @Test fun quietNotificationPreservesConversationAndEnds() {
        val mixer = RingMixer(shortArrayOf(10000, -10000))
        mixer.start(.2f)
        val output = shortArrayOf(5000, 5000, 5000)
        mixer.mix(output)
        assertArrayEquals(shortArrayOf(7000, 3000, 5000), output)
        val next = shortArrayOf(5000)
        mixer.mix(next); assertEquals(5000, next[0].toInt())
    }
    @Test fun repeatRestartsInsteadOfStackingAndClipsSafely() {
        val mixer = RingMixer(shortArrayOf(10000, -10000))
        mixer.start(.6f); mixer.mix(shortArrayOf(0))
        mixer.start(.6f)
        val output = shortArrayOf(32000, -32000)
        mixer.mix(output)
        assertArrayEquals(shortArrayOf(32767, -32768), output)
    }
    @Test fun pcmDecodePreservesSignedSamples() {
        assertArrayEquals(shortArrayOf(0, -32768, 32767), RingMixer.decode(byteArrayOf(0, 0, 0, -128, -1, 127)))
    }
}
