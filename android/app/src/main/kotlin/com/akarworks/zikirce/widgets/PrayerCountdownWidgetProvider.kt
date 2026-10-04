package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R
import java.util.Calendar
import kotlin.math.cos
import kotlin.math.sin

class PrayerCountdownWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_CONFIGURATION_CHANGED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, PrayerCountdownWidgetProvider::class.java)
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
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_countdown)

                val city = WidgetDataHelper.getStringPref(context, "SelectedCity", "İstanbul")
                val cachedTimes = WidgetDataHelper.getCachedPrayerTimes(context, city)

                val nextPrayer = WidgetDataHelper.calculateNextPrayer(cachedTimes)
                val localizedNext = WidgetDataHelper.getDirectionalPrayerName(context, nextPrayer.name)

                views.setTextViewText(R.id.widget_next_prayer_name, localizedNext.uppercase())

                val remainingStr = WidgetDataHelper.formatRemainingTime(context, nextPrayer.remainingMs)
                views.setTextViewText(R.id.widget_next_prayer_countdown, remainingStr)

                val bitmap = createConcentricRingsBitmap(cachedTimes, context = context)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_rings_image, bitmap)
                }

                val openIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getActivity(context, 102, openIntent, flags)
                views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)

                WidgetAlarmScheduler.scheduleNextPrayerAlarm(context)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {}
        }

        private fun createConcentricRingsBitmap(times: WidgetPrayerTimes, context: Context): Bitmap? {
            return try {
                val size = 400
                val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)

                val cx = size / 2f
                val cy = size / 2f

                val nextPrayer = WidgetDataHelper.calculateNextPrayer(times)
                val progress = (nextPrayer.progressPercent / 100.0).coerceIn(0.0, 1.0)

                val strokeWidth = size * 0.088f
                val radius = (size - strokeWidth) / 2f - 4f
                val ringRect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)

                val colorHex = WidgetDataHelper.getCountdownColorHex(
                    nextPrayer.name, 360.0, 360.0 * progress
                )

                // 1. Background track (Universal semi-transparent track)
                val paintBg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    this.strokeWidth = strokeWidth * 0.25f
                    color = Color.parseColor("#26D97706")
                }
                canvas.drawCircle(cx, cy, radius, paintBg)

                // 2. Foreground progress arc
                val elapsedAngle = (progress * 360.0).toFloat()
                if (elapsedAngle > 0.5f) {
                    val paintFg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        this.strokeWidth = strokeWidth
                        strokeCap = Paint.Cap.ROUND
                        color = Color.parseColor(colorHex)
                    }
                    canvas.drawArc(ringRect, 270f, elapsedAngle, false, paintFg)
                }

                // 3. 60 Dial ticks (Universal semi-transparent ticks)
                val tickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    strokeCap = Paint.Cap.ROUND
                    color = Color.parseColor("#33D97706")
                }

                for (i in 0 until 60) {
                    val isMajor = (i % 5 == 0)
                    val endR = radius - strokeWidth * 0.5f - 2f
                    val startR = endR - if (isMajor) 8f else 4f
                    tickPaint.strokeWidth = if (isMajor) 2f else 1f

                    val angleRad = Math.toRadians((i * 6.0 - 90.0))
                    val cosA = cos(angleRad).toFloat()
                    val sinA = sin(angleRad).toFloat()

                    val x1 = cx + startR * cosA
                    val y1 = cy + startR * sinA
                    val x2 = cx + endR * cosA
                    val y2 = cy + endR * sinA

                    canvas.drawLine(x1, y1, x2, y2, tickPaint)
                }

                bitmap
            } catch (_: Exception) {
                null
            }
        }
    }
}
