import WidgetKit
import SwiftUI

// MARK: - Shared Timeline Providers for Spiritual, Kaza & Streak Widgets
struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakDataHelper.loadEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakDataHelper.loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = StreakDataHelper.loadEntry()
        // Reload at midnight for weekly streak calendar transition
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct KazaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> KazaEntry {
        KazaDataHelper.loadEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (KazaEntry) -> Void) {
        completion(KazaDataHelper.loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KazaEntry>) -> Void) {
        let entry = KazaDataHelper.loadEntry()
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - Theme Palette for Spiritual Widgets (Zikirce Design Language: Pure White Light / True Black Dark)
private struct SpiritualPalette {
    let colorScheme: ColorScheme

    var bgStart: Color {
        colorScheme == .dark ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
    }
    var bgEnd: Color {
        colorScheme == .dark ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
    }
    var textPrimary: Color {
        colorScheme == .dark ? Color(hex: 0xFFFFFF) : Color(hex: 0x1E2B27)
    }
    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: 0xA8B5B0) : Color(hex: 0x506861)
    }
    var gold: Color {
        colorScheme == .dark ? Color(hex: 0xF7D15A) : Color(hex: 0xB57D15)
    }
    var emerald: Color {
        colorScheme == .dark ? Color(hex: 0x2DD4BF) : Color(hex: 0x236B56)
    }
    var cardSurface: Color {
        colorScheme == .dark ? Color(hex: 0x121212) : Color(hex: 0xF4F8F6)
    }
}


// MARK: - 8. HijriCalendarWidget (Hijri & Gregorian Date + Next Prayer Countdown + Lock Screen Support)
#if swift(>=5.7)
@available(iOS 16.0, *)
struct HijriCalendarAccessoryRectangularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 9, weight: .bold))
                Text("HİCRİ TAKVİM")
                    .font(.system(size: 9, weight: .bold))
                Spacer()
                Text(entry.city)
                    .font(.system(size: 9, weight: .medium))
                    .opacity(0.8)
            }
            Text(entry.hijriDate)
                .font(.system(size: 12, weight: .bold, design: .serif))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text("\(entry.nextPrayerName): \(entry.nextPrayerTime)")
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                LivePrayerCountdownText(
                    startDate: entry.date,
                    targetDate: entry.nextPrayerDate,
                    font: .system(size: 10, weight: .bold, design: .monospaced),
                    alignment: .trailing
                )
            }
        }
    }
}

@available(iOS 16.0, *)
struct HijriCalendarAccessoryInlineView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        Text("🌙 \(entry.hijriDate)")
    }
}

@available(iOS 16.0, *)
struct KazaAccessoryCircularView: View {
    var entry: KazaEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                Text("\(entry.totalDebt)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Text("KAZA")
                    .font(.system(size: 8, weight: .bold))
            }
        }
    }
}

@available(iOS 16.0, *)
struct KazaAccessoryRectangularView: View {
    var entry: KazaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                Text("Kaza Borcu")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(entry.totalDebt)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
            }
            Text("En Çok: \(entry.highestPrayerName) (\(entry.highestPrayerCount))")
                .font(.system(size: 9, weight: .medium))
                .opacity(0.8)
            Text(entry.hasCompletedToday ? "Bugün kaza kılındı ✓" : "Bugünkü kaza bekleniyor")
                .font(.system(size: 9, weight: .semibold))
                .opacity(0.9)
        }
    }
}

@available(iOS 16.0, *)
struct KazaAccessoryInlineView: View {
    var entry: KazaEntry

    var body: some View {
        Text("📋 Kaza Borcu: \(entry.totalDebt) Vakit")
    }
}

@available(iOS 16.0, *)
struct KalpSagligiAccessoryCircularView: View {
    var entry: StreakEntry

