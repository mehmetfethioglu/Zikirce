import Foundation
import SwiftUI
import WidgetKit

// MARK: - Constants & Shared Preferences
enum WidgetConstants {
    static let appGroupId = "group.com.akarworks.zikirce"

    static var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }
}

// MARK: - Color Hex Helper
extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Zero-Battery Live Countdown View
struct LivePrayerCountdownText: View {
    let startDate: Date
    let targetDate: Date

    var body: some View {
        let safeEnd = max(startDate, targetDate)
        if #available(iOS 16.0, *) {
            Text(timerInterval: startDate...safeEnd, countsDown: true)
                .monospacedDigit()
        } else {
            Text(safeEnd, style: .timer)
                .monospacedDigit()
        }
    }
}

// MARK: - Prayer Times Models
struct PrayerItem: Identifiable {
    let id: String
    let name: String
    let time: String
    let isCurrent: Bool
    let isNext: Bool
}

struct PrayerTimesEntry: TimelineEntry {
    let date: Date
    let city: String
    let hijriDay: String
    let hijriMonth: String
    let hijriYear: String
    let hijriDate: String
    let gregorianDateStr: String
    let weekdayName: String
    let currentPrayerName: String
    let currentPrayerTime: String
    let nextPrayerName: String
    let nextPrayerDirectionalName: String
    let nextPrayerTime: String
    let prevPrayerDate: Date
    let nextPrayerDate: Date
    let progress: Double
    let countdownColorHex: String
    let allPrayers: [PrayerItem]
    let isSample: Bool

    static var placeholder: PrayerTimesEntry {
        let now = Date()
        let prayers = [
            PrayerItem(id: "imsak", name: "İmsak", time: "05:15", isCurrent: false, isNext: false),
            PrayerItem(id: "gunes", name: "Güneş", time: "06:42", isCurrent: false, isNext: false),
            PrayerItem(id: "ogle", name: "Öğle", time: "13:06", isCurrent: true, isNext: false),
            PrayerItem(id: "ikindi", name: "İkindi", time: "16:20", isCurrent: false, isNext: true),
            PrayerItem(id: "aksam", name: "Akşam", time: "19:22", isCurrent: false, isNext: false),
            PrayerItem(id: "yatsi", name: "Yatsı", time: "20:45", isCurrent: false, isNext: false),
        ]
        return PrayerTimesEntry(
            date: now,
            city: "İstanbul",
            hijriDay: "19",
            hijriMonth: "Rebiülevvel",
            hijriYear: "1448",
            hijriDate: "19 Rebiülevvel 1448",
            gregorianDateStr: "16 EKİM 2026",
            weekdayName: "CUMA",
            currentPrayerName: "Öğle",
            currentPrayerTime: "13:06",
            nextPrayerName: "İkindi",
            nextPrayerDirectionalName: "İKİNDİYE",
            nextPrayerTime: "16:20",
            prevPrayerDate: now.addingTimeInterval(-3600),
            nextPrayerDate: now.addingTimeInterval(5400),
            progress: 0.4,
            countdownColorHex: "#10B981",
            allPrayers: prayers,
            isSample: true
        )
    }
}

// MARK: - Offline Astronomical & Cached Prayer Data Helper
enum PrayerDataHelper {
    private static let hijriMonthNamesTr = [
        "Muharrem", "Safer", "Rebiülevvel", "Rebiülahir",
        "Cemaziyelevvel", "Cemaziyelahir", "Recep", "Şaban",
        "Ramazan", "Şevval", "Zilkade", "Zilhicce"
    ]

