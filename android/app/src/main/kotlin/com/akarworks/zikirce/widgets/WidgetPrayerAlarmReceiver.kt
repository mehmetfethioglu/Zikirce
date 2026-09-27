package com.akarworks.zikirce.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WidgetPrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        try {
            WidgetTimeTickReceiver.updateAllWidgets(context)
            WidgetAlarmScheduler.scheduleNextPrayerAlarm(context)
        } catch (_: Exception) {}
    }
}
