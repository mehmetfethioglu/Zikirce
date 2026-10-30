package com.akarworks.cuedeck

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * BroadcastReceiver and helper that delivers real Android OS system notifications
 * (status bar, heads-up popups, lock screen) for CueDeck Watch Planner items,
 * and restores scheduled alarms across device reboots.
 */
class CueDeckReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            ACTION_WATCH_REMINDER -> {
                val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 2001)
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "CueDeck İzleme Vakti"
                val body = intent.getStringExtra(EXTRA_BODY) ?: "Planlanan izleme seansı zamanı geldi."
                val subText = intent.getStringExtra(EXTRA_SUB_TEXT)
                val cueId = intent.getStringExtra(EXTRA_CUE_ID)
                val isLeadReminder = intent.getBooleanExtra(EXTRA_IS_LEAD_REMINDER, false)
                val watchStartMillis = intent.getLongExtra(EXTRA_WATCH_START_MILLIS, 0L)

                // If a lead reminder ("15 dk sonra") was delayed because the phone was off,
                // and the actual watch start time has already arrived/passed, skip the stale lead
                // notification so both notifications do not pile up simultaneously.
                val now = System.currentTimeMillis()
                if (isLeadReminder && watchStartMillis > 0L && now >= watchStartMillis - 45_000L) {
                    return
                }

                CueDeckNotificationHelper.showSystemNotification(
                    context = context,
                    notificationId = notificationId,
                    title = title,
                    body = body,
                    subText = subText,
                    cueId = cueId
                )
            }
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
                CueDeckNotificationHelper.reschedulePersistedAlarms(context)
            }
        }
    }

    companion object {
        const val ACTION_WATCH_REMINDER = "com.akarworks.cuedeck.ACTION_WATCH_REMINDER"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_SUB_TEXT = "sub_text"
        const val EXTRA_CUE_ID = "cue_id"
        const val EXTRA_IS_LEAD_REMINDER = "is_lead_reminder"
        const val EXTRA_WATCH_START_MILLIS = "watch_start_millis"
    }
}