    private static let cityCoordinates: [String: (Double, Double)] = [
        "Adana": (37.0000, 35.3213), "Adıyaman": (37.7648, 38.2786), "Afyonkarahisar": (38.7507, 30.5567),
        "Ağrı": (39.7191, 43.0503), "Aksaray": (38.3687, 34.0370), "Amasya": (40.6501, 35.8353),
        "Ankara": (39.9334, 32.8597), "Antalya": (36.8848, 30.7056), "Ardahan": (41.1105, 42.7022),
        "Artvin": (41.1828, 41.8183), "Aydın": (37.8560, 27.8416), "Balıkesir": (39.6484, 27.8826),
        "Bartın": (41.6344, 32.3375), "Batman": (37.8812, 41.1293), "Bayburt": (40.2552, 40.2249),
        "Bilecik": (40.1451, 29.9799), "Bingöl": (38.8853, 40.4983), "Bitlis": (38.4006, 42.1095),
        "Bolu": (40.7358, 31.6061), "Burdur": (37.7203, 30.2908), "Bursa": (40.1885, 29.0610),
        "Çanakkale": (40.1553, 26.4142), "Çankırı": (40.6013, 33.6134), "Çorum": (40.5506, 34.9556),
        "Denizli": (37.7765, 29.0864), "Diyarbakır": (37.9144, 40.2110), "Düzce": (40.8438, 31.1565),
        "Edirne": (41.6768, 26.5603), "Elazığ": (38.6810, 39.2264), "Erzincan": (39.7500, 39.5000),
        "Erzurum": (39.9056, 41.2658), "Eskişehir": (39.7767, 30.5206), "Gaziantep": (37.0662, 37.3833),
        "Giresun": (40.9128, 38.3895), "Gümüşhane": (40.4600, 39.4700), "Hakkari": (37.5833, 43.7333),
        "Hatay": (36.2023, 36.1613), "Iğdır": (39.9200, 44.0400), "Isparta": (37.7648, 30.5566),
        "İstanbul": (41.0082, 28.9784), "İzmir": (38.4192, 27.1287), "Kahramanmaraş": (37.5858, 36.9371),
        "Karabük": (41.2061, 32.6204), "Karaman": (37.1759, 33.2287), "Kars": (40.6013, 43.0975),
        "Kastamonu": (41.3887, 33.7827), "Kayseri": (38.7205, 35.4826), "Kırıkkale": (39.8468, 33.5153),
        "Kırklareli": (41.7355, 27.2252), "Kırşehir": (39.1425, 34.1709), "Kilis": (36.7184, 37.1212),
        "Kocaeli": (40.8533, 29.8815), "Konya": (37.8714, 32.4847), "Kütahya": (39.4167, 29.9833),
        "Malatya": (38.3552, 38.3095), "Manisa": (38.6191, 27.4289), "Mardin": (37.3212, 40.7245),
        "Mersin": (36.8121, 34.6415), "Muğla": (37.2153, 28.3636), "Muş": (38.7432, 41.5064),
        "Nevşehir": (38.6244, 34.7144), "Niğde": (37.9667, 34.6833), "Ordu": (40.9839, 37.8764),
        "Osmaniye": (37.0742, 36.2478), "Rize": (41.0201, 40.5234), "Sakarya": (40.7569, 30.3783),
        "Samsun": (41.2867, 36.3300), "Şanlıurfa": (37.1674, 38.7955), "Siirt": (37.9333, 41.9500),
        "Sinop": (42.0231, 35.1531), "Şırnak": (37.5164, 42.4594), "Sivas": (39.7477, 36.9934),
        "Tekirdağ": (40.9833, 27.5167), "Tokat": (40.3167, 36.5500), "Trabzon": (41.0027, 39.7168),
        "Tunceli": (39.1079, 39.5401), "Uşak": (38.6823, 29.4082), "Van": (38.5012, 43.3730),
        "Yalova": (40.6500, 29.2667), "Yozgat": (39.8181, 34.8147), "Zonguldak": (41.4564, 31.7987)
    ]

    static func calculateHijri(for date: Date) -> (day: String, month: String, year: String) {
        let cal = Calendar(identifier: .gregorian)
        let comp = cal.dateComponents([.year, .month, .day], from: date)
        var y = Double(comp.year ?? 2026)
        var m = Double(comp.month ?? 1)
        let d = Double(comp.day ?? 1)

        if m < 3 {
            y -= 1
            m += 12
        }
        let a = floor(y / 100.0)
        let b = 2.0 - a + floor(a / 4.0)
        var jd = floor(365.25 * (y + 4716.0)) + floor(30.6001 * (m + 1.0)) + d + b - 1524.5
        jd = floor(jd) + 0.5
        var l = jd - 1948440.0 + 10632.0
        let n = floor((l - 1.0) / 10631.0)
        l = l - 10631.0 * n + 354.0
        let j = floor((10985.0 - l) / 5316.0) * floor((50.0 * l) / 17719.0) +
                floor(l / 5670.0) * floor((43.0 * l) / 15238.0)
        l = l - floor((30.0 - j) / 15.0) * floor((17719.0 * j) / 50.0) -
                floor(j / 16.0) * floor((15238.0 * j) / 43.0) + 29.0
        let hMonth = min(12, max(1, Int(floor((24.0 * l) / 709.0))))
        let hDay = min(30, max(1, Int(l - floor((709.0 * Double(hMonth)) / 24.0))))
        let hYear = Int(30.0 * n + j - 30.0)

        return ("\(hDay)", hijriMonthNamesTr[hMonth - 1], "\(hYear)")
    }

