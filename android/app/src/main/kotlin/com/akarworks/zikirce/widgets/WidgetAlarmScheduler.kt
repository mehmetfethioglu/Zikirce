package com.akarworks.zikirce.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object WidgetAlarmScheduler {

    fun scheduleNextPrayerAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

            val city = WidgetDataHelper.getStringPref(context, "SelectedCity", "İstanbul")
            val cachedTimes = WidgetDataHelper.getCachedPrayerTimes(context, city)

            val now = Calendar.getInstance()
            val nowSeconds = now.get(Calendar.HOUR_OF_DAY) * 3600 + now.get(Calendar.MINUTE) * 60 + now.get(Calendar.SECOND)

            val prayerSeconds = listOf(
                WidgetDataHelper.parseTimeMinutes(cachedTimes.imsak) * 60,
                WidgetDataHelper.parseTimeMinutes(cachedTimes.gunes) * 60,
                WidgetDataHelper.parseTimeMinutes(cachedTimes.ogle) * 60,
                WidgetDataHelper.parseTimeMinutes(cachedTimes.ikindi) * 60,
                WidgetDataHelper.parseTimeMinutes(cachedTimes.aksam) * 60,
                WidgetDataHelper.parseTimeMinutes(cachedTimes.yatsi) * 60
            )

            var nextAlarmCal: Calendar? = null

            for (pSec in prayerSeconds) {
                // Schedule alarm 1 second after prayer time enters so now is strictly in the new prayer period
                if (pSec > nowSeconds) {
                    val target = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, pSec / 3600)
                        set(Calendar.MINUTE, (pSec % 3600) / 60)
                        set(Calendar.SECOND, 1)
                        set(Calendar.MILLISECOND, 0)
                    }
                    nextAlarmCal = target
                    break
                }
            }

            if (nextAlarmCal == null) {
                val firstSec = prayerSeconds[0]
                nextAlarmCal = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, 1)
                    set(Calendar.HOUR_OF_DAY, firstSec / 3600)
                    set(Calendar.MINUTE, (firstSec % 3600) / 60)
                    set(Calendar.SECOND, 1)
                    set(Calendar.MILLISECOND, 0)
                }
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // 1. Primary prayer entry alarm (at exact HH:mm:01)
            val prayerIntent = Intent(context, WidgetPrayerAlarmReceiver::class.java).apply {
                action = "com.akarworks.zikirce.WIDGET_PRAYER_ALARM"
            }
            val prayerPendingIntent = PendingIntent.getBroadcast(context, 1001, prayerIntent, flags)
            setAlarmSafe(alarmManager, nextAlarmCal.timeInMillis, prayerPendingIntent)

            // 2. Backup prayer entry alarm (1 minute after prayer entry to guarantee rollover)
            val backupIntent = Intent(context, WidgetPrayerAlarmReceiver::class.java).apply {
                action = "com.akarworks.zikirce.WIDGET_BACKUP_ALARM"
            }
            val backupPendingIntent = PendingIntent.getBroadcast(context, 1002, backupIntent, flags)
            setAlarmSafe(alarmManager, nextAlarmCal.timeInMillis + 60_000L, backupPendingIntent)
        } catch (_: Exception) {}
    }

    private fun setAlarmSafe(alarmManager: AlarmManager, triggerMillis: Long, pendingIntent: PendingIntent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent)
                    return
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent)
                return
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent)
                return
            }
        } catch (_: Exception) {}

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent)
            }
        } catch (_: Exception) {}
    }
}
