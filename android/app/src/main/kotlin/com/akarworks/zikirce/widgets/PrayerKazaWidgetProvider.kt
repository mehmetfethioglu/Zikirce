package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import android.widget.Toast
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class PrayerKazaWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == ACTION_DECREMENT_KAZA) {
            val prayerName = intent.getStringExtra("PrayerName") ?: return
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val kazaCounts = WidgetDataHelper.getKazaCountsFromDb(context)
                    val current = kazaCounts[prayerName] ?: 0

                    if (current > 0) {
                        WidgetDataHelper.decrementKazaInDb(context, prayerName)

                        Handler(Looper.getMainLooper()).post {
                            Toast.makeText(context, "$prayerName kazası düşüldü! 🎉", Toast.LENGTH_SHORT).show()
                        }
                    } else {
                        Handler(Looper.getMainLooper()).post {
                            Toast.makeText(context, "$prayerName namazı için kaza borcunuz bulunmuyor.", Toast.LENGTH_SHORT).show()
                        }
                    }

                    // Trigger widget update
                    val appWidgetManager = AppWidgetManager.getInstance(context) ?: return@launch
                    val component = ComponentName(context, PrayerKazaWidgetProvider::class.java)
                    val ids = appWidgetManager.getAppWidgetIds(component)
                    if (ids != null && ids.isNotEmpty()) {
                        for (id in ids) {
                            updateWidgetSync(context, appWidgetManager, id)
                        }
                    }

                    val quickComp = ComponentName(context, KazaQuickWidgetProvider::class.java)
                    val quickIds = appWidgetManager.getAppWidgetIds(quickComp)
                    if (quickIds != null && quickIds.isNotEmpty()) {
                        for (id in quickIds) {
                            KazaQuickWidgetProvider.updateWidget(context, appWidgetManager, id)
                        }
                    }
                } catch (_: Exception) {}
            }
        }

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, PrayerKazaWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                for (id in ids) {
                    updateWidgetSync(context, appWidgetManager, id)
                }
            }
        }
    }

    override fun onUpdate(context: Context?, appWidgetManager: AppWidgetManager?, appWidgetIds: IntArray?) {
        if (context == null || appWidgetManager == null || appWidgetIds == null) return
        for (id in appWidgetIds) {
            updateWidgetSync(context, appWidgetManager, id)
        }
    }

    companion object {
        const val ACTION_DECREMENT_KAZA = "Zikirce.ACTION_DECREMENT_KAZA"

        fun updateWidgetSync(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_kaza)
                val kazaCounts = WidgetDataHelper.getKazaCountsFromDb(context)

                val cSabah = kazaCounts["Sabah"] ?: 0
                val cOgle = kazaCounts["Öğle"] ?: 0
                val cIkindi = kazaCounts["İkindi"] ?: 0
                val cAksam = kazaCounts["Akşam"] ?: 0
                val cYatsi = kazaCounts["Yatsı"] ?: 0

                val total = cSabah + cOgle + cIkindi + cAksam + cYatsi
                views.setTextViewText(R.id.widget_kaza_total, total.toString())

                views.setTextViewText(R.id.widget_kaza_count_sabah, cSabah.toString())
                views.setTextViewText(R.id.widget_kaza_count_ogle, cOgle.toString())
                views.setTextViewText(R.id.widget_kaza_count_ikindi, cIkindi.toString())
                views.setTextViewText(R.id.widget_kaza_count_aksam, cAksam.toString())
                views.setTextViewText(R.id.widget_kaza_count_yatsi, cYatsi.toString())

                // Set click listeners for the 5 cards
                val prayers = arrayOf("Sabah", "Öğle", "İkindi", "Akşam", "Yatsı")
                val cardIds = intArrayOf(
                    R.id.widget_card_sabah,
                    R.id.widget_card_ogle,
                    R.id.widget_card_ikindi,
                    R.id.widget_card_aksam,
                    R.id.widget_card_yatsi
                )

                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }

                for (i in prayers.indices) {
                    val pName = prayers[i]
                    val decIntent = Intent(context, PrayerKazaWidgetProvider::class.java).apply {
                        action = ACTION_DECREMENT_KAZA
                        putExtra("PrayerName", pName)
                        putExtra("WidgetId", appWidgetId)
                    }
                    val pendingDec = PendingIntent.getBroadcast(context, 200 + i, decIntent, flags)
                    views.setOnClickPendingIntent(cardIds[i], pendingDec)
                }

                // Open App on title click
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val pendingOpen = PendingIntent.getActivity(context, 106, openIntent, flags)
                views.setOnClickPendingIntent(R.id.widget_title_kaza, pendingOpen)
                views.setOnClickPendingIntent(R.id.widget_root_layout, pendingOpen)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {}
        }
    }
}
