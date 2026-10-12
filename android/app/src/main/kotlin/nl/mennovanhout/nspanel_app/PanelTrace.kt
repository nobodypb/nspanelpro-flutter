package nl.mennovanhout.nspanel_app

import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.util.UUID

/** A dedicated tag containing only explicitly allowed diagnostics. */
internal object PanelTrace {
    private val session = UUID.randomUUID().toString()
    private var sequence = 0L

    @Synchronized fun record(event: String, fields: Map<*, *>) {
        val safe = TraceFields.sanitize(event, fields) ?: return
        val row = mapOf("v" to 1, "session" to session, "seq" to ++sequence,
            "wall_ms" to System.currentTimeMillis(), "elapsed_ms" to SystemClock.elapsedRealtime(),
            "uptime_ms" to SystemClock.uptimeMillis(), "event" to event, "fields" to safe)
        Log.i("NSPanelTrace", JSONObject(row).toString())
    }
}

internal object TraceFields {
    private val numbers = setOf("fingers", "device_id", "event_uptime_ms", "down_uptime_ms",
        "detector_ms", "value", "baseline", "old_baseline", "noise", "threshold",
        "delay_seconds", "multiplier")
    private val booleans = setOf("interactive", "foreground", "saver", "accepted", "dark", "adaptive")
    private val reasons = mapOf(
        "display" to setOf("screen", "snapshot", "lifecycle", "wake"),
        "calibration" to setOf("initial", "weak_stable"),
        "proximity" to setOf("enter", "leave", "recalibrated_leave"),
        "detector" to setOf("started", "stopped", "reconfigured"))
    private val actions = setOf("down", "up", "cancel", "pointer_down", "pointer_up", "vendor_down", "other")

    fun sanitize(event: String, fields: Map<*, *>): Map<String, Any?>? {
        if (event != "touch" && event !in reasons) return null
        return fields.entries.mapNotNull { (key, value) ->
            if (key !is String) null
            else when {
                key in numbers && (value == null || value is Number && value.toDouble().isFinite()) -> key to value
                key in booleans && value is Boolean -> key to value
                key == "reason" && value in (reasons[event] ?: emptySet()) -> key to value
                key == "action" && event == "touch" && value in actions -> key to value
                else -> null
            }
        }.toMap()
    }
}