    var body: some View {
        Gauge(value: min(1.0, max(0.0, entry.progress)), in: 0...1) {
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text("%\(Int(entry.progress * 100))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

@available(iOS 16.0, *)
struct KalpSagligiAccessoryRectangularView: View {
    var entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Manevi Kalp")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("%\(Int(entry.progress * 100))")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            ProgressView(value: min(1.0, max(0.0, entry.progress)))
            Text("\(entry.streakCount) Gün Kesintisiz Seri")
                .font(.system(size: 9, weight: .medium))
                .opacity(0.8)
        }
    }
}

@available(iOS 16.0, *)
struct KalpSagligiAccessoryInlineView: View {
    var entry: StreakEntry

    var body: some View {
        Text("❤️ Kalp Sağlığı: %\(Int(entry.progress * 100)) • \(entry.streakCount) Gün")
    }
}

@available(iOS 16.0, *)
struct ZikirCounterAccessoryCircularView: View {
    var entry: StreakEntry

    var body: some View {
        Gauge(value: min(1.0, max(0.0, entry.progress)), in: 0...1) {
            Image(systemName: "circle.hexagongrid.fill")
        } currentValueLabel: {
            Text("\(entry.todayCount)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

@available(iOS 16.0, *)
struct ZikirCounterAccessoryRectangularView: View {
    var entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Günlük Zikir")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(entry.todayCount)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            ProgressView(value: min(1.0, max(0.0, entry.progress)))
            Text("Hedef: \(entry.dailyGoal) zikir")
                .font(.system(size: 9, weight: .medium))
                .opacity(0.8)
        }
    }
}

@available(iOS 16.0, *)
struct ZikirCounterAccessoryInlineView: View {
    var entry: StreakEntry

    var body: some View {
        Text("📿 Zikir: \(entry.todayCount) / \(entry.dailyGoal)")
    }
}

@available(iOS 16.0, *)
struct StreakAccessoryCircularView: View {
    var entry: StreakEntry

    var body: some View {
        Gauge(value: min(1.0, max(0.0, entry.progress)), in: 0...1) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.streakCount)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

@available(iOS 16.0, *)
struct StreakAccessoryRectangularView: View {
    var entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("\(entry.streakCount) Gün Seri")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(entry.todayCount)/\(entry.dailyGoal)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            ProgressView(value: min(1.0, max(0.0, entry.progress)))
            Text(entry.isCompleted ? "Bugünkü hedef tamamlandı ✨" : "Hedefe kalan: \(max(0, entry.dailyGoal - entry.todayCount))")
                .font(.system(size: 9, weight: .medium))
                .opacity(0.8)
                .lineLimit(1)
        }
    }
}

@available(iOS 16.0, *)
struct StreakAccessoryInlineView: View {
    var entry: StreakEntry

    var body: some View {
        Text("🔥 \(entry.streakCount) Gün Seri (\(entry.todayCount)/\(entry.dailyGoal))")
    }
}
#endif

struct HijriCalendarWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryRectangular:
                HijriCalendarAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                HijriCalendarAccessoryInlineView(entry: entry)
                    .widgetBackground(Color.clear)
            default:
                defaultContent
            }
        } else {
            defaultContent
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        let p = SpiritualPalette(colorScheme: colorScheme)
        let gregorianFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "d MMMM yyyy, EEEE"
            return df
        }()

