package com.akarworks.zikirce.widgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class WidgetTimeTickReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        when (intent.action) {
            Intent.ACTION_TIME_TICK,
            Intent.ACTION_USER_PRESENT -> {
                // Lightweight prayer-only refresh (zero SQLite queries)
                updatePrayerWidgetsOnly(context)
            }
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED -> {
                updateAllWidgets(context)
            }
        }
    }

    companion object {
        fun updatePrayerWidgetsOnly(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context) ?: return

                // 1. Prayer Times Table Widget
                val ptIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerTimesWidgetProvider::class.java))
                if (ptIds != null && ptIds.isNotEmpty()) {
                    for (id in ptIds) {
                        PrayerTimesWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 2. Prayer Times Mini Widget
                val miniIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerTimesMiniWidgetProvider::class.java))
                if (miniIds != null && miniIds.isNotEmpty()) {
                    for (id in miniIds) {
                        PrayerTimesMiniWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 3. Prayer Countdown Circular Widget
                val cdIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerCountdownWidgetProvider::class.java))
                if (cdIds != null && cdIds.isNotEmpty()) {
                    for (id in cdIds) {
                        PrayerCountdownWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 4. Digital Clock Widget
                val digIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerDigitalClockWidgetProvider::class.java))
                if (digIds != null && digIds.isNotEmpty()) {
                    for (id in digIds) {
                        PrayerDigitalClockWidgetProvider.updateWidgetStatic(context, appWidgetManager, id)
                    }
                }

                // 5. Selçuklu Yıldızı Analog Clock Widget
                val analogIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerAnalogClockWidgetProvider::class.java))
                if (analogIds != null && analogIds.isNotEmpty()) {
                    for (id in analogIds) {
                        PrayerAnalogClockWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 10. 2x1 Next Prayer Widget
                val nextIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerNextWidgetProvider::class.java))
                if (nextIds != null && nextIds.isNotEmpty()) {
                    for (id in nextIds) {
                        PrayerNextWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 13. Mini Prayer Widget
                val prayerMiniIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerMiniWidgetProvider::class.java))
                if (prayerMiniIds != null && prayerMiniIds.isNotEmpty()) {
                    for (id in prayerMiniIds) {
                        PrayerMiniWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                WidgetAlarmScheduler.scheduleNextPrayerAlarm(context)
            } catch (_: Exception) {}
        }

        fun updateAllWidgets(context: Context) {
            try {
                updatePrayerWidgetsOnly(context)

                val appWidgetManager = AppWidgetManager.getInstance(context) ?: return

                // 6. Daily Verse / Hijri Calendar Widget
                val verseIds = appWidgetManager.getAppWidgetIds(ComponentName(context, DailyVerseWidgetProvider::class.java))
                if (verseIds != null && verseIds.isNotEmpty()) {
                    for (id in verseIds) {
                        DailyVerseWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 7. Kaza Prayer Tracker Widget
                val kazaIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerKazaWidgetProvider::class.java))
                if (kazaIds != null && kazaIds.isNotEmpty()) {
                    for (id in kazaIds) {
                        PrayerKazaWidgetProvider.updateWidgetSync(context, appWidgetManager, id)
                    }
                }

                // 8. Spiritual Heart Health Widget
                val kalpIds = appWidgetManager.getAppWidgetIds(ComponentName(context, KalpSagligiWidgetProvider::class.java))
                if (kalpIds != null && kalpIds.isNotEmpty()) {
                    for (id in kalpIds) {
                        KalpSagligiWidgetProvider.updateWidgetSync(context, appWidgetManager, id)
                    }
                }

                // 9. Daily Streak / Dhikr Widget
                val zikirIds = appWidgetManager.getAppWidgetIds(ComponentName(context, ZikirCounterWidgetProvider::class.java))
                if (zikirIds != null && zikirIds.isNotEmpty()) {
                    for (id in zikirIds) {
                        ZikirCounterWidgetProvider.updateWidgetTick(context, appWidgetManager, id)
                    }
                }

                // 11. 2x1 Streak Widget
                val streakIds = appWidgetManager.getAppWidgetIds(ComponentName(context, StreakWidgetProvider::class.java))
                if (streakIds != null && streakIds.isNotEmpty()) {
                    for (id in streakIds) {
                        StreakWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 12. 2x1 Quick Kaza Widget
                val quickKazaIds = appWidgetManager.getAppWidgetIds(ComponentName(context, KazaQuickWidgetProvider::class.java))
                if (quickKazaIds != null && quickKazaIds.isNotEmpty()) {
                    for (id in quickKazaIds) {
                        KazaQuickWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }

                // 14. Külliyat & Okuma Rafı Widget
                val kulliyatIds = appWidgetManager.getAppWidgetIds(ComponentName(context, KulliyatWidgetProvider::class.java))
                if (kulliyatIds != null && kulliyatIds.isNotEmpty()) {
                    for (id in kulliyatIds) {
                        KulliyatWidgetProvider.updateWidget(context, appWidgetManager, id)
                    }
                }
            } catch (_: Exception) {}
        }
    }
}
