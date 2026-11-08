import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';
import 'package:zamera/main.dart';
import 'package:zamera/dialogs/release_notes_dialog.dart';
import 'package:zamera/dialogs/settings_sheet.dart';
import 'package:zamera/models/app_version_info.dart';
import 'package:zamera/services/version_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sharma 2005 CIEDE2000 canonical pairs match within 1e-3', () {
    final pair1 = ZameraCapture.computeCiede2000(
      const [50.0000, 2.6772, -79.7751],
      const [50.0000, 0.0000, -82.7485],
    );
    expect((pair1 - 2.0425).abs(), lessThan(1e-3));

    final pair2 = ZameraCapture.computeCiede2000(
      const [50.0000, 3.1571, -77.2803],
      const [50.0000, 0.0000, -82.7485],
    );
    expect((pair2 - 2.8615).abs(), lessThan(1e-3));
  });

  test('24-Patch ColorChecker 3x3 calibration reduces sensor color cast below DeltaE 0.5', () {
    final measured = ZameraCapture.simulateUncalibratedSensor24(
      redShift: 1.55,
      greenShift: 1.20,
      blueShift: 0.78,
    );
    final res = ZameraCapture.calibrateColorChecker24(measured);
    expect(res.meanDeltaEBefore, greaterThan(8.0));
    expect(res.meanDeltaEAfter, lessThan(0.5));
    expect(res.patchDeltaEAfter.length, equals(24));
  });

  test('Pro Video module is enabled and exposes Phase 3 Cinema profiles', () {
    const info = ZameraVideoIsolationInfo();
    expect(info.isEnabledByFlag, isTrue);
    expect(info.plannedProfiles, isNotEmpty);
  });

  test('VersionTrackingService detects first launch and version updates accurately', () async {
    // 1. Initial State (Clean install)
    SharedPreferences.setMockInitialValues({});
    final service = await VersionTrackingService.initialize();
    expect(service.isFirstLaunch, isTrue);
    expect(service.isVersionUpdate, isFalse);

    // 2. Mark seen
    await service.markCurrentVersionSeen();
    expect(service.isFirstLaunch, isFalse);
    expect(service.isVersionUpdate, isFalse);

    // 3. Simulated Older version (e.g. build 1)
    SharedPreferences.setMockInitialValues({
      'zamera_last_seen_version': '0.1.0',
      'zamera_last_seen_build': 1,
      'zamera_has_completed_onboarding': true,
    });
    final updatedService = await VersionTrackingService.initialize();
    expect(updatedService.isFirstLaunch, isFalse);
    expect(updatedService.isVersionUpdate, isTrue);
  });

  testWidgets('ReleaseNotesDialog renders general features and changelog tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReleaseNotesDialog(initialShowFeatures: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zamera'), findsOneWidget);
    expect(find.text('ZAMERA PROFESYONEL ÖZELLİKLERİ'), findsOneWidget);
    expect(find.text('Gerçek Renk & Sanat Modu (ΔE₀₀ ≤ 1.0)'), findsOneWidget);
    expect(find.text('Sinema Seviyesi Pro Video (180° Kilit)'), findsOneWidget);

    // Switch to changelog tab
    await tester.tap(find.text('Sürüm ${AppVersionInfo.currentVersion}'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Faz 0-3 iOS Eşliği'), findsOneWidget);
  });

  testWidgets('SettingsSheet displays all configuration and compliance tiles', (WidgetTester tester) async {
    bool probeOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSheet(
            onOpenProbe: () => probeOpened = true,
            onOpenCalibration: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zamera Ayarları'), findsOneWidget);
    expect(find.text('Sürüm Notları & Yenilikler'), findsOneWidget);
    expect(find.text('Zamera Genel Özellikleri'), findsOneWidget);
    expect(find.text('Cihaz Yetenek Probe (Faz 0)'), findsOneWidget);
    expect(find.text('Gizlilik Politikası (GitHub Pages)', skipOffstage: false), findsOneWidget);
    expect(find.text('Telif & Açık Kaynak Lisansları', skipOffstage: false), findsOneWidget);

    expect(find.text('ColorChecker Kalibrasyonu (Faz 1)'), findsOneWidget);
    await tester.tap(find.text('Cihaz Yetenek Probe (Faz 0)'));
    await tester.pumpAndSettle();
    expect(probeOpened, isTrue);
  });

  testWidgets('Zamera shortened categories, radial shutter swipe menu, Portrait and Pro Video modes work cleanly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'zamera_last_seen_version': AppVersionInfo.currentVersion,
      'zamera_last_seen_build': AppVersionInfo.currentBuildNumber,
      'zamera_has_completed_onboarding': true,
    });
    final vs = await VersionTrackingService.initialize();

    await tester.pumpWidget(ZameraApp(versionService: vs));
    expect(find.text('ZAMERA'), findsNothing);
    expect(find.text('Faz 0: Probe'), findsNothing);
    expect(find.text('SANAT'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('PORTRE'), findsOneWidget);
    expect(find.text('VİDEO'), findsOneWidget);

    // Verify Settings button exists on top right
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // Open Settings Sheet from Top Bar
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Zamera Ayarları'), findsOneWidget);
    // Dismiss sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Radial setting buttons (.5, 1x, 2x, ISO, WB...) are hidden by default when category opens
    expect(find.text('ISO'), findsNothing);
    expect(find.text('WB'), findsNothing);

    // Swipe up on the shutter button in the direction of the arrow to open radial setting buttons
    await tester.drag(find.byKey(const ValueKey('shutter_button_gesture')), const Offset(0, -45));
    await tester.pumpAndSettle();
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('WB'), findsOneWidget);

    // Select a radial setting button (e.g. ISO) and verify radial adjustment dial opens
    await tester.tap(find.text('ISO'));
    await tester.pumpAndSettle();

    // Switch to PORTRE mode and verify ideal default settings (radial menu resets to hidden)
    await tester.tap(find.text('PORTRE'));
    await tester.pumpAndSettle();
    expect(find.text('ƒ 2.0'), findsOneWidget);
    expect(find.text('ISO'), findsNothing);

    // Swipe up on shutter in PORTRE mode, tap IŞIK and verify Panjur & Monochrome effects exist
    await tester.drag(find.byKey(const ValueKey('shutter_button_gesture')), const Offset(0, -45));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IŞIK'));
    await tester.pumpAndSettle();
    expect(find.text('PANJUR GÖLGESİ'), findsOneWidget);
    expect(find.text('PANJUR MONO'), findsOneWidget);
    expect(find.text('SAHNE MONO'), findsOneWidget);

    // Switch to VİDEO mode and verify Cinema HUD + swipe-up radial Cinema buttons (FPS, AÇI, PROFİL, LUT, SES)
    await tester.tap(find.text('VİDEO'));
    await tester.pumpAndSettle();
    expect(find.textContaining('STBY 00:00:00:00'), findsOneWidget);

    await tester.drag(find.byKey(const ValueKey('shutter_button_gesture')), const Offset(0, -45));
    await tester.pumpAndSettle();
    expect(find.text('FPS'), findsOneWidget);
    expect(find.text('AÇI'), findsOneWidget);
    expect(find.text('PROFİL'), findsOneWidget);
    expect(find.text('LUT'), findsOneWidget);
    expect(find.text('SES'), findsOneWidget);
    expect(find.text('2× DİJ'), findsOneWidget);

    // Open LUT radial dial and verify .CUBE loader and LUT pills appear
    await tester.tap(find.text('LUT'));
    await tester.pumpAndSettle();
    expect(find.text('.CUBE YÜKLE'), findsOneWidget);

    // Verify radial setting buttons are hidden from wheel while a dial is active (anti-clutter)
    expect(find.text('SES'), findsNothing);

    // Verify Active Dial Return Pill is visible directly above mode strip
    expect(find.byIcon(Icons.undo_rounded), findsOneWidget);

    // Tap return pill and verify radial settings menu re-opens cleanly
    await tester.tap(find.byIcon(Icons.undo_rounded));
    await tester.pumpAndSettle();
    expect(find.text('FPS'), findsOneWidget);
    expect(find.text('AÇI'), findsOneWidget);
    expect(find.text('SES'), findsOneWidget);

    // Tap MF in Video mode and verify curved tangent options (AF OTO, SONSUZ, PEAKING, A<->B)
    await tester.tap(find.text('MF'));
    await tester.pumpAndSettle();
    expect(find.text('AF (OTOMATİK)'), findsOneWidget);
    expect(find.text('∞ SONSUZ'), findsOneWidget);
    expect(find.text('PEAKING'), findsOneWidget);

    // Return to radial menu via return pill again
    await tester.tap(find.byIcon(Icons.undo_rounded));
    await tester.pumpAndSettle();
    expect(find.text('EV'), findsOneWidget);
  });
}
