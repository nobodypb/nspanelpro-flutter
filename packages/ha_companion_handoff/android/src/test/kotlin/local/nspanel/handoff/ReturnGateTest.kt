package local.nspanel.handoff
import org.junit.Assert.*
import org.junit.Test
class ReturnGateTest {
    @Test fun stalePreparationCannotConsumeReturn() {
        val gate = ReturnGate()
        assertFalse(gate.prepare("session", "session"))
        assertTrue(gate.request())
        assertFalse(gate.prepare("session", "old"))
        assertTrue(gate.prepare("session", "session"))
    }
    @Test fun duplicateScreenAndReadyEventsOnlyReturnOnce() {
        val gate = ReturnGate()
        assertTrue(gate.request()); assertFalse(gate.request())
        assertTrue(gate.prepare("s", "s")); assertFalse(gate.prepare("s", "s"))
    }
}
