package com.tahrir.app.tahrir

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tahrir.app/native_bridge"
    private val NOTIF_CHANNEL_ID = "tahrir_smart_mutalaa_channel"
    private var pendingIncomingFilePath: String? = null

    private val allowedExtensions = setOf(
        ".pdf", ".epub", ".txt", ".md", ".markdown", ".html", ".htm"
    )
    private val maxIncomingFileBytes = 150L * 1024L * 1024L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return

        try {
            val cacheCanonical = cacheDir.canonicalPath
            val appDataCanonical = File(applicationInfo.dataDir).canonicalPath

            if (uri.scheme == "file") {
                val path = uri.path
                if (!path.isNullOrBlank()) {
                    val targetFile = File(path)
                    val canonical = targetFile.canonicalPath
                    val isInsideAppPrivateDir =
                        canonical.startsWith(appDataCanonical) && !canonical.startsWith(cacheCanonical)
                    val lowerName = targetFile.name.lowercase()
                    val hasAllowedExt = allowedExtensions.any { lowerName.endsWith(it) }
                    if (!isInsideAppPrivateDir &&
                        hasAllowedExt &&
                        targetFile.exists() &&
                        targetFile.isFile &&
                        targetFile.length() in 1L..maxIncomingFileBytes
                    ) {
                        pendingIncomingFilePath = canonical
                    }
                    return
                }
            }

            val displayName = resolveDisplayName(uri)
            val mimeType = contentResolver.getType(uri) ?: intent.type ?: ""
            val rawExt = when {
                displayName != null && displayName.contains(".") ->
                    "." + displayName.substringAfterLast(".").lowercase()
                        .replace(Regex("[^a-z0-9]"), "")
                mimeType.contains("epub", ignoreCase = true) -> ".epub"
                mimeType.contains("markdown", ignoreCase = true) -> ".md"
                mimeType.contains("text", ignoreCase = true) -> ".txt"
                else -> ".pdf"
            }
            val ext = if (allowedExtensions.contains(rawExt)) rawExt else ".pdf"

            val safeBaseName = (displayName?.substringBeforeLast(".") ?: "shared_book")
                .replace(Regex("[^a-zA-Z0-9_\\-çğıöşüÇĞİÖŞÜ ]"), "_")
                .trim()
                .take(80)
                .ifEmpty { "shared_book" }

            val outFile = File(
                cacheDir,
                "shared_book_${System.currentTimeMillis()}_${safeBaseName}$ext"
            )
            if (!outFile.canonicalPath.startsWith(cacheCanonical)) {
                return
            }

            var totalCopied = 0L
            var exceededLimit = false
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    val buffer = ByteArray(8192)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        totalCopied += read
                        if (totalCopied > maxIncomingFileBytes) {
                            exceededLimit = true
                            break
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }

            if (exceededLimit) {
                outFile.delete()
                return
            }

            if (outFile.exists() && outFile.length() in 1L..maxIncomingFileBytes) {
                pendingIncomingFilePath = outFile.canonicalPath
            }
        } catch (_: Exception) {
            // Güvenli sessiz hata yönetimi
        }
    }

    private fun resolveDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) cursor.getString(idx) else null
                    } else null
                }
        } catch (_: Exception) {
            uri.lastPathSegment
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeIncomingFile" -> {
                        val path = pendingIncomingFilePath
                        pendingIncomingFilePath = null
                        result.success(path)
                    }
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val granted = ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) == PackageManager.PERMISSION_GRANTED
                            if (!granted) {
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    1001
                                )
                            }
                        }
                        result.success(true)
                    }
                    "updateHomeWidget" -> {
                        val streak = call.argument<Int>("streakDays") ?: 0
                        val today = call.argument<Int>("todayMinutesRead") ?: 0
                        val goal = call.argument<Int>("dailyGoalMinutes") ?: 20
                        val title = call.argument<String>("bookTitle") ?: "Kutadgu Bilig"
                        val quote = call.argument<String>("dailyQuote") ?: ""
                        val progress = call.argument<Int>("progressPercent") ?: 0

                        TahrirHomeWidgetProvider.saveAndRefreshAll(
                            applicationContext,
                            streak,
                            today,
                            goal,
                            title,
                            quote,
                            progress
                        )
                        result.success(true)
                    }
                    "requestPinHomeWidget" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                            val myProvider = ComponentName(
                                applicationContext,
                                TahrirHomeWidgetProvider::class.java
                            )
                            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                                val pinned = appWidgetManager.requestPinAppWidget(myProvider, null, null)
                                result.success(pinned)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(false)
                    }
                    "showSmartNotification" -> {
                        val title = call.argument<String>("title") ?: "Tahrir Mütalaa Vakti"
                        val body = call.argument<String>("body") ?: "Kaldığınız satırdan okumaya devam edin."
                        dispatchNativeNotification(title, body)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun dispatchNativeNotification(title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "Tahrir Akıllı Mütalaa & Seri Bildirimleri",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Yalnızca günlük okuma hedefiniz eksik olduğunda veya seriniz tehlikedeyken hatırlatır."
            }
            manager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        manager.notify(1453, notification)
    }
}
