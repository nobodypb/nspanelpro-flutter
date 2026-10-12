package local.nspanel.handoff

/** Idempotent native return handshake, independent of Android lifecycle order. */
internal class ReturnGate {
    var pending = false; private set
    var requested = false; private set
    fun request(): Boolean {
        if (pending) return false
        pending = true
        return true
    }
    fun prepare(expected: String, received: String?): Boolean {
        if (!pending || requested || expected != received) return false
        requested = true
        return true
    }
}
