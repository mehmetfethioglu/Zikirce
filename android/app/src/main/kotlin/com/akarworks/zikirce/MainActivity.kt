package com.akarworks.zikirce

import android.content.ComponentName
import android.content.Intent
import android.hardware.display.DisplayManager
import android.media.MediaRouter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Display
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.akarworks.zikirce/battery_optimization"
    private val TV_CAST_CHANNEL = "com.akarworks.zikirce/tv_cast"
    private val QIBLA_METHOD_CHANNEL = "com.akarworks.zikirce/qibla_native"
    private val QIBLA_COMPASS_CHANNEL = "com.akarworks.zikirce/qibla_compass"
    private var tvCastChannel: MethodChannel? = null
    private var qiblaBridge: QiblaNativeBridge? = null
    private var displayManager: DisplayManager? = null
    private var displayListener: DisplayManager.DisplayListener? = null

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
                "isTelevision" -> {
                    result.success(isRunningOnTelevision())
                }
                "getAppVersion" -> {
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val vName = pInfo.versionName ?: ""
                        val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode.toInt()
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode
                        }
                        result.success(mapOf("versionName" to vName, "versionCode" to vCode))
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        val castChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CAST_CHANNEL)
        tvCastChannel = castChannel
        castChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCastStatus" -> result.success(queryCastStatus())
                "openCastPicker" -> {
                    val opened = openAndroidCastPicker()
                    result.success(
                        mapOf(
                            "opened" to opened,
                            "mode" to if (opened) "system_cast_settings" else "unsupported"
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
        registerCastDisplayListener()

        val bridge = qiblaBridge ?: QiblaNativeBridge(this)
        qiblaBridge = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QIBLA_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                bridge.handleMethodCall(call, result)
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, QIBLA_COMPASS_CHANNEL)
            .setStreamHandler(bridge)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (qiblaBridge?.onRequestPermissionsResult(requestCode, permissions, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onResume() {
        super.onResume()
        com.akarworks.zikirce.widgets.WidgetTimeTickReceiver.updateAllWidgets(this)
        com.akarworks.zikirce.widgets.WidgetAlarmScheduler.scheduleNextPrayerAlarm(this)
        pushCastStatusToFlutter()
    }

    override fun onDestroy() {
        try {
            displayListener?.let { listener ->
                displayManager?.unregisterDisplayListener(listener)
            }
        } catch (e: Exception) {
            Log.w("ZikirceCast", "DisplayListener unregister warning: ${e.message}")
        }
        displayListener = null
        tvCastChannel = null
        qiblaBridge?.dispose()
        qiblaBridge = null
        super.onDestroy()
    }

    private fun registerCastDisplayListener() {
        try {
            val manager = (getSystemService(DISPLAY_SERVICE) as? DisplayManager) ?: return
            displayManager = manager
            displayListener?.let { manager.unregisterDisplayListener(it) }
            val listener = object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) {
                    pushCastStatusToFlutter()
                }

                override fun onDisplayRemoved(displayId: Int) {
                    pushCastStatusToFlutter()
                }

                override fun onDisplayChanged(displayId: Int) {
                    pushCastStatusToFlutter()
                }
            }
            displayListener = listener
            manager.registerDisplayListener(listener, Handler(Looper.getMainLooper()))
        } catch (e: Exception) {
            Log.w("ZikirceCast", "DisplayListener register warning: ${e.message}")
        }
    }

    private fun pushCastStatusToFlutter() {
        val channel = tvCastChannel ?: return
        runOnUiThread {
            try {
                channel.invokeMethod("onCastStateChanged", queryCastStatus())
            } catch (e: Exception) {
                Log.w("ZikirceCast", "pushCastStatusToFlutter warning: ${e.message}")
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun queryCastStatus(): Map<String, Any?> {
        val isHardwareTv = isRunningOnTelevision()
        return try {
            val manager = displayManager ?: (getSystemService(DISPLAY_SERVICE) as? DisplayManager)
            displayManager = manager

            val presentationDisplay = manager
                ?.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                ?.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }

            val mediaRouter = getSystemService(MEDIA_ROUTER_SERVICE) as? MediaRouter
            val selectedVideoRoute = mediaRouter?.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO)
            val liveVideoRoute = if (
                selectedVideoRoute != null &&
                selectedVideoRoute != mediaRouter.defaultRoute &&
                selectedVideoRoute.isEnabled
            ) {
                selectedVideoRoute
            } else {
                null
            }

            val fallbackDisplay = manager?.displays?.firstOrNull { display ->
                display.displayId != Display.DEFAULT_DISPLAY &&
                    (display.flags and Display.FLAG_PRIVATE) == 0 &&
                    display.state != Display.STATE_OFF &&
                    !display.name.equals("Built-in Screen", ignoreCase = true)
            }

            val activeDisplay = presentationDisplay ?: fallbackDisplay
            val isConnected = activeDisplay != null || liveVideoRoute != null
            val deviceName = liveVideoRoute?.name?.toString()?.takeIf { it.isNotBlank() }
                ?: activeDisplay?.name?.takeIf { it.isNotBlank() }

            val lowerName = deviceName?.lowercase() ?: ""
            val connectionType = when {
                !isConnected -> "none"
                liveVideoRoute == null &&
                    (lowerName.contains("hdmi") ||
                        lowerName.contains("usb") ||
                        lowerName.contains("wired")) -> "wired"
                else -> "wireless"
            }

            mapOf(
                "supported" to !isHardwareTv,
                "isConnected" to isConnected,
                "isVisualMirroring" to isConnected,
                "deviceName" to deviceName,
                "connectionType" to connectionType,
                "platform" to "android"
            )
        } catch (e: Exception) {
            Log.w("ZikirceCast", "queryCastStatus error: ${e.message}")
            mapOf(
                "supported" to !isHardwareTv,
                "isConnected" to false,
                "isVisualMirroring" to false,
                "deviceName" to null,
                "connectionType" to "none",
                "platform" to "android"
            )
        }
    }

    private fun openAndroidCastPicker(): Boolean {
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        val candidateIntents = mutableListOf<Intent>()

        if (manufacturer.contains("samsung")) {
            candidateIntents.add(Intent("com.samsung.wfd.LAUNCH_WFD_PICKER_DLG"))
            candidateIntents.add(
                Intent().setComponent(
                    ComponentName(
                        "com.samsung.android.smartmirroring",
                        "com.samsung.android.smartmirroring.CastingDialogActivity"
                    )
                )
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            candidateIntents.add(Intent(Settings.ACTION_CAST_SETTINGS))
        }
        candidateIntents.add(Intent("android.settings.WIFI_DISPLAY_SETTINGS"))

        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")) {
            candidateIntents.add(
                Intent().setComponent(
                    ComponentName(
                        "com.android.settings",
                        "com.android.settings.Settings\$WifiDisplaySettingsActivity"
                    )
                )
            )
        }

        candidateIntents.add(Intent(Settings.ACTION_DISPLAY_SETTINGS))

        for (intent in candidateIntents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (e: Exception) {
                Log.d("ZikirceCast", "Cast intent candidate skipped (${intent.action ?: intent.component}): ${e.message}")
            }
        }
        return false
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        com.akarworks.zikirce.widgets.WidgetTimeTickReceiver.updateAllWidgets(this)
    }

    private fun isRunningOnTelevision(): Boolean {
        return try {
            val uiModeManager = getSystemService(UI_MODE_SERVICE) as? android.app.UiModeManager
            val isTvUiMode = uiModeManager?.currentModeType == android.content.res.Configuration.UI_MODE_TYPE_TELEVISION
            val hasLeanback = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_LEANBACK)
            val hasTelevisionFeature = packageManager.hasSystemFeature("android.hardware.type.television")
            isTvUiMode || hasLeanback || hasTelevisionFeature
        } catch (_: Exception) {
            false
        }
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
