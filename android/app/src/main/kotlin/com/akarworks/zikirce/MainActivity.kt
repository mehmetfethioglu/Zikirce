package com.akarworks.zikirce

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.akarworks.zikirce/battery_optimization"

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenAwake" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                "openAutoStart" -> {
                    val opened = openAutoStartSettings()
                    result.success(opened)
                }
                "openBatterySaverNoRestrictions" -> {
                    val opened = openBatterySaverSettings()
                    result.success(opened)
                }
                "openNotificationSettings" -> {
                    val opened = openNotificationSettings()
                    result.success(opened)
                }
                "openExactAlarmSettings" -> {
                    val opened = openExactAlarmSettings()
                    result.success(opened)
                }
                "canScheduleExactAlarms" -> {
                    val can = canScheduleExactAlarms()
                    result.success(can)
                }
                "openAppPermissions" -> {
                    val opened = openAppPermissions()
                    result.success(opened)
                }
                "getManufacturer" -> {
                    result.success(Build.MANUFACTURER ?: "")
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        com.akarworks.zikirce.widgets.WidgetTimeTickReceiver.updateAllWidgets(this)
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(ALARM_SERVICE) as? android.app.AlarmManager
            return alarmManager?.canScheduleExactAlarms() ?: true
        }
        return true
    }

    private fun openExactAlarmSettings(): Boolean {
        val pkg = packageName
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$pkg")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            }
        } catch (_: Exception) {}
        return openAppDetailsSettings()
    }

    private fun openAppPermissions(): Boolean {
        val pkg = packageName
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")) {
            try {
                val intent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                    putExtra("extra_pkgname", pkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {}
        }
        return openAppDetailsSettings()
    }

    private fun openAutoStartSettings(): Boolean {
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        val pkg = packageName

        // 1. Xiaomi / Redmi / POCO
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")) {
            val intents = listOf(
                Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
                Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT),
                Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartListActivity"))
            )
            for (intent in intents) {
                try {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    return true
                } catch (_: Exception) {}
            }
        }

        // 2. Huawei / Honor
        if (manufacturer.contains("huawei") || manufacturer.contains("honor")) {
            try {
                val intent = Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        // 3. Fallback: Application Details
        return openAppDetailsSettings()
    }

    private fun openBatterySaverSettings(): Boolean {
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        val pkg = packageName

        // 1. Xiaomi / MIUI PowerKeeper "No Restrictions" screen
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")) {
            try {
                val intent = Intent("miui.intent.action.POWER_HIDE_MODE_APP_LIST")
                intent.putExtra("package_name", pkg)
                intent.putExtra("package_label", "Zikirce")
                intent.setComponent(ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {}

            try {
                val intent = Intent()
                intent.setComponent(ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsContainerManagementActivity"))
                intent.putExtra("package_name", pkg)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        // 2. Standard Android Ignore Battery Optimizations
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$pkg")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (_: Exception) {}

        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (_: Exception) {}

        return openAppDetailsSettings()
    }

    private fun openNotificationSettings(): Boolean {
        val pkg = packageName
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            }
        } catch (_: Exception) {}

        return openAppDetailsSettings()
    }

    private fun openAppDetailsSettings(): Boolean {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (_: Exception) {
            return false
        }
    }
}
