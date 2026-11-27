package com.akarworks.organicscore

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL_NAME = "com.akarworks.kilerce/notifications"
        private const val EXPIRY_NOTIFICATION_ID = 32216
        private const val REQ_POST_NOTIFICATIONS = 9104
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        handlePermissionRequest(result)
                    }
                    "areNotificationsEnabled" -> {
                        result.success(KilerceNotificationHelper.hasNotificationPermission(this))
                    }
                    "showNotification" -> {
                        val id = call.argument<Number>("id")?.toInt() ?: 32220
                        val channelId = call.argument<String>("channelId")
                            ?: KilerceNotificationHelper.CHANNEL_MENU
                        val title = call.argument<String>("title") ?: "Kilerce"
                        val body = call.argument<String>("body") ?: ""
                        result.success(
                            KilerceNotificationHelper.showNotification(
                                this,
                                id,
                                channelId,
                                title,
                                body
                            )
                        )
                    }
                    "showExpiryNotification" -> {
                        val title = call.argument<String>("title") ?: "Kilerce SKT Hatırlatıcı"
                        val body = call.argument<String>("body")
                            ?: "Dolabınızda tüketilmesi gereken ürünler var."
                        val shown = KilerceNotificationHelper.showNotification(
                            this,
                            EXPIRY_NOTIFICATION_ID,
                            KilerceNotificationHelper.CHANNEL_SKT,
                            title,
                            body
                        )
                        result.success(shown)
                    }
                    "scheduleReminder" -> {
                        val id = call.argument<Number>("id")?.toInt() ?: 32220
                        val channelId = call.argument<String>("channelId")
                            ?: KilerceNotificationHelper.CHANNEL_MENU
                        val title = call.argument<String>("title") ?: "Kilerce"
                        val body = call.argument<String>("body") ?: ""
                        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
                        val scheduled = KilerceNotificationHelper.scheduleReminder(
                            this,
                            id,
                            channelId,
                            title,
                            body,
                            triggerAtMillis
                        )
                        result.success(scheduled)
                    }
                    "cancelReminder" -> {
                        val id = call.argument<Number>("id")?.toInt() ?: 32220
                        KilerceNotificationHelper.cancelReminder(this, id)
                        result.success(true)
                    }
                    "openEmailClient" -> {
                        val to = call.argument<String>("to") ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        result.success(launchEmailClient(to, subject, body))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun handlePermissionRequest(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
            return
        }
        val alreadyGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (alreadyGranted) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQ_POST_NOTIFICATIONS
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun launchEmailClient(to: String, subject: String, body: String): Boolean {
        return try {
            val mailtoUri = Uri.parse(
                "mailto:${Uri.encode(to)}?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}"
            )
            val intent = Intent(Intent.ACTION_SENDTO, mailtoUri)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
