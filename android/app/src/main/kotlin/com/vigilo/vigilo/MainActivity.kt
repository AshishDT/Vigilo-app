package com.vigilo.vigilo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager.LayoutParams
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture
    companion object {
        private const val CHANNEL = "com.vigilo.vigilo/screen_events"
        private const val PREFS_NAME = "vigilo_security_prefs"
        private const val KEY_SCREEN_OFF_TIME = "screen_off_time"
        private const val KEY_IS_DARK_THEME = "is_dark_theme"
        // Idle timeout threshold: 15 minutes (900,000 ms), matching app idle timeout.
        private const val IDLE_TIMEOUT_MS = 15 * 60 * 1000L
        private const val COLOR_DARK_NAVY = "#071A2B"
        private const val COLOR_LIGHT_BG = "#EAF1F8"
    }

    private var methodChannel: MethodChannel? = null
    private var screenOffReceiver: BroadcastReceiver? = null
    private var coverView: View? = null
    private var isColdStart = true
    private var isAuthenticating = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.addFlags(LayoutParams.FLAG_SECURE)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setTheme" -> {
                        val isDark = call.argument<Boolean>("dark") ?: true
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit().putBoolean(KEY_IS_DARK_THEME, isDark).apply()
                        val bgColor = if (isDark) {
                            android.graphics.Color.parseColor(COLOR_DARK_NAVY)
                        } else {
                            android.graphics.Color.parseColor(COLOR_LIGHT_BG)
                        }
                        runOnUiThread {
                            window.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(bgColor))
                            window.decorView.setBackgroundColor(bgColor)
                            coverView?.setBackgroundColor(bgColor)
                        }
                        result.success(null)
                    }
                    "getTheme" -> {
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        val isDark = prefs.getBoolean(KEY_IS_DARK_THEME, true)
                        result.success(isDark)
                    }
                    "setAuthenticating" -> {
                        isAuthenticating = call.argument<Boolean>("authenticating") ?: false
                        result.success(null)
                    }
                    "dismissNativeCover" -> {
                        runOnUiThread {
                            dismissCover()
                            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                                .edit()
                                .remove(KEY_SCREEN_OFF_TIME)
                                .apply()
                        }
                        result.success(null)
                    }
                    "clearPauseTime" -> {
                        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                            .edit()
                            .remove(KEY_SCREEN_OFF_TIME)
                            .apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        isColdStart = true

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isDark = prefs.getBoolean(KEY_IS_DARK_THEME, true)
        val bgColor = if (isDark) {
            android.graphics.Color.parseColor(COLOR_DARK_NAVY)
        } else {
            android.graphics.Color.parseColor(COLOR_LIGHT_BG)
        }
        window.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(bgColor))
        window.decorView.setBackgroundColor(bgColor)

        screenOffReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                    if (!isAuthenticating) {
                        val p = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        p.edit().putLong(KEY_SCREEN_OFF_TIME, System.currentTimeMillis()).apply()
                        showCover()
                    }
                    methodChannel?.invokeMethod("onScreenOff", null)
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenOffReceiver, filter)
    }

    override fun onPause() {
        super.onPause()
        if (isAuthenticating) return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_SCREEN_OFF_TIME)) {
            prefs.edit().putLong(KEY_SCREEN_OFF_TIME, System.currentTimeMillis()).apply()
        }
        showCover()
    }

    override fun onResume() {
        if (isColdStart) {
            isColdStart = false
            dismissCover()
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_SCREEN_OFF_TIME)
                .apply()
        } else {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val pauseTime = prefs.getLong(KEY_SCREEN_OFF_TIME, 0L)
            if (pauseTime > 0L) {
                val elapsed = System.currentTimeMillis() - pauseTime
                if (elapsed < IDLE_TIMEOUT_MS) {
                    // Quick unlock within timeout: dismiss cover immediately before drawing
                    dismissCover()
                    prefs.edit().remove(KEY_SCREEN_OFF_TIME).apply()
                } else {
                    // Timeout exceeded: keep cover in place until Flutter paints the shield
                    showCover()
                }
            } else {
                dismissCover()
            }
        }
        super.onResume()
    }

    private fun showCover() {
        if (coverView != null) return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isDark = prefs.getBoolean(KEY_IS_DARK_THEME, true)
        val color = if (isDark) {
            android.graphics.Color.parseColor(COLOR_DARK_NAVY)
        } else {
            android.graphics.Color.parseColor(COLOR_LIGHT_BG)
        }
        val decorView = window.decorView as? ViewGroup ?: return
        val view = View(this).apply {
            setBackgroundColor(color)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            elevation = 9999f
            isClickable = true
            isFocusable = true
        }
        decorView.addView(view)
        decorView.bringChildToFront(view)
        coverView = view
    }

    private fun dismissCover() {
        coverView?.let { view ->
            val decorView = window.decorView as? ViewGroup
            decorView?.removeView(view)
            coverView = null
        }
    }

    override fun onDestroy() {
        screenOffReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        dismissCover()
        super.onDestroy()
    }
}
