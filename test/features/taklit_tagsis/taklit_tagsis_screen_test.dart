import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/features/taklit_tagsis/domain/taklit_tagsis_service.dart';
import 'package:organicscore/features/taklit_tagsis/presentation/taklit_tagsis_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TaklitTagsisScreen renders simplified layout with search and segmented switcher', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const TaklitTagsisScreen(),
      ),
    );

    // Initial loading or loaded state
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Title
    expect(find.text('Bakanlık Kara Listesi'), findsOneWidget);

    // Verify Search Field
    expect(find.byType(TextField), findsOneWidget);

    // Verify Segment Switcher options exist
    expect(find.textContaining('Tümü'), findsWidgets);
    expect(find.textContaining('Sağlık'), findsWidgets);
    expect(find.textContaining('Tağşiş'), findsWidgets);

    // Verify RefreshIndicator exists
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('TaklitTagsisBrandCard renders concise 3-line layout without dense metadata clutter', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final group = TaklitTagsisBrandGroup(
      brandName: 'Örnek Süt Marka',
      companyName: 'Örnek Gıda San. Tic. A.Ş.',
      primaryCategory: 'Süt ve Süt Ürünleri',
      hasHealthHazard: false,
      uniqueReasons: const ['Bitkisel yağ ve nişasta tespiti'],
      products: [
        TaklitTagsisItem(
          companyName: 'Örnek Gıda San. Tic. A.Ş.',
          brandName: 'Örnek Süt Marka',
          productName: 'Tam Yağlı Taze Kaşar Peyniri',
          reason: 'Bitkisel yağ ve nişasta tespiti',
          category: 'Süt ve Süt Ürünleri',
          announcedAt: DateTime(2026, 11, 20),
        ),
      ],
      latestAnnouncedAt: DateTime(2026, 11, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TaklitTagsisBrandCard(
              group: group,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Örnek Süt Marka'), findsOneWidget);
    expect(find.text('Tağşiş'), findsOneWidget);
    expect(find.text('Bitkisel yağ ve nişasta tespiti'), findsOneWidget);
    expect(find.text('Süt ve Süt Ürünleri · 1 ürün'), findsOneWidget);

    expect(find.textContaining('Uygunsuz Ürün İlanı'), findsNothing);
    expect(find.textContaining('Duyuru:'), findsNothing);
    expect(find.text('İncele'), findsNothing);
    expect(find.textContaining('Örnek Gıda San.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
