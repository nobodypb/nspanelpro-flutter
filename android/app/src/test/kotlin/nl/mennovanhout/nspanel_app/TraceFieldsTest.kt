package nl.mennovanhout.nspanel_app

import org.junit.Assert.*
import org.junit.Test

class TraceFieldsTest {
    @Test fun removesContentAndInvalidValues() {
        assertEquals(mapOf("action" to "down", "accepted" to false, "device_id" to 2),
            TraceFields.sanitize("touch", mapOf("action" to "down", "accepted" to false,
                "device_id" to 2, "x" to 123, "text" to "private", "threshold" to Double.NaN,
                "reason" to "private", "noise" to "private")))
        assertNull(TraceFields.sanitize("private", emptyMap<Any, Any>()))
    }
    @Test fun preservesCalibrationNullAndNumericValues() {
        val fields = mapOf("reason" to "initial", "old_baseline" to null,
            "baseline" to 20.5, "delay_seconds" to 120, "dark" to true)
        assertEquals(fields, TraceFields.sanitize("calibration", fields))
    }
}
