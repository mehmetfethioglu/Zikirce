package com.akarworks.zikirce.widgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class WidgetTimeTickReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        if (intent.action == Intent.ACTION_TIME_TICK ||
            intent.action == Intent.ACTION_TIME_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED
        ) {
            updateAllWidgets(context)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context) ?: return

                // 1. Prayer Times Table Widget
                val ptComp = ComponentName(context, PrayerTimesWidgetProvider::class.java)
                val ptIds = appWidgetManager.getAppWidgetIds(ptComp)
                if (ptIds != null && ptIds.isNotEmpty()) {
                    for (id in ptIds) {
                        PrayerTimesWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 2. Prayer Times Mini Widget
                val miniComp = ComponentName(context, PrayerTimesMiniWidgetProvider::class.java)
                val miniIds = appWidgetManager.getAppWidgetIds(miniComp)
                if (miniIds != null && miniIds.isNotEmpty()) {
                    for (id in miniIds) {
                        PrayerTimesMiniWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 3. Prayer Countdown Circular Widget
                val cdComp = ComponentName(context, PrayerCountdownWidgetProvider::class.java)
                val cdIds = appWidgetManager.getAppWidgetIds(cdComp)
                if (cdIds != null && cdIds.isNotEmpty()) {
                    for (id in cdIds) {
                        PrayerCountdownWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 4. Digital Clock Widget
                val digComp = ComponentName(context, PrayerDigitalClockWidgetProvider::class.java)
                val digIds = appWidgetManager.getAppWidgetIds(digComp)
                if (digIds != null && digIds.isNotEmpty()) {
                    for (id in digIds) {
                        PrayerDigitalClockWidgetProvider.updateWidgetStatic(context, appWidgetManager, id)
                    }
                }

                // 5. Analog Clock Widget
                val analogComp = ComponentName(context, PrayerAnalogClockWidgetProvider::class.java)
                val analogIds = appWidgetManager.getAppWidgetIds(analogComp)
                if (analogIds != null && analogIds.isNotEmpty()) {
                    for (id in analogIds) {
                        PrayerAnalogClockWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 6. Daily Verse / Hijri Calendar Widget
                val verseComp = ComponentName(context, DailyVerseWidgetProvider::class.java)
                val verseIds = appWidgetManager.getAppWidgetIds(verseComp)
                if (verseIds != null && verseIds.isNotEmpty()) {
                    for (id in verseIds) {
                        DailyVerseWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 7. Kaza Prayer Tracker Widget
                val kazaComp = ComponentName(context, PrayerKazaWidgetProvider::class.java)
                val kazaIds = appWidgetManager.getAppWidgetIds(kazaComp)
                if (kazaIds != null && kazaIds.isNotEmpty()) {
                    for (id in kazaIds) {
                        PrayerKazaWidgetProvider.updateWidgetSync(context, appWidgetManager, id)
                    }
                }

                // 8. Spiritual Heart Health Widget
                val kalpComp = ComponentName(context, KalpSagligiWidgetProvider::class.java)
                val kalpIds = appWidgetManager.getAppWidgetIds(kalpComp)
                if (kalpIds != null && kalpIds.isNotEmpty()) {
                    for (id in kalpIds) {
                        KalpSagligiWidgetProvider.updateWidgetSync(context, appWidgetManager, id)
                    }
                }

                // 9. Daily Streak / Dhikr Widget
                val zikirComp = ComponentName(context, ZikirCounterWidgetProvider::class.java)
                val zikirIds = appWidgetManager.getAppWidgetIds(zikirComp)
                if (zikirIds != null && zikirIds.isNotEmpty()) {
                    for (id in zikirIds) {
                        ZikirCounterWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 10. 2x1 Next Prayer Widget
                val nextComp = ComponentName(context, PrayerNextWidgetProvider::class.java)
                val nextIds = appWidgetManager.getAppWidgetIds(nextComp)
                if (nextIds != null && nextIds.isNotEmpty()) {
                    for (id in nextIds) {
                        PrayerNextWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 11. 2x1 Streak Widget
                val streakComp = ComponentName(context, StreakWidgetProvider::class.java)
                val streakIds = appWidgetManager.getAppWidgetIds(streakComp)
                if (streakIds != null && streakIds.isNotEmpty()) {
                    for (id in streakIds) {
                        StreakWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 12. 2x1 Quick Kaza Widget
                val quickKazaComp = ComponentName(context, KazaQuickWidgetProvider::class.java)
                val quickKazaIds = appWidgetManager.getAppWidgetIds(quickKazaComp)
                if (quickKazaIds != null && quickKazaIds.isNotEmpty()) {
                    for (id in quickKazaIds) {
                        KazaQuickWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 13. Mini Prayer Widget
                val prayerMiniComp = ComponentName(context, PrayerMiniWidgetProvider::class.java)
                val prayerMiniIds = appWidgetManager.getAppWidgetIds(prayerMiniComp)
                if (prayerMiniIds != null && prayerMiniIds.isNotEmpty()) {
                    for (id in prayerMiniIds) {
                        PrayerMiniWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // Reschedule next exact alarm
                WidgetAlarmScheduler.scheduleNextPrayerAlarm(context)
            } catch (_: Exception) {}
        }
    }
}
