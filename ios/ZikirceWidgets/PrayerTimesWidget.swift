import WidgetKit
import SwiftUI

// MARK: - Shared Timeline Provider for All Prayer & Clock Widgets
struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerTimesEntry {
        PrayerDataHelper.loadEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerTimesEntry) -> Void) {
        completion(PrayerDataHelper.loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimesEntry>) -> Void) {
        completion(PrayerDataHelper.buildTimeline())
    }
}

// MARK: - Theme Helpers for Prayer Widgets (Zikirce Design Language: Pure White Light / True Black Dark)
private struct WidgetThemePalette {
    let colorScheme: ColorScheme

    var cardBgStart: Color {
        colorScheme == .dark ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
    }
    var cardBgEnd: Color {
        colorScheme == .dark ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
    }
    var cardBorder: Color {
        colorScheme == .dark ? Color(hex: 0x222825) : Color(hex: 0xE0EBE7)
    }
    var textPrimary: Color {
        colorScheme == .dark ? Color(hex: 0xFFFFFF) : Color(hex: 0x1E2B27)
    }
    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: 0xA8B5B0) : Color(hex: 0x506861)
    }
    var goldAccent: Color {
        colorScheme == .dark ? Color(hex: 0xF7D15A) : Color(hex: 0xB57D15)
    }
    var emeraldAccent: Color {
        colorScheme == .dark ? Color(hex: 0x2DD4BF) : Color(hex: 0x236B56)
    }
    var pillBg: Color {
        colorScheme == .dark ? Color(hex: 0x121212) : Color(hex: 0xF4F8F6)
    }
    var pillBorder: Color {
        colorScheme == .dark ? Color(hex: 0xD4AF37).opacity(0.32) : Color(hex: 0xD8E5E1)
    }
    var activeRowBg: Color {
        colorScheme == .dark ? Color(hex: 0xD4AF37).opacity(0.16) : Color(hex: 0x236B56).opacity(0.10)
    }
}


// MARK: - 1. PrayerTimesWidget (Full 6-Prayer Table + Live Countdown + Lock Screen Support)
#if swift(>=5.7)
@available(iOS 16.0, *)
struct PrayerTimesAccessoryRectangularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(entry.city.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                }
                Text("\(entry.nextPrayerName) • \(entry.nextPrayerTime)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Text("Kalan:")
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.8)
                    LivePrayerCountdownText(
                        startDate: entry.date,
                        targetDate: entry.nextPrayerDate,
                        font: .system(size: 11, weight: .bold, design: .monospaced),
                        alignment: .leading
                    )
                }
            }
            Spacer()
        }
    }
}

@available(iOS 16.0, *)
struct PrayerTimesAccessoryCircularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(entry.nextPrayerName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                Text(entry.nextPrayerTime)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .lineLimit(1)
            }
        }
    }
}

@available(iOS 16.0, *)
struct PrayerTimesAccessoryInlineView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        Text("🕌 \(entry.nextPrayerName): \(entry.nextPrayerTime)")
    }
}
#endif

