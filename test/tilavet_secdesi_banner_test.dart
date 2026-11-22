import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/features/kuran/data/tilavet_secdesi_data.dart';
import 'package:zikirce/features/kuran/presentation/widgets/tilavet_secdesi_debt_reminder_banner.dart';
import 'package:zikirce/features/kuran/presentation/widgets/tilavet_secdesi_floating_banner.dart';
import 'package:zikirce/features/kuran/presentation/widgets/tilavet_secdesi_guide_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TilavetSecdesiDebtReminderBanner', () {
    testWidgets('shows debt text and Rehber chip, close tap dismisses without opening guide', (tester) async {
      var openGuideCount = 0;
      var dismissCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TilavetSecdesiDebtReminderBanner(
              debtCount: 1,
              onOpenGuide: () => openGuideCount++,
              onDismiss: () => dismissCount++,
            ),
          ),
        ),
      );

      expect(
        find.text('1 adet tilâvet secdesi borcunuz bulunuyor.'),
        findsOneWidget,
      );
      expect(find.text('Rehber'), findsOneWidget);
      expect(
        find.byKey(const Key('tilavet_debt_banner_guide_chip')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('tilavet_debt_banner_close_button')));
      await tester.pump();

      expect(dismissCount, equals(1));
      expect(openGuideCount, equals(0));
    });

    testWidgets('keeps clear gap between Rehber arrow chip and close icon, and respects 44x44 touch target', (tester) async {
      var openGuideCount = 0;
      var dismissCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: TilavetSecdesiDebtReminderBanner(
                  debtCount: 2,
                  onOpenGuide: () => openGuideCount++,
                  onDismiss: () => dismissCount++,
                ),
              ),
            ),
          ),
        ),
      );

      final closeButtonFinder =
          find.byKey(const Key('tilavet_debt_banner_close_button'));
      final closeRect = tester.getRect(closeButtonFinder);
      expect(closeRect.width, greaterThanOrEqualTo(44.0));
      expect(closeRect.height, greaterThanOrEqualTo(44.0));

      final chipRect = tester.getRect(
        find.byKey(const Key('tilavet_debt_banner_guide_chip')),
      );
      final closeIconRect = tester.getRect(find.byIcon(Icons.close_rounded));
      expect(closeIconRect.left - chipRect.right, greaterThanOrEqualTo(20.0));

      // Tapping near the left edge of the close button still triggers dismiss only.
      await tester.tapAt(Offset(closeRect.left + 2, closeRect.center.dy));
      await tester.pump();
      expect(dismissCount, equals(1));
      expect(openGuideCount, equals(0));

      // Tapping the Rehber chip opens guide without triggering dismiss.
      await tester.tap(find.byKey(const Key('tilavet_debt_banner_guide_chip')));
      await tester.pump();
      expect(openGuideCount, equals(1));
      expect(dismissCount, equals(1));
    });

    testWidgets('renders without overflow on narrow 320px screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: TilavetSecdesiDebtReminderBanner(
                debtCount: 14,
                onOpenGuide: () {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('14 adet tilâvet secdesi borcunuz bulunuyor.'),
        findsOneWidget,
      );
    });
  });

  group('TilavetSecdesiFloatingBanner', () {
    testWidgets('has 44x44 close target, dismisses without opening guide, and fits 320px width', (tester) async {
      var dismissCount = 0;
      final secdeItem = TilavetSecdesiData.allSecdeVerses.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: TilavetSecdesiFloatingBanner(
                secdeItem: secdeItem,
                onDismiss: () => dismissCount++,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final closeFinder =
          find.byKey(const Key('tilavet_floating_banner_close_button'));
      final closeRect = tester.getRect(closeFinder);
      expect(closeRect.width, greaterThanOrEqualTo(44.0));
      expect(closeRect.height, greaterThanOrEqualTo(44.0));

      await tester.tapAt(Offset(closeRect.left + 2, closeRect.center.dy));
      await tester.pumpAndSettle();

      expect(dismissCount, equals(1));
      expect(find.byType(TilavetSecdesiGuideSheet), findsNothing);
    });
  });

  group('Top section placement without overlapping Quran text', () {
    testWidgets('banner sits above Quran section and closes cleanly', (tester) async {
      var showBanner = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Hûd • Cüz 12')),
                body: Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: showBanner
                          ? TilavetSecdesiDebtReminderBanner(
                              debtCount: 1,
                              onOpenGuide: () {},
                              onDismiss: () {
                                setState(() {
                                  showBanner = false;
                                });
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: Container(
                        key: const Key('quran_text_box'),
                        color: const Color(0xFFFBF8F1),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      final bannerRect =
          tester.getRect(find.byType(TilavetSecdesiDebtReminderBanner));
      final quranBoxRect =
          tester.getRect(find.byKey(const Key('quran_text_box')));
      expect(bannerRect.bottom, lessThanOrEqualTo(quranBoxRect.top));

      await tester.tap(find.byKey(const Key('tilavet_debt_banner_close_button')));
      await tester.pumpAndSettle();

      expect(find.byType(TilavetSecdesiDebtReminderBanner), findsNothing);
    });
  });
}