    static func calculateOfflineTimes(city: String, for date: Date) -> (imsak: String, gunes: String, ogle: String, ikindi: String, aksam: String, yatsi: String) {
        let coords = cityCoordinates[city] ?? (41.0082, 28.9784)
        let lat = coords.0
        let lng = coords.1

        let cal = Calendar(identifier: .gregorian)
        let dayOfYear = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        let fractionalYear = (2.0 * Double.pi / 365.0) * (dayOfYear - 1.0)

        let eqt = 229.18 * (0.000075 + 0.001868 * cos(fractionalYear)
                - 0.032077 * sin(fractionalYear)
                - 0.014615 * cos(2.0 * fractionalYear)
                - 0.040849 * sin(2.0 * fractionalYear))

        let declination = 0.006918 - 0.399912 * cos(fractionalYear)
                + 0.070257 * sin(fractionalYear)
                - 0.006758 * cos(2.0 * fractionalYear)
                + 0.000907 * sin(2.0 * fractionalYear)
                - 0.002697 * cos(3.0 * fractionalYear)
                + 0.00148 * sin(3.0 * fractionalYear)

        let latRad = lat * Double.pi / 180.0
        let solarNoon = 12.0 + 3.0 - (lng / 15.0) - (eqt / 60.0)

        func hourAngle(_ zenithDeg: Double) -> Double {
            let zRad = zenithDeg * Double.pi / 180.0
            let c = min(1.0, max(-1.0, (cos(zRad) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))))
            return acos(c) * 180.0 / Double.pi
        }

        let hSunrise = hourAngle(90.833)
        let sunrise = solarNoon - (hSunrise / 15.0)
        let sunset = solarNoon + (hSunrise / 15.0)
        let fajr = solarNoon - (hourAngle(108.0) / 15.0)
        let isha = solarNoon + (hourAngle(107.0) / 15.0)

