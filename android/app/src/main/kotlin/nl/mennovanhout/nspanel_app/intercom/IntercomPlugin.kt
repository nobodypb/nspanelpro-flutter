package nl.mennovanhout.nspanel_app.intercom

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.*
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Surface
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.rtsp.RtspMediaSource
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.EOFException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** One foreground session; all callbacks carry its generation. No background service. */
class IntercomPlugin(private val activity: Activity, engine: FlutterEngine) {
    private val main = Handler(Looper.getMainLooper())
    private val textures = engine.renderer
    private var events: EventChannel.EventSink? = null
    private var session: Session? = null
    private var permissionResult: MethodChannel.Result? = null
    private val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val commands = MethodChannel(engine.dartExecutor.binaryMessenger, "nl.mennovanhout.nspanel/intercom")
    init {
        // RTSP errors can embed credential-bearing URIs; report only typed errors.
        androidx.media3.common.util.Log.setLogLevel(androidx.media3.common.util.Log.LOG_LEVEL_OFF)
        EventChannel(engine.dartExecutor.binaryMessenger, "nl.mennovanhout.nspanel/intercomEvents")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { events = sink }
                override fun onCancel(arguments: Any?) { stop(); events = null }
            })
        commands.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "open" -> {
                        stop()
                        val args = call.arguments as Map<*, *>
                        val s = Session((args["session"] as Number).toInt(), args["profile"] as Map<*, *>)
                        session = s; s.start()
                        result.success(mapOf("texture" to s.texture.id()))
                    }
                    "permission" -> {
                        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) result.success(true)
                        else if (permissionResult != null) result.success(false)
                        else { permissionResult = result; activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION) }
                    }
                    "microphone" -> {
                        val args = call.arguments as Map<*, *>
                        val s = session
                        if (s == null || s.id != (args["session"] as Number).toInt()) throw IntercomFailure("closed")
                        s.microphone(args["enabled"] == true); result.success(null)
                    }
                    "volume" -> {
                        val args = call.arguments as Map<*, *>
                        session?.takeIf { it.id == (args["session"] as Number).toInt() }?.volume =
                            (args["volume"] as Number).toFloat().coerceIn(0f, 1f)
                        result.success(null)
                    }
                    "stop" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args == null || session?.id == (args["session"] as? Number)?.toInt()) stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                diagnostic("command", e)
                stop()
                result.error((e as? IntercomFailure)?.reason ?: "network", "Intercom operation failed", null)
            }
        }
    }
    fun permission(request: Int, granted: IntArray): Boolean {
        if (request != PERMISSION) return false
        permissionResult?.success(granted.isNotEmpty() && granted[0] == PackageManager.PERMISSION_GRANTED)
        permissionResult = null; return true
    }
    fun background() { if (permissionResult == null) stop("background") }
    fun screenOff() { stop("screen_off") }
    fun dispose() { stop(); permissionResult?.success(false); permissionResult = null; commands.setMethodCallHandler(null); events = null }
    private fun stop(reason: String? = null) {
        val old = session ?: return
        session = null; old.close()
        if (reason != null) events?.success(mapOf("session" to old.id, "kind" to "ended", "reason" to reason))
    }
    private fun emit(s: Session, kind: String, extra: Map<String, Any> = emptyMap()) {
        main.post { if (session === s && !s.closed.get()) events?.success(mapOf("session" to s.id, "kind" to kind) + extra) }
    }
    private fun diagnostic(stage: String, e: Exception) {
        // Class and code location only: exception messages/URIs may contain secrets.
        val location = e.stackTrace.firstOrNull { it.className.startsWith("nl.mennovanhout") }
        android.util.Log.w("Intercom", "$stage:${e.javaClass.simpleName}:${location?.methodName}:${location?.lineNumber}")
    }
    fun stopped() { stop("background") }
    private fun failed(s: Session, e: Exception) {
        diagnostic("media", e)
        main.post {
            if (session === s) {
                events?.success(mapOf("session" to s.id, "kind" to "error", "reason" to ((e as? IntercomFailure)?.reason ?: "network")))
                stop()
            }
        }
    }
    private inner class Session(val id: Int, profile: Map<*, *>) {
        val connection = DoorBirdConnection(profile)
        private val apm = AudioProcessor()
        val texture: TextureRegistry.SurfaceTextureEntry = textures.createSurfaceTexture()
        private val surface = Surface(texture.surfaceTexture())
        private val pool = Executors.newFixedThreadPool(4)
        val closed = AtomicBoolean(false)
        private val resources = Object()
        @Volatile private var mic = false
        @Volatile private var transmitting = false
        @Volatile private var recorder: AudioRecord? = null
        @Volatile private var track: AudioTrack? = null
        @Volatile var volume = 0.5f
        @Volatile private var audioFrames = 0L
        @Volatile private var lastAudio = 0L
        @Volatile private var videoFrames = 0L
        @Volatile private var lastVideo = 0L
        @Volatile private var delayMs = 40
        @Volatile private var writeAt = 0L
        private val started = SystemClock.elapsedRealtime()
        private var firstReady = false
        private var player: ExoPlayer? = null
        private val oldMode = audio.mode
        private val oldSpeaker = audio.isSpeakerphoneOn
        private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setOnAudioFocusChangeListener({ change -> if (change < 0 && session === this) stop("audio_focus") }, main).build()
        private val watchdog = object : Runnable {
            override fun run() {
                if (closed.get()) return
                val now = SystemClock.elapsedRealtime()
                if (!firstReady && lastAudio > 0 && lastVideo > 0) {
                    firstReady = true; emit(this@Session, "preview", mapOf("ready_ms" to now - started))
                }
                if ((!firstReady && now - started > 10000) || (lastAudio > 0 && now - lastAudio > 5000) ||
                    (lastVideo > 0 && now - lastVideo > 5000) || (writeAt > 0 && now - writeAt > 5000)) {
                    failed(this@Session, IntercomFailure("timeout")); return
                }
                emit(this@Session, "metrics", mapOf("audio_frames" to audioFrames, "video_frames" to videoFrames,
                    "elapsed_ms" to now - started, "delay_ms" to delayMs, "microphone" to mic))
                main.postDelayed(this, 1000)
            }
        }
        fun start() {
            if (audio.requestAudioFocus(focus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) throw IntercomFailure("audio_focus")
            audio.mode = AudioManager.MODE_IN_COMMUNICATION; audio.isSpeakerphoneOn = true
            main.post(watchdog)
            pool.execute {
                try {
                    connection.authenticate()
                    val input = connection.receive()
                    if (closed.get()) return@execute
                    main.post { if (!closed.get()) startVideo() }
                    val size = AudioTrack.getMinBufferSize(16000, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT).coerceAtLeast(1280)
                    val output = AudioTrack.Builder().setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()).setAudioFormat(AudioFormat.Builder().setSampleRate(16000)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build()).setBufferSizeInBytes(size).build()
                    synchronized(resources) { if (closed.get()) { output.release(); return@execute }; track = output; output.play() }
                    val wire = ByteArray(80); val pcm = ShortArray(160); var written = 0L
                    while (!closed.get()) {
                        var at = 0
                        while (at < wire.size) { val n = input.read(wire, at, wire.size - at); if (n < 0) throw EOFException(); at += n }
                        for (i in wire.indices) {
                            val value = (MuLaw.decode(wire[i]) * volume).toInt().toShort()
                            pcm[i * 2] = value; pcm[i * 2 + 1] = value
                        }
                        apm.render(pcm)
                        var offset = 0
                        while (offset < pcm.size && !closed.get()) {
                            val n = output.write(pcm, offset, pcm.size - offset, AudioTrack.WRITE_BLOCKING)
                            if (n <= 0) throw IntercomFailure("audio_device")
                            offset += n; written += n
                        }
                        val played = output.playbackHeadPosition.toLong() and 0xffffffffL
                        delayMs = ((written - played).coerceAtLeast(0) * 1000 / 16000 + 20).toInt()
                        audioFrames++; lastAudio = SystemClock.elapsedRealtime()
                    }
                } catch (e: Exception) { if (!closed.get()) failed(this, e) }
            }
        }
        private fun startVideo() {
            val uri = Uri.Builder().scheme("rtsp").encodedAuthority(Uri.encode(connection.username) + ":" +
                Uri.encode(connection.password) + "@" + connection.host + ":554").path("/mpeg/media.amp").build()
            val video = ExoPlayer.Builder(activity).build(); player = video
            video.trackSelectionParameters = video.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(androidx.media3.common.C.TRACK_TYPE_AUDIO, true).build()
            video.setVideoSurface(surface)
            video.setVideoFrameMetadataListener { _, _, format, _ ->
                videoFrames++; lastVideo = SystemClock.elapsedRealtime()
                if (videoFrames == 1L) emit(this, "video", mapOf("width" to format.width, "height" to format.height))
            }
            video.addListener(object : Player.Listener {
                override fun onPlayerError(error: PlaybackException) { failed(this@Session, IntercomFailure("video")) }
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_ENDED && !closed.get()) failed(this@Session, IntercomFailure("video"))
                }
            })
            video.setMediaSource(RtspMediaSource.Factory().setForceUseRtpTcp(true).setTimeoutMs(5000).createMediaSource(MediaItem.fromUri(uri)))
            video.prepare(); video.play()
        }
        fun microphone(enabled: Boolean) {
            if (closed.get() || !firstReady) throw IntercomFailure("not_ready")
            if (enabled && activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) throw IntercomFailure("permission")
            mic = enabled
            if (!enabled) {
                try { recorder?.stop() } catch (_: Exception) {}
                emit(this, "muted")
            }
            if (enabled && !transmitting) { transmitting = true; pool.execute { transmit() } }
        }
        private fun transmit() {
            try {
                val socket = connection.transmit()
                pool.execute {
                    try {
                        val line = socket.getInputStream().bufferedReader(Charsets.US_ASCII).readLine() ?: throw EOFException()
                        DoorBirdConnection.checkStatus(line.split(' ').getOrNull(1)?.toIntOrNull() ?: throw IntercomFailure("protocol"))
                    } catch (e: Exception) { if (!closed.get()) failed(this, e) }
                }
                val size = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT).coerceAtLeast(1280)
                val input = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, 16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size)
                synchronized(resources) { if (closed.get()) { input.release(); return }; recorder = input }
                if (input.state != AudioRecord.STATE_INITIALIZED) throw IntercomFailure("audio_device")
                val pcm = ShortArray(160); val wire = ByteArray(80); val out = socket.getOutputStream()
                var total = 0L
                while (!closed.get()) {
                    var captured = false
                    if (mic) {
                        if (input.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                            input.startRecording(); emit(this, "talking")
                        }
                        var at = 0
                        while (at < pcm.size && mic && !closed.get()) {
                            val n = input.read(pcm, at, pcm.size - at, AudioRecord.READ_BLOCKING)
                            if (n <= 0) { if (!mic || closed.get()) break; throw IntercomFailure("audio_device") }
                            at += n
                        }
                        if (at == pcm.size && mic && !closed.get()) {
                            apm.capture(pcm, delayMs)
                            for (i in wire.indices) wire[i] = MuLaw.encode(pcm[i])
                            captured = true
                        }
                    }
                    if (!captured || !mic) wire.fill(0xff.toByte())
                    if (!closed.get()) { writeAt = SystemClock.elapsedRealtime(); out.write(wire); writeAt = 0 }
                    if (!captured) Thread.sleep(10)
                    total += wire.size
                    if (total + wire.size > 9999999) throw IntercomFailure("session_expired")
                }
            } catch (e: Exception) { if (!closed.get()) failed(this, e) }
        }
        fun close() {
            if (!closed.compareAndSet(false, true)) return
            mic = false; main.removeCallbacks(watchdog)
            player?.release(); player = null; surface.release(); texture.release()
            synchronized(resources) {
                try { recorder?.stop() } catch (_: Exception) {}
                try { track?.pause(); track?.flush() } catch (_: Exception) {}
            }
            pool.shutdown()
            Thread {
                connection.close()
                pool.awaitTermination(12, java.util.concurrent.TimeUnit.SECONDS)
                if (!pool.isTerminated) { pool.shutdownNow(); pool.awaitTermination(6, java.util.concurrent.TimeUnit.SECONDS) }
                if (pool.isTerminated) { recorder?.release(); track?.release(); apm.close() }
            }.start()
            audio.abandonAudioFocusRequest(focus); audio.mode = oldMode; audio.isSpeakerphoneOn = oldSpeaker
        }
    }
    companion object { const val PERMISSION = 18018 }
}
