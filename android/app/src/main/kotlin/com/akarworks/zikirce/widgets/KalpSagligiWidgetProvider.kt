package com.akarworks.zikirce.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.widget.RemoteViews
import com.akarworks.zikirce.MainActivity
import com.akarworks.zikirce.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.math.max

class KalpSagligiWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if (context == null || intent == null) return

        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_CONFIGURATION_CHANGED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, KalpSagligiWidgetProvider::class.java)
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
        fun updateWidgetSync(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val views = RemoteViews(context.packageName, R.layout.widget_kalp_sagligi)
                    val stats = WidgetDataHelper.fetchStatsFromDb(context)

                    views.setTextViewText(R.id.widget_today_count, stats.todayZikirCount.toString())

                    val graphBitmap = drawKalpSagligiGraphOnly(stats.todayZikirCount, stats.weeklyDhikrCounts)
                    if (graphBitmap != null) {
                        views.setImageViewBitmap(R.id.widget_graph_image, graphBitmap)
                    }

                    val openIntent = Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getActivity(context, 107, openIntent, flags)
                    views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {}
            }
        }

        private fun drawKalpSagligiGraphOnly(todayCount: Int, weeklyData: List<Int>): Bitmap? {
            return try {
                val size = 400
                val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)

                var maxVal = weeklyData.maxOrNull() ?: 1
                if (todayCount > maxVal) maxVal = todayCount
                if (maxVal < 10) maxVal = 10

                val dataPoints = weeklyData.toMutableList()
                if (dataPoints.size > 6) {
                    dataPoints[6] = todayCount
                }

                val graphLeft = 24f
                val graphRight = 376f
                val graphTop = 150f
                val graphBottom = 265f
                val graphHeight = graphBottom - graphTop

                val points = mutableListOf<PointF>()
                val stepX = (graphRight - graphLeft) / 6f

                for (i in 0 until 7) {
                    val count = if (i < dataPoints.size) dataPoints[i] else 0
                    val normalized = (count.toFloat() / maxVal.toFloat()).coerceIn(0.08f, 1f)
                    val x = graphLeft + i * stepX
                    val y = graphBottom - (normalized * graphHeight)
                    points.add(PointF(x, y))
                }

                // Bezier Curve
                val path = Path()
                val fillPath = Path()

                path.moveTo(points[0].x, points[0].y)
                fillPath.moveTo(points[0].x, graphBottom + 30f)
                fillPath.lineTo(points[0].x, points[0].y)

                for (i in 0 until points.size - 1) {
                    val p0 = points[i]
                    val p1 = points[i + 1]
                    val midX = (p0.x + p1.x) / 2f
                    path.cubicTo(midX, p0.y, midX, p1.y, p1.x, p1.y)
                    fillPath.cubicTo(midX, p0.y, midX, p1.y, p1.x, p1.y)
                }

                fillPath.lineTo(points.last().x, graphBottom + 30f)
                fillPath.close()

                // Gradient Fill Under Curve
                val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    shader = LinearGradient(
                        0f, graphTop, 0f, graphBottom + 30f,
                        Color.parseColor("#4DEB5757"),
                        Color.TRANSPARENT,
                        Shader.TileMode.CLAMP
                    )
                }
                canvas.drawPath(fillPath, fillPaint)

                // Line Stroke
                val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 7f
                    strokeCap = Paint.Cap.ROUND
                    strokeJoin = Paint.Join.ROUND
                    color = Color.parseColor("#EB5757")
                }
                canvas.drawPath(path, linePaint)

                // Peak Indicator on Today
                val todayPoint = points.last()
                val pulsePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#33EB5757")
                    style = Paint.Style.FILL
                }
                canvas.drawCircle(todayPoint.x, todayPoint.y, 14f, pulsePaint)

                val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#EB5757")
                    style = Paint.Style.FILL
                }
                canvas.drawCircle(todayPoint.x, todayPoint.y, 6f, dotPaint)

                bitmap
            } catch (_: Exception) {
                null
            }
        }
    }
}
