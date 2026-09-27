import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/features/kuran/presentation/widgets/desktop_mushaf_nav_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopMushafNavButton Tests', () {
    testWidgets('Hidden on mobile platforms (Android, iOS)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DesktopMushafNavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Sonraki Sayfa',
                onPressed: () {},
                isDark: false,
              ),
            ),
          ),
        );

        expect(find.byType(DesktopMushafNavButton), findsOneWidget);
        expect(find.byType(AnimatedOpacity), findsNothing);
        expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Visible on desktop platforms (Windows) with idle 0.30 opacity and hover 1.0', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      bool wasClicked = false;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: DesktopMushafNavButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Sonraki Sayfa',
                  onPressed: () {
                    wasClicked = true;
                  },
                  isDark: false,
                ),
              ),
            ),
          ),
        );

        // Verify icon is present
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

        // Check idle opacity
        final idleOpacityFinder = find.byType(AnimatedOpacity);
        expect(idleOpacityFinder, findsOneWidget);
        AnimatedOpacity opacityWidget = tester.widget(idleOpacityFinder);
        expect(opacityWidget.opacity, equals(0.30));

        // Hover over the button
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        await gesture.moveTo(tester.getCenter(find.byType(DesktopMushafNavButton)));
        await tester.pumpAndSettle();

        // Opacity should now be 1.0
        opacityWidget = tester.widget(idleOpacityFinder);
        expect(opacityWidget.opacity, equals(1.0));

        // Click the button
        await tester.tap(find.byType(DesktopMushafNavButton));
        await tester.pump();
        expect(wasClicked, isTrue);

        // Move mouse away
        await gesture.moveTo(Offset.zero);
        await tester.pumpAndSettle();

        // Opacity should return to 0.30
        opacityWidget = tester.widget(idleOpacityFinder);
        expect(opacityWidget.opacity, equals(0.30));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
