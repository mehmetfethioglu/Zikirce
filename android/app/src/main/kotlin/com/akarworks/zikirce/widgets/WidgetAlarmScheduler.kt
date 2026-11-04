package com.akarworks.zikirce.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar
import kotlin.math.min

object WidgetAlarmScheduler {

    private val prayerWidgetClasses = arrayOf(
        PrayerTimesWidgetProvider::class.java,
        PrayerTimesMiniWidgetProvider::class.java,
        PrayerCountdownWidgetProvider::class.java,
        PrayerDigitalClockWidgetProvider::class.java,
        PrayerAnalogClockWidgetProvider::class.java,
        PrayerNextWidgetProvider::class.java,
        PrayerMiniWidgetProvider::class.java,
        DailyVerseWidgetProvider::class.java,
        ZikirCounterWidgetProvider::class.java,
        StreakWidgetProvider::class.java
    )

    private fun hasAnyActiveTimeSensitiveWidget(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context) ?: return false
        for (cls in prayerWidgetClasses) {
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            if (ids != null && ids.isNotEmpty()) return true
        }
        return false
    }

    fun scheduleNextPrayerAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val prayerIntent = Intent(context, WidgetPrayerAlarmReceiver::class.java).apply {
                action = "com.akarworks.zikirce.WIDGET_PRAYER_ALARM"
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }
            val prayerPendingIntent = PendingIntent.getBroadcast(context, 1001, prayerIntent, flags)

            val backupIntent = Intent(context, WidgetPrayerAlarmReceiver::class.java).apply {
                action = "com.akarworks.zikirce.WIDGET_BACKUP_ALARM"
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }
            val backupPendingIntent = PendingIntent.getBroadcast(context, 1002, backupIntent, flags)

            // Zero-battery guard: if no time-sensitive widgets are placed on the home screen, cancel alarms
            if (!hasAnyActiveTimeSensitiveWidget(context)) {
                alarmManager.cancel(prayerPendingIntent)
                alarmManager.cancel(backupPendingIntent)
                return
            }

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

            var nextPrayerCal: Calendar? = null

            for (pSec in prayerSeconds) {
                // Schedule alarm at exact HH:mm:00 so Chronometer transitions to next prayer at 00:00 without negative ticks
                if (pSec > nowSeconds) {
                    val target = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, pSec / 3600)
                        set(Calendar.MINUTE, (pSec % 3600) / 60)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 100)
                    }
                    nextPrayerCal = target
                    break
                }
            }

            if (nextPrayerCal == null) {
                val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
                val tomorrowTimes = WidgetDataHelper.getCachedPrayerTimes(context, city, tomorrowCal)
                val firstSec = WidgetDataHelper.parseTimeMinutes(tomorrowTimes.imsak) * 60
                nextPrayerCal = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, 1)
                    set(Calendar.HOUR_OF_DAY, firstSec / 3600)
                    set(Calendar.MINUTE, (firstSec % 3600) / 60)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 100)
                }
            }

            // Next midnight rollover (00:00:00) so Hijri calendar, streak & new day's prayer times update cleanly
            val nextMidnightCal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 200)
            }

            val triggerMillis = min(nextPrayerCal.timeInMillis, nextMidnightCal.timeInMillis)

            // 1. Primary transition alarm (at exact HH:mm:00.100 or 00:00:00.200)
            setAlarmSafe(alarmManager, triggerMillis, prayerPendingIntent)

            // 2. Backup transition alarm (2 seconds later to guarantee immediate rollover)
            setAlarmSafe(alarmManager, triggerMillis + 2_000L, backupPendingIntent)
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
