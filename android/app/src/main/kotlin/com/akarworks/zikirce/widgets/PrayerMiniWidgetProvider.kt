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
import java.util.Locale

class PrayerMiniWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_TIME_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, PrayerMiniWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                for (id in ids) {
                    updateWidget(context, appWidgetManager, id)
                }
            }
        }
    }

    override fun onUpdate(context: Context?, appWidgetManager: AppWidgetManager?, appWidgetIds: IntArray?) {
        if (context == null || appWidgetManager == null || appWidgetIds == null) return
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_mini)

                val city = WidgetDataHelper.getStringPref(context, "SelectedCity", "İstanbul")
                val cachedTimes = WidgetDataHelper.getCachedPrayerTimes(context, city)
                val nextPrayer = WidgetDataHelper.calculateNextPrayer(cachedTimes)

                val prayerTitle = nextPrayer.name.uppercase(Locale.forLanguageTag("tr-TR"))
                views.setTextViewText(R.id.widget_prayer_name, prayerTitle)
                views.setTextViewText(R.id.widget_next_prayer_time, nextPrayer.timeStr)

                val targetRealtime = SystemClock.elapsedRealtime() + nextPrayer.remainingMs
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(R.id.widget_next_prayer_countdown, true)
                }
                views.setChronometer(R.id.widget_next_prayer_countdown, targetRealtime, null, true)

                val pendingIntent = WidgetDataHelper.createWidgetLaunchPendingIntent(
                    context = context,
                    requestCode = 115,
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