struct PrayerTimesWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryRectangular:
                PrayerTimesAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryCircular:
                PrayerTimesAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                PrayerTimesAccessoryInlineView(entry: entry)
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
        let p = WidgetThemePalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(
                colors: [p.cardBgStart, p.cardBgEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: family == .systemLarge ? 8 : 5) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(p.goldAccent)
                            Text(entry.city)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(p.textPrimary)
                                .lineLimit(1)
                        }
                        Text(entry.hijriDate)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(p.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(entry.nextPrayerName) • \(entry.nextPrayerTime)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(p.goldAccent)
                        LivePrayerCountdownText(
                            startDate: entry.date,
                            targetDate: entry.nextPrayerDate,
                            font: .system(size: 14, weight: .bold, design: .monospaced),
                            color: p.emeraldAccent,
                            alignment: .trailing
                        )
                    }
                }
                .padding(.bottom, 2)

                Divider()
                    .background(p.cardBorder)

                // 6 Prayers Grid / Row
                let prayers: [(name: String, time: String, icon: String)] = [
                    ("İmsak", entry.fajr, "sparkles"),
                    ("Güneş", entry.sunrise, "sunrise.fill"),
                    ("Öğle", entry.dhuhr, "sun.max.fill"),
                    ("İkindi", entry.asr, "sun.haze.fill"),
                    ("Akşam", entry.maghrib, "sunset.fill"),
                    ("Yatsı", entry.isha, "moon.stars.fill")
                ]

                if family == .systemMedium {
                    HStack(spacing: 4) {
                        ForEach(prayers, id: \.name) { item in
                            let isNext = item.name == entry.nextPrayerName
                            VStack(spacing: 3) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(isNext ? p.goldAccent : p.textSecondary)
                                Text(item.name)
                                    .font(.system(size: 10, weight: isNext ? .bold : .medium))
                                    .foregroundColor(isNext ? p.textPrimary : p.textSecondary)
                                    .lineLimit(1)
                                Text(item.time)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(isNext ? p.goldAccent : p.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isNext ? p.activeRowBg : Color.clear)
                            )
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        ForEach(prayers, id: \.name) { item in
                            let isNext = item.name == entry.nextPrayerName
                            HStack {
                                Image(systemName: item.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(isNext ? p.goldAccent : p.textSecondary)
                                    .frame(width: 20)
                                Text(item.name)
                                    .font(.system(size: 13, weight: isNext ? .bold : .medium))
                                    .foregroundColor(isNext ? p.textPrimary : p.textSecondary)
                                Spacer()
                                Text(item.time)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(isNext ? p.goldAccent : p.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isNext ? p.activeRowBg : Color.clear)
                            )
                        }
                    }
                }
            }
            .padding(12)
        }
        .widgetBackground(p.cardBgStart)
    }
}

struct PrayerTimesWidget: Widget {
    let kind: String = "PrayerTimesWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        } else {
            return [.systemMedium, .systemLarge]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerTimesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Namaz Vakitleri Tablosu")
        .description("Günlük 6 vakit namaz tablosu ve canlı geri sayım sayacı.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 2. PrayerTimesMiniWidget (Compact 6-Prayer Strip)
struct PrayerTimesMiniWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let p = WidgetThemePalette(colorScheme: colorScheme)
        let prayers: [(name: String, time: String)] = [
            ("İmsak", entry.fajr),
            ("Güneş", entry.sunrise),
            ("Öğle", entry.dhuhr),
            ("İkindi", entry.asr),
            ("Akşam", entry.maghrib),
            ("Yatsı", entry.isha)
        ]

        ZStack {
            LinearGradient(colors: [p.cardBgStart, p.cardBgEnd], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 6) {
                HStack {
                    Text(entry.city)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(p.textPrimary)
                    Spacer()
                    Text("\(entry.nextPrayerName) vaktine:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(p.textSecondary)
                    LivePrayerCountdownText(
                        startDate: entry.date,
                        targetDate: entry.nextPrayerDate,
                        font: .system(size: 11, weight: .bold, design: .monospaced),
                        color: p.goldAccent,
                        alignment: .trailing
                    )
                    .frame(width: 62)
                }

                HStack(spacing: 3) {
                    ForEach(prayers, id: \.name) { item in
                        let isNext = item.name == entry.nextPrayerName
                        VStack(spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 9, weight: isNext ? .bold : .medium))
                                .foregroundColor(isNext ? p.goldAccent : p.textSecondary)
                                .lineLimit(1)
                            Text(item.time)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(isNext ? p.textPrimary : p.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isNext ? p.activeRowBg : Color.clear)
                        )
                    }
                }
            }
            .padding(10)
        }
        .widgetBackground(p.cardBgStart)
    }
}

struct PrayerTimesMiniWidget: Widget {
    let kind: String = "PrayerTimesMiniWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerTimesMiniWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mini Vakit Şeridi")
        .description("Kompakt yatay namaz vakitleri şeridi ve canlı sayaç.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 3. PrayerCountdownWidget (Focused Countdown Card + Lock Screen Support)
#if swift(>=5.7)
@available(iOS 16.0, *)
struct PrayerCountdownAccessoryRectangularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .bold))
                Text("\(entry.nextPrayerName) Vaktine")
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
            LivePrayerCountdownText(
                startDate: entry.date,
                targetDate: entry.nextPrayerDate,
                font: .system(size: 15, weight: .heavy, design: .monospaced),
                alignment: .leading
            )
            Text("\(entry.city) • \(entry.nextPrayerTime)")
                .font(.system(size: 9, weight: .medium))
                .opacity(0.8)
        }
    }
}

