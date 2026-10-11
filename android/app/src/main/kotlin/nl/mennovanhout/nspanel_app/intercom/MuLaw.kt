package nl.mennovanhout.nspanel_app.intercom

/** ITU G.711 mu-law; no containers, 8000 mono samples/second on the wire. */
object MuLaw {
    fun decode(value: Byte): Short {
        val u = value.toInt().inv() and 255
        val magnitude = (((u and 15) shl 3) + 132) shl ((u shr 4) and 7)
        return (if (u and 128 != 0) 132 - magnitude else magnitude - 132).toShort()
    }
    fun encode(value: Short): Byte {
        val sample = value.toInt()
        val sign = if (sample < 0) 128 else 0
        val magnitude = kotlin.math.abs(sample).coerceAtMost(32635) + 132
        var exponent = 7
        var mask = 0x4000
        while (exponent > 0 && magnitude and mask == 0) { exponent--; mask = mask shr 1 }
        return (sign or (exponent shl 4) or ((magnitude shr (exponent + 3)) and 15)).inv().toByte()
    }
}
