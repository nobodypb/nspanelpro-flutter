package local.nspanel.doorbird

import android.util.Base64
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.Closeable
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URL
import java.security.MessageDigest
import java.security.cert.X509Certificate
import java.util.concurrent.CopyOnWriteArrayList
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class IntercomFailure(val reason: String) : Exception(reason)

/** Deliberately no URL/exception logging: media URIs contain temporary credentials. */
class DoorBirdConnection(private val profile: Map<*, *>) : Closeable {
    val host = profile["host"] as? String ?: throw IntercomFailure("configuration")
    val username = profile["username"] as? String ?: throw IntercomFailure("configuration")
    val password = profile["password"] as? String ?: throw IntercomFailure("configuration")
    private val pin = (profile["certificate_sha256"] as? String)?.lowercase()
        ?: throw IntercomFailure("configuration")
    private val sockets = CopyOnWriteArrayList<Closeable>()
    private val requests = CopyOnWriteArrayList<HttpURLConnection>()
    @Volatile private var closed = false
    private var lastRequest = 0L
    private var session = ""
    init {
        if (!host.matches(Regex("[a-zA-Z0-9.-]+")) || !pin.matches(Regex("[a-f0-9]{64}")) ||
            username.isEmpty() || password.isEmpty()) throw IntercomFailure("configuration")
    }
    @Synchronized private fun pace() {
        if (closed) throw IntercomFailure("closed")
        val wait = 1050 - (android.os.SystemClock.elapsedRealtime() - lastRequest)
        if (wait > 0) Thread.sleep(wait)
        if (closed) throw IntercomFailure("closed")
        lastRequest = android.os.SystemClock.elapsedRealtime()
    }
    fun authenticate() {
        pace()
        val trust = object : X509TrustManager {
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) = Unit
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                val actual = MessageDigest.getInstance("SHA-256").digest(chain[0].encoded)
                    .joinToString("") { "%02x".format(it.toInt() and 255) }
                if (actual != pin) throw java.security.cert.CertificateException("Device certificate changed")
            }
        }
        val tls = SSLContext.getInstance("TLS").apply { init(null, arrayOf<TrustManager>(trust), null) }
        val c = URL("https://$host/bha-api/getsession.cgi").openConnection() as HttpsURLConnection
        c.sslSocketFactory = tls.socketFactory
        // Exact configured device certificate is checked by the trust manager.
        c.hostnameVerifier = javax.net.ssl.HostnameVerifier { name, _ -> name == host }
        c.instanceFollowRedirects = false
        c.connectTimeout = 5000; c.readTimeout = 5000
        c.setRequestProperty("Authorization", "Basic " + Base64.encodeToString(
            "$username:$password".toByteArray(Charsets.UTF_8), Base64.NO_WRAP))
        requests.add(c)
        if (closed) { c.disconnect(); throw IntercomFailure("closed") }
        try {
            android.util.Log.i("Intercom", "session HTTP ${c.responseCode}")
            checkStatus(c.responseCode)
            val bytes = c.inputStream.use { it.readBytesLimited(16384) }
            val result = JSONObject(String(bytes, Charsets.UTF_8)).getJSONObject("BHA")
            session = result.optString("SESSIONID")
            if (!session.matches(Regex("[a-zA-Z0-9]+"))) throw IntercomFailure("authentication")
        } catch (_: javax.net.ssl.SSLException) {
            throw IntercomFailure("certificate")
        } finally { c.disconnect(); requests.remove(c) }
        if (closed) throw IntercomFailure("closed")
    }
    fun receive(): BufferedInputStream {
        pace()
        val c = URL("http://$host/bha-api/audio-receive.cgi?sessionid=$session")
            .openConnection() as HttpURLConnection
        c.instanceFollowRedirects = false
        c.connectTimeout = 5000; c.readTimeout = 5000
        requests.add(c)
        if (closed) { c.disconnect(); throw IntercomFailure("closed") }
        android.util.Log.i("Intercom", "receive HTTP ${c.responseCode}, length ${c.contentLength}")
        checkStatus(c.responseCode)
        checkAudioContentType(c.contentType)
        return BufferedInputStream(c.inputStream)
    }
    // DoorBird requires a streaming HTTP/1.0 body with a declared long length.
    // HttpURLConnection buffers/waits for that entire body before exposing errors.
    // A raw socket permits a concurrent status reader and immediate cancellation.
    fun transmit(): Socket {
        pace()
        val socket = Socket()
        sockets.add(socket)
        if (closed) { socket.close(); throw IntercomFailure("closed") }
        socket.connect(InetSocketAddress(host, 80), 5000)
        socket.tcpNoDelay = true
        socket.getOutputStream().write(("POST /bha-api/audio-transmit.cgi?sessionid=$session HTTP/1.0\r\n" +
            "Host: $host\r\nContent-Type: audio/basic\r\nContent-Length: 9999999\r\n" +
            "Connection: Keep-Alive\r\nCache-Control: no-cache\r\n\r\n").toByteArray(Charsets.US_ASCII))
        return socket
    }
    override fun close() {
        closed = true
        sockets.forEach { try { it.close() } catch (_: Exception) {} }
        requests.forEach { it.disconnect() }
        sockets.clear(); requests.clear(); session = ""
    }
    companion object {
        fun checkAudioContentType(value: String?) {
            if (value?.substringBefore(';')?.trim()?.lowercase() != "audio/basic") {
                throw IntercomFailure("audio_response")
            }
        }
        fun checkStatus(status: Int) {
            if (status != 200) throw IntercomFailure(when (status) {
                204 -> "permission"
                401, 403 -> "authentication"
                423 -> "locked"
                503 -> "busy"
                else -> "network"
            })
        }
    }
}

private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
    val out = java.io.ByteArrayOutputStream()
    val buffer = ByteArray(1024)
    while (true) {
        val n = read(buffer)
        if (n < 0) return out.toByteArray()
        if (out.size() + n > limit) throw IntercomFailure("protocol")
        out.write(buffer, 0, n)
    }
}
