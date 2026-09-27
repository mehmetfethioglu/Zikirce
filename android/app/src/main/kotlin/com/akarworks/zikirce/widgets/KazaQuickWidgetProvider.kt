package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import android.widget.Toast
import com.akarworks.zikirce.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.math.*

class KazaQuickWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == ACTION_DECREMENT_KAZA_QUICK) {
            val prayerName = intent.getStringExtra("PrayerName")
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val kazaCounts = WidgetDataHelper.getKazaCountsFromDb(context)
                    val targetPrayer = prayerName ?: findHighestDebtPrayer(kazaCounts).first
                    val currentCount = kazaCounts[targetPrayer] ?: 0

                    if (currentCount > 0) {
                        WidgetDataHelper.decrementKazaInDb(context, targetPrayer)
                        Handler(Looper.getMainLooper()).post {
                            Toast.makeText(context, "$targetPrayer kazası -1 düşüldü! 🎉", Toast.LENGTH_SHORT).show()
                        }
                    } else {
                        Handler(Looper.getMainLooper()).post {
                            Toast.makeText(context, "Kaza borcunuz bulunmuyor.", Toast.LENGTH_SHORT).show()
                        }
                    }

                    val appWidgetManager = AppWidgetManager.getInstance(context) ?: return@launch
                    val component = ComponentName(context, KazaQuickWidgetProvider::class.java)
                    val ids = appWidgetManager.getAppWidgetIds(component)
                    if (ids != null && ids.isNotEmpty()) {
                        for (id in ids) {
                            updateWidget(context, appWidgetManager, id)
                        }
                    }