@available(iOS 16.0, *)
struct PrayerCountdownAccessoryCircularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        Gauge(value: max(0.0, min(1.0, 1.0 - entry.progress)), in: 0...1) {
            Image(systemName: "timer")
        } currentValueLabel: {
            Text(entry.nextPrayerName.prefix(3).uppercased())
                .font(.system(size: 9, weight: .heavy))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

@available(iOS 16.0, *)
struct PrayerCountdownAccessoryInlineView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        Text("⏳ \(entry.nextPrayerName): \(entry.nextPrayerTime)")
    }
}

@available(iOS 16.0, *)
struct PrayerDigitalClockAccessoryRectangularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(entry.date, style: .time)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                Spacer()
                Text(entry.city)
                    .font(.system(size: 9, weight: .medium))
                    .opacity(0.8)
            }
            Text("\(entry.nextPrayerName) • \(entry.nextPrayerTime)")
                .font(.system(size: 11, weight: .bold))
            LivePrayerCountdownText(
                startDate: entry.date,
                targetDate: entry.nextPrayerDate,
                font: .system(size: 10, weight: .bold, design: .monospaced),
                alignment: .leading
            )
        }
    }
}

@available(iOS 16.0, *)
struct PrayerDigitalClockAccessoryInlineView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        Text("⏰ \(entry.nextPrayerName): \(entry.nextPrayerTime)")
    }
}
#endif

struct PrayerCountdownWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryRectangular:
                PrayerCountdownAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryCircular:
                PrayerCountdownAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                PrayerCountdownAccessoryInlineView(entry: entry)
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
        let p = WidgetThemePalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(colors: [p.cardBgStart, p.cardBgEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(p.goldAccent)
                    Text(entry.city)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(p.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(entry.nextPrayerName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(p.textPrimary)

                Text("Vakit: \(entry.nextPrayerTime)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(p.goldAccent)

                LivePrayerCountdownText(
                    startDate: entry.date,
                    targetDate: entry.nextPrayerDate,
                    font: .system(size: 18, weight: .heavy, design: .monospaced),
                    color: p.emeraldAccent,
                    alignment: .leading
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(p.pillBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.pillBorder, lineWidth: 1))
                )
            }
            .padding(12)
        }
        .widgetBackground(p.cardBgStart)
    }
}

struct PrayerCountdownWidget: Widget {
    let kind: String = "PrayerCountdownWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerCountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Vakit Geri Sayım")
        .description("Sıradaki namaz vaktine kalan süreyi saniye saniye gösterir.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 4. PrayerDigitalClockWidget (Digital Clock + Next Prayer Countdown + Lock Screen Support)
struct PrayerDigitalClockWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryRectangular:
                PrayerDigitalClockAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                PrayerDigitalClockAccessoryInlineView(entry: entry)
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
        let p = WidgetThemePalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(colors: [p.cardBgStart, p.cardBgEnd], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 6) {
                HStack {
                    Text(entry.city)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(p.goldAccent)
                    Spacer()
                    Text(entry.hijriDate)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(p.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(entry.date, style: .time)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(p.textPrimary)

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.nextPrayerName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(p.textPrimary)
                        Text(entry.nextPrayerTime)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(p.goldAccent)
                    }
                    Spacer()
                    LivePrayerCountdownText(
                        startDate: entry.date,
                        targetDate: entry.nextPrayerDate,
                        font: .system(size: 13, weight: .bold, design: .monospaced),
                        color: p.emeraldAccent,
                        alignment: .trailing
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(p.pillBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.pillBorder, lineWidth: 1))
                )
            }
            .padding(12)
        }
        .widgetBackground(p.cardBgStart)
    }
}

