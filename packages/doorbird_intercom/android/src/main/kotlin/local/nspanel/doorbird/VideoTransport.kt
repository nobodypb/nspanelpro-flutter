package local.nspanel.doorbird

/** Prefer live RTP datagrams; fall back if the LAN does not deliver UDP video. */
class VideoTransport {
    var useTcp = false
        private set
    fun failed(receivedFrame: Boolean) {
        if (!receivedFrame) useTcp = true
    }
}
