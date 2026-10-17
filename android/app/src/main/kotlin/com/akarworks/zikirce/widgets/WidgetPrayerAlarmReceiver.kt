package com.akarworks.zikirce.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.Calendar

class WidgetPrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        val pendingResult = goAsync()
        try {
            val cal = Calendar.getInstance()
            val isMidnightWindow = cal.get(Calendar.HOUR_OF_DAY) == 0 && cal.get(Calendar.MINUTE) <= 5
            if (isMidnightWindow) {
                // Midnight rollover: update prayer widgets + Hijri calendar + streak widgets
                WidgetTimeTickReceiver.updateAllWidgets(context)
            } else {
                // Daytime prayer transition: update only prayer widgets (0 SQLite queries, minimal CPU/battery)
                WidgetTimeTickReceiver.updatePrayerWidgetsOnly(context)
            }
        } catch (_: Exception) {
        } finally {
            pendingResult.finish()
        }
    }
}
