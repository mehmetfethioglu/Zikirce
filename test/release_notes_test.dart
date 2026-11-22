import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/release/hasibu_release_notes.dart';
import 'package:hasibu/features/pdks/presentation/screens/hasibu_release_notes_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Hasibu Release Notes Registry & Tracker', () {
    test('latest release entry aligns with version 1.0.11 build 12', () {
      expect(hasibuReleaseNotesRegistry, isNotEmpty);

      final latest = hasibuReleaseNotesRegistry.first;
      expect(latest.version, equals(hasibuAppVersion));
      expect(latest.version, equals('1.0.11'));
      expect(latest.buildNumber, equals(hasibuAppBuildNumber));
      expect(latest.buildNumber, equals(12));
      expect(latest.versionLabel, equals(hasibuFullVersionLabel));

      for (final entry in hasibuReleaseNotesRegistry) {
        expect(entry.title.trim(), isNotEmpty);
        expect(entry.releaseDate.trim(), isNotEmpty);
        expect(entry.categoryTag.trim(), isNotEmpty);
        expect(entry.highlights, isNotEmpty);
        for (final h in entry.highlights) {
          expect(h.trim(), isNotEmpty);
        }
      }
    });

    test('HasibuReleaseNotesTracker tracks unseen version via SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      expect(await HasibuReleaseNotesTracker.hasUnseenReleaseNotes(), isTrue);

      final saved = await HasibuReleaseNotesTracker.markCurrentVersionSeen();
      expect(saved, isTrue);
      expect(await HasibuReleaseNotesTracker.hasUnseenReleaseNotes(), isFalse);
    });
  });

  group('Hasibu Release Notes UI & Responsive Tests', () {
    Future<void> verifyQuickCardAndDialog(
      WidgetTester tester,
      Size surfaceSize,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: const HasibuReleaseNotesQuickCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_release_notes_card')),
        findsOneWidget,
      );
      final openBtn =
          find.byKey(const ValueKey('settings_open_release_notes_button'));
      expect(openBtn, findsOneWidget);

      await tester.ensureVisible(openBtn);
      await tester.tap(openBtn);
      await tester.pumpAndSettle();

      expect(find.text('Hasibu Sürüm Notları'), findsOneWidget);
      expect(find.text(hasibuFullVersionLabel), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
      );

      final closeBtn =
          find.byKey(const ValueKey('release_notes_close_button'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Hasibu Sürüm Notları'), findsNothing);
      expect(await HasibuReleaseNotesTracker.hasUnseenReleaseNotes(), isFalse);
    }

    testWidgets('renders dialog and card cleanly on desktop 1440x900',
        (tester) async {
      await verifyQuickCardAndDialog(tester, const Size(1440, 900));
    });

    testWidgets('renders dialog and card without overflow on mobile 390x844',
        (tester) async {
      await verifyQuickCardAndDialog(tester, const Size(390, 844));
    });

    testWidgets('ReleaseNotesAppBarButton clears unseen indicator on open',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [ReleaseNotesAppBarButton()],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btn = find.byKey(const ValueKey('appbar_release_notes_button'));
      expect(btn, findsOneWidget);

      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Hasibu Sürüm Notları'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('release_notes_close_button')));
      await tester.pumpAndSettle();

      expect(await HasibuReleaseNotesTracker.hasUnseenReleaseNotes(), isFalse);
    });
  });
}