struct PrayerDigitalClockWidget: Widget {
    let kind: String = "PrayerDigitalClockWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerDigitalClockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dijital Vakit Saati")
        .description("Dijital saat, hicri takvim ve sıradaki vakit geri sayımı.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 5. PrayerAnalogClockWidget (Zikirce Rounded 8-Pointed Seljuk Star & Tesbih Analog Clock)
struct SeljukAnalogClockDialView: View {
    let entry: PrayerTimesEntry
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            let p = WidgetThemePalette(colorScheme: colorScheme)
            let bottomBarHeight: CGFloat = max(18.0, geo.size.height * 0.118)
            let clockSide = min(geo.size.width, max(60.0, geo.size.height - bottomBarHeight - 1.5))

            VStack(spacing: 1) {
                // 1. Upper Main Area: Zikirce Rounded 8-Pointed Seljuk Star + Brown Tesbih Clock (Minimal Margin)
                ZStack {
                    Canvas { context, size in
                        let cx = size.width / 2.0
                        let cy = size.height / 2.0
                        // Outer rosette max radius is 55.0 + 42.8 = 97.8 (diameter 195.6); scale to fill clockSide
                        let scale = min(size.width, size.height) / 197.0

                        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                            CGPoint(x: cx + (x - 110.0) * scale, y: cy + (y - 110.0) * scale)
                        }

                        // Exact 8-Lobed Rosette Path from ZikirceLogoPainter (rc = 55.0)
                        func rosettePath(rLobe: CGFloat, rCenter: CGFloat) -> Path {
                            var path = Path()
                            let rc: CGFloat = 55.0 * scale
                            let rl = rLobe * scale
                            let r0 = rCenter * scale
                            path.addEllipse(in: CGRect(x: cx - r0, y: cy - r0, width: r0 * 2, height: r0 * 2))
                            for k in 0..<8 {
                                let angle = Double(k) * .pi / 4.0
                                let lcx = cx + CGFloat(cos(angle)) * rc
                                let lcy = cy + CGFloat(sin(angle)) * rc
                                path.addEllipse(in: CGRect(x: lcx - rl, y: lcy - rl, width: rl * 2, height: rl * 2))
                            }
                            return path
                        }

                        let emeraldBorder = isDark ? Color(hex: 0x1B5E45) : Color(hex: 0x174D35)
                        let goldMain = Color(hex: 0xC8A353)
                        let goldHighlight = Color(hex: 0xE5C878)
                        // Filled warm cream dial in both Light and Dark themes
                        let dialFill = Color(hex: 0xF1EACA)
                        let hourDotColor = Color(hex: 0x174D35)
                        let minuteTickColor = Color(hex: 0x9E7B32)

                        // Canonical Zikirce Logo Brown Tesbih Palette
                        let tesbihDark = Color(hex: 0x442410)
                        let tesbihMid = Color(hex: 0x62371A)
                        let tesbihLight = Color(hex: 0x86522B)

                        // Layer 1: Outer Emerald 8-Lobed Rosette (rLobe=42.8, rCusp=88.08)
                        let outerRosette = rosettePath(rLobe: 42.8, rCenter: 88.08)
                        context.fill(outerRosette, with: .color(emeraldBorder))

                        // Layer 2: Middle Burnished Gold 8-Lobed Rosette (rLobe=32.5, rCusp=75.58)
                        let goldRosette = rosettePath(rLobe: 32.5, rCenter: 75.58)
                        context.fill(goldRosette, with: .color(goldMain))

                        // Layer 3: Inner Warm Cream Dial Rosette (rLobe=25.5, rCusp=65.0)
                        let innerRosette = rosettePath(rLobe: 25.5, rCenter: 65.0)
                        context.fill(innerRosette, with: .color(dialFill))

                        // Proportional Circular Dial Track (R = 58.5):
                        // - Full hours represented by a dot each (r = 1.85)
                        // - 4 thin minute lines between adjacent hours (R = 57.1 .. 59.9)
                        let rTrack: CGFloat = 58.5 * scale
                        let rMinIn: CGFloat = 57.1 * scale
                        let rMinOut: CGFloat = 59.9 * scale
                        let dotR: CGFloat = 1.85 * scale

                        for m in 0..<60 {
                            let angle = (Double(m) * 6.0 - 90.0) * .pi / 180.0
                            let cosA = CGFloat(cos(angle))
                            let sinA = CGFloat(sin(angle))
                            if m % 5 == 0 {
                                let dcx = cx + cosA * rTrack
                                let dcy = cy + sinA * rTrack
                                let dRect = CGRect(x: dcx - dotR, y: dcy - dotR, width: dotR * 2, height: dotR * 2)
                                context.fill(Path(ellipseIn: dRect), with: .color(hourDotColor))
                            } else {
                                var tick = Path()
                                tick.move(to: CGPoint(x: cx + cosA * rMinIn, y: cy + sinA * rMinIn))
                                tick.addLine(to: CGPoint(x: cx + cosA * rMinOut, y: cy + sinA * rMinOut))
                                context.stroke(
                                    tick,
                                    with: .color(minuteTickColor),
                                    style: StrokeStyle(lineWidth: 0.95 * scale, lineCap: .round)
                                )
                            }
                        }

                        // Exact ZikirceLogoPainter Brown Tesbih
                        var strap = Path()
                        strap.move(to: pt(147.2, 41.5))
                        strap.addCurve(to: pt(156.2, 35.2), control1: pt(148.5, 36.5), control2: pt(152.0, 33.8))
                        strap.addCurve(to: pt(160.2, 40.5), control1: pt(159.0, 36.2), control2: pt(160.8, 38.8))
                        strap.addCurve(to: pt(152.2, 40.5), control1: pt(157.5, 38.8), control2: pt(154.5, 38.6))
                        strap.addCurve(to: pt(147.2, 41.5), control1: pt(150.5, 41.8), control2: pt(148.8, 43.2))
                        strap.closeSubpath()
                        context.fill(strap, with: .color(tesbihDark))

                        var cord = Path()
                        cord.move(to: pt(147.2, 43.0))
                        cord.addCurve(to: pt(149.2, 78.5), control1: pt(144.2, 53.0), control2: pt(144.0, 67.0))
                        cord.addCurve(to: pt(165.0, 101.5), control1: pt(153.2, 87.0), control2: pt(159.5, 95.0))
                        cord.move(to: pt(181.5, 76.3))
                        cord.addCurve(to: pt(165.0, 101.5), control1: pt(180.5, 84.5), control2: pt(175.0, 94.5))
                        context.stroke(cord, with: .color(tesbihDark), lineWidth: 1.5 * scale)

                        let beadCoords: [(CGFloat, CGFloat)] = [
                            (147.2, 43.0), (145.6, 48.6), (144.8, 54.5), (144.5, 60.5), (145.0, 66.5),
                            (146.5, 72.6), (149.2, 78.5), (152.8, 84.2), (157.0, 89.6), (161.2, 95.0),
                            (181.5, 76.3), (180.6, 82.2), (178.2, 88.0), (174.4, 93.4), (169.8, 97.8)
                        ]
                        let beadR = 2.85 * scale
                        let hiR = 0.85 * scale
                        for (bx, by) in beadCoords {
                            let c = pt(bx, by)
                            let bRect = CGRect(x: c.x - beadR, y: c.y - beadR, width: beadR * 2, height: beadR * 2)
                            context.fill(Path(ellipseIn: bRect), with: .color(tesbihMid))
                            context.stroke(Path(ellipseIn: bRect), with: .color(tesbihDark), lineWidth: 0.85 * scale)
                            let hRect = CGRect(x: c.x - beadR * 0.4, y: c.y - beadR * 0.4, width: hiR * 2, height: hiR * 2)
                            context.fill(Path(ellipseIn: hRect), with: .color(tesbihLight))
                        }

                        // Knot Bead at (165.0, 101.5)
                        let knotCenter = pt(165.0, 101.5)
                        let knotR = 3.1 * scale
                        let knotRect = CGRect(x: knotCenter.x - knotR, y: knotCenter.y - knotR, width: knotR * 2, height: knotR * 2)
                        context.fill(Path(ellipseIn: knotRect), with: .color(tesbihMid))
                        context.stroke(Path(ellipseIn: knotRect), with: .color(tesbihDark), lineWidth: 0.95 * scale)

                        // Imame Body + Small Tip Bead (x=165.0, y=104.2..110.8)
                        var imame = Path()
                        imame.move(to: pt(163.8, 104.2))
                        imame.addLine(to: pt(166.2, 104.2))
                        imame.addCurve(to: pt(166.4, 110.2), control1: pt(166.7, 106.5), control2: pt(166.0, 108.8))
                        imame.addLine(to: pt(163.6, 110.2))
                        imame.addCurve(to: pt(163.8, 104.2), control1: pt(164.0, 108.8), control2: pt(163.3, 106.5))
                        imame.closeSubpath()
                        context.fill(imame, with: .color(tesbihMid))
                        context.stroke(imame, with: .color(tesbihDark), lineWidth: 0.85 * scale)

                        let tipCenter = pt(165.0, 110.6)
                        let tipR = 1.75 * scale
                        let tipRect = CGRect(x: tipCenter.x - tipR, y: tipCenter.y - tipR, width: tipR * 2, height: tipR * 2)
                        context.fill(Path(ellipseIn: tipRect), with: .color(tesbihMid))
                        context.stroke(Path(ellipseIn: tipRect), with: .color(tesbihDark), lineWidth: 0.85 * scale)

                        // Tassel (Püskül) at x=161.0..169.0, y=111.8..124.2
                        var tassel = Path()
                        tassel.move(to: pt(164.0, 111.8))
                        tassel.addLine(to: pt(166.0, 111.8))
                        tassel.addCurve(to: pt(169.0, 123.6), control1: pt(167.2, 115.2), control2: pt(168.4, 119.5))
                        tassel.addCurve(to: pt(161.0, 123.6), control1: pt(166.5, 124.5), control2: pt(163.5, 124.5))
                        tassel.addCurve(to: pt(164.0, 111.8), control1: pt(161.6, 119.5), control2: pt(162.8, 115.2))
                        tassel.closeSubpath()
                        context.fill(tassel, with: .color(tesbihDark))

                        var tasselThreads = Path()
                        tasselThreads.move(to: pt(165.0, 112.5))
                        tasselThreads.addLine(to: pt(165.0, 123.8))
                        tasselThreads.move(to: pt(164.1, 112.8))
                        tasselThreads.addLine(to: pt(162.7, 123.4))
                        tasselThreads.move(to: pt(165.9, 112.8))
                        tasselThreads.addLine(to: pt(167.3, 123.4))
                        context.stroke(tasselThreads, with: .color(tesbihLight), lineWidth: 0.7 * scale)

                        // Classic Dauphine Hands (Hour, Minute) + Red Second Hand
                        let cal = Calendar.current
                        let comps = cal.dateComponents([.hour, .minute, .second], from: entry.date)
                        let hour = Double(comps.hour ?? 0).truncatingRemainder(dividingBy: 12.0)
                        let minute = Double(comps.minute ?? 0)
                        let second = Double(comps.second ?? 0)

                        let hourAngle = ((hour + minute / 60.0) * 30.0 - 90.0) * .pi / 180.0
                        let minuteAngle = ((minute + second / 60.0) * 6.0 - 90.0) * .pi / 180.0
                        let secondAngle = (second * 6.0 - 90.0) * .pi / 180.0

                        let handFill = Color(hex: 0x163A2B)
                        let redSecond = Color(hex: 0xDC2626)

                        func drawDauphineHand(angle: Double, length: CGFloat, halfWidth: CGFloat, tail: CGFloat, fill: Color, stroke: Color) {
                            let ux = CGFloat(cos(angle))
                            let uy = CGFloat(sin(angle))
                            let px = -uy
                            let py = ux

                            let tip = CGPoint(x: cx + ux * length, y: cy + uy * length)
                            let tailPt = CGPoint(x: cx - ux * tail, y: cy - uy * tail)
                            let shoulderDist = length * 0.12
                            let leftWing = CGPoint(x: cx + ux * shoulderDist + px * halfWidth, y: cy + uy * shoulderDist + py * halfWidth)
                            let rightWing = CGPoint(x: cx + ux * shoulderDist - px * halfWidth, y: cy + uy * shoulderDist - py * halfWidth)

                            var hand = Path()
                            hand.move(to: tailPt)
                            hand.addLine(to: leftWing)
                            hand.addLine(to: tip)
                            hand.addLine(to: rightWing)
                            hand.closeSubpath()

                            context.fill(hand, with: .color(fill))
                            context.stroke(hand, with: .color(stroke), lineWidth: 0.9 * scale)
                        }

                        drawDauphineHand(
                            angle: hourAngle,
                            length: 37.0 * scale,
                            halfWidth: 3.9 * scale,
                            tail: 8.5 * scale,
                            fill: handFill,
                            stroke: goldMain
                        )
                        drawDauphineHand(
                            angle: minuteAngle,
                            length: 50.5 * scale,
                            halfWidth: 3.0 * scale,
                            tail: 10.0 * scale,
                            fill: handFill,
                            stroke: goldMain
                        )

                        // Center Gold Bezel Ring
                        let bossR = 4.5 * scale
                        let bossRect = CGRect(x: cx - bossR, y: cy - bossR, width: bossR * 2, height: bossR * 2)
                        context.fill(Path(ellipseIn: bossRect), with: .color(goldMain))

                        // Classic Red Second Hand
                        var secHand = Path()
                        secHand.move(to: CGPoint(x: cx - CGFloat(cos(secondAngle)) * 14.5 * scale, y: cy - CGFloat(sin(secondAngle)) * 14.5 * scale))
                        secHand.addLine(to: CGPoint(x: cx + CGFloat(cos(secondAngle)) * 54.0 * scale, y: cy + CGFloat(sin(secondAngle)) * 54.0 * scale))
                        context.stroke(secHand, with: .color(redSecond), style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))

                        let redCapR = 2.7 * scale
                        let redCapRect = CGRect(x: cx - redCapR, y: cy - redCapR, width: redCapR * 2, height: redCapR * 2)
                        context.fill(Path(ellipseIn: redCapRect), with: .color(redSecond))

                        let pinR = 1.0 * scale
                        let pinRect = CGRect(x: cx - pinR, y: cy - pinR, width: pinR * 2, height: pinR * 2)
                        context.fill(Path(ellipseIn: pinRect), with: .color(goldHighlight))
                    }

                    // Cardinal Numerals: 12 - 3 - 6 - 9 in the 4 cardinal lobes (R = 71.2 / 197.0 = 0.361)
                    let dialTextPrimary = Color(hex: 0x1E2B27)
                    let dialTextSecondary = Color(hex: 0x236B56)
                    let numRadius = clockSide * 0.361
                    let numFont = Font.system(size: clockSide * 0.058, weight: .bold, design: .rounded)
                    Text("12")
                        .font(numFont)
                        .foregroundColor(dialTextPrimary)
                        .offset(y: -numRadius)
                    Text("3")
                        .font(numFont)
                        .foregroundColor(dialTextPrimary)
                        .offset(x: numRadius)
                    Text("6")
                        .font(numFont)
                        .foregroundColor(dialTextPrimary)
                        .offset(y: numRadius)
                    Text("9")
                        .font(numFont)
                        .foregroundColor(dialTextPrimary)
                        .offset(x: -numRadius)

                    // Subtle Upper-Center Upcoming Prayer Name & Exact Time
                    VStack(spacing: 0) {
                        Text(entry.nextPrayerName)
                            .font(.system(size: clockSide * 0.048, weight: .semibold))
                            .foregroundColor(dialTextSecondary)
                            .lineLimit(1)
                        Text(entry.nextPrayerTime)
                            .font(.system(size: clockSide * 0.054, weight: .bold, design: .rounded))
                            .foregroundColor(dialTextPrimary)
                            .lineLimit(1)
                    }
                    .offset(y: -clockSide * 0.145)
                }
                .frame(width: clockSide, height: clockSide)


                // 2. Bottom Bar Outside the Clock: Elegant Live Countdown Timer
                LivePrayerCountdownText(
                    startDate: entry.date,
                    targetDate: entry.nextPrayerDate,
                    font: .system(size: max(10.5, bottomBarHeight * 0.56), weight: .bold, design: .monospaced),
                    color: isDark ? Color(hex: 0xF7D15A) : Color(hex: 0x1E2B27),
                    alignment: .center
                )
                .padding(.horizontal, 10)
                .frame(height: bottomBarHeight)
                .background(
                    Capsule()
                        .fill(p.pillBg)
                        .overlay(
                            Capsule()
                                .stroke(p.pillBorder, lineWidth: 1.0)
                        )
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct PrayerAnalogClockWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let p = WidgetThemePalette(colorScheme: colorScheme)
        ZStack {
            p.cardBgStart
            SeljukAnalogClockDialView(entry: entry, colorScheme: colorScheme)
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
        }
        .widgetBackground(p.cardBgStart)
    }
}

