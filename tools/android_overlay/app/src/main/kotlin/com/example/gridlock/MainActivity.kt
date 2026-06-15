package com.example.gridlock

import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.gridlock/kiosk"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startLock" -> { startLock(); result.success(null) }
                "stopLock" -> { stopLock(); result.success(null) }
                "enableImmersive" -> { enableImmersive(); result.success(null) }
                "keepScreenOn" -> {
                    val on = call.argument<Boolean>("on") ?: true
                    setKeepScreenOn(on); result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onLockTaskModeExiting() {
        super.onLockTaskModeExiting()
        // Notify Flutter that screen pinning was exited (e.g. Back + Recents).
        channel?.invokeMethod("onLockExited", null)
    }

    private fun startLock() {
        // Ordinary screen pinning: with no Device Owner, startLockTask() shows
        // the system pin confirmation and stays escapable (hold Back + Recents).
        try {
            startLockTask()
        } catch (e: IllegalStateException) {
            // Already pinned, or not permitted on this device — ignore.
        }
    }

    private fun stopLock() {
        try {
            stopLockTask()
        } catch (e: IllegalStateException) {
            // Not currently pinned — ignore.
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enableImmersive()
    }

    private fun enableImmersive() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.hide(WindowInsets.Type.systemBars())
                it.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                )
        }
    }

    private fun setKeepScreenOn(on: Boolean) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
