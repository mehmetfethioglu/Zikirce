import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_card_widget.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_preview_modal.dart';

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

  testWidgets('ZikirShareCardWidget renders with custom theme and format', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: const SingleChildScrollView(
          child: ZikirShareCardWidget(
            zikirName: 'Subhanallah',
            arabicText: 'سُبْحَانَ اللهِ',
            virtue: 'Her namazın peşinden otuz üç defa tesbih edin.',
            category: 'Hadislerden Zikirler',
            currentCount: 33,
            targetCount: 33,
            totalCount: 99,
            format: ZikirShareCardFormat.story9x16,
            theme: ZikirShareCardTheme.emeraldSufi,
            showCounterStats: true,
          ),
        ),
      ),
    );

    expect(find.text('SUBHANALLAH'), findsOneWidget);
    expect(find.text('سُبْحَانَ اللهِ'), findsOneWidget);
    expect(find.text('“Her namazın peşinden otuz üç defa tesbih edin.”'), findsOneWidget);
    expect(find.text('BU OTURUM'), findsOneWidget);
    expect(find.text('TOPLAM ZİKİR'), findsOneWidget);
    expect(find.text('MANEVİ NİYET'), findsOneWidget);
    expect(find.text('ZİKİRCE'), findsOneWidget);
  });

  testWidgets('ZikirSharePreviewModal opens and switches themes & formats', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                ZikirSharePreviewModal.show(
                  context: context,
                  zikirName: 'İstiğfar',
                  arabicText: 'أَسْتَغْفِرُ اللهَ',
                  virtue: 'Tevbe ve bağışlanma kapısı.',
                  category: 'Hadislerden Zikirler',
                  currentCount: 100,
                  targetCount: 100,
                  totalCount: 500,
                );
              },
              child: const Text('Paylaşım Modalını Aç'),
            );
          },
        ),
      ),
    );

    // Tap button to open modal
    await tester.tap(find.text('Paylaşım Modalını Aç'));
    await tester.pumpAndSettle();

    // Verify modal is open
    expect(find.text('Zikir Kartı Paylaş'), findsOneWidget);
    expect(find.text('Görsel Olarak Paylaş'), findsOneWidget);
    expect(find.text('Düz Metin Olarak Paylaş'), findsOneWidget);
    expect(find.text('Kare (1:1)'), findsOneWidget);

    // Switch to Square format
    await tester.tap(find.text('Kare (1:1)'));
    await tester.pumpAndSettle();

    // Toggle stats checkbox
    await tester.tap(find.text('Sayaç'));
    await tester.pumpAndSettle();

    // Theme selector tap
    await tester.tap(find.text('Gece Seması'));
    await tester.pumpAndSettle();
  });
}