object CueDeckNotificationHelper {
    const val CHANNEL_ID = "cuedeck_watch_reminders_v1"
    private const val CHANNEL_NAME = "CueDeck İzleme Planı Bildirimleri"
    private const val CHANNEL_DESC =
        "Planlanan TV izleme seansları ve oynatma listesi hatırlatma bildirimleri"
    private const val ALARMS_FILE_NAME = "cuedeck_scheduled_alarms.json"

    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= 33) {
            context.checkSelfPermission("android.permission.POST_NOTIFICATIONS") ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return
            val existing = nm.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = CHANNEL_DESC
                    enableVibration(true)
                    enableLights(true)
                    lightColor = 0xFFE2A84B.toInt()
                }
                nm.createNotificationChannel(channel)
            }
        }
    }

    fun showSystemNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
        subText: String? = null,
        cueId: String? = null
    ): Boolean {
        return try {
            ensureChannel(context)
            if (!hasNotificationPermission(context)) {
                return false
            }

            val nm =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return false

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (!cueId.isNullOrEmpty()) {
                    putExtra(CueDeckReminderReceiver.EXTRA_CUE_ID, cueId)
                }
            }

            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val contentIntent = PendingIntent.getActivity(
                context,
                notificationId,
                launchIntent,
                pendingFlags
            )

            val smallIconRes = if (context.applicationInfo.icon != 0) {
                context.applicationInfo.icon
            } else {
                android.R.drawable.ic_popup_reminder
            }

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
                    .setPriority(Notification.PRIORITY_HIGH)
                    .setDefaults(Notification.DEFAULT_ALL)
            }

            builder
                .setSmallIcon(smallIconRes)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setContentIntent(contentIntent)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder
                    .setCategory(Notification.CATEGORY_REMINDER)
                    .setVisibility(Notification.VISIBILITY_PUBLIC)
                    .setColor(0xFFE2A84B.toInt())
            }

            if (!subText.isNullOrEmpty()) {
                builder.setSubText(subText)
            }

            nm.notify(notificationId, builder.build())
            true
        } catch (_: Exception) {
            false
        }
    }

    fun syncScheduledAlarms(
        context: Context,
        alarms: List<Map<String, Any?>>
    ): Int {
        ensureChannel(context)
        cancelPersistedAlarms(context)

        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return 0
        val now = System.currentTimeMillis()
        val persistedArray = JSONArray()
        var scheduledCount = 0

        for (entry in alarms) {
            val alarmId = (entry["alarmId"] as? Number)?.toInt() ?: continue
            val triggerAtMillis = (entry["triggerAtMillis"] as? Number)?.toLong() ?: continue
            if (triggerAtMillis <= now) continue

            val title = (entry["title"] as? String)?.trim().orEmpty()
            val body = (entry["body"] as? String)?.trim().orEmpty()
            val subText = (entry["subText"] as? String)?.trim().orEmpty()
            val cueId = (entry["cueId"] as? String)?.trim().orEmpty()
            val isLeadReminder = (entry["isLeadReminder"] as? Boolean) ?: false
            val watchStartMillis = (entry["watchStartMillis"] as? Number)?.toLong() ?: 0L
            if (title.isEmpty()) continue

            scheduleSingleAlarm(
                context = context,
                am = am,
                alarmId = alarmId,
                triggerAtMillis = triggerAtMillis,
                title = title,
                body = body,
                subText = subText,
                cueId = cueId,
                isLeadReminder = isLeadReminder,
                watchStartMillis = watchStartMillis
            )

            persistedArray.put(
                JSONObject().apply {
                    put("alarmId", alarmId)
                    put("triggerAtMillis", triggerAtMillis)
                    put("title", title)
                    put("body", body)
                    put("subText", subText)
                    put("cueId", cueId)
                    put("isLeadReminder", isLeadReminder)
                    put("watchStartMillis", watchStartMillis)
                }
            )
            scheduledCount++
        }

        try {
            File(context.filesDir, ALARMS_FILE_NAME)
                .writeText(persistedArray.toString(), Charsets.UTF_8)
        } catch (_: Exception) {
        }

        return scheduledCount
    }

    fun cancelPersistedAlarms(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val file = File(context.filesDir, ALARMS_FILE_NAME)
        if (!file.exists()) return
        try {
            val raw = file.readText(Charsets.UTF_8)
            val arr = JSONArray(raw)
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val alarmId = obj.optInt("alarmId", -1)
                if (alarmId == -1) continue
                val intent = Intent(context, CueDeckReminderReceiver::class.java).apply {
                    action = CueDeckReminderReceiver.ACTION_WATCH_REMINDER
                }
                val pi = PendingIntent.getBroadcast(context, alarmId, intent, pendingFlags)
                if (pi != null) {
                    am.cancel(pi)
                    pi.cancel()
                }
            }
            file.delete()
        } catch (_: Exception) {
        }
    }

    fun reschedulePersistedAlarms(context: Context) {
        ensureChannel(context)
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val file = File(context.filesDir, ALARMS_FILE_NAME)
        if (!file.exists()) return
        val now = System.currentTimeMillis()
        try {
            val arr = JSONArray(file.readText(Charsets.UTF_8))
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val alarmId = obj.optInt("alarmId", -1)
                val triggerAtMillis = obj.optLong("triggerAtMillis", 0L)
                if (alarmId == -1 || triggerAtMillis <= now) continue
                scheduleSingleAlarm(
                    context = context,
                    am = am,
                    alarmId = alarmId,
                    triggerAtMillis = triggerAtMillis,
                    title = obj.optString("title", "CueDeck İzleme Vakti"),
                    body = obj.optString("body", ""),
                    subText = obj.optString("subText", ""),
                    cueId = obj.optString("cueId", ""),
                    isLeadReminder = obj.optBoolean("isLeadReminder", false),
                    watchStartMillis = obj.optLong("watchStartMillis", 0L)
                )
            }
        } catch (_: Exception) {
        }
    }

    private fun scheduleSingleAlarm(
        context: Context,
        am: AlarmManager,
        alarmId: Int,
        triggerAtMillis: Long,
        title: String,
        body: String,
        subText: String,
        cueId: String,
        isLeadReminder: Boolean = false,
        watchStartMillis: Long = 0L
    ) {
        val intent = Intent(context, CueDeckReminderReceiver::class.java).apply {
            action = CueDeckReminderReceiver.ACTION_WATCH_REMINDER
            addFlags(Intent.FLAG_RECEIVER_FOREGROUND or Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
            putExtra(CueDeckReminderReceiver.EXTRA_NOTIFICATION_ID, alarmId)
            putExtra(CueDeckReminderReceiver.EXTRA_TITLE, title)
            putExtra(CueDeckReminderReceiver.EXTRA_BODY, body)
            putExtra(CueDeckReminderReceiver.EXTRA_SUB_TEXT, subText)
            putExtra(CueDeckReminderReceiver.EXTRA_CUE_ID, cueId)
            putExtra(CueDeckReminderReceiver.EXTRA_IS_LEAD_REMINDER, isLeadReminder)
            putExtra(CueDeckReminderReceiver.EXTRA_WATCH_START_MILLIS, watchStartMillis)
        }

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pi = PendingIntent.getBroadcast(context, alarmId, intent, pendingFlags)

        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context,
            alarmId,
            showIntent,
            pendingFlags
        )

        try {
            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.canScheduleExactAlarms()
            } else {
                true
            }
            if (canExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // setAlarmClock wakes the device out of Deep Doze & HyperOS/MIUI battery saver
                // at the exact second without deferral.
                val clockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
                am.setAlarmClock(clockInfo, pi)
            } else if (canExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
        } catch (_: SecurityException) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                }
            } catch (_: Exception) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                }
            }
        } catch (_: Exception) {
        }
    }
}
