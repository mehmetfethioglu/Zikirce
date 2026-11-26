import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamera/dialogs/settings_sheet.dart';
import 'package:zamera/dialogs/zamera_paywall_sheet.dart';
import 'package:zamera/l10n/zamera_l10n.dart';
import 'package:zamera/models/zamera_monetization_models.dart';
import 'package:zamera/models/zamera_preferences.dart';
import 'package:zamera/services/zamera_monetization_gateway.dart';
import 'package:zamera/services/zamera_monetization_service.dart';
import 'package:zamera/widgets/studio/sticker_studio_sheet.dart';

class _FakeBillingGateway implements BillingGateway {
  final StreamController<BillingPurchaseUpdate> _controller =
      StreamController<BillingPurchaseUpdate>.broadcast();
  final Map<ZameraPlanId, String> livePrices;
  final List<ZameraPlanId> purchasedPlans = <ZameraPlanId>[];
  ZameraPlanId? autoRestorePlan;

  _FakeBillingGateway({
    this.livePrices = const <ZameraPlanId, String>{},
    this.autoRestorePlan,
  });

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<ZameraPlanId, ZameraStoreOffer>> queryPrices() async {
    return <ZameraPlanId, ZameraStoreOffer>{
      for (final plan in ZameraPlanId.values)
        plan: ZameraStoreOffer(
          plan: plan,
          localizedPrice: livePrices[plan],
          isLiveFromStore: livePrices.containsKey(plan),
        ),
    };
  }

  @override
  Stream<BillingPurchaseUpdate> get purchaseUpdates => _controller.stream;

  @override
  Future<bool> buy(ZameraPlanId plan) async {
    purchasedPlans.add(plan);
    _controller.add(
      BillingPurchaseUpdate(
        eventType: BillingEventType.purchased,
        productId: plan.productId,
        transactionId: 'tx_${plan.name}',
      ),
    );
    return true;
  }

  @override
  Future<void> restore() async {
    final plan = autoRestorePlan;
    if (plan != null) {
      _controller.add(
        BillingPurchaseUpdate(
          eventType: BillingEventType.restored,
          productId: plan.productId,
          transactionId: 'restore_${plan.name}',
        ),
      );
    }
  }

  final List<String> acknowledgedProducts = <String>[];