struct PrayerAnalogClockWidget: Widget {
    let kind: String = "PrayerAnalogClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerAnalogClockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Selçuklu Yıldızı Analog Saat")
        .description("Zikirce 8 köşeli Selçuklu yıldızı ve tesbih çerçeveli analog saat, alt bölümde canlı geri sayım sayacı.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}


// MARK: - 6. PrayerNextWidget (Next Prayer + Following Prayer Card + Lock Screen Support)
#if swift(>=5.7)
@available(iOS 16.0, *)
struct PrayerNextAccessoryRectangularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("SIRADAKİ VAKİT")
                    .font(.system(size: 9, weight: .bold))
            }
            Text("\(entry.nextPrayerName) • \(entry.nextPrayerTime)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1)
            HStack(spacing: 3) {
                Text("Kalan:")
                    .font(.system(size: 9, weight: .medium))
                    .opacity(0.8)
                LivePrayerCountdownText(
                    startDate: entry.date,
                    targetDate: entry.nextPrayerDate,
                    font: .system(size: 11, weight: .bold, design: .monospaced),
                    alignment: .leading
                )
            }
        }
    }
}

@available(iOS 16.0, *)
struct PrayerNextAccessoryCircularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(entry.nextPrayerName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                Text(entry.nextPrayerTime)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .lineLimit(1)
            }
        }
    }
}

