import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/zikir/presentation/widgets/add_edit_zikir_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
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

  testWidgets('AddEditZikirSheet renders tabs and allows switching to Zikirmatikten Aktar', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                AddEditZikirSheet.show(context);
              },
              child: const Text('Open Sheet'),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap button to open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify Tab 1 (Yeni Zikir) and Tab 2 (Zikirmatikten Aktar) headers are present
    expect(find.text('Yeni Zikir'), findsWidgets);
    expect(find.text('Zikirmatikten Aktar'), findsWidgets);

    // Switch to Tab 2 (Zikirmatikten Aktar)
    await tester.tap(find.text('Zikirmatikten Aktar').first);
    await tester.pumpAndSettle();

    // Verify Tab 2 fields: Çekilmiş Miktar and quick chips (+33, +99, +100, +500, +1000)
    expect(find.text('+33'), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
    expect(find.text('Aktar'), findsOneWidget);

    // Tap +100 quick chip
    await tester.tap(find.text('+100'));
    await tester.pumpAndSettle();

    // Verify 100 is in the text field
    expect(find.text('100'), findsWidgets);

    // Tap +33 quick chip to make it 133
    await tester.tap(find.text('+33'));
    await tester.pumpAndSettle();
    expect(find.text('133'), findsWidgets);

    // Tap "Aktar" button
    await tester.tap(find.text('Aktar'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Verify sheet closed and zikir count updated
    final zikirs = await db.select(db.zikirs).get();
    final first = zikirs.first;
    expect(first.totalCount, equals(133));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('AddEditZikirSheet initialTabIndex 1 directly opens Zikirmatikten Aktar tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                AddEditZikirSheet.show(context, initialTabIndex: 1);
              },
              child: const Text('Open Transfer Sheet'),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Transfer Sheet'));
    await tester.pumpAndSettle();

    // Verify Tab 2 items are immediately visible
    expect(find.text('+99'), findsOneWidget);
    expect(find.text('+1000'), findsOneWidget);
    expect(find.text('Aktar'), findsOneWidget);

    Navigator.of(tester.element(find.text('Aktar'))).pop();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
