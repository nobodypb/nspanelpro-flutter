package nl.mennovanhout.nspanel_app.intercom

import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class AudioResponseTest {
    @Test fun acceptsG711WithOptionalParameters() {
        DoorBirdConnection.checkAudioContentType("audio/basic")
        DoorBirdConnection.checkAudioContentType(" Audio/Basic ; rate=8000")
    }
    @Test fun rejectsRedirectedHtmlBeforeItReachesTheSpeaker() {
        for (type in listOf(null, "text/html; charset=UTF-8", "application/json", "audio/wav")) {
            try {
                DoorBirdConnection.checkAudioContentType(type)
                fail("Unexpected content must not be played")
            } catch (e: IntercomFailure) { assertEquals("audio_response", e.reason) }
        }
    }
}
