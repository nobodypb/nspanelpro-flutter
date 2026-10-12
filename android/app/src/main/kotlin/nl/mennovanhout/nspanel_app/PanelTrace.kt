package nl.mennovanhout.nspanel_app

import android.content.Context
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicLong

/** A dedicated tag containing only explicitly allowed diagnostics. */
internal object PanelTrace {
    private val session = UUID.randomUUID().toString()
    private var sequence = 0L
    private var journal: TraceJournal? = null
    private val lost = AtomicLong()
    private val writer = ThreadPoolExecutor(1, 1, 30, TimeUnit.SECONDS,
        ArrayBlockingQueue<Runnable>(512), { task -> Thread(task, "panel-trace-writer").apply { isDaemon = true } })
        .apply { allowCoreThreadTimeOut(true) }

    @Synchronized fun initialize(context: Context) {
        if (journal == null) journal = TraceJournal(TraceFiles.directory(context.applicationContext.filesDir),
            "trace-${System.currentTimeMillis()}-$session")
    }

    @Synchronized fun record(event: String, fields: Map<*, *>) {
        val safe = TraceFields.sanitize(event, fields) ?: return
        val row = mapOf("v" to 1, "session" to session, "seq" to ++sequence,
            "wall_ms" to System.currentTimeMillis(), "elapsed_ms" to SystemClock.elapsedRealtime(),
            "uptime_ms" to SystemClock.uptimeMillis(), "event" to event, "fields" to safe)
        val line = JSONObject(row).toString()
        Log.i("NSPanelTrace", line)
        val target = journal ?: return
        try {
            writer.execute {
                val dropped = lost.getAndSet(0)
                val stored = line.dropLast(1) + ",\"buffer_lost_before\":$dropped}"
                try { target.append(stored) }
                catch (_: Exception) {
                    lost.addAndGet(dropped + 1)
                    Log.w("NSPanelTraceStatus", "Trace journal write failed")
                }
            }
        } catch (_: RejectedExecutionException) {
            lost.incrementAndGet()
            Log.w("NSPanelTraceStatus", "Trace journal queue full")
        }
    }
}

internal object TraceFields {
    private val numbers = setOf("fingers", "device_id", "event_uptime_ms", "down_uptime_ms",
        "detector_ms", "value", "baseline", "old_baseline", "noise", "threshold",
        "delay_seconds", "multiplier", "model_age_ms", "baseline_age_ms",
        "previous_model_age_ms", "previous_baseline_age_ms", "evidence_ms", "sample_count",
        "count", "since_switch_ms")
    private val booleans = setOf("interactive", "foreground", "saver", "accepted", "dark", "adaptive", "suppressed")
    private val reasons = mapOf(
        "display" to setOf("screen", "snapshot", "lifecycle", "wake"),
        "calibration" to setOf("initial", "weak_stable"),
        "proximity" to setOf("enter", "leave", "recalibrated_leave"),
        "detector" to setOf("started", "stopped", "reconfigured"),
        "recovery" to setOf("sensor_gap", "touch", "strong", "expired", "restored", "direction", "ready"),
        "repetition" to setOf("off_near"),
        "wake_request" to setOf("app", "hold", "ring", "mqtt", "touch", "proximity", "platform", "initial", "foreground"))
    private val actions = setOf("down", "up", "cancel", "pointer_down", "pointer_up", "vendor_down", "other")

    fun sanitize(event: String, fields: Map<*, *>): Map<String, Any?>? {
        if (event != "touch" && event !in reasons) return null
        return fields.entries.mapNotNull { (key, value) ->
            if (key !is String) null
            else when {
                key in numbers && (value == null || value is Number && value.toDouble().isFinite()) -> key to value
                key in booleans && value is Boolean -> key to value
                key == "reason" && value in (reasons[event] ?: emptySet()) -> key to value
                key == "decision" && event == "wake_request" && value in setOf("accepted", "inactive", "disabled", "near_blocked") -> key to value
                key == "action" && event == "touch" && value in actions -> key to value
                else -> null
            }
        }.toMap()
    }
}
