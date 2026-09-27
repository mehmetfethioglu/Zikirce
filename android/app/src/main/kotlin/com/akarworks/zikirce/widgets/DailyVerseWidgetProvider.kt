package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R
import java.text.SimpleDateFormat
import java.util.*

class DailyVerseWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_CONFIGURATION_CHANGED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, DailyVerseWidgetProvider::class.java)
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
                val views = RemoteViews(context.packageName, R.layout.widget_daily_verse)

                val city = WidgetDataHelper.getStringPref(context, "SelectedCity", "İstanbul")
                val cachedTimes = WidgetDataHelper.getCachedPrayerTimes(context, city)

                val (defDay, defMonth, defYear) = WidgetDataHelper.calculateHijri()
                val hijriDayStr = cachedTimes.hijriDay.ifEmpty { defDay }
                val hijriMonthStr = cachedTimes.hijriMonth.ifEmpty { defMonth }
                val hijriYearStr = cachedTimes.hijriYear.ifEmpty { defYear }

                val daysOfWeekFull = arrayOf("PAZARTESİ", "SALI", "ÇARŞAMBA", "PERŞEMBE", "CUMA", "CUMARTESİ", "PAZAR")
                val cal = Calendar.getInstance()
                val dayOfWeekIdx = ((cal.get(Calendar.DAY_OF_WEEK) + 5) % 7)
                val activeDayName = daysOfWeekFull[dayOfWeekIdx]

                val today = Date()
                val trLocale = Locale("tr", "TR")
                val gregFormatter = SimpleDateFormat("d MMMM yyyy", trLocale)
                val gregorianDateStr = gregFormatter.format(today).uppercase(trLocale)

                views.setTextViewText(R.id.widget_day_name, activeDayName)
                views.setTextViewText(R.id.widget_hijri_day, hijriDayStr)
                views.setTextViewText(R.id.widget_hijri_month_year, "${hijriMonthStr.uppercase(trLocale)} $hijriYearStr")
                views.setTextViewText(R.id.widget_gregorian_date, gregorianDateStr)

                val openIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getActivity(context, 105, openIntent, flags)
                views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {}
        }
    }
}
