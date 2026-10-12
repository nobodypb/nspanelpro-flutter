package local.nspanel.doorbird

/** A bounded notification mixed before the AEC render reference, at 16 kHz mono. */
class RingMixer(private val samples: ShortArray) {
    private var position = samples.size
    private var gain = 0f
    @Volatile var mixedSamples = 0L
        private set
    @Synchronized fun start(level: Float) {
        gain = if (level.isFinite()) level.coerceIn(0f, 1f) else 0f
        position = 0
    }
    @Synchronized fun mix(output: ShortArray) {
        for (i in output.indices) {
            if (position >= samples.size) break
            mixedSamples++
            output[i] = (output[i].toInt() + (samples[position++] * gain).toInt())
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
    }
    companion object {
        fun decode(bytes: ByteArray): ShortArray = ShortArray(bytes.size / 2) { i ->
            ((bytes[i * 2].toInt() and 255) or (bytes[i * 2 + 1].toInt() shl 8)).toShort()
        }
    }
}
