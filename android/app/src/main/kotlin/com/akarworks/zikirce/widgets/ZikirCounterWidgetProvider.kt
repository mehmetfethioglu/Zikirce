package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.cos
import kotlin.math.sin

class ZikirCounterWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_CONFIGURATION_CHANGED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, ZikirCounterWidgetProvider::class.java)
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
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val views = RemoteViews(context.packageName, R.layout.widget_zikir)
                    val stats = WidgetDataHelper.fetchStatsFromDb(context)

                    if (stats.isGoldCompletedToday) {
                        views.setInt(R.id.widget_root_layout, "setBackgroundResource", R.drawable.widget_streak_gold_bg)
                    } else {
                        views.setInt(R.id.widget_root_layout, "setBackgroundResource", R.drawable.widget_digital_clock_bg)
                    }

                    val bitmap = drawStreakWidgetBitmap(stats)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_image, bitmap)
                    }
                    views.setViewVisibility(R.id.widget_placeholder_layout, View.GONE)

                    val openIntent = Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getActivity(context, 108, openIntent, flags)
                    views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {}
            }
        }

        private fun drawStreakWidgetBitmap(stats: WidgetStatsData): Bitmap? {
            return try {
                val size = 400
                val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)

                val scale = size / 320f
                canvas.scale(scale, scale)

                val width = 320f
                val height = 320f

                val isGold = stats.isGoldCompletedToday

                // 1. Center Disc
                val cx = width / 2f
                val cy = 95f
                val radius = 58f

                val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = if (isGold) Color.parseColor("#FFFDF5") else Color.parseColor("#18888888")
                }
                canvas.drawCircle(cx, cy, radius, centerPaint)

                centerPaint.style = Paint.Style.STROKE
                centerPaint.strokeWidth = 2f
                centerPaint.color = if (isGold) Color.parseColor("#FFA000") else Color.parseColor("#30888888")
                canvas.drawCircle(cx, cy, radius, centerPaint)

                // 2. Confetti Particles
                val rand = Random(stats.streakCount.toLong())
                val confettiColors = intArrayOf(
                    Color.parseColor("#F43F5E"),
                    Color.parseColor("#10B981"),
                    Color.parseColor("#8B5CF6"),
                    Color.parseColor("#3B82F6"),
                    Color.parseColor("#F59E0B")
                )
                for (i in 0 until 12) {
                    val angle = (i * 30.0 + rand.nextDouble() * 15.0) * Math.PI / 180.0
                    val dist = radius + 8f + rand.nextFloat() * 14f
                    val px = (cx + dist * cos(angle)).toFloat()
                    val py = (cy + dist * sin(angle)).toFloat()
                    val pColor = confettiColors[i % confettiColors.size]

                    val confPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = pColor
                        style = Paint.Style.FILL
                    }
                    if (i % 2 == 0) {
                        canvas.drawCircle(px, py, 3f, confPaint)
                    } else {
                        canvas.drawRect(px - 2.5f, py - 2.5f, px + 2.5f, py + 2.5f, confPaint)
                    }
                }

                // 3. Streak Count Number (Crisp High-Contrast)
                val streakText = stats.streakCount.toString()
                val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isGold) Color.parseColor("#3E2723") else Color.parseColor("#10B981")
                    textSize = if (streakText.length > 2) 44f else 54f
                    textAlign = Paint.Align.CENTER
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                }
                val fontMetrics = textPaint.fontMetrics
                val textY = cy - (fontMetrics.ascent + fontMetrics.descent) / 2f
                canvas.drawText(streakText, cx, textY, textPaint)

                // 4. Status Title Badge ("Altın Gün!" / "Harika Gidiyorsun!")
                val badgeText = if (isGold) {
                    "Altın Gün!"
                } else if (stats.isCompletedToday) {
                    "Harika Gidiyorsun!"
                } else {
                    "Bugünü Tamamla"
                }

                val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isGold) Color.parseColor("#B45309") else Color.parseColor("#F59E0B")
                    textSize = 14f
                    textAlign = Paint.Align.CENTER
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                }
                canvas.drawText(badgeText, cx, 185f, badgePaint)

                // 5. Weekly Calendar Card (Bottom Half)
                val cardRect = RectF(12f, 202f, width - 12f, 278f)
                val cardPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isGold) Color.parseColor("#FFF3E0") else Color.parseColor("#12888888")
                    style = Paint.Style.FILL
                }
                canvas.drawRoundRect(cardRect, 16f, 16f, cardPaint)

                cardPaint.style = Paint.Style.STROKE
                cardPaint.strokeWidth = 1f
                cardPaint.color = if (isGold) Color.parseColor("#FFE0B2") else Color.parseColor("#20888888")
                canvas.drawRoundRect(cardRect, 16f, 16f, cardPaint)

                // Weekday Bubbles
                val dayLabels = arrayOf("Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz")
                val cal = Calendar.getInstance()
                val currentDayOfWeek = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7

                val startX = 24f
                val availableWidth = (width - 48f)
                val daySpacing = availableWidth / 7f

                val dayLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    textSize = 10f
                    textAlign = Paint.Align.CENTER
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                    color = if (isGold) Color.parseColor("#795548") else Color.parseColor("#94A3B8")
                }

                val bubblePaint = Paint(Paint.ANTI_ALIAS_FLAG)

                for (i in 0 until 7) {
                    val x = startX + i * daySpacing + daySpacing / 2f
                    val labelY = 222f
                    val bubbleY = 250f
                    val bubbleR = 12f

                    canvas.drawText(dayLabels[i], x, labelY, dayLabelPaint)

                    val isPast = i < currentDayOfWeek
                    val isToday = i == currentDayOfWeek
                    val isFuture = i > currentDayOfWeek

                    val dayCal = Calendar.getInstance()
                    dayCal.add(Calendar.DAY_OF_YEAR, i - currentDayOfWeek)
                    val dayDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(dayCal.time)

                    val isDayDone = if (isToday) {
                        stats.isCompletedToday || stats.todayZikirCount > 0
                    } else if (isPast) {
                        stats.activeDatesInWeek.contains(dayDateStr)
                    } else {
                        false
                    }

                    if (isDayDone) {
                        // Completed Day: Emerald green circle with white check
                        bubblePaint.style = Paint.Style.FILL
                        bubblePaint.color = Color.parseColor("#10B981")
                        canvas.drawCircle(x, bubbleY, bubbleR, bubblePaint)

                        val checkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = Color.WHITE
                            style = Paint.Style.STROKE
                            strokeWidth = 2f
                            strokeCap = Paint.Cap.ROUND
                            strokeJoin = Paint.Join.ROUND
                        }
                        val checkPath = Path().apply {
                            moveTo(x - 4.5f, bubbleY)
                            lineTo(x - 1.5f, bubbleY + 3.5f)
                            lineTo(x + 5f, bubbleY - 3.5f)
                        }
                        canvas.drawPath(checkPath, checkPaint)
                    } else if (isToday) {
                        // Today Incomplete: Amber bordered circle with glowing center
                        bubblePaint.style = Paint.Style.FILL
                        bubblePaint.color = if (isGold) Color.parseColor("#FFE082") else Color.parseColor("#20F59E0B")
                        canvas.drawCircle(x, bubbleY, bubbleR, bubblePaint)

                        bubblePaint.style = Paint.Style.STROKE
                        bubblePaint.strokeWidth = 2f
                        bubblePaint.color = Color.parseColor("#F59E0B")
                        canvas.drawCircle(x, bubbleY, bubbleR, bubblePaint)

                        bubblePaint.style = Paint.Style.FILL
                        canvas.drawCircle(x, bubbleY, 4f, bubblePaint)
                    } else {
                        // Incomplete / Future Day: Outline ring
                        bubblePaint.style = Paint.Style.STROKE
                        bubblePaint.strokeWidth = 1.5f
                        bubblePaint.color = if (isGold) Color.parseColor("#BCAAA4") else Color.parseColor("#4094A3B8")
                        canvas.drawCircle(x, bubbleY, bubbleR, bubblePaint)
                    }
                }

                bitmap
            } catch (_: Exception) {
                null
            }
        }
    }
}
