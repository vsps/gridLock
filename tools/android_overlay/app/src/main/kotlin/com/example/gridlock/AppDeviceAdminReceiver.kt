package com.example.gridlock

import android.app.admin.DeviceAdminReceiver
import android.content.ComponentName
import android.content.Context

/// Device admin component. Its [ComponentName] is the handle passed to
/// DevicePolicyManager (setLockTaskPackages) once the app is the device owner.
class AppDeviceAdminReceiver : DeviceAdminReceiver() {
    companion object {
        fun componentName(context: Context): ComponentName =
            ComponentName(context.applicationContext, AppDeviceAdminReceiver::class.java)
    }
}
