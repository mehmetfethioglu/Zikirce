import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamera/dialogs/settings_sheet.dart';
import 'package:zamera/models/app_version_info.dart';
import 'package:zamera/models/radial_ring_models.dart';
import 'package:zamera/models/zamera_preferences.dart';
import 'package:zamera/painters/radial_wheel_painter.dart';
import 'package:zamera/screens/camera_home_screen.dart';
import 'package:zamera/services/version_tracking_service.dart';
import 'package:zamera/services/zamera_settings_store.dart';
import 'package:zamera/widgets/radial_shutter_feature_arc.dart';
import 'package:zamera/widgets/video_cinema_hud.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Support email is updated to theakar@windowslive.com', () {
    expect(AppVersionInfo.supportEmail, equals('theakar@windowslive.com'));
  });

  test('ZameraPreferences JSON round-trip and SharedPrefsZameraSettingsStore work cleanly', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPrefsZameraSettingsStore();

    const customPrefs = ZameraPreferences(
      photoFormat: PhotoCaptureFormat.proRaw48Mp,
      photoColorSpace: PhotoColorSpace.displayP3,
      fullSensorResolution: true,
      videoContainer: VideoContainerFormat.movProRes422Hq,
      videoResolution: VideoResolutionPreset.fhd1080p,
      defaultVideoFps: 24,
      videoBitrate: VideoBitrateTier.cinemaAllIntra,
      videoAudioFormat: VideoAudioFormat.pcm24BitUncompressed,
      lock180ShutterAngleByDefault: false,
      showLiveHistogramByDefault: true,
      showFocusPeakingByDefault: true,
    );

    final saved = await store.save(customPrefs);
    expect(saved, isTrue);

    final loaded = await store.load();
    expect(loaded, equals(customPrefs));
    expect(loaded.photoFormat.prefersProRaw48Mp, isTrue);
    expect(loaded.photoColorSpace.usesDisplayP3, isTrue);
    expect(loaded.videoResolution.heightPx, equals(1080));

    final resetOk = await store.reset();
    expect(resetOk, isTrue);
    final afterReset = await store.load();
    expect(afterReset, equals(const ZameraPreferences()));
  });

  test('RadialRingGeometry classifies Ring 0, Ring 1, and Ring 2 strictly and independently', () {
    const center = Offset(200, 310);
    final innerR = RadialRingGeometry.computeInnerWheelRadius(400); // 236.0
    final secRadii = RadialRingGeometry.secondaryBandRadii(innerR);
    final outerWithSec =
        RadialRingGeometry.outerFeatureBandRadii(innerR, hasSecondary: true);
    final outerNoSec =
        RadialRingGeometry.outerFeatureBandRadii(innerR, hasSecondary: false);

    // When secondary ring is empty, Ring 2 collapses cleanly onto innerR with zero gap
    expect(outerNoSec.inner, equals(innerR));
    expect(outerWithSec.inner, equals(secRadii.outer));

    // Hit-test apex points on each concentric band
    final ring0Pt = Offset(center.dx, center.dy - (innerR - 30.0));
    final ring1Pt = Offset(center.dx, center.dy - secRadii.mid);
    final ring2Pt = Offset(center.dx, center.dy - outerWithSec.mid);

    expect(
      RadialRingGeometry.hitTestBand(
        point: ring0Pt,
        center: center,
        innerWheelRadius: innerR,
        hasSecondary: true,
        hasOuterFeature: true,
      ),
      equals(RadialRingBand.innerPrimary),
    );
    expect(
      RadialRingGeometry.hitTestBand(
        point: ring1Pt,
        center: center,
        innerWheelRadius: innerR,
        hasSecondary: true,
        hasOuterFeature: true,
      ),
      equals(RadialRingBand.middleSecondary),
    );
    expect(
      RadialRingGeometry.hitTestBand(
        point: ring2Pt,
        center: center,
        innerWheelRadius: innerR,
        hasSecondary: true,
        hasOuterFeature: true,
      ),
      equals(RadialRingBand.outerFeature),
    );
  });

  testWidgets('Full-screen SettingsSheet renders photo/video recording formats and support email', (tester) async {
    ZameraPreferences? updatedPrefs;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => SettingsSheet.show(
                  context,
                  onOpenProbe: () {},
                  onOpenCalibration: () {},
                  onPreferencesChanged: (next) => updatedPrefs = next,
                ),
                child: const Text('OPEN_SETTINGS'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN_SETTINGS'));
    await tester.pumpAndSettle();

    // Verify SettingsSheet covers the entire full-screen viewport (800x600)
    final sheetSize = tester.getSize(find.byType(SettingsSheet));
    expect(sheetSize.width, equals(800.0));
    expect(sheetSize.height, equals(600.0));

    // Verify new support email & recording format sections
    expect(
      find.text('theakar@windowslive.com', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('GÖRÜNTÜ KAYIT FORMATLARI', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('VİDEO KAYIT FORMATLARI', skipOffstage: false),
      findsOneWidget,
    );

    // Select 48MP ProRAW format and verify callback fires with updated preference
    final proRawFinder = find.text('PRORAW 48', skipOffstage: false);
    expect(proRawFinder, findsOneWidget);
    await tester.ensureVisible(proRawFinder);
    await tester.pumpAndSettle();
    await tester.tap(proRawFinder);
    await tester.pumpAndSettle();

    expect(updatedPrefs, isNotNull);
    expect(updatedPrefs!.photoFormat, equals(PhotoCaptureFormat.proRaw48Mp));
  });

  testWidgets('All 4 modes render radial above-shutter features, move them to outermost Ring 2 on dial select, and adjust rings independently', (tester) async {
    SharedPreferences.setMockInitialValues({
      'zamera_last_seen_version': AppVersionInfo.currentVersion,
      'zamera_last_seen_build': AppVersionInfo.currentBuildNumber,
      'zamera_has_completed_onboarding': true,
    });
    final vs = await VersionTrackingService.initialize();
    final memStore = InMemoryZameraSettingsStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ZameraHomeScreen(
          versionService: vs,
          settingsStore: memStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    IosCameraRadialWheelPainter currentWheelPainter() {
      final cpFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is IosCameraRadialWheelPainter,
      );
      expect(cpFinder, findsOneWidget);
      return tester.widget<CustomPaint>(cpFinder).painter
          as IosCameraRadialWheelPainter;
    }

    // 1. SANAT mode: RadialShutterFeatureArc is shown above shutter; selecting ISO moves features to outermost Ring 2
    expect(find.byType(RadialShutterFeatureArc), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('shutter_button_gesture')),
      const Offset(0, -45),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ISO'));
    await tester.pumpAndSettle();

    final sanatPainter = currentWheelPainter();
    expect(sanatPainter.secondaryItems, isEmpty);
    expect(
      sanatPainter.outerFeatureItems.map((e) => e.label),
      containsAll(<String>['1:1 TON', 'GRİ KART WB', 'KAYIPSIZ PNG']),
    );

    // 2. PRO mode: RadialShutterFeatureArc is shown above shutter; selecting WB exposes 3 independent rings!
    await tester.tap(find.text('PRO'));
    await tester.pumpAndSettle();
    expect(find.byType(RadialShutterFeatureArc), findsOneWidget);
    expect(find.text('ZEBRA %95'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('shutter_button_gesture')),
      const Offset(0, -45),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('radial_menu_btn_WB')));
    await tester.pumpAndSettle();

    final proBefore = currentWheelPainter();
    expect(proBefore.secondaryItems, isNotEmpty);
    expect(
      proBefore.outerFeatureItems.map((e) => e.label),
      containsAll(<String>['ZEBRA %95', 'PEAKING', 'HİSTOGRAM']),
    );

    final domeFinder =
        find.byKey(const ValueKey('radial_concentric_dome_gesture'));
    final domeRect = tester.getRect(domeFinder);
    final wheelCenter = Offset(domeRect.center.dx, domeRect.bottom - 46.0);
    final innerR = RadialRingGeometry.computeInnerWheelRadius(domeRect.width);
    final secBand = RadialRingGeometry.secondaryBandRadii(innerR);
    final extBand =
        RadialRingGeometry.outerFeatureBandRadii(innerR, hasSecondary: true);

    final norm0 = proBefore.normalizedValue;
    final sec0 = proBefore.secondaryScrollPos;
    final out0 = proBefore.outerFeatureScrollPos;

    // A) Dragging Outermost Ring 2 changes ONLY outerFeatureScrollPos (Ring 0 & Ring 1 untouched!)
    await tester.dragFrom(
      Offset(wheelCenter.dx, wheelCenter.dy - extBand.mid),
      const Offset(-85, 0),
    );
    await tester.pumpAndSettle();
    final afterRing2Drag = currentWheelPainter();
    expect(afterRing2Drag.outerFeatureScrollPos, isNot(equals(out0)));
    expect(afterRing2Drag.normalizedValue, equals(norm0));
    expect(afterRing2Drag.secondaryScrollPos, equals(sec0));

    // B) Dragging Middle Ring 1 changes ONLY secondaryScrollPos (Ring 0 & Ring 2 untouched!)
    final outAfter2 = afterRing2Drag.outerFeatureScrollPos;
    await tester.dragFrom(
      Offset(wheelCenter.dx, wheelCenter.dy - secBand.mid),
      const Offset(-90, 0),
    );
    await tester.pumpAndSettle();
    final afterRing1Drag = currentWheelPainter();
    expect(afterRing1Drag.secondaryScrollPos, isNot(equals(sec0)));
    expect(afterRing1Drag.normalizedValue, equals(norm0));
    expect(afterRing1Drag.outerFeatureScrollPos, equals(outAfter2));

    // C) Dragging Inner Ring 0 changes ONLY normalizedValue (Ring 1 & Ring 2 untouched!)
    final secAfter1 = afterRing1Drag.secondaryScrollPos;
    await tester.dragFrom(
      Offset(wheelCenter.dx, wheelCenter.dy - (innerR - 45.0)),
      const Offset(-95, 0),
    );
    await tester.pumpAndSettle();
    final afterRing0Drag = currentWheelPainter();
    expect(afterRing0Drag.normalizedValue, isNot(equals(norm0)));
    expect(afterRing0Drag.secondaryScrollPos, equals(secAfter1));
    expect(afterRing0Drag.outerFeatureScrollPos, equals(outAfter2));

    // 3. PORTRE & VİDEO modes also render radial above-shutter decks and transfer features to Ring 2
    await tester.tap(find.text('PORTRE'));
    await tester.pumpAndSettle();
    expect(find.byType(RadialShutterFeatureArc), findsOneWidget);

    await tester.tap(find.text('VİDEO'));
    await tester.pumpAndSettle();
    expect(find.byType(VideoCinemaQuickDeck), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('shutter_button_gesture')),
      const Offset(0, -45),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('radial_menu_btn_FPS')));
    await tester.pumpAndSettle();
    expect(
      currentWheelPainter().outerFeatureItems.map((e) => e.label),
      containsAll(<String>['ODAK A', 'ODAK B', 'A↔B GEÇİŞ']),
    );
  });
}