        let asrAngle = atan(1.0 + tan(abs(latRad - declination)))
        let cosHAsr = min(1.0, max(-1.0, (sin(asrAngle) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))))
        let hAsr = acos(cosHAsr) * 180.0 / Double.pi
        let asr = solarNoon + (hAsr / 15.0)

        func fmt(_ dec: Double) -> String {
            var h = Int(floor(dec))
            var m = Int(((dec - Double(h)) * 60.0).rounded())
            if m >= 60 {
                h += 1
                m -= 60
            }
            h = ((h % 24) + 24) % 24
            return String(format: "%02d:%02d", h, m)
        }

        return (fmt(fajr), fmt(sunrise), fmt(solarNoon), fmt(asr), fmt(sunset), fmt(isha))
    }

    static func directionalName(_ prayerName: String) -> String {
        switch prayerName.lowercased() {
        case "imsak", "sabah": return "İMSAĞA"
        case "güneş", "gunes": return "GÜNEŞE"
        case "öğle", "ogle": return "ÖĞLEYE"
        case "ikindi": return "İKİNDİYE"
        case "akşam", "aksam": return "AKŞAMA"
        case "yatsı", "yatsi": return "YATSIYA"
        default: return prayerName.uppercased(with: Locale(identifier: "tr_TR"))
        }
    }

    static func countdownColorHex(prayerName: String, progress: Double) -> String {
        let green = "#10B981"
        let orange = "#F59E0B"
        let red = "#EF4444"
        let bordeaux = "#8B0000"
        let p = min(1.0, max(0.0, progress))

        switch prayerName {
        case "Güneş":
            if p < 0.15 || p > 0.85 { return bordeaux }
            let mid = (p - 0.15) / 0.70
            if mid < 0.30 { return green }
            if mid < 0.70 { return orange }
            return red
        case "Öğle":
            if p < 0.40 { return green }
            if p < 0.70 { return orange }
            if p < 0.90 { return red }
            return bordeaux
        default:
            if p >= 0.85 { return bordeaux }
            let sub = p / 0.85
            if sub < 0.35 { return green }
            if sub < 0.70 { return orange }
            return red
        }
    }

    static func fetchPrayerTimes(for date: Date = Date()) -> PrayerTimesEntry {
        let prefs = WidgetConstants.userDefaults
        let city = prefs?.string(forKey: "SelectedCity") ?? "İstanbul"

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.dateFormat = "yyyy-MM-dd"
        let targetDayStr = dateFmt.string(from: date)

        let offline = calculateOfflineTimes(city: city, for: date)
        var imsak = offline.imsak
        var gunes = offline.gunes
        var ogle = offline.ogle
        var ikindi = offline.ikindi
        var aksam = offline.aksam
        var yatsi = offline.yatsi

        let calcHijri = calculateHijri(for: date)
        var hDay = calcHijri.day
        var hMonth = calcHijri.month
        var hYear = calcHijri.year

        if let jsonStr = prefs?.string(forKey: "CachedPrayerTimes_\(city)") ?? prefs?.string(forKey: "PrayerTimesJson"),
           let data = jsonStr.data(using: .utf8),
           let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let cachedDate = (dict["Date"] as? String) ?? (dict["date"] as? String) ?? ""
            if cachedDate.isEmpty || cachedDate == targetDayStr {
                imsak = (dict["Imsak"] as? String) ?? imsak
                gunes = (dict["Gunes"] as? String) ?? gunes
                ogle = (dict["Ogle"] as? String) ?? ogle
                ikindi = (dict["Ikindi"] as? String) ?? ikindi
                aksam = (dict["Aksam"] as? String) ?? aksam
                yatsi = (dict["Yatsi"] as? String) ?? yatsi

                if let d = dict["HijriDay"] as? String, !d.isEmpty { hDay = d }
                if let m = dict["HijriMonth"] as? String, !m.isEmpty { hMonth = m }
                if let y = dict["HijriYear"] as? String, !y.isEmpty { hYear = y }
            }
        }

        let hijriStr = "\(hDay) \(hMonth) \(hYear)"

        let trLocale = Locale(identifier: "tr_TR")
        let gregFmt = DateFormatter()
        gregFmt.locale = trLocale
        gregFmt.dateFormat = "d MMMM yyyy"
        let gregorianDateStr = gregFmt.string(from: date).uppercased(with: trLocale)

        let weekdayFmt = DateFormatter()
        weekdayFmt.locale = trLocale
        weekdayFmt.dateFormat = "EEEE"
        let weekdayName = weekdayFmt.string(from: date).uppercased(with: trLocale)

        let rawList: [(key: String, name: String, time: String)] = [
            ("imsak", "İmsak", imsak),
            ("gunes", "Güneş", gunes),
            ("ogle", "Öğle", ogle),
            ("ikindi", "İkindi", ikindi),
            ("aksam", "Akşam", aksam),
            ("yatsi", "Yatsı", yatsi)
        ]

        let calendar = Calendar.current
        var prayerDates: [(key: String, name: String, time: String, date: Date)] = []

        for item in rawList {
            if let pDate = parseTimeToday(item.time, calendar: calendar, referenceDate: date) {
                prayerDates.append((item.key, item.name, item.time, pDate))
            }
        }

        var currentIdx = max(0, prayerDates.count - 1)
        var nextIdx = 0

        for (idx, p) in prayerDates.enumerated() {
            if date < p.date {
                nextIdx = idx
                currentIdx = (idx == 0) ? (prayerDates.count - 1) : (idx - 1)
                break
            }
        }

        let current = prayerDates.indices.contains(currentIdx) ? prayerDates[currentIdx] : ("ogle", "Öğle", ogle, date)
        var next = prayerDates.indices.contains(nextIdx) ? prayerDates[nextIdx] : ("ikindi", "İkindi", ikindi, date)

        var prevDate = current.date
        var nextDate = next.date

        if nextIdx == 0 {
            if date >= (prayerDates.last?.date ?? date) {
                // Past today's Yatsı -> Next prayer is tomorrow's İmsak
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date
                let tomorrowOffline = calculateOfflineTimes(city: city, for: tomorrow)
                let tomorrowImsak = tomorrowOffline.imsak
                nextDate = parseTimeToday(tomorrowImsak, calendar: calendar, referenceDate: tomorrow) ?? calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
                next = ("imsak", "İmsak", tomorrowImsak, nextDate)
            } else {
                // Before today's İmsak -> Previous prayer was yesterday's Yatsı
                prevDate = calendar.date(byAdding: .day, value: -1, to: prevDate) ?? prevDate
            }
        }

        let totalSec = max(1.0, nextDate.timeIntervalSince(prevDate))
        let elapsedSec = max(0.0, date.timeIntervalSince(prevDate))
        let progress = min(1.0, max(0.0, elapsedSec / totalSec))
        let colorHex = countdownColorHex(prayerName: next.name, progress: progress)

        let prayerItems = prayerDates.enumerated().map { (idx, item) in
            PrayerItem(
                id: item.key,
                name: item.name,
                time: item.time,
                isCurrent: idx == currentIdx,
                isNext: idx == nextIdx
            )
        }

        return PrayerTimesEntry(
            date: date,
            city: city,
            hijriDay: hDay,
            hijriMonth: hMonth,
            hijriYear: hYear,
            hijriDate: hijriStr,
            gregorianDateStr: gregorianDateStr,
            weekdayName: weekdayName,
            currentPrayerName: current.name,
            currentPrayerTime: current.time,
            nextPrayerName: next.name,
            nextPrayerDirectionalName: directionalName(next.name),
            nextPrayerTime: next.time,
            prevPrayerDate: prevDate,
            nextPrayerDate: nextDate,
            progress: progress,
            countdownColorHex: colorHex,
            allPrayers: prayerItems,
            isSample: false
        )
    }

    static func buildTimeline(includeProgressSteps: Bool = false) -> Timeline<PrayerTimesEntry> {
        let now = Date()
        let currentEntry = fetchPrayerTimes(for: now)
        var entries: [PrayerTimesEntry] = [currentEntry]

        let calendar = Calendar.current

        // If the widget renders a progress ring/bar, insert lightweight 15-minute checkpoints up to nextPrayerDate
        if includeProgressSteps {
            var stepDate = now.addingTimeInterval(900)
            while stepDate < currentEntry.nextPrayerDate {
                entries.append(fetchPrayerTimes(for: stepDate))
                stepDate = stepDate.addingTimeInterval(900)
            }
        }

        // Pre-populate exact transition entries for today + midnight + tomorrow (24h deterministic schedule)
        var candidateDates: [Date] = []
        for dayOffset in 0...1 {
            guard let refDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let dayEntry = fetchPrayerTimes(for: refDay)
            for p in dayEntry.allPrayers {
                if let pDate = parseTimeToday(p.time, calendar: calendar, referenceDate: refDay) {
                    let triggerDate = pDate.addingTimeInterval(1) // 1s after adhan time
                    if triggerDate > now {
                        candidateDates.append(triggerDate)
                    }
                }
            }
        }

        // Also add midnight rollover
        if let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            let midnightTrigger = tomorrowStart.addingTimeInterval(2)
            if midnightTrigger > now {
                candidateDates.append(midnightTrigger)
            }
        }

        candidateDates.sort()
        for tDate in candidateDates {
            entries.append(fetchPrayerTimes(for: tDate))
        }

        let reloadDate = currentEntry.nextPrayerDate.addingTimeInterval(2)
        return Timeline(entries: entries, policy: .after(reloadDate))
    }

    static func parseTimeToday(_ timeStr: String, calendar: Calendar, referenceDate: Date) -> Date? {
        let clean = timeStr.split(separator: " ").first.map(String.init) ?? timeStr
        let parts = clean.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
}

