import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_card_widget.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/streak_share_card_widget.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/streak_share_preview_modal.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/quick_stats_share_card_widget.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/quick_stats_share_preview_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('tr'),
        theme: ThemeData(
          extensions: const [AppThemeColors.greenLight],
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('StreakShareCardWidget renders streak info, rank, and hadith', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: const SingleChildScrollView(
          child: StreakShareCardWidget(
            currentStreak: 12,
            bestStreak: 25,
            totalDays: 48,
            rankName: 'Âbid',
            rankBadge: '📿',
            isGoldCompleted: true,
            format: ZikirShareCardFormat.story9x16,
            theme: ZikirShareCardTheme.emeraldSufi,
          ),
        ),
      ),
    );

    expect(find.text('ALTIN GÜN • 12 GÜNLÜK SERİ'), findsOneWidget);
    expect(find.text('Makam: Âbid'), findsOneWidget);
    expect(find.text('AKTİF SERİ'), findsOneWidget);
    expect(find.text('12 Gün'), findsOneWidget);
    expect(find.text('EN İYİ SERİ'), findsOneWidget);
    expect(find.text('25 Gün'), findsOneWidget);
    expect(find.text('TOPLAM GÜN'), findsOneWidget);
    expect(find.text('48 Gün'), findsOneWidget);
  });

  testWidgets('QuickStatsShareCardWidget renders today, week, avg, and quran pages', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: const SingleChildScrollView(
          child: QuickStatsShareCardWidget(
            todayZikir: '350',
            thisWeekZikir: '2.450',
            dailyAvgZikir: '320',
            totalZikir: '15.800',
            quranPages: '10',
            rankName: 'Zâhid',
            rankBadge: '🌿',
            format: ZikirShareCardFormat.square1x1,
            theme: ZikirShareCardTheme.midnightGold,
          ),
        ),
      ),
    );

    expect(find.text('İBADET VE ZİKİR ÖZETİ'), findsOneWidget);
    expect(find.text('BUGÜN ZİKİR'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
    expect(find.text('BU HAFTA'), findsOneWidget);
    expect(find.text('2.450'), findsOneWidget);
    expect(find.text('GÜNLÜK ORTALAMA'), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
    expect(find.text('TOPLAM ZİKİR'), findsOneWidget);
    expect(find.text('15.800'), findsOneWidget);
    expect(find.text('KUR\'AN OKUMA'), findsOneWidget);
    expect(find.text('10 Sayfa'), findsOneWidget);
  });

  testWidgets('StreakSharePreviewModal opens and allows format and theme selection', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                StreakSharePreviewModal.show(
                  context,
                  currentStreak: 7,
                  bestStreak: 14,
                  totalDays: 30,
                  rankName: 'Mübtedi',
                  rankBadge: '🌱',
                );
              },
              child: const Text('Seri Paylaş Modalını Aç'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Seri Paylaş Modalını Aç'));
    await tester.pumpAndSettle();

    expect(find.text('İbadet Serisi Paylaş'), findsOneWidget);
    expect(find.text('Görsel Olarak Paylaş'), findsOneWidget);
    expect(find.text('Düz Metin Olarak Paylaş'), findsOneWidget);

    // Switch to square
    await tester.tap(find.text('Kare (1:1)'));
    await tester.pumpAndSettle();

    // Tap theme
    await tester.tap(find.text('Gece'));
    await tester.pumpAndSettle();
  });

  testWidgets('QuickStatsSharePreviewModal opens and allows format and theme selection', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                QuickStatsSharePreviewModal.show(
                  context: context,
                  todayZikir: '100',
                  thisWeekZikir: '700',
                  dailyAvgZikir: '100',
                  totalZikir: '5.000',
                  quranPages: '5',
                  rankName: 'Ârif',
                  rankBadge: '✨',
                );
              },
              child: const Text('İstatistik Paylaş Modalını Aç'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('İstatistik Paylaş Modalını Aç'));
    await tester.pumpAndSettle();

    expect(find.text('İbadet Karnesi Paylaş'), findsOneWidget);
    expect(find.text('Görsel Olarak Paylaş'), findsOneWidget);

    // Switch to square
    await tester.tap(find.text('Kare (1:1)'));
    await tester.pumpAndSettle();

    // Tap theme
    await tester.tap(find.text('Turkuaz'));
    await tester.pumpAndSettle();
  });
}
