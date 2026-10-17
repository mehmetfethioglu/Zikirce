import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/core/theme/theme_provider.dart';
import 'package:zikirce/core/widgets/splash/zikirce_splash_overlay.dart';
import 'package:zikirce/core/widgets/splash/zikirce_vector_logo.dart';

void main() {
  group('Zikirce Animated Vector Splash Tests', () {
    testWidgets(
      'ZikirceSplashOverlay renders only 1:1 Vector Logo at exact screen center and size, and dismisses cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeNotifier.buildThemeData(AppThemeColors.dark),
            home: const ZikirceSplashOverlay(
              child: Scaffold(
                body: Center(child: Text('HOME_READY')),
              ),
            ),
          ),
        );

        // Initial frame: Only vector logo is visible on the splash overlay (no extra texts)
        final logoFinder = find.byType(ZikirceVectorLogo);
        final overlayFinder = find.byType(ZikirceSplashOverlay);
        expect(logoFinder, findsOneWidget);
        expect(find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'), findsNothing);
        expect(find.text('ZİKİRCE'), findsNothing);
        expect(find.text('HOME_READY'), findsOneWidget);

        // Verify exact size (188x188dp) and exact full-screen center alignment (matching Native Splash)
        expect(tester.getSize(logoFinder), const Size(188.0, 188.0));
        expect(tester.getCenter(logoFinder), tester.getCenter(overlayFinder));

        // Advance mid-animation (halo + window shimmer + tesbih swing active)
        await tester.pump(const Duration(milliseconds: 600));
        expect(logoFinder, findsOneWidget);
        expect(tester.getCenter(logoFinder), tester.getCenter(overlayFinder));

        // Complete animation and verify splash overlay unmounts itself (Zero Muda)
        await tester.pumpAndSettle();
        expect(logoFinder, findsNothing);
        expect(find.text('HOME_READY'), findsOneWidget);
      },
    );
  });
}