  @override
  Future<void> acknowledgePurchase(String productId, String? transactionId) async {
    acknowledgedProducts.add(productId);
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZameraPlanId & ZameraMonetizationController', () {
    test('OCP catalog defines 30-day (1 month) trial on annualPro and valid product IDs', () {
      expect(ZameraPlanId.annualPro.hasFreeTrial, isTrue);
      expect(ZameraPlanId.annualPro.trialDays, equals(30));
      expect(ZameraPlanId.annualPro.isRecommended, isTrue);
      expect(ZameraPlanId.lifetimePro.isLifetime, isTrue);
      expect(ZameraPlanId.monthlyPro.hasFreeTrial, isFalse);

      expect(
        ZameraPlanId.fromProductId('com.akarworks.zamera.pro.annual'),
        equals(ZameraPlanId.annualPro),
      );
      expect(
        ZameraPlanId.fromProductId('com.akarworks.zamera.pro.lifetime'),
        equals(ZameraPlanId.lifetimePro),
      );
      expect(
        ZameraPlanId.fromProductId('com.akarworks.zamera.pro.monthly'),
        equals(ZameraPlanId.monthlyPro),
      );
      expect(ZameraPlanId.fromProductId('unknown.sku'), isNull);

      final fallbackOffer = const ZameraStoreOffer(plan: ZameraPlanId.annualPro);
      expect(fallbackOffer.priceForLocale(isTurkish: true), equals('₺449,99 / yıl'));
      expect(fallbackOffer.priceForLocale(isTurkish: false), equals(r'$19.99 / yr'));
    });

    test('enforces daily Aha-Moment quotas and resets automatically on UTC day rollover', () async {
      DateTime clock = DateTime.utc(2026, 11, 16, 10, 0);
      final repo = InMemoryMonetizationRepository();
      final billing = _FakeBillingGateway();
      final controller = await ZameraMonetizationController.initialize(
        repository: repo,
        billingGateway: billing,
        nowUtcProvider: () => clock,
        refreshOffersInBackground: false,
      );
      addTearDown(controller.dispose);

      expect(controller.hasProAccess, isFalse);
      expect(
        controller.remainingFreeToday(ZameraProFeature.stickerCutoutExport),
        equals(3),
      );

      // 3 free sticker exports succeed, 4th blocks
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.stickerCutoutExport,
        ),
        isTrue,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.stickerCutoutExport,
        ),
        isTrue,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.stickerCutoutExport,
        ),
        isTrue,
      );
      expect(
        controller.remainingFreeToday(ZameraProFeature.stickerCutoutExport),
        equals(0),
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.stickerCutoutExport,
        ),
        isFalse,
      );

      // 1 free TrueColor shot and 1 free DNG RAW shot succeed, 2nd blocks
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.unlimitedTrueColorCapture,
        ),
        isTrue,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.unlimitedTrueColorCapture,
        ),
        isFalse,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.rawDngCaptureAndExport,
        ),
        isTrue,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.rawDngCaptureAndExport,
        ),
        isFalse,
      );

      // Direct Pro features have 0 free allowance
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.colorCheckerCalibration,
        ),
        isFalse,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.cinemaTenBitLogProRes,
        ),
        isFalse,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.losslessPngArchive,
        ),
        isFalse,
      );

      // Advance clock to next UTC day -> quotas reset cleanly
      clock = DateTime.utc(2026, 11, 17, 0, 5);
      expect(
        controller.remainingFreeToday(ZameraProFeature.stickerCutoutExport),
        equals(3),
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.stickerCutoutExport,
        ),
        isTrue,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.unlimitedTrueColorCapture,
        ),
        isTrue,
      );
    });

    test('activates 30-day free trial on annualPro, handles expiry/restore, and unlocks lifetimePro', () async {
      DateTime clock = DateTime.utc(2026, 11, 16, 12, 0);
      final repo = InMemoryMonetizationRepository();
      final billing = _FakeBillingGateway(
        autoRestorePlan: ZameraPlanId.annualPro,
      );
      final controller = await ZameraMonetizationController.initialize(
        repository: repo,
        billingGateway: billing,
        nowUtcProvider: () => clock,
        refreshOffersInBackground: false,
      );
      addTearDown(controller.dispose);

      expect(await controller.purchasePlan(ZameraPlanId.annualPro), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, equals(ZameraEntitlementStatus.trialActive));
      expect(controller.hasProAccess, isTrue);
      expect(
        controller.state.trialEndsAtUtc,
        equals(DateTime.utc(2026, 12, 16, 12, 0)),
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.colorCheckerCalibration,
        ),
        isTrue,
      );

      // Day 29: trial still active
      clock = DateTime.utc(2026, 12, 15, 12, 0);
      expect(controller.hasProAccess, isTrue);

      // Day 31 without store renewal event -> expired until restored/renewed
      clock = DateTime.utc(2026, 12, 17, 12, 0);
      expect(controller.hasProAccess, isFalse);

      // Store restore confirms renewed active annual subscription
      await controller.restorePurchases();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, equals(ZameraEntitlementStatus.proActive));
      expect(controller.hasProAccess, isTrue);

      // Reload controller from persisted repository & verify lifetimePro
      final reloaded = await ZameraMonetizationController.initialize(
        repository: repo,
        billingGateway: billing,
        nowUtcProvider: () => clock,
        refreshOffersInBackground: false,
      );
      addTearDown(reloaded.dispose);
      expect(reloaded.hasProAccess, isTrue);

      expect(await reloaded.purchasePlan(ZameraPlanId.lifetimePro), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.state.status, equals(ZameraEntitlementStatus.proLifetime));
      expect(reloaded.hasProAccess, isTrue);
      expect(reloaded.state.trialEndsAtUtc, isNull);
    });
  });

  group('Paywall, SettingsSheet & StickerStudioSheet Monetization Widgets', () {
    testWidgets('ZameraPaywallSheet shows 1-month trial default, switches CTAs, and closes on purchase', (tester) async {
      final repo = InMemoryMonetizationRepository();
      final billing = _FakeBillingGateway(
        livePrices: const <ZameraPlanId, String>{
          ZameraPlanId.annualPro: '₺449,99 / yıl',
          ZameraPlanId.lifetimePro: '₺799,99',
          ZameraPlanId.monthlyPro: '₺99,99 / ay',
        },
      );
      final controller = await ZameraMonetizationController.initialize(
        repository: repo,
        billingGateway: billing,
        refreshOffersInBackground: true,
      );
      addTearDown(controller.dispose);

      bool? sheetResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    sheetResult = await ZameraPaywallSheet.show(
                      context,
                      monetization: controller,
                      triggeredFeature: ZameraProFeature.colorCheckerCalibration,
                    );
                  },
                  child: const Text('OPEN_PAYWALL'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN_PAYWALL'));
      await tester.pumpAndSettle();

      expect(find.text('1 AY ÜCRETSİZ DENE'), findsOneWidget);
      expect(find.text('1 Ay Ücretsiz Başlat'), findsOneWidget);
      expect(find.text('Ömür Boyu Pro'), findsOneWidget);
      expect(find.text('Aylık Pro'), findsOneWidget);
      expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
      expect(find.text('24-Yama ColorChecker Kalibrasyonu'), findsOneWidget);

      // Switch to Lifetime Pro -> button updates dynamically
      final lifetimeFinder = find.byKey(
        const ValueKey<String>('paywall_plan_lifetimePro'),
      );
      await tester.ensureVisible(lifetimeFinder);
      await tester.tap(lifetimeFinder);
      await tester.pumpAndSettle();
      expect(find.text('Ömür Boyu Pro Satın Al'), findsOneWidget);

      // Switch back to Annual Pro (1-month trial) and purchase
      final annualFinder = find.byKey(
        const ValueKey<String>('paywall_plan_annualPro'),
      );
      await tester.ensureVisible(annualFinder);
      await tester.tap(annualFinder);
      await tester.pumpAndSettle();

      final ctaFinder = find.byKey(
        const ValueKey<String>('paywall_primary_cta_btn'),
      );
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(sheetResult, isTrue);
      expect(controller.hasProAccess, isTrue);
      expect(billing.purchasedPlans, equals(const <ZameraPlanId>[ZameraPlanId.annualPro]));
    });

    testWidgets('SettingsSheet shows Zamera Pro card and gates PRORAW 48 when free', (tester) async {
      final controller = await ZameraMonetizationController.initialize(
        repository: InMemoryMonetizationRepository(),
        billingGateway: _FakeBillingGateway(),
        refreshOffersInBackground: false,
      );
      addTearDown(controller.dispose);

      ZameraPreferences? savedPrefs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSheet(
              initialPreferences: const ZameraPreferences(
                photoFormat: PhotoCaptureFormat.jpegOnly,
              ),
              monetization: controller,
              onOpenProbe: () {},
              onOpenCalibration: () {},
              onPreferencesChanged: (p) => savedPrefs = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('settings_pro_status_card')),
        findsOneWidget,
      );
      expect(find.text('1 Ay Ücretsiz Dene'), findsOneWidget);

      // Tapping PRORAW 48 opens Paywall and does not mutate prefs unless unlocked
      final proRawFinder = find.text('PRORAW 48', skipOffstage: false);
      await tester.ensureVisible(proRawFinder);
      await tester.tap(proRawFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ZameraPaywallSheet), findsOneWidget);
      expect(savedPrefs, isNull);
    });

    testWidgets('StickerStudioSheet authorizes single session export and opens Paywall after 3 daily exports', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('zamera_st_mon_');
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        try {
          if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
        } on FileSystemException catch (e) {
          debugPrint('Temp cleanup deferred: $e');
        }
      });
      final pngFile = File('${tmpDir.path}/cutout.png');
      final valid1x1Png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      pngFile.writeAsBytesSync(valid1x1Png);

      const channel = MethodChannel('com.akarworks.zamera/capture_probe');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'extractSubjectCutoutPng') {
              return <String, dynamic>{
                'cutoutPngPath': pngFile.path,
                'width': 100,
                'height': 100,
              };
            }
            if (call.method == 'copyPngToClipboard') {
              return true;
            }
            if (call.method == 'shareMediaFiles') {
              return true;
            }
            return <String, dynamic>{};
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final controller = await ZameraMonetizationController.initialize(
        repository: InMemoryMonetizationRepository(),
        billingGateway: _FakeBillingGateway(),
        refreshOffersInBackground: false,
      );
      addTearDown(controller.dispose);

      // Consume 2 of 3 daily sticker exports beforehand -> 1 export remaining
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.stickerCutoutExport,
        ),
        isTrue,
      );
      expect(
        await controller.consumeFeatureOrCheckPro(
          ZameraProFeature.stickerCutoutExport,
        ),
        isTrue,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StickerStudioSheet(
                key: const ValueKey<String>('sticker_session_1'),
                sourceImagePath: pngFile.path,
                focusNorm: const Offset(0.5, 0.5),
                monetization: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Günlük kalan ücretsiz sticker dışa aktarımı: 1/3'),
        findsOneWidget,
      );

      // Copy uses the 3rd export; tapping Share in same session reuses same authorization
      final copyBtn1 = find.byKey(const ValueKey<String>('sticker_copy_btn'));
      await tester.ensureVisible(copyBtn1);
      await tester.tap(copyBtn1);
      await tester.pumpAndSettle();
      expect(
        controller.remainingFreeToday(ZameraProFeature.stickerCutoutExport),
        equals(0),
      );
      final shareBtn1 = find.byKey(const ValueKey<String>('sticker_share_btn'));
      await tester.ensureVisible(shareBtn1);
      await tester.tap(shareBtn1);
      await tester.pumpAndSettle();
      expect(find.byType(ZameraPaywallSheet), findsNothing);

      // Next fresh StickerStudioSheet session with 0 remaining quota -> Copy opens Paywall
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StickerStudioSheet(
                key: const ValueKey<String>('sticker_session_2'),
                sourceImagePath: pngFile.path,
                focusNorm: const Offset(0.5, 0.5),
                monetization: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final copyBtn2 = find.byKey(const ValueKey<String>('sticker_copy_btn'));
      await tester.ensureVisible(copyBtn2);
      await tester.tap(copyBtn2);
      await tester.pumpAndSettle();
      expect(find.byType(ZameraPaywallSheet), findsOneWidget);
    });

    test('validates needsStoreRevalidation, bounded proActive expiry, async restore wait, and ack order', () async {
      DateTime clock = DateTime.utc(2026, 11, 26, 10, 0);
      final repo = InMemoryMonetizationRepository();
      final events = <String>[];

      final delayedBilling = _DelayedBillingGateway(
        onAck: (id) => events.add('ack:$id'),
      );
      final controller = await ZameraMonetizationController.initialize(
        repository: repo,
        billingGateway: delayedBilling,
        nowUtcProvider: () => clock,
        refreshOffersInBackground: false,
      );
      addTearDown(controller.dispose);

      // Simulate purchase -> repository must persist BEFORE acknowledgePurchase is invoked
      await controller.purchasePlan(ZameraPlanId.monthlyPro);
      await Future<void>.delayed(Duration.zero);
      expect(repo.stored?.status, equals(ZameraEntitlementStatus.proActive));
      expect(events, equals(const <String>['ack:com.akarworks.zamera.pro.monthly']));
      expect(controller.hasProAccess, isTrue);

      // Within 24h -> no store revalidation required; after >24h -> needsStoreRevalidation is true
      expect(controller.state.needsStoreRevalidation(clock), isFalse);
      clock = clock.add(const Duration(hours: 25));
      expect(controller.state.needsStoreRevalidation(clock), isTrue);

      // Past monthly expiry window (35d) without store renewal -> no longer entitled
      clock = clock.add(const Duration(days: 40));
      expect(controller.hasProAccess, isFalse);

      // Async delayed restore waits for stream event rather than returning false prematurely
      delayedBilling.delayedRestorePlan = ZameraPlanId.annualPro;
      await controller.restorePurchases();
      expect(controller.hasProAccess, isTrue);
      expect(
        controller.state.statusMessageTr,
        equals('Zamera Pro etkinleştirildi!'),
      );
    });

    testWidgets('ZameraPaywallSheet renders English locale, Terms of Use EULA link, and Semantics', (tester) async {
      final controller = await ZameraMonetizationController.initialize(
        repository: InMemoryMonetizationRepository(),
        billingGateway: _FakeBillingGateway(),
        refreshOffersInBackground: false,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: ZameraL10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => ZameraPaywallSheet.show(
                    context,
                    monetization: controller,
                    triggeredFeature: ZameraProFeature.cinemaTenBitLogProRes,
                  ),
                  child: const Text('OPEN_EN_PAYWALL'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN_EN_PAYWALL'));
      await tester.pumpAndSettle();

      expect(find.text('1-MONTH FREE TRIAL'), findsOneWidget);
      expect(find.text('Start 1-Month Free Trial'), findsOneWidget);
      expect(find.text('Lifetime Pro'), findsOneWidget);
      expect(find.text('Monthly Pro'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('paywall_terms_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('paywall_privacy_btn')), findsOneWidget);
      expect(find.text('Terms of Use (EULA)'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
    });
  });
}

class _DelayedBillingGateway implements BillingGateway {
  final StreamController<BillingPurchaseUpdate> _controller =
      StreamController<BillingPurchaseUpdate>.broadcast();
  final void Function(String productId) onAck;
  ZameraPlanId? delayedRestorePlan;

  _DelayedBillingGateway({required this.onAck});

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<ZameraPlanId, ZameraStoreOffer>> queryPrices() async =>
      ZameraMonetizationState.defaultOffers();

  @override
  Stream<BillingPurchaseUpdate> get purchaseUpdates => _controller.stream;

  @override
  Future<bool> buy(ZameraPlanId plan) async {
    _controller.add(
      BillingPurchaseUpdate(
        eventType: BillingEventType.purchased,
        productId: plan.productId,
        transactionId: 'tx_delay_${plan.name}',
      ),
    );
    return true;
  }

  @override
  Future<void> restore() async {
    final plan = delayedRestorePlan;
    if (plan != null) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
          if (!_controller.isClosed) {
            _controller.add(
              BillingPurchaseUpdate(
                eventType: BillingEventType.restored,
                productId: plan.productId,
                transactionId: 'tx_rest_${plan.name}',
              ),
            );
          }
        }),
      );
    }
  }

  @override
  Future<void> acknowledgePurchase(String productId, String? transactionId) async {
    onAck(productId);
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
