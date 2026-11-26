package com.akarworks.zikirce.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import com.akarworks.zikirce.R

class PrayerTimesMiniWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, PrayerTimesMiniWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                for (id in ids) {
                    updateWidgetTick(context, appWidgetManager, id)
                }
            }
        }
    }

    override fun onUpdate(context: Context?, appWidgetManager: AppWidgetManager?, appWidgetIds: IntArray?) {
        if (context == null || appWidgetManager == null || appWidgetIds == null) return
        for (id in appWidgetIds) {
            updateWidgetTick(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidgetTick(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_times_mini)

                val city = WidgetDataHelper.getStringPref(context, "SelectedCity", "İstanbul")
                val cachedTimes = WidgetDataHelper.getCachedPrayerTimes(context, city)

                views.setTextViewText(R.id.widget_city, city)

                val hijriStr = if (cachedTimes.hijriMonth.isNotEmpty()) {
                    "${cachedTimes.hijriDay} ${cachedTimes.hijriMonth} ${cachedTimes.hijriYear}"
                } else ""
                views.setTextViewText(R.id.widget_hijri, hijriStr)

                val nextPrayer = WidgetDataHelper.calculateNextPrayer(cachedTimes)
                val localizedNext = WidgetDataHelper.getDirectionalPrayerName(context, nextPrayer.name)

                views.setTextViewText(R.id.widget_next_prayer_name, localizedNext)
                views.setTextViewText(R.id.widget_next_prayer_time, nextPrayer.timeStr)

                val targetRealtime = SystemClock.elapsedRealtime() + nextPrayer.remainingMs
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(R.id.widget_next_prayer_countdown, true)
                }
                views.setChronometer(R.id.widget_next_prayer_countdown, targetRealtime, null, true)

                // Open App on click
                val pendingIntent = WidgetDataHelper.createWidgetLaunchPendingIntent(
                    context = context,
                    requestCode = 101,
                    deepLinkUri = "zikirce://namaz",
                    route = "/namaz"
                )
                views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)

                WidgetAlarmScheduler.scheduleNextPrayerAlarm(context)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {}
        }
    }
}
