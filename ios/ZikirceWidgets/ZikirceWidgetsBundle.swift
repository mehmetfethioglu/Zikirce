import WidgetKit
import SwiftUI

struct PrayerWidgetsGroup: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        PrayerTimesMiniWidget()
        PrayerCountdownWidget()
        PrayerDigitalClockWidget()
        PrayerAnalogClockWidget()
        PrayerNextWidget()
        PrayerMiniWidget()
    }
}

struct SpiritualWidgetsGroup: WidgetBundle {
    var body: some Widget {
        HijriCalendarWidget()
        PrayerKazaWidget()
        KazaQuickWidget()
        KalpSagligiWidget()
        ZikirCounterWidget()
        StreakWidget()
    }
}

@main
struct ZikirceWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidgetsGroup().body
        SpiritualWidgetsGroup().body
    }
}
