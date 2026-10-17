import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zikirce/core/services/prayer_times_service.dart';
import 'package:zikirce/core/services/widget_sync_service.dart';
import 'package:zikirce/features/namaz_vakitleri/presentation/widgets/analog_prayer_clock.dart';
import 'package:zikirce/features/namaz_vakitleri/providers/prayer_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalogPrayerClock & Cross-Platform Widget Parity Tests', () {
    testWidgets('Renders Seljuk Star AnalogPrayerClock in light and dark mode without errors', (tester) async {
      final timings = PrayerTimings(
        fajr: '04:12',
        sunrise: '05:48',
        dhuhr: '13:08',
        asr: '16:54',
        maghrib: '20:18',
        isha: '21:46',
        date: '2026-08-31',
      );

      for (final dark in [true, false]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              prayerTimingsProvider.overrideWith((ref) => Future.value(timings)),
              timeTickerStreamProvider.overrideWith((ref) => Stream.value(DateTime(2026, 8, 31, 14, 30, 15))),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: AnalogPrayerClock(
                    size: 240,
                    isDark: dark,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnalogPrayerClock), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    test('AnalogPrayerClock theme color palette covers all 6 prayer periods', () {
      expect(AnalogPrayerClock.prayerColors.length, 6);
      for (int i = 0; i < 6; i++) {
        final color = AnalogPrayerClock.getPrayerThemeColor(i);
        expect(color.toARGB32(), isNonZero);
      }
      // Out of bounds fallback
      final fallbackColor = AnalogPrayerClock.getPrayerThemeColor(99);
      expect(fallbackColor, const Color(0xFFF59E0B));
    });

    test('WidgetSyncService registers all 13 widgets on both Android and iOS', () {
      expect(WidgetSyncService.widgetProviderNames.length, 13);
      expect(WidgetSyncService.iosWidgetKinds.length, 13);
      expect(WidgetSyncService.iosWidgetKinds, contains('PrayerAnalogClockWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('PrayerCountdownWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('PrayerDigitalClockWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('HijriCalendarWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('PrayerKazaWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('KazaQuickWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('KalpSagligiWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('ZikirCounterWidget'));
      expect(WidgetSyncService.iosWidgetKinds, contains('StreakWidget'));
    });
  });
}

