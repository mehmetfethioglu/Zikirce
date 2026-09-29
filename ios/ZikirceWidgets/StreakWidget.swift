import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let entry = StreakDataHelper.fetchStreak()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = StreakDataHelper.fetchStreak()
        
        // Reload after 1 hour or next day at midnight
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Views
struct StreakEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: StreakEntry
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                StreakSmallView(entry: entry)
            case .systemMedium:
                StreakMediumView(entry: entry)
            #if swift(>=5.7)
            case .accessoryCircular:
                StreakAccessoryCircularView(entry: entry)
            case .accessoryInline:
                StreakAccessoryInlineView(entry: entry)
            #endif
            default:
                StreakSmallView(entry: entry)
            }
        }
        .widgetContainerBackground(Color(uiColor: .systemBackground))
    }
}

// MARK: - Small View
struct StreakSmallView: View {
    var entry: StreakEntry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("GÜNÜN SERİSİ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundColor(entry.currentStreak > 0 ? .orange : .secondary)
                    .font(.caption)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("\(entry.currentStreak)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("GÜN SERİ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Completion Status Pill
            HStack(spacing: 4) {
                Image(systemName: entry.isCompleted ? "checkmark.seal.fill" : "circle.dotted")
                    .font(.system(size: 10))
                    .foregroundColor(entry.isCompleted ? .green : .orange)
                
                Text(entry.isCompleted ? "Bugün Tamam" : "\(entry.todayCount)/\(entry.dailyGoal)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(entry.isCompleted ? .green : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(entry.isCompleted ? Color.green.opacity(0.15) : Color(uiColor: .secondarySystemBackground))
            )
        }
        .padding(12)
    }
}

// MARK: - Medium View
struct StreakMediumView: View {
    var entry: StreakEntry
    
    private var progressRatio: Double {
        guard entry.dailyGoal > 0 else { return 0 }
        return min(1.0, Double(entry.todayCount) / Double(entry.dailyGoal))
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left block: Streak badge
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundColor(entry.currentStreak > 0 ? .orange : .secondary)
                
                Text("\(entry.currentStreak)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Günlük Seri")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 90)
            
            Divider()
                .padding(.vertical, 8)
            
            // Right block: Today's progress and motivation
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bugünkü Zikir Hedefi")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    if entry.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(entry.isCompleted ? Color.green : Color.orange)
                            .frame(width: geo.size.width * CGFloat(progressRatio), height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(entry.todayCount) / \(entry.dailyGoal) Zikir")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.isCompleted ? "%100 Tamamlandı" : "%\(Int(progressRatio * 100))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(entry.isCompleted ? .green : .secondary)
                }
                
                Text(entry.isCompleted ? "Harika gidiyorsun! Zincirini korudun. ✨" : "Bugünkü hedefini tamamlayıp seriyi koru! 💪")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
    }
}

// MARK: - Lock Screen (Accessory) Views
#if swift(>=5.7)
struct StreakAccessoryCircularView: View {
    var entry: StreakEntry
    
    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
            Text("\(entry.currentStreak)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
            Text("GÜN")
                .font(.system(size: 8, weight: .bold))
        }
    }
}

struct StreakAccessoryInlineView: View {
    var entry: StreakEntry
    
    var body: some View {
        Text("🔥 \(entry.currentStreak) Günlük Zikir Serisi")
    }
}
#endif

// MARK: - Widget Configuration
struct StreakWidget: Widget {
    let kind: String = "StreakWidget"
    
    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakEntryView(entry: entry)
        }
        .configurationDisplayName("Günün Serisi")
        .description("Zikir serinizi ve günlük hedefinizi ana ekranınızdan takip edin.")
        .supportedFamilies(supportedFamilies)
    }
}
