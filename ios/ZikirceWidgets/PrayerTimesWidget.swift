import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct PrayerTimesProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerTimesEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PrayerTimesEntry) -> Void) {
        let entry = PrayerDataHelper.fetchPrayerTimes()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimesEntry>) -> Void) {
        let now = Date()
        let currentEntry = PrayerDataHelper.fetchPrayerTimes(for: now)
        
        var entries: [PrayerTimesEntry] = [currentEntry]
        
        // Generate future entries for upcoming prayer transition times today
        let calendar = Calendar.current
        for prayer in currentEntry.allPrayers {
            let parts = prayer.time.split(separator: ":")
            if parts.count >= 2,
               let h = Int(parts[0]),
               let m = Int(parts[1]) {
                var comp = calendar.dateComponents([.year, .month, .day], from: now)
                comp.hour = h
                comp.minute = m
                comp.second = 1 // 1 second after adhan time
                if let pDate = calendar.date(from: comp), pDate > now {
                    let futureEntry = PrayerDataHelper.fetchPrayerTimes(for: pDate)
                    entries.append(futureEntry)
                }
            }
        }
        
        // Next reload policy: when next prayer time arrives or after 1 hour
        let reloadDate = currentEntry.nextPrayerDate.addingTimeInterval(5)
        let timeline = Timeline(entries: entries, policy: .after(reloadDate))
        completion(timeline)
    }
}

// MARK: - Widget Views
struct PrayerTimesEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PrayerTimesEntry
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                PrayerTimesSmallView(entry: entry)
            case .systemMedium:
                PrayerTimesMediumView(entry: entry)
            #if swift(>=5.7)
            case .accessoryRectangular:
                PrayerTimesAccessoryRectangularView(entry: entry)
            case .accessoryCircular:
                PrayerTimesAccessoryCircularView(entry: entry)
            case .accessoryInline:
                PrayerTimesAccessoryInlineView(entry: entry)
            #endif
            default:
                PrayerTimesSmallView(entry: entry)
            }
        }
        .widgetContainerBackground(Color(uiColor: .systemBackground))
    }
}

// MARK: - Small View
struct PrayerTimesSmallView: View {
    var entry: PrayerTimesEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.teal)
                    .font(.caption)
                Text(entry.city)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sıradaki Vakit")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(entry.nextPrayerName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(entry.nextPrayerTime)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.teal)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(entry.nextPrayerDate, style: .relative)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(6)
        }
        .padding(12)
    }
}

// MARK: - Medium View
struct PrayerTimesMediumView: View {
    var entry: PrayerTimesEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: City, Hijri date, Countdown
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.city)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(entry.hijriDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.caption2)
                        .foregroundColor(.teal)
                    Text("\(entry.nextPrayerName)'a")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(entry.nextPrayerDate, style: .relative)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.teal)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // 6 Prayers Grid
            HStack(spacing: 4) {
                ForEach(entry.allPrayers) { prayer in
                    PrayerPill(prayer: prayer)
                }
            }
        }
        .padding(12)
    }
}

struct PrayerPill: View {
    let prayer: PrayerItem
    
    var body: some View {
        VStack(spacing: 4) {
            Text(prayer.name)
                .font(.system(size: 11, weight: prayer.isCurrent ? .bold : .medium))
                .foregroundColor(prayer.isCurrent ? .teal : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(prayer.time)
                .font(.system(size: 12, weight: prayer.isCurrent ? .heavy : .semibold, design: .monospaced))
                .foregroundColor(prayer.isCurrent ? .primary : .primary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if prayer.isCurrent {
                Circle()
                    .fill(Color.teal)
                    .frame(width: 4, height: 4)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(prayer.isCurrent ? Color.teal.opacity(0.15) : Color(uiColor: .secondarySystemBackground).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(prayer.isCurrent ? Color.teal.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Lock Screen (Accessory) Views
#if swift(>=5.7)
struct PrayerTimesAccessoryRectangularView: View {
    var entry: PrayerTimesEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption2)
                    Text(entry.city)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                Text("\(entry.nextPrayerName): \(entry.nextPrayerTime)")
                    .font(.headline)
                    .fontWeight(.bold)
                HStack(spacing: 2) {
                    Text("Kalan:")
                        .font(.caption2)
                    Text(entry.nextPrayerDate, style: .relative)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
            Spacer()
        }
    }
}

struct PrayerTimesAccessoryCircularView: View {
    var entry: PrayerTimesEntry
    
    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "moon.fill")
                .font(.system(size: 14))
            Text(entry.nextPrayerName)
                .font(.system(size: 9, weight: .bold))
            Text(entry.nextPrayerTime)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
    }
}

struct PrayerTimesAccessoryInlineView: View {
    var entry: PrayerTimesEntry
    
    var body: some View {
        Text("🕌 \(entry.nextPrayerName): \(entry.nextPrayerTime)")
    }
}
#endif

// MARK: - Widget Configuration
struct PrayerTimesWidget: Widget {
    let kind: String = "PrayerTimesWidget"
    
    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimesProvider()) { entry in
            PrayerTimesEntryView(entry: entry)
        }
        .configurationDisplayName("Ezan Vakitleri")
        .description("Günün namaz vakitlerini ve sıradaki vakte kalan süreyi takip edin.")
        .supportedFamilies(supportedFamilies)
    }
}
