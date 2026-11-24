package com.tahrir.app.tahrir

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class TahrirHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidgetInstance(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "tahrir_home_widget_prefs"

        fun saveAndRefreshAll(
            context: Context,
            streakDays: Int,
            todayMinutes: Int,
            goalMinutes: Int,
            bookTitle: String,
            dailyQuote: String,
            progressPercent: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putInt("streakDays", streakDays)
                .putInt("todayMinutes", todayMinutes)
                .putInt("goalMinutes", goalMinutes)
                .putString("bookTitle", bookTitle)
                .putString("dailyQuote", dailyQuote)
                .putInt("progressPercent", progressPercent)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TahrirHomeWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidgetInstance(context, manager, id)
            }
        }

        fun updateWidgetInstance(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val streak = prefs.getInt("streakDays", 3)
            val today = prefs.getInt("todayMinutes", 0)
            val goal = prefs.getInt("goalMinutes", 20)
            val title = prefs.getString("bookTitle", "Kutadgu Bilig (Seçmeler)") ?: "Tahrir"
            val quote = prefs.getString(
                "dailyQuote",
                "Kişi gönlünü akıl ile süsler, aklı ise bilgi ile aydınlatır."
            ) ?: ""
            val progress = prefs.getInt("progressPercent", 12)

            val views = RemoteViews(context.packageName, R.layout.tahrir_home_widget)
            views.setTextViewText(
                R.id.widget_streak,
                "🔥 $streak Gün Seri • $today/$goal dk"
            )
            views.setTextViewText(R.id.widget_book_title, title)
            views.setTextViewText(R.id.widget_quote, "“$quote”")
            views.setTextViewText(
                R.id.widget_cta,
                "🕯️ %$progress Tamamlandı • Okumaya Devam Et →"
            )

            val launchIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
