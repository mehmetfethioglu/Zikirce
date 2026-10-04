package com.akarworks.zikirce.widgets

import android.content.Context
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.graphics.*
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.*

data class WidgetPrayerTimes(
    val imsak: String = "04:12",
    val gunes: String = "05:48",
    val ogle: String = "13:08",
    val ikindi: String = "16:54",
    val aksam: String = "20:18",
    val yatsi: String = "21:46",
    val hijriDay: String = "",
    val hijriMonth: String = "",
    val hijriYear: String = ""
)

data class NextPrayerResult(
    val name: String,
    val timeStr: String,
    val timeMillis: Long,
    val remainingMs: Long,
    val progressPercent: Int
)

data class WidgetStatsData(
    var todayZikirCount: Int = 0,
    var zikirDailyGoal: Int = 100,
    var streakCount: Int = 0,
    var isCompletedToday: Boolean = false,
    var isGoldCompletedToday: Boolean = false,
    var weeklyDhikrCounts: List<Int> = listOf(0, 0, 0, 0, 0, 0, 0),
    var activeDatesInWeek: Set<String> = emptySet()
)

object WidgetDataHelper {

    private val hijriMonthNamesTr = arrayOf(
        "Muharrem", "Safer", "Rebiülevvel", "Rebiülahir",
        "Cemaziyelevvel", "Cemaziyelahir", "Recep", "Şaban",
        "Ramazan", "Şevval", "Zilkade", "Zilhicce"
    )

    fun calculateHijri(cal: Calendar = Calendar.getInstance()): Triple<String, String, String> {
        val year = cal.get(Calendar.YEAR)
        val month = cal.get(Calendar.MONTH) + 1
        val day = cal.get(Calendar.DAY_OF_MONTH)

        var y = year
        var m = month
        if (m < 3) {
            y -= 1
            m += 12
        }
        val a = floor(y / 100.0)
        val b = 2.0 - a + floor(a / 4.0)
        var jd = floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5

        jd = floor(jd) + 0.5
        var l = jd - 1948440.0 + 10632.0
        val n = floor((l - 1.0) / 10631.0)
        l = l - 10631.0 * n + 354.0
        val j = floor((10985.0 - l) / 5316.0) * floor((50.0 * l) / 17719.0) +
                floor(l / 5670.0) * floor((43.0 * l) / 15238.0)
        l = l - floor((30.0 - j) / 15.0) * floor((17719.0 * j) / 50.0) -
                floor(j / 16.0) * floor((15238.0 * j) / 43.0) + 29.0
        val hMonth = floor((24.0 * l) / 709.0).toInt().coerceIn(1, 12)
        val hDay = (l - floor((709.0 * hMonth) / 24.0)).toInt().coerceIn(1, 30)
        val hYear = (30 * n + j - 30).toInt()

        val monthName = hijriMonthNamesTr[hMonth - 1]
        return Triple(hDay.toString(), monthName, hYear.toString())
    }

    fun translateHijriMonth(raw: String): String {
        val lower = raw.lowercase(Locale.ROOT).trim()
        if (lower.contains("muharram") || lower.contains("muharrem")) return "Muharrem"
        if (lower.contains("safar") || lower.contains("safer")) return "Safer"
        if (lower.contains("rabi") && (lower.contains("awwal") || lower.contains("evvel") || lower.contains("1") || (lower.contains("i") && !lower.contains("ii")))) {
            return "Rebiülevvel"
        }
        if (lower.contains("rabi") && (lower.contains("thani") || lower.contains("ahir") || lower.contains("sani") || lower.contains("2") || lower.contains("ii"))) {
            return "Rebiülahir"
        }
        if (lower.contains("jumada") || lower.contains("cemazi")) {
            if (lower.contains("awwal") || lower.contains("evvel") || lower.contains("ula") || lower.contains("1") || (lower.contains("i") && !lower.contains("ii"))) {
                return "Cemaziyelevvel"
            }
            return "Cemaziyelahir"
        }
        if (lower.contains("rajab") || lower.contains("recep")) return "Recep"
        if (lower.contains("sha'ban") || lower.contains("shaban") || lower.contains("saban") || lower.contains("şaban") || lower.contains("sha’ban") || lower.contains("shaaban")) return "Şaban"
        if (lower.contains("ramad") || lower.contains("ramazan")) return "Ramazan"
        if (lower.contains("shawwal") || lower.contains("sevval") || lower.contains("şevval")) return "Şevval"
        if (lower.contains("qad") || lower.contains("kade") || lower.contains("qi'dah") || lower.contains("qidah") || lower.contains("zilkade")) return "Zilkade"
        if (lower.contains("hij") || lower.contains("hicce") || lower.contains("hijjah") || lower.contains("zilhicce")) return "Zilhicce"
        return raw
    }

    fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    }

    fun getStringPref(context: Context, key: String, defaultValue: String): String {
        // Try HomeWidgetPreferences first
        val hwPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        if (hwPrefs.contains(key)) {
            val v = hwPrefs.getString(key, null)
            if (v != null) return v
        }

        // Try FlutterSharedPreferences (stored with flutter. prefix)
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (flutterPrefs.contains("flutter.$key")) {
            val v = flutterPrefs.getString("flutter.$key", null)
            if (v != null) return v
        }
        if (flutterPrefs.contains(key)) {
            val v = flutterPrefs.getString(key, null)
            if (v != null) return v
        }

        // Try default shared prefs
        val defPrefs = android.preference.PreferenceManager.getDefaultSharedPreferences(context)
        if (defPrefs.contains(key)) {
            val v = defPrefs.getString(key, null)
            if (v != null) return v
        }

        return defaultValue
    }

    fun saveStringPref(context: Context, key: String, value: String) {
        val hwPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        hwPrefs.edit().putString(key, value).apply()

        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().putString("flutter.$key", value).putString(key, value).apply()
    }

    fun getIntPref(context: Context, key: String, defaultValue: Int): Int {
        val hwPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        if (hwPrefs.contains(key)) {
            try { return hwPrefs.getInt(key, defaultValue) } catch (_: Exception) {}
            try { return hwPrefs.getString(key, "")?.toIntOrNull() ?: defaultValue } catch (_: Exception) {}
        }

        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (flutterPrefs.contains("flutter.$key")) {
            try { return flutterPrefs.getInt("flutter.$key", defaultValue) } catch (_: Exception) {}
            try { return (flutterPrefs.getLong("flutter.$key", defaultValue.toLong())).toInt() } catch (_: Exception) {}
            try { return flutterPrefs.getString("flutter.$key", "")?.toIntOrNull() ?: defaultValue } catch (_: Exception) {}
        }
        return defaultValue
    }

    fun getBooleanPref(context: Context, key: String, defaultValue: Boolean): Boolean {
        val hwPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        if (hwPrefs.contains(key)) {
            try { return hwPrefs.getBoolean(key, defaultValue) } catch (_: Exception) {}
        }

        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (flutterPrefs.contains("flutter.$key")) {
            try { return flutterPrefs.getBoolean("flutter.$key", defaultValue) } catch (_: Exception) {}
        }
        return defaultValue
    }

    fun getCachedPrayerTimes(context: Context, city: String): WidgetPrayerTimes {
        val (defDay, defMonth, defYear) = calculateHijri()
        val jsonStr = getStringPref(context, "CachedPrayerTimes_$city", "")
        if (jsonStr.isNotEmpty()) {
            try {
                val obj = JSONObject(jsonStr)
                var rawMonth = obj.optString("HijriMonth", obj.optString("hijriMonth", defMonth))
                if (rawMonth.isEmpty() || rawMonth.equals("null", ignoreCase = true)) {
                    rawMonth = defMonth
                } else {
                    rawMonth = translateHijriMonth(rawMonth)
                }

                var rawDay = obj.optString("HijriDay", obj.optString("hijriDay", defDay))
                if (rawDay.isEmpty() || rawDay.equals("null", ignoreCase = true)) {
                    rawDay = defDay
                }

                var rawYear = obj.optString("HijriYear", obj.optString("hijriYear", defYear))
                if (rawYear.isEmpty() || rawYear.equals("null", ignoreCase = true)) {
                    rawYear = defYear
                }

                return WidgetPrayerTimes(
                    imsak = obj.optString("Imsak", obj.optString("fajr", "04:12")),
                    gunes = obj.optString("Gunes", obj.optString("sunrise", "05:48")),
                    ogle = obj.optString("Ogle", obj.optString("dhuhr", "13:08")),
                    ikindi = obj.optString("Ikindi", obj.optString("asr", "16:54")),
                    aksam = obj.optString("Aksam", obj.optString("maghrib", "20:18")),
                    yatsi = obj.optString("Yatsi", obj.optString("isha", "21:46")),
                    hijriDay = rawDay,
                    hijriMonth = rawMonth,
                    hijriYear = rawYear
                )
            } catch (_: Exception) {}
        }
        return WidgetPrayerTimes(
            hijriDay = defDay,
            hijriMonth = defMonth,
            hijriYear = defYear
        )
    }

    fun parseTimeMinutes(timeStr: String): Int {
        try {
            val clean = timeStr.split(" ")[0].trim()
            val parts = clean.split(":")
            if (parts.size >= 2) {
                val h = parts[0].toInt()
                val m = parts[1].toInt()
                return h * 60 + m
            }
        } catch (_: Exception) {}
        return 0
    }

    fun calculateNextPrayer(times: WidgetPrayerTimes): NextPrayerResult {
        val now = Calendar.getInstance()
        val nowMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val nowSec = now.get(Calendar.SECOND)
        val nowTotalSec = nowMin * 60 + nowSec

        val prayerList = listOf(
            Pair("İmsak", parseTimeMinutes(times.imsak)),
            Pair("Güneş", parseTimeMinutes(times.gunes)),
            Pair("Öğle", parseTimeMinutes(times.ogle)),
            Pair("İkindi", parseTimeMinutes(times.ikindi)),
            Pair("Akşam", parseTimeMinutes(times.aksam)),
            Pair("Yatsı", parseTimeMinutes(times.yatsi))
        )

        var curIdx = prayerList.size - 1
        var nextIdx = 0

        for (i in 0 until prayerList.size) {
            val curTimeSec = prayerList[i].second * 60
            val nxtTimeSec = prayerList[(i + 1) % prayerList.size].second * 60

            if (i == prayerList.size - 1) {
                if (nowTotalSec >= curTimeSec || nowTotalSec < nxtTimeSec) {
                    curIdx = i
                    nextIdx = 0
                    break
                }
            } else {
                if (nowTotalSec >= curTimeSec && nowTotalSec < nxtTimeSec) {
                    curIdx = i
                    nextIdx = i + 1
                    break
                }
            }
        }

        var curPrayer = prayerList[curIdx]
        var nxtPrayer = prayerList[nextIdx]

        // Calculate target timestamp
        val targetCal = Calendar.getInstance()
        var nxtHour = nxtPrayer.second / 60
        var nxtMinute = nxtPrayer.second % 60
        targetCal.set(Calendar.HOUR_OF_DAY, nxtHour)
        targetCal.set(Calendar.MINUTE, nxtMinute)
        targetCal.set(Calendar.SECOND, 0)
        targetCal.set(Calendar.MILLISECOND, 0)

        if (targetCal.timeInMillis <= now.timeInMillis) {
            targetCal.add(Calendar.DAY_OF_YEAR, 1)
        }

        var remainingMs = targetCal.timeInMillis - now.timeInMillis

        // If target is within 500ms or in the past, roll over to the next prayer immediately
        if (remainingMs < 500L) {
            curIdx = nextIdx
            nextIdx = (nextIdx + 1) % prayerList.size
            curPrayer = prayerList[curIdx]
            nxtPrayer = prayerList[nextIdx]

            nxtHour = nxtPrayer.second / 60
            nxtMinute = nxtPrayer.second % 60
            targetCal.set(Calendar.HOUR_OF_DAY, nxtHour)
            targetCal.set(Calendar.MINUTE, nxtMinute)
            targetCal.set(Calendar.SECOND, 0)
            targetCal.set(Calendar.MILLISECOND, 0)

            if (targetCal.timeInMillis <= now.timeInMillis) {
                targetCal.add(Calendar.DAY_OF_YEAR, 1)
            }
            remainingMs = max(0L, targetCal.timeInMillis - now.timeInMillis)
        }

        var startMin = curPrayer.second
        var endMin = nxtPrayer.second
        var curMin = nowMin

        if (nextIdx == 0 && curIdx == prayerList.size - 1) {
            if (curMin < startMin) {
                startMin -= 24 * 60
            } else {
                endMin += 24 * 60
            }
        }

        var totalSec = (endMin - startMin) * 60
        if (totalSec <= 0) totalSec = 1
        var elapsedSec = (curMin - startMin) * 60 + nowSec
        if (elapsedSec < 0) elapsedSec = 0

        val progress = (elapsedSec.toDouble() / totalSec.toDouble()).coerceIn(0.0, 1.0)
        val progressPercent = (progress * 100).toInt()

        val cleanTimeStr = String.format("%02d:%02d", nxtHour, nxtMinute)

        return NextPrayerResult(
            name = nxtPrayer.first,
            timeStr = cleanTimeStr,
            timeMillis = targetCal.timeInMillis,
            remainingMs = max(0L, remainingMs),
            progressPercent = progressPercent
        )
    }

    fun formatRemainingTime(context: Context, remainingMs: Long): String {
        if (remainingMs <= 0L) {
            val lang = getStringPref(context, "AppLanguage", Locale.getDefault().language)
            return if (lang.startsWith("en", ignoreCase = true)) "Adhan Time" else "Vakit Girdi"
        }
        val totalSeconds = remainingMs / 1000
        val totalMinutes = (totalSeconds + 59) / 60
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60

        val lang = getStringPref(context, "AppLanguage", Locale.getDefault().language)
        val isEn = lang.startsWith("en", ignoreCase = true)

        return if (hours > 0) {
            if (minutes > 0) {
                if (isEn) "${hours}h ${minutes}m" else "${hours} sa ${minutes} dk"
            } else {
                if (isEn) "${hours}h" else "${hours} sa"
            }
        } else {
            if (isEn) "${minutes}m" else "${minutes} dk"
        }
    }

    fun getDirectionalPrayerName(context: Context, prayerName: String): String {
        val lang = getStringPref(context, "AppLanguage", Locale.getDefault().language)
        val isEn = lang.startsWith("en", ignoreCase = true)

        if (isEn) {
            return when (prayerName.lowercase()) {
                "imsak", "sabah" -> "TO FAJR"
                "güneş", "gunes" -> "TO SUNRISE"
                "öğle", "ogle" -> "TO DHUHR"
                "ikindi" -> "TO ASR"
                "akşam", "aksam" -> "TO MAGHRIB"
                "yatsı", "yatsi" -> "TO ISHA"
                else -> "TO ${prayerName.uppercase()}"
            }
        }

        return when (prayerName.lowercase()) {
            "imsak", "sabah" -> "İMSAĞA"
            "güneş", "gunes" -> "GÜNEŞE"
            "öğle", "ogle" -> "ÖĞLEYE"
            "ikindi" -> "İKİNDİYE"
            "akşam", "aksam" -> "AKŞAMA"
            "yatsı", "yatsi" -> "YATSIYA"
            else -> prayerName.uppercase(Locale("tr", "TR"))
        }
    }

    fun getCountdownColorHex(prayerName: String, totalMin: Double, elapsedMin: Double): String {
        val Green = "#10B981"
        val Orange = "#F59E0B"
        val Red = "#EF4444"
        val Bordeaux = "#8B0000"

        if (totalMin <= 0) return Green

        return when (prayerName) {
            "İmsak", "Sabah" -> {
                if (elapsedMin >= totalMin - 15) return Bordeaux
                val remainingTotal = totalMin - 15
                if (remainingTotal <= 0) return Bordeaux
                val progress = elapsedMin / remainingTotal
                when {
                    progress < 0.333 -> Green
                    progress < 0.667 -> Orange
                    else -> Red
                }
            }
            "Güneş" -> {
                if (totalMin > 90) {
                    if (elapsedMin < 45 || elapsedMin >= totalMin - 45) return Bordeaux
                    val midProg = (elapsedMin - 45) / (totalMin - 90)
                    when {
                        midProg < 0.30 -> Green
                        midProg < 0.70 -> Orange
                        else -> Red
                    }
                } else {
                    val progress = elapsedMin / totalMin
                    if (progress < 0.15 || progress > 0.85) return Bordeaux
                    val midProg = (progress - 0.15) / 0.70
                    when {
                        midProg < 0.30 -> Green
                        midProg < 0.70 -> Orange
                        else -> Red
                    }
                }
            }
            "Öğle" -> {
                val progress = elapsedMin / totalMin
                when {
                    progress < 0.40 -> Green
                    progress < 0.70 -> Orange
                    progress < 0.90 -> Red
                    else -> Bordeaux
                }
            }
            "İkindi" -> {
                if (totalMin > 45) {
                    if (elapsedMin >= totalMin - 45) return Bordeaux
                    val progress = elapsedMin / (totalMin - 45)
                    when {
                        progress < 0.40 -> Green
                        progress < 0.75 -> Orange
                        else -> Red
                    }
                } else {
                    val progress = elapsedMin / totalMin
                    if (progress >= 0.85) return Bordeaux
                    val firstProg = progress / 0.85
                    when {
                        firstProg < 0.40 -> Green
                        firstProg < 0.75 -> Orange
                        else -> Red
                    }
                }
            }
            "Akşam" -> {
                if (totalMin > 40) {
                    if (elapsedMin >= totalMin - 10) return Bordeaux
                    when {
                        elapsedMin < 30 -> Green
                        elapsedMin < totalMin - 30 -> Orange
                        else -> Red
                    }
                } else {
                    val progress = elapsedMin / totalMin
                    if (progress >= 0.90) return Bordeaux
                    when {
                        progress < 0.30 -> Green
                        progress < 0.75 -> Orange
                        else -> Red
                    }
                }
            }
            "Yatsı" -> {
                if (totalMin > 45) {
                    if (elapsedMin >= totalMin - 45) return Bordeaux
                    val progress = elapsedMin / (totalMin - 45)
                    when {
                        progress < 0.333 -> Green
                        progress < 0.667 -> Orange
                        else -> Red
                    }
                } else {
                    val progress = elapsedMin / totalMin
                    if (progress >= 0.85) return Bordeaux
                    val firstProg = progress / 0.85
                    when {
                        firstProg < 0.333 -> Green
                        firstProg < 0.667 -> Orange
                        else -> Red
                    }
                }
            }
            else -> Green
        }
    }

    fun getDatabase(context: Context, readOnly: Boolean = true): SQLiteDatabase? {
        val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
        val candidates = mutableListOf<File>()

        // 1. Primary Drift Database in app_flutter
        candidates.add(File(appFlutterDir, "zikirce_app.sqlite"))
        candidates.add(File(appFlutterDir, "app_database.sqlite"))

        // 2. Any active session databases in app_flutter
        if (appFlutterDir.exists() && appFlutterDir.isDirectory) {
            val list = appFlutterDir.listFiles { _, name -> name.endsWith(".sqlite") || name.endsWith(".db") }
            if (list != null) {
                for (f in list) {
                    if (!candidates.contains(f)) {
                        candidates.add(f)
                    }
                }
            }
        }

        // 3. Fallback to filesDir
        candidates.add(File(context.filesDir, "zikirce_app.sqlite"))
        candidates.add(File(context.filesDir, "app_database.sqlite"))
        candidates.add(File(context.filesDir, "zikir.db"))

        for (f in candidates) {
            if (f.exists() && f.length() > 0) {
                try {
                    val flags = if (readOnly) {
                        SQLiteDatabase.OPEN_READONLY
                    } else {
                        SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING
                    }
                    val db = SQLiteDatabase.openDatabase(f.absolutePath, null, flags)
                    if (!readOnly) {
                        try { db.enableWriteAheadLogging() } catch (_: Exception) {}
                    }
                    return db
                } catch (_: Exception) {
                    try {
                        return SQLiteDatabase.openDatabase(f.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                    } catch (_: Exception) {}
                }
            }
        }
        return null
    }

    private fun tableExists(db: SQLiteDatabase, tableName: String): Boolean {
        return try {
            val cursor = db.rawQuery("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", arrayOf(tableName))
            val exists = cursor.moveToFirst()
            cursor.close()
            exists
        } catch (_: Exception) {
            false
        }
    }

    fun fetchStatsFromDb(context: Context): WidgetStatsData {
        val stats = WidgetStatsData()
        stats.todayZikirCount = getIntPref(context, "TodayZikirCount", 0)
        stats.streakCount = getIntPref(context, "CurrentStreak", 0)
        stats.isGoldCompletedToday = getBooleanPref(context, "IsTodayGoldCompleted", false)
        stats.zikirDailyGoal = getIntPref(context, "ZikirDailyGoal", 100)

        // Parse weekly counts fallback from SharedPreferences if available
        val weeklyPrefStr = getStringPref(context, "WeeklyDhikrCounts", "")
        if (weeklyPrefStr.isNotEmpty()) {
            try {
                val parsed = weeklyPrefStr.split(",").mapNotNull { it.trim().toIntOrNull() }
                if (parsed.size == 7) {
                    stats.weeklyDhikrCounts = parsed
                }
            } catch (_: Exception) {}
        }

        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val db = getDatabase(context) ?: return stats

        try {
            var dbTodayCount = 0
            var foundToday = false

            // 1. Today's Dhikr Count from Drift table
            if (tableExists(db, "zikir_logs")) {
                val c1 = db.rawQuery(
                    "SELECT SUM(count) FROM zikir_logs WHERE date_str = ?",
                    arrayOf(todayStr)
                )
                if (c1.moveToFirst() && !c1.isNull(0)) {
                    dbTodayCount += c1.getInt(0)
                    foundToday = true
                }
                c1.close()
            }

            // 1.1 Today's Dhikr Count from MAUI legacy table
            if (tableExists(db, "ZikirLog")) {
                val cLegacy = db.rawQuery(
                    "SELECT SUM(CekilenMiktar) FROM ZikirLog WHERE date(Tarih, 'unixepoch', 'localtime') = ?",
                    arrayOf(todayStr)
                )
                if (cLegacy.moveToFirst() && !cLegacy.isNull(0)) {
                    dbTodayCount += cLegacy.getInt(0)
                    foundToday = true
                }
                cLegacy.close()
            }

            if (foundToday || dbTodayCount > 0) {
                stats.todayZikirCount = dbTodayCount
            }

            // 2. Weekly Dhikr Counts (Last 7 Days)
            val weeklyCounts = mutableListOf<Int>()
            val activeDates = mutableSetOf<String>()

            for (i in 6 downTo 0) {
                val tempCal = Calendar.getInstance()
                tempCal.add(Calendar.DAY_OF_YEAR, -i)
                val dStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(tempCal.time)

                var dayCount = 0
                if (tableExists(db, "zikir_logs")) {
                    val c2 = db.rawQuery(
                        "SELECT SUM(count) FROM zikir_logs WHERE date_str = ?",
                        arrayOf(dStr)
                    )
                    if (c2.moveToFirst() && !c2.isNull(0)) {
                        dayCount += c2.getInt(0)
                    }
                    c2.close()
                }

                if (tableExists(db, "ZikirLog")) {
                    val c2Legacy = db.rawQuery(
                        "SELECT SUM(CekilenMiktar) FROM ZikirLog WHERE date(Tarih, 'unixepoch', 'localtime') = ?",
                        arrayOf(dStr)
                    )
                    if (c2Legacy.moveToFirst() && !c2Legacy.isNull(0)) {
                        dayCount += c2Legacy.getInt(0)
                    }
                    c2Legacy.close()
                }

                if (dayCount > 0) {
                    activeDates.add(dStr)
                }
                weeklyCounts.add(dayCount)
            }

            if (weeklyCounts.any { it > 0 }) {
                stats.weeklyDhikrCounts = weeklyCounts
            }
            stats.activeDatesInWeek = activeDates

            // 3. Streak check
            if (tableExists(db, "user_streaks")) {
                val c3 = db.rawQuery("SELECT current_streak FROM user_streaks LIMIT 1", null)
                if (c3.moveToFirst() && !c3.isNull(0)) {
                    stats.streakCount = c3.getInt(0)
                }
                c3.close()
            } else if (tableExists(db, "UserStreak")) {
                val c3Legacy = db.rawQuery("SELECT CurrentStreak FROM UserStreak LIMIT 1", null)
                if (c3Legacy.moveToFirst() && !c3Legacy.isNull(0)) {
                    stats.streakCount = c3Legacy.getInt(0)
                }
                c3Legacy.close()
            }

            stats.isCompletedToday = stats.todayZikirCount > 0 || activeDates.contains(todayStr)
        } catch (_: Exception) {
        } finally {
            try { db.close() } catch (_: Exception) {}
        }

        return stats
    }

    fun getKazaCountsFromDb(context: Context): Map<String, Int> {
        val result = mutableMapOf(
            "Sabah" to 0, "Öğle" to 0, "İkindi" to 0, "Akşam" to 0, "Yatsı" to 0
        )

        // Read from preferences fallback first
        for (k in result.keys) {
            result[k] = getIntPref(context, "KazaCount_$k", 0)
        }

        val db = getDatabase(context) ?: return result
        try {
            if (tableExists(db, "kaza_prayers")) {
                val cursor = db.rawQuery(
                    "SELECT prayer_type, total_count FROM kaza_prayers",
                    null
                )
                while (cursor.moveToNext()) {
                    val name = cursor.getString(0)
                    val count = max(0, cursor.getInt(1))
                    if (result.containsKey(name)) {
                        result[name] = count
                    }
                }
                cursor.close()
            } else if (tableExists(db, "KazaPrayer")) {
                val cursor = db.rawQuery(
                    "SELECT PrayerName, Count FROM KazaPrayer",
                    null
                )
                while (cursor.moveToNext()) {
                    val name = cursor.getString(0)
                    val count = max(0, cursor.getInt(1))
                    if (result.containsKey(name)) {
                        result[name] = count
                    }
                }
                cursor.close()
            }
        } catch (_: Exception) {
        } finally {
            try { db.close() } catch (_: Exception) {}
        }

        return result
    }

    fun decrementKazaInDb(context: Context, prayerName: String): Boolean {
        val db = getDatabase(context, readOnly = false) ?: return false
        var success = false

        try {
            db.beginTransaction()

            // 1. Update Drift table: Must decrement total_count AND increment completed_count
            if (tableExists(db, "kaza_prayers")) {
                db.execSQL(
                    "UPDATE kaza_prayers SET total_count = MAX(0, total_count - 1), completed_count = completed_count + 1 WHERE prayer_type = ? AND total_count > 0",
                    arrayOf(prayerName)
                )
            }

            // 2. Update legacy table if present
            if (tableExists(db, "KazaPrayer")) {
                db.execSQL(
                    "UPDATE KazaPrayer SET Count = MAX(0, Count - 1) WHERE PrayerName = ?",
                    arrayOf(prayerName)
                )
            }

            // 3. Insert melt log if table exists
            if (tableExists(db, "kaza_melt_logs")) {
                db.execSQL(
                    "INSERT INTO kaza_melt_logs (prayer_type, melt_amount, timestamp) VALUES (?, 1, ?)",
                    arrayOf<Any>(prayerName, System.currentTimeMillis())
                )
            }

            db.setTransactionSuccessful()
            success = true
        } catch (_: Exception) {
        } finally {
            try { db.endTransaction() } catch (_: Exception) {}
            try { db.close() } catch (_: Exception) {}
        }

        // Also update shared prefs and HomeWidget preferences
        val cur = getIntPref(context, "KazaCount_$prayerName", 1)
        val newCount = max(0, cur - 1)
        saveStringPref(context, "KazaCount_$prayerName", newCount.toString())

        try {
            val hwPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            hwPrefs.edit().putInt("KazaCount_$prayerName", newCount).apply()
            val flPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flPrefs.edit().putInt("flutter.KazaCount_$prayerName", newCount).apply()
        } catch (_: Exception) {}

        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        saveStringPref(context, "KazaLastCompletedDate", todayStr)

        return success
    }

    fun hasKazaCompletedToday(context: Context): Boolean {
        val todayStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
        val lastDate = getStringPref(context, "KazaLastCompletedDate", "")
        if (lastDate == todayStr) return true

        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val startOfDay = cal.timeInMillis

        val db = getDatabase(context) ?: return false
        var hasToday = false
        try {
            if (tableExists(db, "kaza_melt_logs")) {
                val cursor = db.rawQuery(
                    "SELECT id FROM kaza_melt_logs WHERE timestamp >= ? LIMIT 1",
                    arrayOf(startOfDay.toString())
                )
                hasToday = cursor.moveToFirst()
                cursor.close()
            }
        } catch (_: Exception) {
        } finally {
            try { db.close() } catch (_: Exception) {}
        }

        if (hasToday) {
            saveStringPref(context, "KazaLastCompletedDate", todayStr)
        }
        return hasToday
    }
}