// MARK: - Streak & Spiritual Heart Health Models
struct StreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let todayCount: Int
    let dailyGoal: Int
    let isCompleted: Bool
    let isGoldCompleted: Bool
    let weeklyCounts: [Int]
    let activeDatesInWeek: Set<String>
    let isSample: Bool

    static var placeholder: StreakEntry {
        StreakEntry(
            date: Date(),
            currentStreak: 12,
            todayCount: 150,
            dailyGoal: 100,
            isCompleted: true,
            isGoldCompleted: false,
            weeklyCounts: [80, 120, 95, 140, 110, 160, 150],
            activeDatesInWeek: [],
            isSample: true
        )
    }
}

enum StreakDataHelper {
    static func fetchStreak() -> StreakEntry {
        guard let prefs = WidgetConstants.userDefaults else {
            return .placeholder
        }

        let streak = max(0, prefs.integer(forKey: "CurrentStreak"))
        let todayCount = max(0, prefs.integer(forKey: "TodayZikirCount"))
        var dailyGoal = prefs.integer(forKey: "ZikirDailyGoal")
        if dailyGoal <= 0 { dailyGoal = 100 }
        let isGold = prefs.bool(forKey: "IsTodayGoldCompleted")
        let isCompleted = isGold || (todayCount > 0 && todayCount >= dailyGoal) || todayCount > 0

        var weeklyCounts: [Int] = [0, 0, 0, 0, 0, 0, todayCount]
        if let weeklyStr = prefs.string(forKey: "WeeklyDhikrCounts"), !weeklyStr.isEmpty {
            let parsed = weeklyStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parsed.count == 7 {
                weeklyCounts = parsed
            }
        }

        var activeDates = Set<String>()
        if let activeStr = prefs.string(forKey: "ActiveDatesInWeek"), !activeStr.isEmpty {
            for item in activeStr.split(separator: ",") {
                activeDates.insert(String(item).trimmingCharacters(in: .whitespaces))
            }
        } else {
            let cal = Calendar.current
            let now = Date()
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "yyyy-MM-dd"
            for i in 0..<7 {
                if weeklyCounts[i] > 0, let d = cal.date(byAdding: .day, value: -(6 - i), to: now) {
                    activeDates.insert(fmt.string(from: d))
                }
            }
        }

        return StreakEntry(
            date: Date(),
            currentStreak: streak,
            todayCount: todayCount,
            dailyGoal: dailyGoal,
            isCompleted: isCompleted,
            isGoldCompleted: isGold,
            weeklyCounts: weeklyCounts,
            activeDatesInWeek: activeDates,
            isSample: false
        )
    }
}

