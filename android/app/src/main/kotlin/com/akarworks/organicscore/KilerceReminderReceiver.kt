package com.akarworks.organicscore

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

object KilerceNotificationHelper {
    const val CHANNEL_SKT = "kilerce_skt_alerts"
    const val CHANNEL_MENU = "kilerce_menu_alerts"
    const val ACTION_SHOW_REMINDER = "com.akarworks.organicscore.ACTION_SHOW_REMINDER"

    private const val PREFS_NAME = "kilerce_scheduled_reminders_v1"
    private const val KEY_IDS = "scheduled_ids"
    private const val EXTRA_ID = "reminder_id"
    private const val EXTRA_CHANNEL_ID = "reminder_channel_id"
    private const val EXTRA_TITLE = "reminder_title"
    private const val EXTRA_BODY = "reminder_body"

    fun hasNotificationPermission(context: Context): Boolean {
        val enabledInSettings = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (!enabledInSettings) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val sktChannel = NotificationChannel(
            CHANNEL_SKT,
            "Kilerce SKT Hatırlatıcı",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Son kullanma tarihi yaklaşan kiler ürünleri için günlük hatırlatma"
        }

        val menuChannel = NotificationChannel(
            CHANNEL_MENU,
            "Günlük Menü & Eksik Malzeme",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Bugünkü menünüzde eksik ürün varsa sabah hatırlatma bildirimi"
        }

        manager.createNotificationChannel(sktChannel)
        manager.createNotificationChannel(menuChannel)
    }

    fun showNotification(
        context: Context,
        id: Int,
        channelId: String,
        title: String,
        body: String
    ): Boolean {
        if (!hasNotificationPermission(context)) {
            return false
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return false

        ensureChannels(context)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val effectiveChannel = if (channelId == CHANNEL_MENU) CHANNEL_MENU else CHANNEL_SKT
        val priority = if (effectiveChannel == CHANNEL_MENU) {
            NotificationCompat.PRIORITY_HIGH
        } else {
            NotificationCompat.PRIORITY_DEFAULT
        }

        val notification = NotificationCompat.Builder(context, effectiveChannel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setPriority(priority)
            .setAutoCancel(true)
            .build()

        manager.notify(id, notification)
        return true
    }

    fun scheduleReminder(
        context: Context,
        id: Int,
        channelId: String,
        title: String,
        body: String,
        triggerAtMillis: Long
    ): Boolean {
        if (triggerAtMillis <= System.currentTimeMillis()) {
            return false
        }
        ensureChannels(context)

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ids = (prefs.getStringSet(KEY_IDS, emptySet()) ?: emptySet()).toMutableSet()
        ids.add(id.toString())
        prefs.edit()
            .putStringSet(KEY_IDS, ids)
            .putString("ch_$id", channelId)
            .putString("title_$id", title)
            .putString("body_$id", body)
            .putLong("at_$id", triggerAtMillis)
            .apply()

        return setAlarm(context, id, channelId, title, body, triggerAtMillis)
    }

    fun cancelReminder(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val pendingIntent = buildBroadcastPendingIntent(
            context = context,
            id = id,
            channelId = CHANNEL_SKT,
            title = "",
            body = ""
        )
        alarmManager?.cancel(pendingIntent)
        pendingIntent.cancel()
        removeFromPrefs(context, id)
    }

    fun rescheduleAllFromPrefs(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ids = (prefs.getStringSet(KEY_IDS, emptySet()) ?: emptySet()).toList()
        val now = System.currentTimeMillis()
        for (idStr in ids) {
            val id = idStr.toIntOrNull() ?: continue
            val triggerAt = prefs.getLong("at_$id", 0L)
            if (triggerAt <= now) {
                removeFromPrefs(context, id)
                continue
            }
            val channelId = prefs.getString("ch_$id", CHANNEL_MENU) ?: CHANNEL_MENU
            val title = prefs.getString("title_$id", null) ?: continue
            val body = prefs.getString("body_$id", null) ?: continue
            setAlarm(context, id, channelId, title, body, triggerAt)
        }
    }

    fun removeFromPrefs(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ids = (prefs.getStringSet(KEY_IDS, emptySet()) ?: emptySet()).toMutableSet()
        ids.remove(id.toString())
        prefs.edit()
            .putStringSet(KEY_IDS, ids)
            .remove("ch_$id")
            .remove("title_$id")
            .remove("body_$id")
            .remove("at_$id")
            .apply()
    }

    private fun setAlarm(
        context: Context,
        id: Int,
        channelId: String,
        title: String,
        body: String,
        triggerAtMillis: Long
    ): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return false
        val pendingIntent = buildBroadcastPendingIntent(context, id, channelId, title, body)
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent
        )
        return true
    }

    private fun buildBroadcastPendingIntent(
        context: Context,
        id: Int,
        channelId: String,
        title: String,
        body: String
    ): PendingIntent {
        val intent = Intent(context, KilerceReminderReceiver::class.java).apply {
            action = ACTION_SHOW_REMINDER
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_CHANNEL_ID, channelId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun handleReminderIntent(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, 32220)
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID) ?: CHANNEL_MENU
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Kilerce Hatırlatma"
        val body = intent.getStringExtra(EXTRA_BODY) ?: "Bugünkü menünüzü ve dolabınızı kontrol edin."
        showNotification(context, id, channelId, title, body)
        removeFromPrefs(context, id)
    }
}

class KilerceReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                KilerceNotificationHelper.rescheduleAllFromPrefs(context)
            }
            KilerceNotificationHelper.ACTION_SHOW_REMINDER -> {
                KilerceNotificationHelper.handleReminderIntent(context, intent)
            }
        }
    }
}
