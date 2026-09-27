import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zikirce/app/app.dart';
import 'package:zikirce/features/namaz_vakitleri/providers/prayer_providers.dart';

void main() {
  testWidgets('ZikirceApp pump smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timeTickerStreamProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
        child: const ZikirceApp(),
      ),
    );
    expect(find.byType(ZikirceApp), findsOneWidget);
  });
}
