package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class StreakWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, StreakWidgetProvider::class.java)
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
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val views = RemoteViews(context.packageName, R.layout.widget_streak)
                    val stats = WidgetDataHelper.fetchStatsFromDb(context)

                    val lightBitmap = draw2x1StreakBitmap(stats, isDark = false)
                    val darkBitmap = draw2x1StreakBitmap(stats, isDark = true)

                    if (lightBitmap != null && darkBitmap != null) {
                        views.setImageViewBitmap(R.id.widget_image_light, lightBitmap)
                        views.setImageViewBitmap(R.id.widget_image_dark, darkBitmap)
                    }

                    val openIntent = Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        data = Uri.parse("zikirce://zikir")
                        putExtra("route", "/zikir")
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getActivity(context, 111, openIntent, flags)
                    views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {}
            }
        }

        private fun draw2x1StreakBitmap(stats: WidgetStatsData, isDark: Boolean): Bitmap? {
            return try {
                val width = 600
                val height = 300
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)

                val cardRect = RectF(4f, 4f, width - 4f, height - 4f)
                val cornerRadius = 42f

                // 1. Background Card
                val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    if (stats.isGoldCompletedToday) {
                        shader = LinearGradient(
                            cardRect.left, cardRect.top, cardRect.right, cardRect.bottom,
                            Color.parseColor("#FFF8E1"), Color.parseColor("#FFE082"),
                            Shader.TileMode.CLAMP
                        )
                    } else {
                        color = if (isDark) Color.parseColor("#14100C") else Color.parseColor("#FFFDF9")
                    }
                }
                canvas.drawRoundRect(cardRect, cornerRadius, cornerRadius, bgPaint)

                // 2. Card Border
                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2.5f
                    color = if (stats.isGoldCompletedToday) {
                        Color.parseColor("#FFB300")
                    } else {
                        if (isDark) Color.parseColor("#24FFFFFF") else Color.parseColor("#14000000")
                    }
                }
                canvas.drawRoundRect(cardRect, cornerRadius, cornerRadius, borderPaint)

                // 3. Left Section: Flame, Streak Number & Subtitle
                val leftCenterX = 115f

                // Flame Icon
                val flamePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    textSize = 52f
                    textAlign = Paint.Align.CENTER
                }
                canvas.drawText("🔥", leftCenterX, 86f, flamePaint)

                // Big Streak Number
                val numberPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (stats.isGoldCompletedToday) {
                        Color.parseColor("#4E342E")
                    } else if (isDark) {
                        Color.parseColor("#FFFFFF")
                    } else {
                        Color.parseColor("#0F172A")
                    }
                    textSize = 72f
                    isFakeBoldText = true
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                }
                canvas.drawText("${stats.streakCount}", leftCenterX, 172f, numberPaint)

                // Streak Subtitle
                val subPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (stats.isGoldCompletedToday) {
                        Color.parseColor("#B45309")
                    } else if (isDark) {
                        Color.parseColor("#FBBF24")
                    } else {
                        Color.parseColor("#D97706")
                    }
                    textSize = 21f
                    isFakeBoldText = true
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    letterSpacing = 0.08f
                }
                val subTitle = if (stats.isGoldCompletedToday) "ALTIN GÜN" else "GÜN SERİSİ"
                canvas.drawText(subTitle, leftCenterX, 222f, subPaint)

                // 4. Elegant Vertical Divider
                val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2f
                    color = if (stats.isGoldCompletedToday) {
                        Color.parseColor("#25B45309")
                    } else if (isDark) {
                        Color.parseColor("#18FFFFFF")
                    } else {
                        Color.parseColor("#12000000")
                    }
                }
                canvas.drawLine(228f, 44f, 228f, 256f, divPaint)

                // 5. Right Section: Weekly 7-Day Badges (Pzt - Paz)
                val rightStartX = 256f
                val rightEndX = 556f

                val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (stats.isGoldCompletedToday) {
                        Color.parseColor("#78350F")
                    } else if (isDark) {
                        Color.parseColor("#A1A1AA")
                    } else {
                        Color.parseColor("#64748B")
                    }
                    textSize = 20f
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    letterSpacing = 0.06f
                }
                canvas.drawText("HAFTALIK İLERLEME", rightStartX, 68f, headerPaint)

                val todayCal = Calendar.getInstance()
                val curDayIdx = (todayCal.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Monday = 0

                val weekDates = Array(7) { i ->
                    val temp = Calendar.getInstance()
                    temp.add(Calendar.DAY_OF_YEAR, i - curDayIdx)
                    SimpleDateFormat("yyyy-MM-dd", Locale.US).format(temp.time)
                }
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(todayCal.time)
                val dayLabels = arrayOf("P", "S", "Ç", "P", "C", "C", "P")

                val badgeY = 126f
                val badgeRadius = 18f
                val spacing = (rightEndX - rightStartX - (badgeRadius * 2)) / 6f

                val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG)
                val letterPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    textSize = 17f
                    isFakeBoldText = true
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                }

                for (i in 0 until 7) {
                    val dotX = rightStartX + badgeRadius + i * spacing
                    val isDayToday = (weekDates[i] == todayStr)
                    val isCompleted = stats.activeDatesInWeek.contains(weekDates[i])
                    val isFuture = i > curDayIdx

                    if (isFuture) {
                        badgePaint.style = Paint.Style.STROKE
                        badgePaint.strokeWidth = 2f
                        badgePaint.color = if (stats.isGoldCompletedToday) {
                            Color.parseColor("#40B45309")
                        } else if (isDark) {
                            Color.parseColor("#28221C")
                        } else {
                            Color.parseColor("#E2E8F0")
                        }
                        canvas.drawCircle(dotX, badgeY, badgeRadius, badgePaint)
                        letterPaint.color = if (isDark) Color.parseColor("#524B45") else Color.parseColor("#94A3B8")
                    } else if (isDayToday) {
                        if (isCompleted || stats.isCompletedToday) {
                            badgePaint.style = Paint.Style.FILL
                            badgePaint.color = if (stats.isGoldCompletedToday) Color.parseColor("#F59E0B") else Color.parseColor("#10B981")
                            canvas.drawCircle(dotX, badgeY, badgeRadius, badgePaint)
                            letterPaint.color = Color.WHITE
                        } else {
                            badgePaint.style = Paint.Style.STROKE
                            badgePaint.strokeWidth = 3f
                            badgePaint.color = if (stats.isGoldCompletedToday) Color.parseColor("#D97706") else Color.parseColor("#F59E0B")
                            canvas.drawCircle(dotX, badgeY, badgeRadius, badgePaint)
                            letterPaint.color = badgePaint.color
                        }
                    } else {
                        if (isCompleted) {
                            badgePaint.style = Paint.Style.FILL
                            badgePaint.color = if (stats.isGoldCompletedToday) Color.parseColor("#D97706") else Color.parseColor("#10B981")
                            canvas.drawCircle(dotX, badgeY, badgeRadius, badgePaint)
                            letterPaint.color = Color.WHITE
                        } else {
                            badgePaint.style = Paint.Style.STROKE
                            badgePaint.strokeWidth = 2f
                            badgePaint.color = if (stats.isGoldCompletedToday) Color.parseColor("#60B45309") else if (isDark) Color.parseColor("#38302A") else Color.parseColor("#CBD5E1")
                            canvas.drawCircle(dotX, badgeY, badgeRadius, badgePaint)
                            letterPaint.color = if (isDark) Color.parseColor("#78716C") else Color.parseColor("#94A3B8")
                        }
                    }

                    canvas.drawText(dayLabels[i], dotX, badgeY + 6f, letterPaint)
                }

                // 6. Right Section Bottom: Today's Status Banner
                val pillRect = RectF(rightStartX, 186f, rightEndX, 246f)
                val pillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = if (stats.isGoldCompletedToday || stats.isCompletedToday) {
                        if (stats.isGoldCompletedToday) Color.parseColor("#F59E0B") else Color.parseColor("#10B981")
                    } else {
                        if (isDark) Color.parseColor("#221C16") else Color.parseColor("#F1E9DE")
                    }
                }
                canvas.drawRoundRect(pillRect, 30f, 30f, pillPaint)

                val pillTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (stats.isGoldCompletedToday || stats.isCompletedToday) {
                        Color.WHITE
                    } else {
                        if (isDark) Color.parseColor("#FBBF24") else Color.parseColor("#B45309")
                    }
                    textSize = 21f
                    isFakeBoldText = true
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    letterSpacing = 0.05f
                }
                val statusText = if (stats.isGoldCompletedToday || stats.isCompletedToday) {
                    "BUGÜN TAMAMLANDI ✨"
                } else {
                    "Bugünkü hedefini tamamla 🎯"
                }
                canvas.drawText(statusText, (rightStartX + rightEndX) / 2f, 223f, pillTextPaint)

                bitmap
            } catch (_: Exception) {
                null
            }
        }
    }
}
