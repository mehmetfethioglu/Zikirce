package com.akarworks.zikirce.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

class WidgetPrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        val pendingResult = goAsync()
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Zikirce:WidgetAlarmWakeLock")
            wakeLock?.acquire(3000)
            try {
                WidgetTimeTickReceiver.updateAllWidgets(context)
                WidgetAlarmScheduler.scheduleNextPrayerAlarm(context)
            } finally {
                if (wakeLock?.isHeld == true) {
                    wakeLock.release()
                }
            }
        } catch (_: Exception) {
        } finally {
            pendingResult.finish()
        }
    }
}
