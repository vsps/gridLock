package com.example.gridlock

import android.app.admin.DevicePolicyManager
import android.content.Context
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

    private val dpm: DevicePolicyManager
        get() = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun isDeviceOwner(): Boolean = dpm.isDeviceOwnerApp(packageName)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLock" -> { startLock(); result.success(null) }
                    "stopLock" -> { stopLock(); result.success(null) }
                    "enableImmersive" -> { enableImmersive(); result.success(null) }
                    "keepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: true
                        setKeepScreenOn(on); result.success(null)
                    }
                    "isDeviceOwner" -> result.success(isDeviceOwner())
                    else -> result.notImplemented()
                }
            }
    }

    private fun startLock() {
        if (isDeviceOwner()) {
            // Whitelist this app so startLockTask() enters lock task mode without
            // the user-escapable "screen pinning" confirmation.
            val admin = AppDeviceAdminReceiver.componentName(this)
            dpm.setLockTaskPackages(admin, arrayOf(packageName))
        }
        try {
            startLockTask()
        } catch (e: IllegalStateException) {
            // Already locked, or not permitted on this device — ignore.
        }
    }

    private fun stopLock() {
        try {
            stopLockTask()
        } catch (e: IllegalStateException) {
            // Not currently in a lock task — ignore.
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
