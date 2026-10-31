package com.akarworks.zikirce.widgets

import android.content.Context
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.graphics.*
import org.json.JSONArray
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

data class WidgetKulliyatBook(
    val id: String,
    val title: String,
    val author: String,
    val category: String,
    val currentPage: Int,
    val totalPages: Int,
    val progressPercent: Int,
    val paletteIndex: Int,
    val hasStarted: Boolean
)

data class WidgetKulliyatData(
    val lastBookId: String,
    val lastBookTitle: String,
    val lastBookAuthor: String,
    val lastBookCategory: String,
    val lastBookPage: Int,
    val lastBookTotalPages: Int,
    val lastBookPercent: Int,
    val lastBookPaletteIndex: Int,
    val lastBookReference: String,
    val startedCount: Int,
    val totalBooksCount: Int,
    val bookmarksCount: Int,
    val highlightsCount: Int,
    val shelfBooks: List<WidgetKulliyatBook>
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

    private val cityCoordinates = mapOf(
        "Adana" to Pair(37.0000, 35.3213), "Adıyaman" to Pair(37.7648, 38.2786), "Afyonkarahisar" to Pair(38.7507, 30.5567),
        "Ağrı" to Pair(39.7191, 43.0503), "Aksaray" to Pair(38.3687, 34.0370), "Amasya" to Pair(40.6501, 35.8353),
        "Ankara" to Pair(39.9334, 32.8597), "Antalya" to Pair(36.8848, 30.7056), "Ardahan" to Pair(41.1105, 42.7022),
        "Artvin" to Pair(41.1828, 41.8183), "Aydın" to Pair(37.8560, 27.8416), "Balıkesir" to Pair(39.6484, 27.8826),
        "Bartın" to Pair(41.6344, 32.3375), "Batman" to Pair(37.8812, 41.1293), "Bayburt" to Pair(40.2552, 40.2249),
        "Bilecik" to Pair(40.1451, 29.9799), "Bingöl" to Pair(38.8853, 40.4983), "Bitlis" to Pair(38.4006, 42.1095),
        "Bolu" to Pair(40.7358, 31.6061), "Burdur" to Pair(37.7203, 30.2908), "Bursa" to Pair(40.1885, 29.0610),
        "Çanakkale" to Pair(40.1553, 26.4142), "Çankırı" to Pair(40.6013, 33.6134), "Çorum" to Pair(40.5506, 34.9556),
        "Denizli" to Pair(37.7765, 29.0864), "Diyarbakır" to Pair(37.9144, 40.2110), "Düzce" to Pair(40.8438, 31.1565),
        "Edirne" to Pair(41.6768, 26.5603), "Elazığ" to Pair(38.6810, 39.2264), "Erzincan" to Pair(39.7500, 39.5000),
        "Erzurum" to Pair(39.9056, 41.2658), "Eskişehir" to Pair(39.7767, 30.5206), "Gaziantep" to Pair(37.0662, 37.3833),
        "Giresun" to Pair(40.9128, 38.3895), "Gümüşhane" to Pair(40.4600, 39.4700), "Hakkari" to Pair(37.5833, 43.7333),
        "Hatay" to Pair(36.2023, 36.1613), "Iğdır" to Pair(39.9200, 44.0400), "Isparta" to Pair(37.7648, 30.5566),
        "İstanbul" to Pair(41.0082, 28.9784), "İzmir" to Pair(38.4192, 27.1287), "Kahramanmaraş" to Pair(37.5858, 36.9371),
        "Karabük" to Pair(41.2061, 32.6204), "Karaman" to Pair(37.1759, 33.2287), "Kars" to Pair(40.6013, 43.0975),
        "Kastamonu" to Pair(41.3887, 33.7827), "Kayseri" to Pair(38.7205, 35.4826), "Kırıkkale" to Pair(39.8468, 33.5153),
        "Kırklareli" to Pair(41.7355, 27.2252), "Kırşehir" to Pair(39.1425, 34.1709), "Kilis" to Pair(36.7184, 37.1212),
        "Kocaeli" to Pair(40.8533, 29.8815), "Konya" to Pair(37.8714, 32.4847), "Kütahya" to Pair(39.4167, 29.9833),
        "Malatya" to Pair(38.3552, 38.3095), "Manisa" to Pair(38.6191, 27.4289), "Mardin" to Pair(37.3212, 40.7245),
        "Mersin" to Pair(36.8121, 34.6415), "Muğla" to Pair(37.2153, 28.3636), "Muş" to Pair(38.7432, 41.5064),
        "Nevşehir" to Pair(38.6244, 34.7144), "Niğde" to Pair(37.9667, 34.6833), "Ordu" to Pair(40.9839, 37.8764),
        "Osmaniye" to Pair(37.0742, 36.2478), "Rize" to Pair(41.0201, 40.5234), "Sakarya" to Pair(40.7569, 30.3783),
        "Samsun" to Pair(41.2867, 36.3300), "Şanlıurfa" to Pair(37.1674, 38.7955), "Siirt" to Pair(37.9333, 41.9500),
        "Sinop" to Pair(42.0231, 35.1531), "Şırnak" to Pair(37.5164, 42.4594), "Sivas" to Pair(39.7477, 36.9934),
        "Tekirdağ" to Pair(40.9833, 27.5167), "Tokat" to Pair(40.3167, 36.5500), "Trabzon" to Pair(41.0027, 39.7168),
        "Tunceli" to Pair(39.1079, 39.5401), "Uşak" to Pair(38.6823, 29.4082), "Van" to Pair(38.5012, 43.3730),
        "Yalova" to Pair(40.6500, 29.2667), "Yozgat" to Pair(39.8181, 34.8147), "Zonguldak" to Pair(41.4564, 31.7987)
    )

    fun calculateOfflinePrayerTimes(city: String, cal: Calendar = Calendar.getInstance()): WidgetPrayerTimes {
        val coords = cityCoordinates[city] ?: Pair(41.0082, 28.9784)
        val lat = coords.first
        val lng = coords.second

        val dayOfYear = cal.get(Calendar.DAY_OF_YEAR)
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val fractionalYear = (2.0 * Math.PI / 365.0) * (dayOfYear - 1 + (hour - 12.0) / 24.0)

        val eqt = 229.18 * (0.000075 + 0.001868 * cos(fractionalYear)
                - 0.032077 * sin(fractionalYear)
                - 0.014615 * cos(2 * fractionalYear)
                - 0.040849 * sin(2 * fractionalYear))

        val declination = 0.006918 - 0.399912 * cos(fractionalYear)
                + 0.070257 * sin(fractionalYear)
                - 0.006758 * cos(2 * fractionalYear)
                + 0.000907 * sin(2 * fractionalYear)
                - 0.002697 * cos(3 * fractionalYear)
                + 0.00148 * sin(3 * fractionalYear)

        val latRad = lat * Math.PI / 180.0
        val zoneOffset = 3.0
        val solarNoon = 12.0 + zoneOffset - (lng / 15.0) - (eqt / 60.0)

        fun hourAngle(zenithDeg: Double): Double {
            val zRad = zenithDeg * Math.PI / 180.0
            val c = ((cos(zRad) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))).coerceIn(-1.0, 1.0)
            return acos(c) * 180.0 / Math.PI
        }

        val hSunrise = hourAngle(90.833)
        val sunrise = solarNoon - (hSunrise / 15.0)
        val sunset = solarNoon + (hSunrise / 15.0)
        val fajr = solarNoon - (hourAngle(108.0) / 15.0)
        val isha = solarNoon + (hourAngle(107.0) / 15.0)

        val asrAngle = atan(1.0 + tan(abs(latRad - declination)))
        val cosHAsr = ((sin(asrAngle) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))).coerceIn(-1.0, 1.0)
        val hAsr = acos(cosHAsr) * 180.0 / Math.PI
        val asr = solarNoon + (hAsr / 15.0)

        fun fmt(dec: Double): String {
            var h = floor(dec).toInt()
            var m = ((dec - h) * 60.0).roundToInt()
            if (m >= 60) {
                h += 1
                m -= 60
            }
            h = ((h % 24) + 24) % 24
            return String.format(Locale.US, "%02d:%02d", h, m)
        }

        val (defDay, defMonth, defYear) = calculateHijri(cal)
        return WidgetPrayerTimes(
            imsak = fmt(fajr),
            gunes = fmt(sunrise),
            ogle = fmt(solarNoon),
            ikindi = fmt(asr),
            aksam = fmt(sunset),
            yatsi = fmt(isha),
            hijriDay = defDay,
            hijriMonth = defMonth,
            hijriYear = defYear
        )
    }

    fun getCachedPrayerTimes(context: Context, city: String): WidgetPrayerTimes {
        val nowCal = Calendar.getInstance()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(nowCal.time)
        val (defDay, defMonth, defYear) = calculateHijri(nowCal)

        // 1. Try today's dated cache from Flutter PrayerTimesService first
        val datedJson = getStringPref(context, "prayer_times_${city}_$todayStr", "")
        val candidateJson = if (datedJson.isNotEmpty()) datedJson else getStringPref(context, "CachedPrayerTimes_$city", "")

        if (candidateJson.isNotEmpty()) {
            try {
                val obj = JSONObject(candidateJson)
                val cachedDate = obj.optString("Date", obj.optString("date", ""))
                // Use cached JSON only if it has no date tag or matches today's date
                if (cachedDate.isEmpty() || cachedDate == todayStr) {
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

                    val fallback = calculateOfflinePrayerTimes(city, nowCal)
                    return WidgetPrayerTimes(
                        imsak = obj.optString("Imsak", obj.optString("fajr", fallback.imsak)),
                        gunes = obj.optString("Gunes", obj.optString("sunrise", fallback.gunes)),
                        ogle = obj.optString("Ogle", obj.optString("dhuhr", fallback.ogle)),
                        ikindi = obj.optString("Ikindi", obj.optString("asr", fallback.ikindi)),
                        aksam = obj.optString("Aksam", obj.optString("maghrib", fallback.aksam)),
                        yatsi = obj.optString("Yatsi", obj.optString("isha", fallback.yatsi)),
                        hijriDay = rawDay,
                        hijriMonth = rawMonth,
                        hijriYear = rawYear
                    )
                }
            } catch (_: Exception) {}
        }

        // 2. Automatic offline astronomical calculation when cache is from a previous day or missing
        return calculateOfflinePrayerTimes(city, nowCal)
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

    fun getLocalizedPrayerName(context: Context, prayerName: String): String {
        val lang = getStringPref(context, "AppLanguage", Locale.getDefault().language)
        val isEn = lang.startsWith("en", ignoreCase = true)

        if (isEn) {
            return when (prayerName.lowercase(Locale("tr", "TR"))) {
                "imsak", "sabah" -> "Fajr"
                "güneş", "gunes" -> "Sunrise"
                "öğle", "ogle" -> "Dhuhr"
                "ikindi" -> "Asr"
                "akşam", "aksam" -> "Maghrib"
                "yatsı", "yatsi" -> "Isha"
                else -> prayerName
            }
        }

        return when (prayerName.lowercase(Locale("tr", "TR"))) {
            "imsak", "sabah" -> "İmsak"
            "güneş", "gunes" -> "Güneş"
            "öğle", "ogle" -> "Öğle"
            "ikindi" -> "İkindi"
            "akşam", "aksam" -> "Akşam"
            "yatsı", "yatsi" -> "Yatsı"
            else -> prayerName
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

    fun getBookPaletteColors(paletteIndex: Int): IntArray {
        return when (paletteIndex.coerceIn(0, 7)) {
            0 -> intArrayOf(
                Color.parseColor("#123F30"), // primaryLeather (Hünkâr Zümrüdü)
                Color.parseColor("#0A241B"), // secondaryLeather
                Color.parseColor("#D4AF37"), // goldAccent
                Color.parseColor("#0E3226")  // spineColor
            )
            1 -> intArrayOf(
                Color.parseColor("#4E141C"), // primaryLeather (Osmanlı Yakutu)
                Color.parseColor("#2B090E"), // secondaryLeather
                Color.parseColor("#E5C158"), // goldAccent
                Color.parseColor("#3B0E15")  // spineColor
            )
            2 -> intArrayOf(
                Color.parseColor("#162944"), // primaryLeather (Semerkand Lâciverdi)
                Color.parseColor("#0C1728"), // secondaryLeather
                Color.parseColor("#DFB85C"), // goldAccent
                Color.parseColor("#102036")  // spineColor
            )
            3 -> intArrayOf(
                Color.parseColor("#1C1C20"), // primaryLeather (Kâbe Kisvesi)
                Color.parseColor("#0F0F12"), // secondaryLeather
                Color.parseColor("#D4AF37"), // goldAccent
                Color.parseColor("#141417")  // spineColor
            )
            4 -> intArrayOf(
                Color.parseColor("#523214"), // primaryLeather (Endülüs Kehribarı)
                Color.parseColor("#301C0A"), // secondaryLeather
                Color.parseColor("#F0C96B"), // goldAccent
                Color.parseColor("#3F250E")  // spineColor
            )
            5 -> intArrayOf(
                Color.parseColor("#134047"), // primaryLeather (Uhud Turkuazı)
                Color.parseColor("#0A2327"), // secondaryLeather
                Color.parseColor("#D6B45A"), // goldAccent
                Color.parseColor("#0E3136")  // spineColor
            )
            6 -> intArrayOf(
                Color.parseColor("#3B1A3D"), // primaryLeather (Buhara Mürdümü)
                Color.parseColor("#200D22"), // secondaryLeather
                Color.parseColor("#E2BE62"), // goldAccent
                Color.parseColor("#2C122E")  // spineColor
            )
            else -> intArrayOf(
                Color.parseColor("#4A3321"), // primaryLeather (Tahrir Deri Kahvesi)
                Color.parseColor("#2A1C11"), // secondaryLeather
                Color.parseColor("#E6C675"), // goldAccent
                Color.parseColor("#382618")  // spineColor
            )
        }
    }

    fun fetchKulliyatData(context: Context): WidgetKulliyatData {
        val lastMushafPage = getIntPref(context, "LastReadPage", 1).coerceIn(1, 604)
        val mushafStarted = lastMushafPage > 1
        val mushafPct = if (mushafStarted) ((lastMushafPage * 100.0) / 604.0).roundToInt().coerceIn(1, 100) else 0

        val defaultShelf = mutableListOf(
            WidgetKulliyatBook(
                id = "book_mushaf",
                title = "Kur’ân-ı Kerîm",
                author = "Diyanet Mushafları İnceleme Kurulu",
                category = "Kur’ân-ı Kerîm",
                currentPage = lastMushafPage,
                totalPages = 604,
                progressPercent = mushafPct,
                paletteIndex = 0,
                hasStarted = mushafStarted
            ),
            WidgetKulliyatBook(
                id = "book_meal_diyanet",
                title = "Diyanet Meâli",
                author = "Türkiye Diyanet Vakfı Heyeti",
                category = "Meâller",
                currentPage = 1,
                totalPages = 604,
                progressPercent = 0,
                paletteIndex = 4,
                hasStarted = false
            ),
            WidgetKulliyatBook(
                id = "book_tafseer_kuran_yolu",
                title = "Kur’ân Yolu",
                author = "Karaman, Çağrıcı, Dönmez, Gümüş",
                category = "Tefsirler",
                currentPage = 1,
                totalPages = 6236,
                progressPercent = 0,
                paletteIndex = 2,
                hasStarted = false
            ),
            WidgetKulliyatBook(
                id = "book_hadith_buhari",
                title = "Sahîh-i Buhârî",
                author = "İmam Muhammed b. İsmâil el-Buhârî",
                category = "Kütüb-i Sitte & Hadis",
                currentPage = 1,
                totalPages = 7563,
                progressPercent = 0,
                paletteIndex = 1,
                hasStarted = false
            ),
            WidgetKulliyatBook(
                id = "book_hadith_riyazus_salihin",
                title = "Riyâzü’s-Sâlihîn",
                author = "İmam Muhyiddîn en-Nevevî",
                category = "Kütüb-i Sitte & Hadis",
                currentPage = 1,
                totalPages = 1896,
                progressPercent = 0,
                paletteIndex = 5,
                hasStarted = false
            ),
            WidgetKulliyatBook(
                id = "book_risale_sozler",
                title = "Sözler",
                author = "Bediüzzaman Said Nursî",
                category = "Risale-i Nur Külliyatı",
                currentPage = 1,
                totalPages = 812,
                progressPercent = 0,
                paletteIndex = 1,
                hasStarted = false
            )
        )

        val shelfBooks = mutableListOf<WidgetKulliyatBook>()
        val shelfJson = getStringPref(context, "KulliyatShelfBooksJson", "")
        if (shelfJson.isNotEmpty()) {
            try {
                val arr = JSONArray(shelfJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    val id = obj.optString("id", "book_$i")
                    val title = obj.optString("t", "İslâmî Eser")
                    val author = obj.optString("a", "")
                    val category = obj.optString("c", "Külliyat")
                    val curPage = obj.optInt("p", 1).coerceAtLeast(1)
                    val totPages = obj.optInt("tp", 604).coerceAtLeast(1)
                    val pct = obj.optInt("pct", 0).coerceIn(0, 100)
                    val pal = obj.optInt("pal", i % 8).coerceIn(0, 7)
                    val started = obj.optBoolean("st", curPage > 1 || pct > 0)
                    shelfBooks.add(
                        WidgetKulliyatBook(
                            id = id,
                            title = title,
                            author = author,
                            category = category,
                            currentPage = curPage,
                            totalPages = totPages,
                            progressPercent = pct,
                            paletteIndex = pal,
                            hasStarted = started
                        )
                    )
                }
            } catch (_: Exception) {}
        }

        if (shelfBooks.isEmpty()) {
            val rawBookshelf = getStringPref(context, "zikirce_tahrir_bookshelf_v2", "")
            if (rawBookshelf.isNotEmpty()) {
                try {
                    val arr = JSONArray(rawBookshelf)
                    val savedMap = mutableMapOf<String, JSONObject>()
                    for (i in 0 until arr.length()) {
                        val item = arr.optJSONObject(i) ?: continue
                        val id = item.optString("id", "")
                        if (id.isNotEmpty()) {
                            savedMap[id] = item
                        }
                    }
                    for (def in defaultShelf) {
                        val s = savedMap[def.id]
                        if (s != null) {
                            val tot = s.optInt("totalPages", def.totalPages).coerceAtLeast(1)
                            var cur = s.optInt("currentPage", def.currentPage).coerceIn(1, tot)
                            var st = s.optBoolean("hasStartedReading", def.hasStarted)
                            if (def.id == "book_mushaf" && lastMushafPage > cur) {
                                cur = lastMushafPage
                                st = true
                            }
                            val pct = if (st) ((cur * 100.0) / tot.toDouble()).roundToInt().coerceIn(1, 100) else 0
                            val pal = s.optInt("paletteIndex", def.paletteIndex).coerceIn(0, 7)
                            shelfBooks.add(
                                def.copy(
                                    currentPage = cur,
                                    totalPages = tot,
                                    progressPercent = pct,
                                    paletteIndex = pal,
                                    hasStarted = st
                                )
                            )
                        } else {
                            shelfBooks.add(def)
                        }
                    }
                } catch (_: Exception) {}
            }
        }

        if (shelfBooks.isEmpty()) {
            shelfBooks.addAll(defaultShelf)
        }

        val fallbackActive = shelfBooks.firstOrNull { it.hasStarted } ?: shelfBooks.first()
        val lastBookId = getStringPref(context, "KulliyatLastBookId", fallbackActive.id)
        val lastBookTitle = getStringPref(context, "KulliyatLastBookTitle", fallbackActive.title)
        val lastBookAuthor = getStringPref(context, "KulliyatLastBookAuthor", fallbackActive.author)
        val lastBookCategory = getStringPref(context, "KulliyatLastBookCategory", fallbackActive.category)
        val lastBookPage = getIntPref(context, "KulliyatLastBookPage", fallbackActive.currentPage).coerceAtLeast(1)
        val lastBookTotalPages = getIntPref(context, "KulliyatLastBookTotalPages", fallbackActive.totalPages).coerceAtLeast(1)
        val lastBookPercent = getIntPref(context, "KulliyatLastBookPercent", fallbackActive.progressPercent).coerceIn(0, 100)
        val lastBookPaletteIndex = getIntPref(context, "KulliyatLastBookPaletteIndex", fallbackActive.paletteIndex).coerceIn(0, 7)
        val defaultRef = "Sayfa $lastBookPage / $lastBookTotalPages"
        val lastBookReference = getStringPref(context, "KulliyatLastBookReference", defaultRef)

        val defaultStartedCount = shelfBooks.count { it.hasStarted }
        val startedCount = getIntPref(context, "KulliyatStartedCount", defaultStartedCount).coerceAtLeast(0)
        val totalBooksCount = getIntPref(context, "KulliyatTotalBooksCount", 24).coerceAtLeast(shelfBooks.size)
        val bookmarksCount = getIntPref(context, "KulliyatBookmarksCount", 0).coerceAtLeast(0)
        val highlightsCount = getIntPref(context, "KulliyatHighlightsCount", 0).coerceAtLeast(0)

        return WidgetKulliyatData(
            lastBookId = lastBookId,
            lastBookTitle = lastBookTitle,
            lastBookAuthor = lastBookAuthor,
            lastBookCategory = lastBookCategory,
            lastBookPage = lastBookPage,
            lastBookTotalPages = lastBookTotalPages,
            lastBookPercent = lastBookPercent,
            lastBookPaletteIndex = lastBookPaletteIndex,
            lastBookReference = lastBookReference,
            startedCount = startedCount,
            totalBooksCount = totalBooksCount,
            bookmarksCount = bookmarksCount,
            highlightsCount = highlightsCount,
            shelfBooks = shelfBooks
        )
    }
}

