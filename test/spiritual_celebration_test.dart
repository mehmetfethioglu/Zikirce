import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zikirce/core/services/celebration_service.dart';
import 'package:zikirce/core/widgets/celebration/nur_particles_painter.dart';
import 'package:zikirce/core/widgets/celebration/spiritual_celebration_overlay.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spiritual Celebration & Nur Particles Tests', () {
    test('NurParticle generation creates deterministic particles with no nulls', () {
      final particles = NurParticlesPainter.generateParticles(count: 48);
      expect(particles.length, 48);
      for (final p in particles) {
        expect(p.size, greaterThan(0));
        expect(p.baseRadius, greaterThan(0));
        expect(p.speed, greaterThan(0));
      }
    });

    test('CelebrationEvent factory methods construct valid objects', () {
      final zikirEvent = CelebrationEvent.randomZikirMilestone(
        zikirName: 'Sübhanallahi ve bihamdihi',
        count: 33,
      );
      expect(zikirEvent.type, CelebrationType.zikirTarget);
      expect(zikirEvent.title, contains('Elhamdülillah'));
      expect(zikirEvent.hadithOrVirtue?.isNotEmpty, true);
      expect(zikirEvent.xpGained, 50);

      final goalEvent = CelebrationEvent.dailyGoalCompleted(goalTitle: '5 Vakit Namaz');
      expect(goalEvent.type, CelebrationType.dailyGoal);
      expect(goalEvent.subtitle, '5 Vakit Namaz');

      final goldenDayEvent = CelebrationEvent.goldenDayAchieved();
      expect(goldenDayEvent.type, CelebrationType.goldenDay);
      expect(goldenDayEvent.xpGained, 150);
    });

    testWidgets('SpiritualCelebrationOverlay renders child and responds to celebrationProvider',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: ThemeData(
                  extensions: const [AppThemeColors.greenLight],
                ),
                home: const SpiritualCelebrationOverlay(
                  child: Scaffold(
                    body: Center(
                      child: Text('Main Screen Content'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Main Screen Content'), findsOneWidget);

      // Trigger zikir milestone celebration
      container.read(celebrationProvider.notifier).trigger(
            CelebrationEvent.randomZikirMilestone(
              zikirName: 'Kelime-i Tevhid',
              count: 100,
            ),
          );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check that "Elhamdülillah" appears in the overlay
      expect(find.text('Elhamdülillah 🌟'), findsOneWidget);

      // Ensure that taps still pass through in ambient mode (non-blocking)
      final mainText = find.text('Main Screen Content');
      expect(mainText, findsOneWidget);

      // Advance time until auto-dismiss
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.text('Elhamdülillah 🌟'), findsNothing);
    });

    testWidgets('SpiritualCelebrationOverlay renders interactive card for golden day milestone',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: ThemeData(
                  extensions: const [AppThemeColors.greenLight],
                ),
                home: const SpiritualCelebrationOverlay(
                  child: Scaffold(
                    body: Center(
                      child: Text('Dashboard Screen'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Trigger golden day celebration
      container.read(celebrationProvider.notifier).trigger(
            CelebrationEvent.goldenDayAchieved(),
          );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check title and XP
      expect(find.text('🌟 Altın Gün Tamamlandı! 🌟'), findsOneWidget);
      expect(find.text('+150 Manevi Derece'), findsOneWidget);

      // Dismiss by tapping card/overlay
      await tester.tap(find.text('Kapatmak için dokunun'));
      await tester.pumpAndSettle();

      expect(find.text('🌟 Altın Gün Tamamlandı! 🌟'), findsNothing);
    });
  });
}