// MARK: - Kaza Prayer Models
struct KazaEntry: TimelineEntry {
    let date: Date
    let sabah: Int
    let ogle: Int
    let ikindi: Int
    let aksam: Int
    let yatsi: Int
    let totalDebt: Int
    let highestPrayerName: String
    let highestPrayerCount: Int
    let hasCompletedToday: Bool

    static var placeholder: KazaEntry {
        KazaEntry(
            date: Date(),
            sabah: 0,
            ogle: 0,
            ikindi: 0,
            aksam: 0,
            yatsi: 0,
            totalDebt: 0,
            highestPrayerName: "Sabah",
            highestPrayerCount: 0,
            hasCompletedToday: false
        )
    }
}

enum KazaDataHelper {
    static func fetchKaza() -> KazaEntry {
        let prefs = WidgetConstants.userDefaults
        let sabah = max(0, prefs?.integer(forKey: "KazaCount_Sabah") ?? 0)
        let ogle = max(0, prefs?.integer(forKey: "KazaCount_Öğle") ?? 0)
        let ikindi = max(0, prefs?.integer(forKey: "KazaCount_İkindi") ?? 0)
        let aksam = max(0, prefs?.integer(forKey: "KazaCount_Akşam") ?? 0)
        let yatsi = max(0, prefs?.integer(forKey: "KazaCount_Yatsı") ?? 0)

        let total = sabah + ogle + ikindi + aksam + yatsi
        let pairs: [(String, Int)] = [
            ("Sabah", sabah), ("Öğle", ogle), ("İkindi", ikindi), ("Akşam", aksam), ("Yatsı", yatsi)
        ]
        var maxName = "Sabah"
        var maxVal = -1
        for (name, c) in pairs {
            if c > maxVal {
                maxVal = c
                maxName = name
            }
        }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        let todayStr = fmt.string(from: Date())
        let lastDate = prefs?.string(forKey: "KazaLastCompletedDate") ?? ""
        let completedToday = (lastDate == todayStr)

        return KazaEntry(
            date: Date(),
            sabah: sabah,
            ogle: ogle,
            ikindi: ikindi,
            aksam: aksam,
            yatsi: yatsi,
            totalDebt: total,
            highestPrayerName: maxName,
            highestPrayerCount: max(0, maxVal),
            hasCompletedToday: completedToday
        )
    }
}

// MARK: - Widget View Extension for Cross-iOS Compatibility
extension View {
    @ViewBuilder
    func widgetContainerBackground(_ backgroundView: some View) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            self.background(backgroundView)
        }
    }
}
