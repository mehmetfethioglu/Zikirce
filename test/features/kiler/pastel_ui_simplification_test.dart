import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/kiler/domain/kiler_service.dart';
import 'package:organicscore/features/kiler/presentation/kiler_pantry_screen.dart';
import 'package:organicscore/features/kiler/presentation/widgets/kilerce_product_add_card.dart';
import 'package:organicscore/features/scanner/presentation/widgets/scanner_showcase_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Soft Pastel Theme & Simplified UI Tests', () {
    testWidgets(
      'AppTheme exposes soft pastel light/dark backgrounds and ThemeContextExtension tints',
      (tester) async {
        expect(AppColors.lightBackground, const Color(0xFFF2F8F5));
        expect(AppColors.amoledBackground, const Color(0xFF000000));

        late Color lightSage;
        late Color lightPeach;
        late Color darkSage;
        late Color darkBlush;

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('light-theme-app'),
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                lightSage = context.pastelSageTint;
                lightPeach = context.pastelPeachTint;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('dark-theme-app'),
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.amoledDarkTheme,
            themeMode: ThemeMode.dark,
            home: Builder(
              builder: (context) {
                darkSage = context.pastelSageTint;
                darkBlush = context.pastelBlushTint;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(lightSage, AppColors.pastelSageLight);
        expect(lightPeach, AppColors.pastelPeachLight);
        expect(darkSage, AppColors.pastelSageDark);
        expect(darkBlush, AppColors.pastelBlushDark);
      },
    );

    for (final entry in <String, ThemeData>{
      'light': AppTheme.lightTheme,
      'dark': AppTheme.amoledDarkTheme,
    }.entries) {
      testWidgets(
        'KilerPantryScreen renders simplified single-row cards without overflow (${entry.key}) and opens detail sheet',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final originalState = KilerService.instance.value;
          addTearDown(() {
            KilerService.instance.value = originalState;
          });

          final nowMs = DateTime.now().millisecondsSinceEpoch;
          const dayMs = 86400000;
          KilerService.instance.value = KilerState(
            pantryItems: [
              PantryItem(
                id: 1,
                name: 'Salkım Domates',
                normalizedTag: 'domates',
                brand: 'Pazar',
                category: 'Sebze',
                storageZone: StorageZone.fridge,
                quantityLevel: QuantityLevel.full,
                unitLabel: '1 Kg',
                healthScore: 95,
                addedAt: nowMs - dayMs,
                expiresAt: nowMs + (6 * dayMs),
              ),
              PantryItem(
                id: 2,
                name: 'Sızma Zeytinyağı',
                normalizedTag: 'zeytinyagi',
                brand: 'Ev Yapımı',
                category: 'Yağ',
                storageZone: StorageZone.pantry,
                quantityLevel: QuantityLevel.half,
                unitLabel: '1 Lt',
                healthScore: 98,
                addedAt: nowMs - dayMs,
                expiresAt: nowMs + (90 * dayMs),
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: entry.value,
                home: Scaffold(
                  body: SafeArea(
                    child: KilerPantryScreen(
                      onOpenRecipesTab: () {},
                      onOpenScannerTab: () {},
                      onOpenShoppingTab: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Kilerim'), findsOneWidget);
          expect(find.text('Ne Pişirsem?'), findsOneWidget);
          expect(find.text('Salkım Domates'), findsOneWidget);
          expect(find.text('Sızma Zeytinyağı'), findsOneWidget);
          expect(find.text('Tam'), findsOneWidget);
          expect(find.text('Yarım'), findsOneWidget);
          // Verbose multi-button row labels must not appear on cards
          expect(find.text('Bitti -> Listeye'), findsNothing);
          expect(tester.takeException(), isNull);

          // Tap card to open clean detail sheet
          await tester.tap(find.text('Salkım Domates'));
          await tester.pumpAndSettle();

          expect(find.text('Kalan Miktar'), findsOneWidget);
          expect(
            find.text('Bitti · Alışveriş Listesine Ekle'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Modernized scanner widgets and KilerceProductAddCard render cleanly without overflow (${entry.key})',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          const sampleProduct = ShowcaseProduct(
            barcode: '8690000000001',
            name: 'Organik Yulaf Ezmesi',
            brand: 'Doğa Bahçe',
            score: 88,
            category: 'Mükemmel',
            novaGroup: 1,
            boycottStatus: 'CLEAR',
            description: 'Katkısız tam yulaf ezmesi.',
            badges: ['NOVA 1 Doğal', 'Boykotsuz'],
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ScannerUtilityPill(
                              icon: Icons.inventory_2_outlined,
                              label: 'Katalog · 120',
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ScannerUtilityPill(
                              icon: Icons.gavel_rounded,
                              label: 'İfşa · 12',
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ScannerFilterChip(
                            label: 'Temiz 80+',
                            selected: true,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          ScannerFilterChip(
                            label: 'Doğal',
                            selected: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ShowcaseProductTile(
                        item: sampleProduct,
                        scoreColor: AppColors.primaryEmerald,
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      const KilerceProductAddCard(
                        barcode: '8690000000001',
                        productName: 'Organik Yulaf Ezmesi',
                        brand: 'Doğa Bahçe',
                        healthScore: 88,
                        netQuantity: '500 g',
                        marketChains: ['Migros', 'BİM'],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Organik Yulaf Ezmesi'), findsOneWidget);
          expect(find.text('Doğa Bahçe · NOVA 1'), findsOneWidget);
          expect(find.text('Kilere Ekle'), findsOneWidget);
          expect(find.text('Dolaba Ekle'), findsOneWidget);
          expect(find.text('500 g'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
