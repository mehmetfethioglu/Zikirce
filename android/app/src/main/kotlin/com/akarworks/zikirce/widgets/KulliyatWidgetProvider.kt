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
import android.text.TextPaint
import android.text.TextUtils
import android.widget.RemoteViews
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class KulliyatWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, KulliyatWidgetProvider::class.java)
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
                    val views = RemoteViews(context.packageName, R.layout.widget_kulliyat)
                    val data = WidgetDataHelper.fetchKulliyatData(context)

                    val lightBitmap = drawKulliyatWidgetBitmap(data, isDark = false)
                    val darkBitmap = drawKulliyatWidgetBitmap(data, isDark = true)

                    if (lightBitmap != null && darkBitmap != null) {
                        views.setImageViewBitmap(R.id.widget_image_light, lightBitmap)
                        views.setImageViewBitmap(R.id.widget_image_dark, darkBitmap)
                    }

                    val openIntent = Intent(context, MainActivity::class.java).apply {
                        action = "es.antonborri.home_widget.action.LAUNCH"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        this.data = Uri.parse("zikirce://kulliyat?bookId=${data.lastBookId}&page=${data.lastBookPage}")
                        putExtra("route", "/kulliyat")
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getActivity(context, 114, openIntent, flags)
                    views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {}
            }
        }

        private fun ellipsize(text: String, paint: TextPaint, maxWidth: Float): String {
            return TextUtils.ellipsize(text, paint, maxWidth, TextUtils.TruncateAt.END).toString()
        }

        private fun drawKulliyatWidgetBitmap(data: WidgetKulliyatData, isDark: Boolean): Bitmap? {
            return try {
                val width = 680
                val height = 320
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)

                val cardRect = RectF(4f, 4f, width - 4f, height - 4f)
                val cornerRadius = 42f

                // 1. Card Background (Klasik Tahrir Parşömen Light / Zümrüt-Gece Dark)
                val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    shader = if (isDark) {
                        LinearGradient(
                            cardRect.left, cardRect.top, cardRect.right, cardRect.bottom,
                            Color.parseColor("#121815"), Color.parseColor("#0B110E"),
                            Shader.TileMode.CLAMP
                        )
                    } else {
                        LinearGradient(
                            cardRect.left, cardRect.top, cardRect.right, cardRect.bottom,
                            Color.parseColor("#FFFDF8"), Color.parseColor("#F6EFE0"),
                            Shader.TileMode.CLAMP
                        )
                    }
                }
                canvas.drawRoundRect(cardRect, cornerRadius, cornerRadius, bgPaint)

                // 2. Classic Gold / Subtle Card Border
                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2.5f
                    color = if (isDark) Color.parseColor("#42D4AF37") else Color.parseColor("#38B8860B")
                }
                canvas.drawRoundRect(cardRect, cornerRadius, cornerRadius, borderPaint)

                // =========================================================================
                // 3. LEFT SECTION: TAHRİR KLASİK DİKEY SIRT RAFI (5 Books + Walnut Shelf)
                // =========================================================================
                val shelfLeft = 26f
                val shelfRight = 282f
                val shelfTop = 258f
                val shelfBottom = 278f

                // Left & Right Brass Bookends (#E6C76E .. #7D5A16)
                val bookendPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    shader = LinearGradient(
                        0f, 152f, 0f, shelfTop,
                        Color.parseColor("#E6C76E"), Color.parseColor("#7D5A16"),
                        Shader.TileMode.CLAMP
                    )
                }
                canvas.drawRoundRect(RectF(shelfLeft + 4f, 156f, shelfLeft + 11f, shelfTop), 4f, 4f, bookendPaint)
                canvas.drawRoundRect(RectF(shelfRight - 11f, 156f, shelfRight - 4f, shelfTop), 4f, 4f, bookendPaint)

                // Draw up to 5 Book Spines side-by-side
                val booksToDraw = data.shelfBooks.take(5)
                val spineAreaLeft = shelfLeft + 13f
                val spineAreaRight = shelfRight - 13f
                val gap = 4.5f
                val totalSpines = 5
                val spineWidth = (spineAreaRight - spineAreaLeft - gap * (totalSpines - 1)) / totalSpines

                for (i in 0 until booksToDraw.size) {
                    val book = booksToDraw[i]
                    val isActiveBook = book.id == data.lastBookId
                    val colors = WidgetDataHelper.getBookPaletteColors(book.paletteIndex)
                    val primaryLeather = colors[0]
                    val secondaryLeather = colors[1]
                    val goldAccent = colors[2]

                    val sLeft = spineAreaLeft + i * (spineWidth + gap)
                    val sRight = sLeft + spineWidth
                    // Slight natural height variation; active book stands slightly prouder
                    val heightOffset = when {
                        isActiveBook -> 0f
                        i % 2 == 1 -> 10f
                        else -> 5f
                    }
                    val sTop = 40f + heightOffset
                    val sBottom = shelfTop

                    val spineRect = RectF(sLeft, sTop, sRight, sBottom)

                    // Spine Leather Gradient
                    val spinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.FILL
                        shader = LinearGradient(
                            sLeft, sTop, sRight, sBottom,
                            primaryLeather, secondaryLeather,
                            Shader.TileMode.CLAMP
                        )
                    }
                    canvas.drawRoundRect(spineRect, 6f, 6f, spinePaint)

                    // Spine Border (Brighter gold if active book)
                    val spineBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        strokeWidth = if (isActiveBook) 2.2f else 1.1f
                        color = if (isActiveBook) goldAccent else Color.argb(115, Color.red(goldAccent), Color.green(goldAccent), Color.blue(goldAccent))
                    }
                    canvas.drawRoundRect(spineRect, 6f, 6f, spineBorderPaint)

                    // Top & Bottom Gold Şiraze (Headband) Lines
                    val headbandPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        strokeWidth = 1.6f
                        color = Color.argb(190, Color.red(goldAccent), Color.green(goldAccent), Color.blue(goldAccent))
                    }
                    canvas.drawLine(sLeft + 4f, sTop + 11f, sRight - 4f, sTop + 11f, headbandPaint)
                    canvas.drawLine(sLeft + 4f, sTop + 16f, sRight - 4f, sTop + 16f, headbandPaint)
                    canvas.drawLine(sLeft + 4f, sBottom - 46f, sRight - 4f, sBottom - 46f, headbandPaint)

                    // Vertical Rotated Book Short Title
                    val maxTitleLen = (sBottom - 54f) - (sTop + 24f)
                    val spineTitlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = Color.parseColor("#FDF8EE")
                        textSize = 13.5f
                        isFakeBoldText = true
                        textAlign = Paint.Align.CENTER
                        typeface = Typeface.create("serif", Typeface.BOLD)
                    }
                    val clippedSpineTitle = ellipsize(book.title, spineTitlePaint, maxTitleLen)
                    val centerX = (sLeft + sRight) / 2f
                    val centerY = (sTop + 22f + sBottom - 50f) / 2f

                    canvas.save()
                    canvas.rotate(-90f, centerX, centerY)
                    canvas.drawText(clippedSpineTitle, centerX, centerY + 4.5f, spineTitlePaint)
                    canvas.restore()

                    // Bottom Dark Band with %XX + Mini Gold Progress Bar
                    val bandTop = sBottom - 40f
                    val bandRect = RectF(sLeft + 2.5f, bandTop, sRight - 2.5f, sBottom - 3f)
                    val bandPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.FILL
                        color = Color.parseColor("#88000000")
                    }
                    canvas.drawRoundRect(bandRect, 4f, 4f, bandPaint)

                    val pctTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = if (book.progressPercent > 0) goldAccent else Color.parseColor("#B0FDF8EE")
                        textSize = 11.5f
                        isFakeBoldText = true
                        textAlign = Paint.Align.CENTER
                        typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
                    }
                    canvas.drawText("%${book.progressPercent}", centerX, bandTop + 17f, pctTextPaint)

                    // Mini Progress Bar inside spine bottom
                    val miniBarLeft = sLeft + 6f
                    val miniBarRight = sRight - 6f
                    val miniBarTop = sBottom - 12f
                    val miniBarBottom = sBottom - 7.5f
                    val miniTrackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.FILL
                        color = Color.parseColor("#40FFFFFF")
                    }
                    canvas.drawRoundRect(RectF(miniBarLeft, miniBarTop, miniBarRight, miniBarBottom), 2.5f, 2.5f, miniTrackPaint)

                    if (book.progressPercent > 0) {
                        val fillRatio = (book.progressPercent / 100f).coerceIn(0.08f, 1f)
                        val fillRight = miniBarLeft + (miniBarRight - miniBarLeft) * fillRatio
                        val miniFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            style = Paint.Style.FILL
                            color = goldAccent
                        }
                        canvas.drawRoundRect(RectF(miniBarLeft, miniBarTop, fillRight, miniBarBottom), 2.5f, 2.5f, miniFillPaint)
                    }
                }

                // 3D Walnut Wood Shelf Plank (#8C5D38 .. #4A2C15 + Top Gold Strip)
                val shelfRect = RectF(shelfLeft, shelfTop, shelfRight, shelfBottom)
                val woodPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    shader = LinearGradient(
                        shelfLeft, shelfTop, shelfLeft, shelfBottom,
                        Color.parseColor("#8C5D38"), Color.parseColor("#4A2C15"),
                        Shader.TileMode.CLAMP
                    )
                }
                canvas.drawRoundRect(shelfRect, 7f, 7f, woodPaint)

                // Top Gold Inlay Strip on the Shelf Plank
                val shelfGoldPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    shader = LinearGradient(
                        shelfLeft, shelfTop, shelfRight, shelfTop + 3.5f,
                        Color.parseColor("#B8860B"), Color.parseColor("#F3E5AB"),
                        Shader.TileMode.MIRROR
                    )
                }
                canvas.drawRoundRect(RectF(shelfLeft + 2f, shelfTop + 1f, shelfRight - 2f, shelfTop + 4f), 2f, 2f, shelfGoldPaint)

                // =========================================================================
                // 4. VERTICAL DIVIDER
                // =========================================================================
                val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 1.8f
                    color = if (isDark) Color.parseColor("#22D4AF37") else Color.parseColor("#228C5828")
                }
                canvas.drawLine(300f, 36f, 300f, 284f, divPaint)

                // =========================================================================
                // 5. RIGHT SECTION: SON OKUNAN ESER & OKUMAYA DEVAM ET
                // =========================================================================
                val rightStartX = 320f
                val rightEndX = 652f
                val maxRightWidth = rightEndX - rightStartX

                // Top Header: "📚 KÜLLİYAT • SON OKUNAN"
                val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDark) Color.parseColor("#D4AF37") else Color.parseColor("#8C5828")
                    textSize = 16.5f
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    letterSpacing = 0.05f
                }
                canvas.drawText("📚 KÜLLİYAT • SON OKUNAN", rightStartX, 58f, headerPaint)

                // Top-Right Badge: "${data.startedCount}/${data.totalBooksCount} Eser"
                val badgeText = "${data.startedCount}/${data.totalBooksCount} Eser"
                val badgeTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDark) Color.parseColor("#E6C675") else Color.parseColor("#6B421B")
                    textSize = 14.5f
                    isFakeBoldText = true
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                }
                val badgeWidth = badgeTextPaint.measureText(badgeText) + 24f
                val badgeRect = RectF(rightEndX - badgeWidth, 36f, rightEndX, 66f)
                val badgeBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = if (isDark) Color.parseColor("#24D4AF37") else Color.parseColor("#1E8C5828")
                }
                canvas.drawRoundRect(badgeRect, 15f, 15f, badgeBgPaint)
                canvas.drawText(badgeText, badgeRect.centerX(), 56f, badgeTextPaint)

                // Active Book Title
                val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDark) Color.parseColor("#FDF8EE") else Color.parseColor("#1E1610")
                    textSize = 30f
                    isFakeBoldText = true
                    typeface = Typeface.create("serif", Typeface.BOLD)
                }
                val safeTitle = ellipsize(data.lastBookTitle, titlePaint, maxRightWidth)
                canvas.drawText(safeTitle, rightStartX, 104f, titlePaint)

                // Author & Category Subtitle
                val authorPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDark) Color.parseColor("#A3B1AA") else Color.parseColor("#6E5A49")
                    textSize = 17.5f
                    typeface = Typeface.create("sans-serif", Typeface.NORMAL)
                }
                val authorLine = if (data.lastBookAuthor.isNotEmpty()) {
                    "${data.lastBookCategory} • ${data.lastBookAuthor}"
                } else {
                    data.lastBookCategory
                }
                val safeAuthor = ellipsize(authorLine, authorPaint, maxRightWidth)
                canvas.drawText(safeAuthor, rightStartX, 134f, authorPaint)

                // Page / Ayet Reference & Progress Percentage Row
                val refPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDark) Color.parseColor("#E2E8F0") else Color.parseColor("#33261B")
                    textSize = 18.5f
                    isFakeBoldText = true
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                }
                canvas.drawText(data.lastBookReference, rightStartX, 174f, refPaint)

                val pctBigPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDark) Color.parseColor("#D4AF37") else Color.parseColor("#0F5132")
                    textSize = 20f
                    isFakeBoldText = true
                    textAlign = Paint.Align.RIGHT
                    typeface = Typeface.create("sans-serif", Typeface.BOLD)
                }
                canvas.drawText("%${data.lastBookPercent}", rightEndX, 174f, pctBigPaint)

                // Rounded Gold / Emerald Reading Progress Bar
                val barRect = RectF(rightStartX, 190f, rightEndX, 206f)
                val barTrackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = if (isDark) Color.parseColor("#24FFFFFF") else Color.parseColor("#1E8C5828")
                }
                canvas.drawRoundRect(barRect, 8f, 8f, barTrackPaint)

                val activeRatio = (data.lastBookPercent / 100f).coerceIn(0.04f, 1f)
                val fillWidth = (rightEndX - rightStartX) * activeRatio
                val barFillRect = RectF(rightStartX, 190f, rightStartX + fillWidth, 206f)
                val barFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    shader = LinearGradient(
                        barFillRect.left, barFillRect.top, barFillRect.right, barFillRect.bottom,
                        if (isDark) Color.parseColor("#10B981") else Color.parseColor("#123F30"),
                        Color.parseColor("#D4AF37"),
                        Shader.TileMode.CLAMP
                    )
                }
                canvas.drawRoundRect(barFillRect, 8f, 8f, barFillPaint)

                // Bottom Action Capsule ("OKUMAYA DEVAM ET ›" or with Bookmarks badge)
                val pillRect = RectF(rightStartX, 226f, rightEndX, 280f)
                val activePalette = WidgetDataHelper.getBookPaletteColors(data.lastBookPaletteIndex)
                val pillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    shader = LinearGradient(
                        pillRect.left, pillRect.top, pillRect.right, pillRect.bottom,
                        activePalette[0],
                        activePalette[1],
                        Shader.TileMode.CLAMP
                    )
                }
                canvas.drawRoundRect(pillRect, 27f, 27f, pillPaint)

                val pillBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 1.6f
                    color = activePalette[2]
                }
                canvas.drawRoundRect(pillRect, 27f, 27f, pillBorderPaint)

                val pillTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#FDF8EE")
                    textSize = 18.5f
                    isFakeBoldText = true
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    letterSpacing = 0.04f
                }
                val actionLabel = if (data.bookmarksCount > 0) {
                    "🔖 ${data.bookmarksCount} Ayraç • Okumaya Devam Et ›"
                } else {
                    "OKUMAYA DEVAM ET ›"
                }
                canvas.drawText(actionLabel, pillRect.centerX(), 260f, pillTextPaint)

                bitmap
            } catch (_: Exception) {
                null
            }
        }
    }
}
