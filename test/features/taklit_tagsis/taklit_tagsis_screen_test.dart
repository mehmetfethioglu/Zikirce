import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/core/theme/app_theme.dart';
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
}
