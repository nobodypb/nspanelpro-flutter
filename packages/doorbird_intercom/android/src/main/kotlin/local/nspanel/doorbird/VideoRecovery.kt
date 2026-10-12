package local.nspanel.doorbird

/** Video-only retry policy. The owner keeps audio and microphone untouched. */
class VideoRecovery {
    private var failures = 0
    private var startedAt = 0L
    private var lastFrame: Long? = null
    private var healthySince: Long? = null
    private var retryAt: Long? = null
    private var recoveringBuffer = false
    fun started(now: Long) {
        startedAt = now; lastFrame = null; healthySince = null; retryAt = null; recoveringBuffer = false
    }
    fun frame(now: Long) {
        recoveringBuffer = false
        if (lastFrame != null && now - lastFrame!! >= FRAME_TIMEOUT_MS) healthySince = null
        lastFrame = now
        if (healthySince == null) healthySince = now
        if (now - healthySince!! >= 10000) failures = 0
    }
    // READY can precede the next decodable keyframe after a packet gap. Keep
    // the bounded grace until a frame actually returns, not just a state change.
    fun buffering() { recoveringBuffer = true }
    fun stalled(now: Long, buffering: Boolean = false): Boolean {
        if (buffering) recoveringBuffer = true
        return if (lastFrame == null) now - startedAt >= BUFFERING_TIMEOUT_MS
        else now - lastFrame!! >= if (recoveringBuffer) BUFFERING_TIMEOUT_MS else FRAME_TIMEOUT_MS
    }
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
    companion object {
        const val FRAME_TIMEOUT_MS = 5000L
        const val BUFFERING_TIMEOUT_MS = 10000L
        // Allow brief transport gaps; prolonged RTP silence may still end the stream.
        const val RTSP_TIMEOUT_MS = 12000L
        private val delays = longArrayOf(1000, 2000, 5000, 10000, 15000)
    }
}
