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

// MARK: - Prayer Times Models & Parsing
struct PrayerItem: Identifiable {
    let id: String
    let name: String
    let time: String
    let isCurrent: Bool
}

struct PrayerTimesEntry: TimelineEntry {
    let date: Date
    let city: String
    let hijriDate: String
    let currentPrayerName: String
    let currentPrayerTime: String
    let nextPrayerName: String
    let nextPrayerTime: String
    let nextPrayerDate: Date
    let allPrayers: [PrayerItem]
    let isSample: Bool
    
    static var placeholder: PrayerTimesEntry {
        let now = Date()
        let prayers = [
            PrayerItem(id: "imsak", name: "İmsak", time: "05:15", isCurrent: false),
            PrayerItem(id: "gunes", name: "Güneş", time: "06:42", isCurrent: false),
            PrayerItem(id: "ogle", name: "Öğle", time: "13:06", isCurrent: true),
            PrayerItem(id: "ikindi", name: "İkindi", time: "16:24", isCurrent: false),
            PrayerItem(id: "aksam", name: "Akşam", time: "19:22", isCurrent: false),
            PrayerItem(id: "yatsi", name: "Yatsı", time: "20:45", isCurrent: false),
        ]
        return PrayerTimesEntry(
            date: now,
            city: "İstanbul",
            hijriDate: "18 Ramazan 1446",
            currentPrayerName: "Öğle",
            currentPrayerTime: "13:06",
            nextPrayerName: "İkindi",
            nextPrayerTime: "16:24",
            nextPrayerDate: Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now,
            allPrayers: prayers,
            isSample: true
        )
    }
}

enum PrayerDataHelper {
    static func fetchPrayerTimes(for date: Date = Date()) -> PrayerTimesEntry {
        guard let prefs = WidgetConstants.userDefaults else {
            return .placeholder
        }
        
        let city = prefs.string(forKey: "SelectedCity") ?? "İstanbul"
        let jsonStr = prefs.string(forKey: "CachedPrayerTimes_\(city)") ?? prefs.string(forKey: "PrayerTimesJson")
        
        guard let jsonStr = jsonStr,
              let data = jsonStr.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .placeholder
        }
        
        let imsak = dict["Imsak"] as? String ?? "05:00"
        let gunes = dict["Gunes"] as? String ?? "06:30"
        let ogle = dict["Ogle"] as? String ?? "13:00"
        let ikindi = dict["Ikindi"] as? String ?? "16:30"
        let aksam = dict["Aksam"] as? String ?? "19:15"
        let yatsi = dict["Yatsi"] as? String ?? "20:30"
        
        let hDay = dict["HijriDay"] as? String ?? ""
        let hMonth = dict["HijriMonth"] as? String ?? ""
        let hYear = dict["HijriYear"] as? String ?? ""
        let hijriStr = [hDay, hMonth, hYear].filter { !$0.isEmpty }.joined(separator: " ")
        
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
        
        // Find current and next prayer
        var currentIdx = prayerDates.count - 1
        var nextIdx = 0
        
        for (idx, p) in prayerDates.enumerated() {
            if date < p.date {
                nextIdx = idx
                currentIdx = (idx == 0) ? (prayerDates.count - 1) : (idx - 1)
                break
            }
        }
        
        let current = prayerDates.indices.contains(currentIdx) ? prayerDates[currentIdx] : prayerDates[0]
        let next = prayerDates.indices.contains(nextIdx) ? prayerDates[nextIdx] : prayerDates[0]
        
        var nextDate = next.date
        if nextIdx == 0 && date >= (prayerDates.last?.date ?? date) {
            // Next prayer is tomorrow's Imsak
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        
        let prayerItems = prayerDates.enumerated().map { (idx, item) in
            PrayerItem(
                id: item.key,
                name: item.name,
                time: item.time,
                isCurrent: idx == currentIdx
            )
        }
        
        return PrayerTimesEntry(
            date: date,
            city: city,
            hijriDate: hijriStr.isEmpty ? "Zikirce" : hijriStr,
            currentPrayerName: current.name,
            currentPrayerTime: current.time,
            nextPrayerName: next.name,
            nextPrayerTime: next.time,
            nextPrayerDate: nextDate,
            allPrayers: prayerItems,
            isSample: false
        )
    }
    
    private static func parseTimeToday(_ timeStr: String, calendar: Calendar, referenceDate: Date) -> Date? {
        let parts = timeStr.split(separator: ":")
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

// MARK: - Streak Models & Helpers
struct StreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let todayCount: Int
    let dailyGoal: Int
    let isCompleted: Bool
    let isSample: Bool
    
    static var placeholder: StreakEntry {
        StreakEntry(
            date: Date(),
            currentStreak: 12,
            todayCount: 150,
            dailyGoal: 100,
            isCompleted: true,
            isSample: true
        )
    }
}

enum StreakDataHelper {
    static func fetchStreak() -> StreakEntry {
        guard let prefs = WidgetConstants.userDefaults else {
            return .placeholder
        }
        
        let streak = prefs.integer(forKey: "CurrentStreak")
        let todayCount = prefs.integer(forKey: "TodayZikirCount")
        var dailyGoal = prefs.integer(forKey: "ZikirDailyGoal")
        if dailyGoal <= 0 { dailyGoal = 100 }
        let isCompleted = prefs.bool(forKey: "IsTodayGoldCompleted") || (todayCount >= dailyGoal)
        
        return StreakEntry(
            date: Date(),
            currentStreak: max(0, streak),
            todayCount: max(0, todayCount),
            dailyGoal: dailyGoal,
            isCompleted: isCompleted,
            isSample: false
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
