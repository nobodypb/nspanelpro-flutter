package local.nspanel.doorbird

/** Video-only retry policy. The owner keeps audio and microphone untouched. */
class VideoRecovery {
    private var failures = 0
    private var startedAt = 0L
    private var lastFrame: Long? = null
    private var healthySince: Long? = null
    private var retryAt: Long? = null
    fun started(now: Long) {
        startedAt = now; lastFrame = null; healthySince = null; retryAt = null
    }
    fun frame(now: Long) {
        lastFrame = now
        if (healthySince == null) healthySince = now
        if (now - healthySince!! >= 10000) failures = 0
    }
    fun stalled(now: Long): Boolean =
        if (lastFrame == null) now - startedAt >= 10000 else now - lastFrame!! >= 5000
    fun failed(now: Long): Long {
        val delay = delays[failures.coerceAtMost(delays.lastIndex)]
        if (failures < delays.lastIndex) failures++
        retryAt = now + delay; lastFrame = null; healthySince = null
        return delay
    }
    fun takeDue(now: Long): Boolean {
        val due = retryAt ?: return false
        if (now < due) return false
        retryAt = null; return true
    }
    fun cancel() { retryAt = null }
    companion object { private val delays = longArrayOf(1000, 2000, 5000, 10000, 15000) }
}
