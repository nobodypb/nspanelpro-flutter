package local.nspanel.handoff

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

internal object SessionBus {
    var sink: EventChannel.EventSink? = null
    var service: HandoffService? = null
    var last: Map<String, Any> = mapOf("state" to "idle")
    fun emit(state: String, id: String, dark: Boolean = false) {
        android.util.Log.i("CompanionHandoff", "state=$state dark=$dark")
        last = mapOf("state" to state, "session" to id, "dark" to dark)
        sink?.success(last)
    }
    fun target(context: Context): Intent? = listOf(
        "io.homeassistant.companion.android.minimal", "io.homeassistant.companion.android"
    ).firstNotNullOfOrNull { context.packageManager.getLaunchIntentForPackage(it) }
}

class CompanionHandoffPlugin : FlutterPlugin, ActivityAware, Application.ActivityLifecycleCallbacks {
    private var activity: Activity? = null
    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "local.nspanel/companion_handoff")
        events = EventChannel(binding.binaryMessenger, "local.nspanel/companion_handoff/events")
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                SessionBus.sink = sink; sink.success(SessionBus.last)
            }
            override fun onCancel(arguments: Any?) { SessionBus.sink = null }
        })
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(Build.VERSION.SDK_INT == 27 && SessionBus.target(context) != null)
                "begin" -> {
                    val host = activity
                    if (Build.VERSION.SDK_INT != 27 || host == null || SessionBus.target(context) == null) {
                        result.error("unavailable", "Companion handoff unavailable", null)
                    } else if (SessionBus.service != null) {
                        result.error("busy", "A handoff is already active", null)
                    } else {
                        val intent = Intent(context, HandoffService::class.java)
                            .setAction("begin").putExtra("host", host.componentName.flattenToString())
                            .putExtra("task", host.taskId)
                        try {
                            context.startForegroundService(intent)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("start_failed", "Companion session could not start", null)
                        }
                    }
                }
                "prepared" -> { SessionBus.service?.prepared(call.arguments as? String); result.success(null) }
                "finish" -> { SessionBus.service?.finish(call.arguments as? String); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detach(); methods.setMethodCallHandler(null); events.setStreamHandler(null); SessionBus.sink = null
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.activity.application.registerActivityLifecycleCallbacks(this)
    }
    private fun detach() { activity?.application?.unregisterActivityLifecycleCallbacks(this); activity = null }
    override fun onDetachedFromActivity() = detach()
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onActivityResumed(a: Activity) { if (a === activity) SessionBus.service?.resumed() }
    override fun onActivityPaused(a: Activity) { if (a === activity) SessionBus.service?.leftHost = true }
    override fun onActivityCreated(a: Activity, state: Bundle?) {}
    override fun onActivityStarted(a: Activity) {}
    override fun onActivityStopped(a: Activity) {}
    override fun onActivitySaveInstanceState(a: Activity, state: Bundle) {}
    override fun onActivityDestroyed(a: Activity) {}
}
