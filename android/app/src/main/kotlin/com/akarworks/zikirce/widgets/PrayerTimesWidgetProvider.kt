package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R

class PrayerTimesWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, PrayerTimesWidgetProvider::class.java)
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
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_times)

                val city = WidgetDataHelper.getStringPref(context, "SelectedCity", "İstanbul")
                val cachedTimes = WidgetDataHelper.getCachedPrayerTimes(context, city)

                views.setTextViewText(R.id.widget_city, city)

                val hijriStr = if (cachedTimes.hijriMonth.isNotEmpty()) {
                    "${cachedTimes.hijriDay} ${cachedTimes.hijriMonth} ${cachedTimes.hijriYear}"
                } else ""
                views.setTextViewText(R.id.widget_hijri, hijriStr)

                // 6 Prayer times
                views.setTextViewText(R.id.widget_imsak, cachedTimes.imsak)
                views.setTextViewText(R.id.widget_gunes, cachedTimes.gunes)
                views.setTextViewText(R.id.widget_ogle, cachedTimes.ogle)
                views.setTextViewText(R.id.widget_ikindi, cachedTimes.ikindi)
                views.setTextViewText(R.id.widget_aksam, cachedTimes.aksam)
                views.setTextViewText(R.id.widget_yatsi, cachedTimes.yatsi)

                val nextPrayer = WidgetDataHelper.calculateNextPrayer(cachedTimes)
                val localizedNext = WidgetDataHelper.getDirectionalPrayerName(context, nextPrayer.name)

                views.setTextViewText(R.id.widget_next_prayer_name, localizedNext)
                views.setTextViewText(R.id.widget_next_prayer_time, nextPrayer.timeStr)

                val safeMs = kotlin.math.max(0L, nextPrayer.remainingMs)
                val baseTime = SystemClock.elapsedRealtime() + safeMs
                views.setChronometer(R.id.widget_next_prayer_countdown, baseTime, null, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(R.id.widget_next_prayer_countdown, true)
                }

                // Reset all container backgrounds
                views.setInt(R.id.widget_imsak_container, "setBackgroundResource", R.drawable.widget_time_bg_normal)
                views.setInt(R.id.widget_gunes_container, "setBackgroundResource", R.drawable.widget_time_bg_normal)
                views.setInt(R.id.widget_ogle_container, "setBackgroundResource", R.drawable.widget_time_bg_normal)
                views.setInt(R.id.widget_ikindi_container, "setBackgroundResource", R.drawable.widget_time_bg_normal)
                views.setInt(R.id.widget_aksam_container, "setBackgroundResource", R.drawable.widget_time_bg_normal)
                views.setInt(R.id.widget_yatsi_container, "setBackgroundResource", R.drawable.widget_time_bg_normal)

                val activeContainerId = when (nextPrayer.name) {
                    "İmsak" -> R.id.widget_imsak_container
                    "Güneş" -> R.id.widget_gunes_container
                    "Öğle" -> R.id.widget_ogle_container
                    "İkindi" -> R.id.widget_ikindi_container
                    "Akşam" -> R.id.widget_aksam_container
                    "Yatsı" -> R.id.widget_yatsi_container
                    else -> -1
                }
                if (activeContainerId != -1) {
                    views.setInt(activeContainerId, "setBackgroundResource", R.drawable.widget_time_bg_active)
                }

                // Open App on click
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getActivity(context, 100, openIntent, flags)
                views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_city, pendingIntent)

                WidgetAlarmScheduler.scheduleNextPrayerAlarm(context)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {}
        }
    }
}