@available(iOS 16.0, *)
struct PrayerNextAccessoryInlineView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        Text("🔔 \(entry.nextPrayerName): \(entry.nextPrayerTime)")
    }
}

@available(iOS 16.0, *)
struct PrayerMiniAccessoryCircularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 11))
                Text(entry.nextPrayerName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                Text(entry.nextPrayerTime)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .lineLimit(1)
            }
        }
    }
}

@available(iOS 16.0, *)
struct PrayerMiniAccessoryRectangularView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VAKİT: \(entry.nextPrayerName)")
                    .font(.system(size: 10, weight: .bold))
                Text(entry.nextPrayerTime)
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                Text(entry.city)
                    .font(.system(size: 9, weight: .medium))
                    .opacity(0.8)
            }
            Spacer()
        }
    }
}

@available(iOS 16.0, *)
struct PrayerMiniAccessoryInlineView: View {
    var entry: PrayerTimesEntry

    var body: some View {
        Text("🕌 \(entry.nextPrayerName): \(entry.nextPrayerTime)")
    }
}
#endif

struct PrayerNextWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryRectangular:
                PrayerNextAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryCircular:
                PrayerNextAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                PrayerNextAccessoryInlineView(entry: entry)
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
        let p = WidgetThemePalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(colors: [p.cardBgStart, p.cardBgEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.city)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(p.goldAccent)
                    Spacer()
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 11))
                        .foregroundColor(p.emeraldAccent)
                }

                Spacer()

                Text("SIRADAKİ VAKİT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(p.textSecondary)

                HStack(alignment: .firstTextBaseline) {
                    Text(entry.nextPrayerName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(p.textPrimary)
                    Spacer()
                    Text(entry.nextPrayerTime)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(p.goldAccent)
                }

                LivePrayerCountdownText(
                    startDate: entry.date,
                    targetDate: entry.nextPrayerDate,
                    font: .system(size: 15, weight: .heavy, design: .monospaced),
                    color: p.emeraldAccent,
                    alignment: .leading
                )
            }
            .padding(12)
        }
        .widgetBackground(p.cardBgStart)
    }
}

