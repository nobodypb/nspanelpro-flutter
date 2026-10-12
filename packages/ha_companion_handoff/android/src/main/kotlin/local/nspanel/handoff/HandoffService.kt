package local.nspanel.handoff

import android.app.*
import android.content.*
import android.os.*
import android.view.Display
import android.hardware.display.DisplayManager
import java.util.UUID

/** Owns only an explicitly started external session; never a permanent watchdog. */
class HandoffService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val power get() = getSystemService(PowerManager::class.java)
    private val prefs get() = getSharedPreferences("companion_handoff_session", MODE_PRIVATE)
    private var id = ""
    private val gate = ReturnGate()
    var leftHost = false
    private var cpu: PowerManager.WakeLock? = null
    private fun dark() = !power.isInteractive &&
        getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)?.state == Display.STATE_OFF
    private val screen = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                // Display.STATE_OFF may follow the non-interactive broadcast.
                retainCpu()
                handler.postDelayed({ awaitDark(20) }, 100)
            }
        }
    }
    private fun retainCpu() {
        if (cpu?.isHeld == true) return
        cpu = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "companion:handoff").apply {
            setReferenceCounted(false); acquire(15000)
        }
    }
    private fun awaitDark(attempts: Int) {
        if (power.isInteractive) {
            cpu?.let { if (it.isHeld) it.release() }
        } else if (dark()) {
            returnHome()
        } else if (attempts > 0) {
            handler.postDelayed({ awaitDark(attempts - 1) }, 100)
        }
    }
    override fun onCreate() {
        super.onCreate(); SessionBus.service = this
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("companion_handoff", "Home Assistant", NotificationManager.IMPORTANCE_LOW).apply {
            setSound(null, null); enableVibration(false)
        })
        startForeground(7007, Notification.Builder(this, "companion_handoff")
            .setSmallIcon(android.R.drawable.ic_menu_revert).setContentTitle("Home Assistant geöffnet")
            .setContentText("Rückkehr zum Panel beim Ausschalten des Displays")
            .setOngoing(true).setShowWhen(false).build())
        registerReceiver(screen, IntentFilter(Intent.ACTION_SCREEN_OFF))
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (id.isNotEmpty()) return START_STICKY
        if (intent?.action == "begin") {
            id = UUID.randomUUID().toString()
            prefs.edit().putString("id", id).putString("host", intent.getStringExtra("host"))
                .putInt("task", intent.getIntExtra("task", -1))
                .putInt("boot", android.provider.Settings.Global.getInt(contentResolver, "boot_count", -1)).commit()
            try {
                val target = SessionBus.target(this) ?: error("missing companion")
                SessionBus.emit("external", id)
                startActivity(target.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (_: Exception) { fail() }
        } else {
            id = prefs.getString("id", "") ?: ""
            val sameBoot = prefs.getInt("boot", -2) == android.provider.Settings.Global.getInt(contentResolver, "boot_count", -1)
            if (id.isEmpty() || !sameBoot) { prefs.edit().clear().commit(); stopSelf() }
            else returnHome()
        }
        return START_STICKY
    }
    private fun returnHome() {
        if (id.isEmpty() || !gate.request()) return
        retainCpu()
        SessionBus.emit("returning", id, dark())
        handler.postDelayed({ if (!gate.requested) prepared(id) }, 2000)
    }
    fun prepared(session: String?) {
        if (!gate.prepare(id, session)) return
        try {
            val manager = getSystemService(ActivityManager::class.java)
            val task = manager.appTasks.firstOrNull { it.taskInfo.id == prefs.getInt("task", -1) }
            if (task != null) task.moveToFront()
            else {
                val component = ComponentName.unflattenFromString(prefs.getString("host", "") ?: "") ?: error("missing host")
                require(component.packageName == packageName)
                startActivity(Intent().setComponent(component).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
            }
        } catch (_: Exception) { fail() }
    }
    fun resumed() {
        if (id.isEmpty() || (!leftHost && !gate.pending)) return
        SessionBus.emit("resumed", id, dark())
    }
    fun finish(session: String?) {
        if (session != id) return
        prefs.edit().clear().commit(); SessionBus.last = mapOf("state" to "idle"); stopSelf()
    }
    private fun fail() {
        SessionBus.emit("error", id); prefs.edit().clear().commit(); stopSelf()
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterReceiver(screen)
        cpu?.let { if (it.isHeld) it.release() }; cpu = null
        if (SessionBus.service === this) SessionBus.service = null
        super.onDestroy()
    }
    override fun onBind(intent: Intent?) = null
}
