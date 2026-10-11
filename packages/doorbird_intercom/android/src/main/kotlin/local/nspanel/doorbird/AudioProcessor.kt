package local.nspanel.doorbird

/** Session-owned AEC3/NS. Close only after the audio workers have stopped. */
class AudioProcessor : AutoCloseable {
    private var handle = create()
    fun render(samples: ShortArray) { check(process(handle, samples, true, 0) == 0) }
    fun capture(samples: ShortArray, delayMs: Int) {
        check(process(handle, samples, false, delayMs.coerceIn(0, 500)) == 0)
    }
    override fun close() { if (handle != 0L) { destroy(handle); handle = 0 } }
    private external fun create(): Long
    private external fun process(handle: Long, samples: ShortArray, reverse: Boolean, delay: Int): Int
    private external fun destroy(handle: Long)
    companion object { init { System.loadLibrary("intercom_apm") } }
}