                    // Also update main Kaza widget if present
                    val mainKazaComponent = ComponentName(context, PrayerKazaWidgetProvider::class.java)
                    val mainKazaIds = appWidgetManager.getAppWidgetIds(mainKazaComponent)
                    if (mainKazaIds != null && mainKazaIds.isNotEmpty()) {
                        for (id in mainKazaIds) {
                            PrayerKazaWidgetProvider.updateWidgetSync(context, appWidgetManager, id)
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
            val component = ComponentName(context, KazaQuickWidgetProvider::class.java)
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
        const val ACTION_DECREMENT_KAZA_QUICK = "Zikirce.ACTION_DECREMENT_KAZA_QUICK"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val views = RemoteViews(context.packageName, R.layout.widget_kaza_quick)
                    val kazaCounts = WidgetDataHelper.getKazaCountsFromDb(context)
                    val (highestPrayer, count) = findHighestDebtPrayer(kazaCounts)
                    val hasCompletedToday = WidgetDataHelper.hasKazaCompletedToday(context)

                    val lightBitmap = draw2x1KazaBitmap(highestPrayer, count, hasCompletedToday, isDark = false)
                    val darkBitmap = draw2x1KazaBitmap(highestPrayer, count, hasCompletedToday, isDark = true)

                    if (lightBitmap != null && darkBitmap != null) {
                        views.setImageViewBitmap(R.id.widget_image_light, lightBitmap)
                        views.setImageViewBitmap(R.id.widget_image_dark, darkBitmap)
                    }

                    // Decrement PendingIntent on tap
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }

                    val decIntent = Intent(context, KazaQuickWidgetProvider::class.java).apply {
                        action = ACTION_DECREMENT_KAZA_QUICK
                        putExtra("PrayerName", highestPrayer)
                        putExtra("WidgetId", appWidgetId)
                    }
                    val pendingDec = PendingIntent.getBroadcast(context, 300 + appWidgetId, decIntent, flags)
                    views.setOnClickPendingIntent(R.id.widget_root_layout, pendingDec)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {}
            }
        }

        private fun findHighestDebtPrayer(kazaCounts: Map<String, Int>): Pair<String, Int> {
            val order = listOf("Sabah", "Öğle", "İkindi", "Akşam", "Yatsı")
            var maxPrayer = "Sabah"
            var maxVal = -1

            for (p in order) {
                val c = kazaCounts[p] ?: 0
                if (c > maxVal) {
                    maxVal = c
                    maxPrayer = p
                }
            }

            return Pair(maxPrayer, max(0, maxVal))
        }

        private fun drawTashahhudSilhouette(canvas: Canvas, offsetX: Float, offsetY: Float, scale: Float, paint: Paint) {
            val saveCount = canvas.save()
            canvas.translate(offsetX, offsetY)
            canvas.scale(scale, scale)

            // Head in reverent prayer posture
            canvas.drawCircle(68f, 32f, 15f, paint)

            // Torso, folded arms and legs in tashahhud
            val path = Path().apply {
                moveTo(58f, 45f)
                cubicTo(42f, 60f, 36f, 92f, 40f, 125f)
                quadTo(42f, 142f, 60f, 142f)
                lineTo(112f, 142f)
                quadTo(126f, 142f, 122f, 126f)
                lineTo(114f, 110f)
                quadTo(106f, 98f, 94f, 98f)
                lineTo(82f, 75f)
                quadTo(76f, 58f, 72f, 45f)
                close()
            }
            canvas.drawPath(path, paint)

            // Ground accent line
            val basePaint = Paint(paint).apply {
                style = Paint.Style.STROKE
                strokeWidth = 2.5f / scale
                strokeCap = Paint.Cap.ROUND
                alpha = (paint.alpha * 0.4f).toInt()
            }
            canvas.drawLine(28f, 145f, 134f, 145f, basePaint)

            canvas.restoreToCount(saveCount)
        }

        private fun draw2x1KazaBitmap(
            prayerName: String,
            count: Int,
            hasCompletedToday: Boolean,
            isDark: Boolean
        ): Bitmap? {
            return try {
                val width = 600
                val height = 300
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)

                val cardRect = RectF(4f, 4f, width - 4f, height - 4f)
                val cornerRadius = 42f

                // 1. Background Card (Green Day vs Default)
                val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    if (hasCompletedToday) {
                        shader = if (isDark) {
                            LinearGradient(
                                cardRect.left, cardRect.top, cardRect.right, cardRect.bottom,
                                Color.parseColor("#064E3B"), Color.parseColor("#022C22"),
                                Shader.TileMode.CLAMP
                            )
                        } else {
                            LinearGradient(
                                cardRect.left, cardRect.top, cardRect.right, cardRect.bottom,
                                Color.parseColor("#F0FDF4"), Color.parseColor("#DCFCE7"),
                                Shader.TileMode.CLAMP
                            )
                        }
                    } else {
                        color = if (isDark) Color.parseColor("#14100C") else Color.parseColor("#FFFDF9")
                    }
                }
                canvas.drawRoundRect(cardRect, cornerRadius, cornerRadius, bgPaint)

                // 2. Card Border
                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2.5f
                    color = if (hasCompletedToday) {
                        if (isDark) Color.parseColor("#10B981") else Color.parseColor("#059669")
                    } else {
                        if (isDark) Color.parseColor("#24FFFFFF") else Color.parseColor("#14000000")
                    }
                }
                canvas.drawRoundRect(cardRect, cornerRadius, cornerRadius, borderPaint)

                // 3. Left Section: Tashahhud Silhouette
                val silPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = if (hasCompletedToday) {
                        if (isDark) Color.parseColor("#A7F3D0") else Color.parseColor("#047857")
                    } else {
                        if (isDark) Color.parseColor("#D4D4D8") else Color.parseColor("#334155")
                    }
                }
                drawTashahhudSilhouette(canvas, offsetX = 30f, offsetY = 50f, scale = 1.34f, paint = silPaint)

                // 4. Subtle Vertical Divider
                val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2f
                    color = if (hasCompletedToday) {
                        if (isDark) Color.parseColor("#3010B981") else Color.parseColor("#30059669")
                    } else {
                        if (isDark) Color.parseColor("#18FFFFFF") else Color.parseColor("#12000000")
                    }
                }
                canvas.drawLine(232f, 44f, 232f, 256f, divPaint)

                // 5. Right Section: Prayer Name, Debt Count & Action Pill
                val rightStartX = 256f
                val rightEndX = 556f

                // Header Tag
                val tagPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (hasCompletedToday) {
                        if (isDark) Color.parseColor("#A7F3D0") else Color.parseColor("#047857")
                    } else {
                        if (isDark) Color.parseColor("#FBBF24") else Color.parseColor("#B45309")
                    }
                    textSize = 19f
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    letterSpacing = 0.08f
                }
                canvas.drawText("EN ÇOK BORÇLU VAKİT", rightStartX, 68f, tagPaint)

                // Prayer Name (e.g. "SABAH KAZASI")
                val prayerTitle = "${prayerName.uppercase(Locale.forLanguageTag("tr-TR"))} KAZASI"
                val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (hasCompletedToday) {
                        if (isDark) Color.parseColor("#FFFFFF") else Color.parseColor("#064E3B")
                    } else {
                        if (isDark) Color.parseColor("#FFFFFF") else Color.parseColor("#0F172A")
                    }
                    textSize = 34f
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                }
                canvas.drawText(prayerTitle, rightStartX, 116f, namePaint)

                // Debt Count (e.g. "24 VAKİT")
                val countPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (hasCompletedToday) {
                        if (isDark) Color.parseColor("#34D399") else Color.parseColor("#059669")
                    } else {
                        if (isDark) Color.parseColor("#F59E0B") else Color.parseColor("#D97706")
                    }
                    textSize = 54f
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                }
                val countText = if (count > 0) "$count VAKİT" else "0 BORÇ ✨"
                canvas.drawText(countText, rightStartX, 178f, countPaint)

                // Action Pill Button (Bottom)
                val pillRect = RectF(rightStartX, 202f, rightEndX, 256f)
                val pillRadius = 27f

                val btnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = if (hasCompletedToday) {
                        if (isDark) Color.parseColor("#065F46") else Color.parseColor("#059669")
                    } else {
                        if (count > 0) {
                            if (isDark) Color.parseColor("#D97706") else Color.parseColor("#F59E0B")
                        } else {
                            if (isDark) Color.parseColor("#065F46") else Color.parseColor("#059669")
                        }
                    }
                }
                canvas.drawRoundRect(pillRect, pillRadius, pillRadius, btnPaint)

                val btnTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.WHITE
                    textSize = 20f
                    isFakeBoldText = true
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                    letterSpacing = 0.05f
                }

                val actionLabel = if (hasCompletedToday) {
                    "Bugün Kılındı ✓  (-1 Düş)"
                } else if (count > 0) {
                    "Tek Dokunuşla -1 Düş 👆"
                } else {
                    "Kaza Borcunuz Yok ✨"
                }
                canvas.drawText(actionLabel, (rightStartX + rightEndX) / 2f, 237f, btnTextPaint)

                bitmap
            } catch (_: Exception) {
                null
            }
        }
    }
}
