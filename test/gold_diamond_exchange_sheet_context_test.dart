import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/badge_detail_modal.dart';
import 'package:zikirce/features/gamification/models/badge_models.dart';
import 'package:zikirce/features/gamification/presentation/widgets/gold_diamond_exchange_sheet.dart';

class _ContextCaptureHost extends StatefulWidget {
  final ValueChanged<BuildContext> onBuildContext;

  const _ContextCaptureHost({required this.onBuildContext});

  @override
  State<_ContextCaptureHost> createState() => _ContextCaptureHostState();
}

class _ContextCaptureHostState extends State<_ContextCaptureHost> {
  @override
  Widget build(BuildContext context) {
    widget.onBuildContext(context);
    return const SizedBox.shrink();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'GoldCount': 50,
      'DiamondCount': 0,
    });
    db = AppDatabase(NativeDatabase.memory());

    await db.update(db.userStreaks).write(
      const UserStreaksCompanion(
        currentStreak: drift.Value(5),
        bestStreak: drift.Value(10),
        freezeCount: drift.Value(2),
        xp: drift.Value(50),
        rank: drift.Value('Mübtedi'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestApp({required Widget child}) {
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

  Badge buildLockedTestBadge() {
    return Badge(
      id: 'test_badge',
      category: 'Zikir',
      name: 'Test Rozet',
      description: 'Desc',
      iconPath: '',
      emoji: '🏅',
      isUnlocked: false,
      glowColor: Colors.amber,
      criteria: '100',
      unlockCost: 10,
    );
  }

  testWidgets(
    'GoldDiamondExchangeSheet.show safely returns when StatefulElement context is unmounted',
    (WidgetTester tester) async {
      BuildContext? capturedContext;

      await tester.pumpWidget(
        createTestApp(
          child: _ContextCaptureHost(
            onBuildContext: (ctx) => capturedContext = ctx,
          ),
        ),
      );
      await tester.pump();

      expect(capturedContext, isNotNull);
      expect(capturedContext!.mounted, isTrue);

      await tester.pumpWidget(
        createTestApp(child: const SizedBox.shrink()),
      );
      await tester.pump();

      expect(capturedContext!.mounted, isFalse);

      await GoldDiamondExchangeSheet.show(capturedContext!);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(GoldDiamondExchangeSheet), findsNothing);
    },
  );

  testWidgets(
    'BadgeDetailModal SnackBarAction opens GoldDiamondExchangeSheet after modal pops',
    (WidgetTester tester) async {
      final badge = buildLockedTestBadge();

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => BadgeDetailModal.show(context, badge),
                child: const Text('Open Badge Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Open Badge Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BadgeDetailModal), findsOneWidget);

      await tester.tap(find.text('10 Elmas ile Kilidi Aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BadgeDetailModal), findsNothing);
      expect(find.byType(SnackBarAction), findsOneWidget);

      await tester.tap(find.byType(SnackBarAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(GoldDiamondExchangeSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'BadgeDetailModal convert button opens GoldDiamondExchangeSheet after modal pops',
    (WidgetTester tester) async {
      final badge = buildLockedTestBadge();

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => BadgeDetailModal.show(context, badge),
                child: const Text('Open Badge Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Open Badge Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BadgeDetailModal), findsOneWidget);

      await tester.tap(find.text('🪙 Altın Dönüştür ve Kilidi Aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(BadgeDetailModal), findsNothing);
      expect(find.byType(GoldDiamondExchangeSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}
