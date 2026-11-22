import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/session/session_providers.dart';
import 'package:zikirce/core/session/user_session.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/namaz_vakitleri/domain/qibla_math.dart';
import 'package:zikirce/features/namaz_vakitleri/domain/qibla_models.dart';
import 'package:zikirce/features/namaz_vakitleri/presentation/screens/qibla_compass_screen.dart';
import 'package:zikirce/features/namaz_vakitleri/presentation/widgets/qibla_3d_painter.dart';
import 'package:zikirce/features/namaz_vakitleri/presentation/widgets/qibla_finder_card.dart';
import 'package:zikirce/features/namaz_vakitleri/providers/qibla_providers.dart';
import 'package:zikirce/features/namaz_vakitleri/services/qibla_sensor_service.dart';

class _FakeQiblaSensorSource implements QiblaSensorSource {
  final StreamController<QiblaSensorSample> _controller =
      StreamController<QiblaSensorSample>.broadcast();
  bool started = false;
  bool disposed = false;

  @override
  Stream<QiblaSensorSample> get sampleStream => _controller.stream;

  @override
  void start() {
    started = true;
  }

  void emit(QiblaSensorSample sample) {
    if (!disposed && !_controller.isClosed) {
      _controller.add(sample);
    }
  }

  @override
  void dispose() {
    disposed = true;
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('QiblaMath birim testleri', () {
    test('Başlıca şehirler için küresel kıble açısını doğru hesaplar', () {
      expect(
        QiblaMath.calculateQiblaBearing(41.0082, 28.9784),
        closeTo(151.6, 0.8),
      ); // İstanbul
      expect(
        QiblaMath.calculateQiblaBearing(39.9334, 32.8597),
        closeTo(159.4, 0.8),
      ); // Ankara
      expect(
        QiblaMath.calculateQiblaBearing(40.7128, -74.0060),
        closeTo(58.5, 0.8),
      ); // New York
      expect(
        QiblaMath.calculateQiblaBearing(-6.2088, 106.8456),
        closeTo(295.1, 0.8),
      ); // Cakarta
    });

    test('İstanbul ile Kâbe arasındaki Haversine mesafesini doğru hesaplar', () {
      final km = QiblaMath.calculateDistanceToKaabaKm(41.0082, 28.9784);
      expect(km, inInclusiveRange(2380.0, 2420.0));
    });

    test('Manyetik sapma (declination) Türkiye, Londra ve NYC için doğrudur', () {
      final istDec = QiblaMath.estimateMagneticDeclination(41.0082, 28.9784);
      final ankDec = QiblaMath.estimateMagneticDeclination(39.9334, 32.8597);
      final nycDec = QiblaMath.estimateMagneticDeclination(40.7128, -74.0060);
      final lonDec = QiblaMath.estimateMagneticDeclination(51.5074, -0.1278);

      expect(istDec, inInclusiveRange(5.5, 7.0));
      expect(ankDec, inInclusiveRange(5.5, 7.0));
      expect(nycDec, lessThan(-10.0));
      expect(lonDec, inInclusiveRange(0.0, 2.5));
    });

    test('Eğim düzeltmeli pusula düz ve 20° eğimli konumda yönü korur', () {
      // Yatay zemin: K=0°, D=90°, G=180°, B=270°
      final north = QiblaMath.calculateTiltCompensatedHeading(
        ax: 0, ay: 0, az: 9.81, mx: 0, my: 25, mz: -40,
      );
      final east = QiblaMath.calculateTiltCompensatedHeading(
        ax: 0, ay: 0, az: 9.81, mx: -25, my: 0, mz: -40,
      );
      final south = QiblaMath.calculateTiltCompensatedHeading(
        ax: 0, ay: 0, az: 9.81, mx: 0, my: -25, mz: -40,
      );
      final west = QiblaMath.calculateTiltCompensatedHeading(
        ax: 0, ay: 0, az: 9.81, mx: 25, my: 0, mz: -40,
      );

      expect(QiblaMath.shortestAngleDelta(north!, 0).abs(), lessThan(0.5));
      expect(east, closeTo(90.0, 0.5));
      expect(south, closeTo(180.0, 0.5));
      expect(west, closeTo(270.0, 0.5));

      // Telefon 20° öne eğikken (X ekseni etrafında dönüş) Kuzey yine 0° olmalı
      const tiltRad = 20.0 * math.pi / 180.0;
      final c = math.cos(tiltRad);
      final s = math.sin(tiltRad);
      final tiltedNorth = QiblaMath.calculateTiltCompensatedHeading(
        ax: 0.0,
        ay: 9.81 * s,
        az: 9.81 * c,
        mx: 0.0,
        my: 25.0 * c - 40.0 * s,
        mz: -25.0 * s - 40.0 * c,
      );
      expect(
        QiblaMath.shortestAngleDelta(tiltedNorth!, 0).abs(),
        lessThan(0.5),
      );
    });

    test('Dairesel açı farkı ve 359°↔0° yumuşatması takla atmaz', () {
      expect(QiblaMath.shortestAngleDelta(355.0, 5.0), closeTo(10.0, 1e-6));
      expect(QiblaMath.shortestAngleDelta(5.0, 355.0), closeTo(-10.0, 1e-6));
      final smoothed = QiblaMath.smoothAngleDeg(358.0, 2.0, 0.5);
      expect(QiblaMath.shortestAngleDelta(smoothed, 0.0).abs(), lessThan(0.01));
    });

    test('Güneş astronomi hesabı öğlen güney yönü ve gece ufuk altı üretir', () {
      final noonSolar = QiblaMath.calculateSolarPosition(
        41.0082,
        28.9784,
        DateTime.utc(2026, 6, 21, 10, 4),
      );
      expect(noonSolar.azimuthDeg, closeTo(180.0, 5.0));
      expect(noonSolar.elevationDeg, greaterThan(60.0));

      final nightSolar = QiblaMath.calculateSolarPosition(
        41.0082,
        28.9784,
        DateTime.utc(2026, 6, 21, 22, 0),
      );
      expect(nightSolar.elevationDeg, lessThan(-10.0));
    });
  });

  group('QiblaController durum makinesi ve hysteresis testleri', () {
    late _FakeQiblaSensorSource fakeSensor;
    late ProviderContainer container;
    late ProviderSubscription<QiblaState> sub;

    setUp(() {
      fakeSensor = _FakeQiblaSensorSource();
      container = ProviderContainer(
        overrides: [
          qiblaSensorSourceProvider.overrideWithValue(fakeSensor),
          activeSessionProvider.overrideWithValue(UserSession.defaultSession()),
        ],
      );
      sub = container.listen(qiblaControllerProvider(const QiblaParams()), (_, __) {});
    });

    tearDown(() {
      sub.close();
      container.dispose();
    });

    test('Uzak -> yaklaşan -> kilitli -> (350ms) tekbir -> (1350ms) kıyam akışı', () async {
      const params = QiblaParams();
      final controller = container.read(qiblaControllerProvider(params).notifier);
      var state = container.read(qiblaControllerProvider(params));

      expect(fakeSensor.started, isTrue);
      expect(state.isSoundEnabled, isFalse);

      final bearing = state.qiblaBearingDeg;
      final dec = state.declinationDeg;

      // 1) Uzak yön (~60° uzak)
      controller.onSensorSample(
        QiblaSensorSample(
          headingDeg: QiblaMath.normalizeAngleDeg(bearing - dec - 60.0),
          tiltDeg: 3.0,
          pitchDeg: 2.0,
          rollDeg: 1.0,
          magneticFieldUt: 45.0,
        ),
      );
      expect(
        container.read(qiblaControllerProvider(params)).phase,
        QiblaAlignmentPhase.searching,
      );

      // 2) Yaklaşan yön (~15° uzak — sensör LPF yumuşatması için ardışık örnekler)
      for (var i = 0; i < 10; i++) {
        controller.onSensorSample(
          QiblaSensorSample(
            headingDeg: QiblaMath.normalizeAngleDeg(bearing - dec - 15.0),
            tiltDeg: 3.0,
            pitchDeg: 2.0,
            rollDeg: 1.0,
            magneticFieldUt: 45.0,
          ),
        );
      }
      expect(
        container.read(qiblaControllerProvider(params)).phase,
        QiblaAlignmentPhase.approaching,
      );

      // 3) Kıbleye tam hizalı (< 4°) -> locked -> 350ms sonra takbir -> 1350ms sonra qiyam
      for (var i = 0; i < 12; i++) {
        controller.onSensorSample(
          QiblaSensorSample(
            headingDeg: QiblaMath.normalizeAngleDeg(bearing - dec),
            tiltDeg: 2.0,
            pitchDeg: 1.0,
            rollDeg: 1.0,
            magneticFieldUt: 45.0,
          ),
        );
      }
      expect(
        container.read(qiblaControllerProvider(params)).phase,
        QiblaAlignmentPhase.locked,
      );

      await Future<void>.delayed(const Duration(milliseconds: 420));
      state = container.read(qiblaControllerProvider(params));
      expect(state.phase, QiblaAlignmentPhase.takbir);

      await Future<void>.delayed(const Duration(milliseconds: 1450));
      state = container.read(qiblaControllerProvider(params));
      expect(state.phase, QiblaAlignmentPhase.qiyam);

      // 4) Hysteresis kontrolü: 6° sapmada kilitli kalır, 11° sapmada kilit açılır
      controller.setManualHeading(bearing + 6.0);
      expect(
        container.read(qiblaControllerProvider(params)).phase,
        QiblaAlignmentPhase.qiyam,
      );

      controller.setManualHeading(bearing + 11.0);
      expect(
        container.read(qiblaControllerProvider(params)).phase,
        QiblaAlignmentPhase.approaching,
      );
    });

    test('Telefon dik iken (tilt > 22°) tekbir tetiklenmez', () async {
      const params = QiblaParams();
      final controller = container.read(qiblaControllerProvider(params).notifier);
      final initial = container.read(qiblaControllerProvider(params));

      controller.onSensorSample(
        QiblaSensorSample(
          headingDeg: QiblaMath.normalizeAngleDeg(
            initial.qiblaBearingDeg - initial.declinationDeg,
          ),
          tiltDeg: 35.0,
          pitchDeg: 35.0,
          rollDeg: 0.0,
          magneticFieldUt: 45.0,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 420));
      final state = container.read(qiblaControllerProvider(params));
      expect(state.isPhoneFlat, isFalse);
      expect(state.phase, isNot(QiblaAlignmentPhase.takbir));
      expect(state.phase, isNot(QiblaAlignmentPhase.qiyam));
    });

    test('Manyetik parazit (95 µT) uyarısı ve figür/ses tercihleri çalışır', () {
      const params = QiblaParams();
      final controller = container.read(qiblaControllerProvider(params).notifier);
      final initial = container.read(qiblaControllerProvider(params));

      expect(initial.figureMode, QiblaFigureMode.male);
      expect(initial.isSoundEnabled, isFalse);

      controller.onSensorSample(
        const QiblaSensorSample(
          headingDeg: 100.0,
          tiltDeg: 5.0,
          pitchDeg: 3.0,
          rollDeg: 2.0,
          magneticFieldUt: 95.0,
        ),
      );
      expect(
        container.read(qiblaControllerProvider(params)).sensorStatus,
        QiblaSensorStatus.interference,
      );

      controller.cycleFigureMode();
      expect(
        container.read(qiblaControllerProvider(params)).figureMode,
        QiblaFigureMode.female,
      );
      controller.cycleFigureMode();
      expect(
        container.read(qiblaControllerProvider(params)).figureMode,
        QiblaFigureMode.prayerRugOnly,
      );
      controller.cycleFigureMode();
      expect(
        container.read(qiblaControllerProvider(params)).figureMode,
        QiblaFigureMode.male,
      );

      controller.toggleSound();
      expect(
        container.read(qiblaControllerProvider(params)).isSoundEnabled,
        isTrue,
      );
    });

    test('Kıble 0° etrafında ±1.2° sensör salınımında zıplamayı ölü bölgeyle sönümler ve Tekbir tekrarlanır',
        () async {
      const params = QiblaParams();
      final controller = container.read(qiblaControllerProvider(params).notifier);
      final initial = container.read(qiblaControllerProvider(params));
      final bearing = initial.qiblaBearingDeg;
      final dec = initial.declinationDeg;

      // Kilitlen ve tekbire geç
      controller.onSensorSample(
        QiblaSensorSample(
          headingDeg: QiblaMath.normalizeAngleDeg(bearing - dec),
          tiltDeg: 1.0,
          pitchDeg: 0.5,
          rollDeg: 0.5,
          magneticFieldUt: 45.0,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        container.read(qiblaControllerProvider(params)).phase,
        QiblaAlignmentPhase.takbir,
      );

      final lockedHeading =
          container.read(qiblaControllerProvider(params)).headingDeg;

      // +1.2° ve -1.2° salınım -> 1.5° deadband nedeniyle heading sabit kalır
      controller.onSensorSample(
        QiblaSensorSample(
          headingDeg: QiblaMath.normalizeAngleDeg(bearing - dec + 1.2),
          tiltDeg: 1.0,
          pitchDeg: 0.5,
          rollDeg: 0.5,
          magneticFieldUt: 45.0,
        ),
      );
      controller.onSensorSample(
        QiblaSensorSample(
          headingDeg: QiblaMath.normalizeAngleDeg(bearing - dec - 1.2),
          tiltDeg: 1.0,
          pitchDeg: 0.5,
          rollDeg: 0.5,
          magneticFieldUt: 45.0,
        ),
      );
      expect(
        container.read(qiblaControllerProvider(params)).headingDeg,
        equals(lockedHeading),
      );

      // Kıyam aşamasına geç ve replayTakbir()'i doğrula
      await Future<void>.delayed(const Duration(milliseconds: 1450));
      var state = container.read(qiblaControllerProvider(params));
      expect(state.phase, QiblaAlignmentPhase.qiyam);
      final prevTick = state.takbirReplayTick;

      controller.replayTakbir();
      state = container.read(qiblaControllerProvider(params));
      expect(state.phase, QiblaAlignmentPhase.takbir);
      expect(state.takbirReplayTick, equals(prevTick + 1));

      await Future<void>.delayed(const Duration(milliseconds: 1450));
      expect(
        container.read(qiblaControllerProvider(params)).phase,
        QiblaAlignmentPhase.qiyam,
      );
    });
  });

  group('Qibla3DPainter giydirme ve kamera kararlılık testleri', () {
    Qibla3DPainter buildPainter({
      required QiblaFigureMode mode,
      required double displayHeadingDeg,
      double takbirProgress = 0.0,
      double cameraOrbitProgress = 0.0,
      double lockSnapProgress = 0.0,
    }) {
      return Qibla3DPainter(
        displayHeadingDeg: displayHeadingDeg,
        qiblaBearingDeg: 152.0,
        sunAzimuthDeg: 185.0,
        isSunVisible: true,
        tiltDeg: 2.0,
        pitchDeg: 1.0,
        rollDeg: 1.0,
        isPhoneFlat: true,
        isInteractivePreview: false,
        phase: cameraOrbitProgress > 0.5
            ? QiblaAlignmentPhase.qiyam
            : QiblaAlignmentPhase.searching,
        figureMode: mode,
        breathPhase: 0.25,
        takbirProgress: takbirProgress,
        cameraOrbitProgress: cameraOrbitProgress,
        lockSnapProgress: lockSnapProgress,
        isTurkish: true,
        isDark: false,
        accentColor: const Color(0xFF236B56),
        goldColor: const Color(0xFFD4A574),
        cardBackground: Colors.white,
        primaryText: const Color(0xFF1E2B27),
        secondaryText: const Color(0xFF506861),
      );
    }

    test('Kâbe dünya yüksekliği figür boyundan büyüktür (anıtsal orantı)', () {
      expect(
        Qibla3DPainter.kaabaWorldHeight,
        greaterThanOrEqualTo(Qibla3DPainter.characterWorldHeight),
      );
    });

    test('Erkek, Kadın ve Sadece Seccade modları tüm animasyon aşamalarında hatasız çizilir',
        () {
      for (final mode in QiblaFigureMode.values) {
        for (final progress in const <double>[0.0, 0.5, 1.0]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final painter = buildPainter(
            mode: mode,
            displayHeadingDeg: 152.0,
            takbirProgress: progress,
            cameraOrbitProgress: progress,
          );
          painter.paint(canvas, const Size(320, 320));
          final picture = recorder.endRecording();
          picture.dispose();
        }
      }
    });

    testWidgets(
        'Kıble 0° geçişinde (+0.5° vs -0.5°) 3B sahne kamerası sağa-sola zıplamaz',
        (tester) async {
      final recorderPos = ui.PictureRecorder();
      buildPainter(
        mode: QiblaFigureMode.male,
        displayHeadingDeg: 152.5,
        takbirProgress: 1.0,
        cameraOrbitProgress: 1.0,
      ).paint(Canvas(recorderPos), const Size(160, 160));
      final picPos = recorderPos.endRecording();

      final recorderNeg = ui.PictureRecorder();
      buildPainter(
        mode: QiblaFigureMode.male,
        displayHeadingDeg: 151.5,
        takbirProgress: 1.0,
        cameraOrbitProgress: 1.0,
      ).paint(Canvas(recorderNeg), const Size(160, 160));
      final picNeg = recorderNeg.endRecording();

      final ratio = await tester.runAsync(() async {
        final imgPos = await picPos.toImage(160, 160);
        final imgNeg = await picNeg.toImage(160, 160);
        final bytesPos = (await imgPos.toByteData())!.buffer.asUint8List();
        final bytesNeg = (await imgNeg.toByteData())!.buffer.asUint8List();
        imgPos.dispose();
        imgNeg.dispose();

        var differingPixels = 0;
        final totalPixels = bytesPos.length ~/ 4;
        for (var i = 0; i < bytesPos.length; i += 4) {
          final diff = (bytesPos[i] - bytesNeg[i]).abs() +
              (bytesPos[i + 1] - bytesNeg[i + 1]).abs() +
              (bytesPos[i + 2] - bytesNeg[i + 2]).abs() +
              (bytesPos[i + 3] - bytesNeg[i + 3]).abs();
          if (diff > 24) {
            differingPixels++;
          }
        }
        return differingPixels / totalPixels;
      });

      picPos.dispose();
      picNeg.dispose();
      expect(ratio, isNotNull);
      // 1° farkta kameranın zıplamaması nedeniyle piksel değişimi çok düşük (%5 altı) kalır.
      expect(ratio!, lessThan(0.05));
    });

    testWidgets(
        'Kilitli görsel tutunma (lockSnapProgress = 1.0) +3.5° vs -3.5° sapmada 0 piksel farkı verir',
        (tester) async {
      final recorderPos = ui.PictureRecorder();
      buildPainter(
        mode: QiblaFigureMode.female,
        displayHeadingDeg: 155.5,
        takbirProgress: 1.0,
        cameraOrbitProgress: 1.0,
        lockSnapProgress: 1.0,
      ).paint(Canvas(recorderPos), const Size(160, 160));
      final picPos = recorderPos.endRecording();

      final recorderNeg = ui.PictureRecorder();
      buildPainter(
        mode: QiblaFigureMode.female,
        displayHeadingDeg: 148.5,
        takbirProgress: 1.0,
        cameraOrbitProgress: 1.0,
        lockSnapProgress: 1.0,
      ).paint(Canvas(recorderNeg), const Size(160, 160));
      final picNeg = recorderNeg.endRecording();

      final differingPixels = await tester.runAsync(() async {
        final imgPos = await picPos.toImage(160, 160);
        final imgNeg = await picNeg.toImage(160, 160);
        final bytesPos = (await imgPos.toByteData())!.buffer.asUint8List();
        final bytesNeg = (await imgNeg.toByteData())!.buffer.asUint8List();
        imgPos.dispose();
        imgNeg.dispose();

        var count = 0;
        for (var i = 0; i < bytesPos.length; i += 4) {
          if (bytesPos[i] != bytesNeg[i] ||
              bytesPos[i + 1] != bytesNeg[i + 1] ||
              bytesPos[i + 2] != bytesNeg[i + 2] ||
              bytesPos[i + 3] != bytesNeg[i + 3]) {
            count++;
          }
        }
        return count;
      });

      picPos.dispose();
      picNeg.dispose();
      expect(differingPixels, equals(0));
    });
  });

  group('Widget testleri', () {
    Widget buildTestApp(
      Widget child, {
      List<Override> overrides = const <Override>[],
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const <Locale>[Locale('tr'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData.light().copyWith(
            extensions: const <ThemeExtension<dynamic>>[
              AppThemeColors.greenLight,
            ],
          ),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('QiblaFinderCard şehir adı, açı ve Kâbe mesafesini gösterir',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(const QiblaFinderCard()),
      );
      await tester.pump();

      final expectedKm = QiblaFinderCard.formatKm(
        QiblaMath.calculateDistanceToKaabaKm(41.0082, 28.9784),
        isTurkish: true,
      );
      expect(find.byKey(const Key('qibla_finder_card')), findsOneWidget);
      expect(find.textContaining('İstanbul'), findsOneWidget);
      expect(find.textContaining('152° GD'), findsOneWidget);
      expect(find.textContaining(expectedKm), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
        'QiblaCompassScreen etkileşimli önizleme, figür modu, ses ve tekbir akışını çalıştırır',
        (tester) async {
      final fakeSensor = _FakeQiblaSensorSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            qiblaSensorSourceProvider.overrideWithValue(fakeSensor),
            activeSessionProvider.overrideWithValue(UserSession.defaultSession()),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: const <Locale>[Locale('tr'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData.light().copyWith(
              extensions: const <ThemeExtension<dynamic>>[
                AppThemeColors.greenLight,
              ],
            ),
            home: const QiblaCompassScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('qibla_compass_dial')), findsOneWidget);
      expect(find.byKey(const Key('qibla_scenario_stepper')), findsOneWidget);
      expect(find.textContaining('Düz Tut'), findsOneWidget);
      expect(find.textContaining('Kâbe\'ye Dön'), findsOneWidget);
      expect(find.textContaining('Tekbir'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('qibla_figure_mode_btn')), findsOneWidget);
      expect(find.byKey(const Key('qibla_sound_toggle_btn')), findsOneWidget);
      expect(find.byKey(const Key('qibla_preview_toggle_btn')), findsOneWidget);

      // 1800ms sensör zaman aşımı sonrası etkileşimli önizleme aktifleşir
      await tester.pump(const Duration(milliseconds: 1850));
      expect(find.text('Canlı Pusula'), findsOneWidget);

      // Figür modu değişimi (Erkek -> Kadın -> Sadece Seccade)
      await tester.tap(find.byKey(const Key('qibla_figure_mode_btn')));
      await tester.pump();
      expect(find.text('Kadın Figür'), findsOneWidget);

      await tester.tap(find.byKey(const Key('qibla_figure_mode_btn')));
      await tester.pump();
      expect(find.text('Sadece Seccade'), findsOneWidget);

      // Ses açma
      await tester.tap(find.byKey(const Key('qibla_sound_toggle_btn')));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      // Parmakla yatay sürükleyince heading değişir
      final beforeDragHeading =
          ProviderScope.containerOf(tester.element(find.byKey(const Key('qibla_compass_dial'))))
              .read(qiblaControllerProvider(const QiblaParams()))
              .headingDeg;
      await tester.drag(
        find.byKey(const Key('qibla_compass_dial')),
        const Offset(-80, 0),
      );
      await tester.pump();
      final afterDragHeading =
          ProviderScope.containerOf(tester.element(find.byKey(const Key('qibla_compass_dial'))))
              .read(qiblaControllerProvider(const QiblaParams()))
              .headingDeg;
      expect(afterDragHeading, isNot(equals(beforeDragHeading)));

      // Sensör üzerinden kıbleye hizala -> tekbir ve kıyam metni görünmeli
      final element = tester.element(find.byKey(const Key('qibla_compass_dial')));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(
        qiblaControllerProvider(const QiblaParams()).notifier,
      );
      final bearing =
          container.read(qiblaControllerProvider(const QiblaParams())).qiblaBearingDeg;
      controller.setManualHeading(bearing);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('İftitah Tekbiri'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1450));
      expect(find.textContaining('Kıyam'), findsOneWidget);
      expect(find.byKey(const Key('qibla_replay_takbir_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('qibla_replay_takbir_btn')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.textContaining('İftitah Tekbiri'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.textContaining('Kıyam'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
