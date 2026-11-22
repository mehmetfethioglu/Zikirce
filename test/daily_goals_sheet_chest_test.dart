import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/daily_goals_sheet.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/surprise_chest_dialog.dart';
import 'package:zikirce/features/gamification/models/surprise_chest_reward.dart';
import 'package:zikirce/features/gamification/providers/gamification_providers.dart';
import 'package:zikirce/features/gamification/services/golden_day_service.dart';

class _ControlledChestGamificationNotifier extends GamificationNotifier {
  final Completer<SurpriseChestReward?> completer =
      Completer<SurpriseChestReward?>();
  int openCalls = 0;

  _ControlledChestGamificationNotifier(super.ref);

  @override
  Future<SurpriseChestReward?> openSurpriseChest({
    required bool isTurkish,
  }) {
    openCalls++;
    return completer.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'DailyGoalsSheet sandık açma akışında dispose sonrası ref kullanım hatası oluşmaz',
    (tester) async {
      late _ControlledChestGamificationNotifier fakeNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyGoalsStatusProvider.overrideWith(
              (ref) async => const DailyGoalsStatus(
                isPrayersMet: true,
                completedPrayersCount: 5,
                isZikirMet: true,
                todayZikirCount: 100,
                zikirGoal: 100,
                isKuranMet: true,
                todayKuranPages: 5,
                kuranGoal: 5,
                isGoldCompleted: true,
                isChestClaimed: false,
              ),
            ),
            gamificationNotifierProvider.overrideWith((ref) {
              fakeNotifier = _ControlledChestGamificationNotifier(ref);
              return fakeNotifier;
            }),
            userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
            diamondCountProvider.overrideWith((ref) async => 10),
            goldCountProvider.overrideWith((ref) async => 100),
            userStreakStreamProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: const <Locale>[Locale('tr'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData.light().copyWith(
              extensions: const <ThemeExtension<dynamic>>[
                AppThemeColors.greenLight,
              ],
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () => DailyGoalsSheet.show(context),
                      child: const Text('OpenGoals'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenGoals'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyGoalsSheet), findsOneWidget);

      // Tap "Aç 🎁" -> pops DailyGoalsSheet and awaits openSurpriseChest while sheet is already disposed.
      await tester.tap(find.text('Aç 🎁'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyGoalsSheet), findsNothing);
      expect(fakeNotifier.openCalls, equals(1));

      // Resolve after DailyGoalsSheet disposal (reproduces exact ZIKIRCE-12 condition).
      fakeNotifier.completer.complete(
        const SurpriseChestReward(
          type: ChestRewardType.gold,
          goldAmount: 50,
          message: 'Bugünkü sandık açıldı!',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SurpriseChestDialog), findsOneWidget);

      // Open the chest inside SurpriseChestDialog and dismiss via claim button.
      await tester.tap(find.text('📦'));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 360));
      }
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Ödülü Al ve Devam Et'));
      await tester.pumpAndSettle();

      expect(find.byType(SurpriseChestDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