        ZStack {
            LinearGradient(colors: [p.bgStart, p.bgEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(p.gold)
                    Text("HİCRİ TAKVİM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(p.gold)
                    Spacer()
                    Text(entry.city)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(p.textSecondary)
                }

                Spacer()

                Text(entry.hijriDate)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(p.textPrimary)
                    .lineLimit(1)

                Text(gregorianFormatter.string(from: entry.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(p.textSecondary)
                    .lineLimit(1)

                Spacer()

                HStack {
                    Text("\(entry.nextPrayerName) (\(entry.nextPrayerTime))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(p.textPrimary)
                    Spacer()
                    LivePrayerCountdownText(
                        startDate: entry.date,
                        targetDate: entry.nextPrayerDate,
                        font: .system(size: 12, weight: .bold, design: .monospaced),
                        color: p.emerald,
                        alignment: .trailing
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(p.cardSurface))
            }
            .padding(12)
        }
        .widgetBackground(p.bgStart)
    }
}

struct HijriCalendarWidget: Widget {
    let kind: String = "HijriCalendarWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            HijriCalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hicri Takvim")
        .description("Hicri ve Miladi takvim ile sıradaki namaz vaktine geri sayım.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 9. PrayerKazaWidget (Detailed Kaza Tracker)
struct PrayerKazaWidgetEntryView: View {
    var entry: KazaEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let p = SpiritualPalette(colorScheme: colorScheme)
        let items: [(String, Int)] = [
            ("Sabah", entry.fajr),
            ("Öğle", entry.dhuhr),
            ("İkindi", entry.asr),
            ("Akşam", entry.maghrib),
            ("Yatsı", entry.isha),
            ("Vitir", entry.witr)
        ]

        ZStack {
            LinearGradient(colors: [p.bgStart, p.bgEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(p.gold)
                    Text("Kaza Namazı Takibi")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(p.textPrimary)
                    Spacer()
                    Text("Toplam: \(entry.totalRemaining)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(p.emerald)
                }

                HStack(spacing: 4) {
                    ForEach(items, id: \.0) { item in
                        VStack(spacing: 2) {
                            Text(item.0)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(p.textSecondary)
                            Text("\(item.1)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(p.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(p.cardSurface))
                    }
                }
            }
            .padding(12)
        }
        .widgetBackground(p.bgStart)
    }
}

struct PrayerKazaWidget: Widget {
    let kind: String = "PrayerKazaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KazaTimelineProvider()) { entry in
            PrayerKazaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Kaza Namazı Tablosu")
        .description("Kalan kaza namazlarınızın vakit bazında detaylı özeti.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 10. KazaQuickWidget (Compact Kaza Summary + Lock Screen Support)
struct KazaQuickWidgetEntryView: View {
    var entry: KazaEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryCircular:
                KazaAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryRectangular:
                KazaAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                KazaAccessoryInlineView(entry: entry)
                    .widgetBackground(Color.clear)
            default:
                defaultContent
            }
        } else {
            defaultContent
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        let p = SpiritualPalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(colors: [p.bgStart, p.bgEnd], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 12))
                        .foregroundColor(p.gold)
                    Text("Kaza Özeti")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(p.textPrimary)
                }
                Spacer()
                Text("\(entry.totalRemaining)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(p.gold)
                Text("Kalan Vakit Borcu")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(p.textSecondary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.completedToday ? p.emerald : p.gold.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(entry.completedToday ? "Bugün kaza kılındı" : "Bugün bekleniyor")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(entry.completedToday ? p.emerald : p.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .widgetBackground(p.bgStart)
    }
}

struct KazaQuickWidget: Widget {
    let kind: String = "KazaQuickWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KazaTimelineProvider()) { entry in
            KazaQuickWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hızlı Kaza Özeti")
        .description("Toplam kalan kaza borcu ve günlük tamamlanma durumu.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 11. KalpSagligiWidget (Spiritual Heart Health / Manevi Kalp + Lock Screen Support)
struct KalpSagligiWidgetEntryView: View {
    var entry: StreakEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryCircular:
                KalpSagligiAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryRectangular:
                KalpSagligiAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                KalpSagligiAccessoryInlineView(entry: entry)
                    .widgetBackground(Color.clear)
            default:
                defaultContent
            }
        } else {
            defaultContent
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        let p = SpiritualPalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(colors: [p.bgStart, p.bgEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0xF43F5E))
                    Text("Manevi Kalp")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(p.textPrimary)
                    Spacer()
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(p.cardSurface, lineWidth: 6)
                        .frame(width: 58, height: 58)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, max(0.05, entry.progress))))
                        .stroke(p.emerald, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 58, height: 58)
                    Text("%\(Int(entry.progress * 100))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(p.textPrimary)
                }
                Spacer()
                Text("\(entry.streakCount) Günlük Seri")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(p.gold)
            }
            .padding(12)
        }
        .widgetBackground(p.bgStart)
    }
}

struct KalpSagligiWidget: Widget {
    let kind: String = "KalpSagligiWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            KalpSagligiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Manevi Kalp Sağlığı")
        .description("Günlük zikir hedefinize göre manevi kalp doluluk oranı.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 12. ZikirCounterWidget (Daily Zikir Goal Progress + Lock Screen Support)
struct ZikirCounterWidgetEntryView: View {
    var entry: StreakEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryCircular:
                ZikirCounterAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryRectangular:
                ZikirCounterAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                ZikirCounterAccessoryInlineView(entry: entry)
                    .widgetBackground(Color.clear)
            default:
                defaultContent
            }
        } else {
            defaultContent
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        let p = SpiritualPalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(colors: [p.bgStart, p.bgEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 12))
                        .foregroundColor(p.gold)
                    Text("Günlük Zikir")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(p.textPrimary)
                }
                Spacer()
                Text("\(entry.todayCount)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(p.emerald)
                Text("Hedef: \(entry.dailyGoal)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(p.textSecondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(p.cardSurface)
                            .frame(height: 6)
                        Capsule()
                            .fill(p.gold)
                            .frame(width: geo.size.width * CGFloat(entry.progress), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(12)
        }
        .widgetBackground(p.bgStart)
    }
}

struct ZikirCounterWidget: Widget {
    let kind: String = "ZikirCounterWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            ZikirCounterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Zikir Sayacı")
        .description("Günlük çekilen zikir sayısı ve hedef ilerleme çubuğu.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 13. StreakWidget (Weekly Streak & Chain Tracker + Lock Screen Support)
struct StreakWidgetEntryView: View {
    var entry: StreakEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryCircular:
                StreakAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryRectangular:
                StreakAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                StreakAccessoryInlineView(entry: entry)
                    .widgetBackground(Color.clear)
            default:
                defaultContent
            }
        } else {
            defaultContent
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        let p = SpiritualPalette(colorScheme: colorScheme)
        let days = ["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"]

        ZStack {
            LinearGradient(colors: [p.bgStart, p.bgEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0xF59E0B))
                    Text("\(entry.streakCount) Gün Seri")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(p.textPrimary)
                    Spacer()
                    Text("\(entry.todayCount)/\(entry.dailyGoal)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(p.emerald)
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<min(7, entry.weekDaysCompleted.count), id: \.self) { idx in
                        let done = entry.weekDaysCompleted[idx]
                        VStack(spacing: 3) {
                            Text(days[idx])
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(p.textSecondary)
                            Circle()
                                .fill(done ? p.emerald : p.cardSurface)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(done ? .white : .clear)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(12)
        }
        .widgetBackground(p.bgStart)
    }
}

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Zikir Zinciri (Seri)")
        .description("Haftalık zikir zinciri ve kesintisiz seri takibi.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}