struct PrayerNextWidget: Widget {
    let kind: String = "PrayerNextWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        } else {
            return [.systemSmall]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerNextWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sıradaki Vakit Kartı")
        .description("Sıradaki namaz vaktini, saatini ve canlı geri sayımını gösterir.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - 7. PrayerMiniWidget (Minimalist 1x1 / Small Pill Widget + Lock Screen Support)
struct PrayerMiniWidgetEntryView: View {
    var entry: PrayerTimesEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryCircular:
                PrayerMiniAccessoryCircularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryRectangular:
                PrayerMiniAccessoryRectangularView(entry: entry)
                    .widgetBackground(Color.clear)
            case .accessoryInline:
                PrayerMiniAccessoryInlineView(entry: entry)
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
        let p = WidgetThemePalette(colorScheme: colorScheme)
        ZStack {
            LinearGradient(colors: [p.cardBgStart, p.cardBgEnd], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16))
                    .foregroundColor(p.goldAccent)
                Text(entry.nextPrayerName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(p.textPrimary)
                Text(entry.nextPrayerTime)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundColor(p.goldAccent)
                LivePrayerCountdownText(
                    startDate: entry.date,
                    targetDate: entry.nextPrayerDate,
                    font: .system(size: 12, weight: .bold, design: .monospaced),
                    color: p.emeraldAccent,
                    alignment: .center
                )
            }
            .padding(10)
        }
        .widgetBackground(p.cardBgStart)
    }
}

struct PrayerMiniWidget: Widget {
    let kind: String = "PrayerMiniWidget"

    private var supportedFamiliesList: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerMiniWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Minimal Vakit")
        .description("Kompakt sıradaki vakit saati ve canlı geri sayım.")
        .supportedFamilies(supportedFamiliesList)
        .contentMarginsDisabledIfAvailable()
    }
}

// MARK: - Helper WidgetConfiguration for iOS 17+ contentMarginsDisabled compatibility

extension WidgetConfiguration {
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 17.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}
