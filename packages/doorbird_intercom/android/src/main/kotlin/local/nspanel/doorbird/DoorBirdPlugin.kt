package local.nspanel.doorbird

import android.app.Activity
import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/** All Android lifecycle hooks belong to the extension, never the host activity. */
class DoorBirdPlugin : FlutterPlugin, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener, Application.ActivityLifecycleCallbacks {
    private var media: IntercomPlugin? = null
    private var binding: ActivityPluginBinding? = null
    private var context: Context? = null
    private val screen = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) media?.screenOff()
        }
    }
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val ctx = binding.applicationContext
        context = ctx
        media = IntercomPlugin(ctx, binding.textureRegistry, binding.binaryMessenger)
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= 33) ctx.registerReceiver(screen, filter, Context.RECEIVER_NOT_EXPORTED)
        else ctx.registerReceiver(screen, filter)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detachActivity()
        context?.unregisterReceiver(screen); context = null
        media?.dispose(); media = null
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addRequestPermissionsResultListener(this)
        binding.activity.application.registerActivityLifecycleCallbacks(this)
        media?.attach(binding.activity)
    }
    private fun detachActivity() {
        binding?.let {
            it.removeRequestPermissionsResultListener(this)
            it.activity.application.unregisterActivityLifecycleCallbacks(this)
        }
        media?.detach(); binding = null
    }
    override fun onDetachedFromActivity() = detachActivity()
    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray): Boolean =
        media?.permission(code, results) ?: false
    override fun onActivityPaused(activity: Activity) { if (activity === binding?.activity) media?.background() }
    override fun onActivityStopped(activity: Activity) { if (activity === binding?.activity) media?.stopped() }
    override fun onActivityCreated(activity: Activity, state: Bundle?) {}
    override fun onActivityStarted(activity: Activity) {}
    override fun onActivityResumed(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) {}
    override fun onActivityDestroyed(activity: Activity) {}
}
