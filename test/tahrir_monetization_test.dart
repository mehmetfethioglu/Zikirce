import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahrir/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:tahrir/features/subscription/presentation/widgets/tahrir_pro_sheet.dart';
import 'package:tahrir/features/subscription/services/tahrir_monetization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Tahrir Monetization & Dismissible Entry Prompt', () {
    test('First launch initializes 24h free Pro trial without paywall',
        () async {
      final service = TahrirMonetizationService();
      addTearDown(service.dispose);

      final installNow = DateTime.utc(2026, 11, 25, 10, 0);
      final loaded = await service.loadEntitlement(now: installNow);

      expect(loaded.firstInstallEpochMs,
          equals(installNow.millisecondsSinceEpoch));
      expect(loaded.isFirst24hTrialActive(installNow), isTrue);
      expect(loaded.hasProAccess(installNow), isTrue);
      expect(loaded.shouldShowEntryPaywall(installNow), isFalse);
      expect(loaded.activeBadgeLabel(installNow), contains('24s Ücretsiz'));

      final withinWindow =
          installNow.add(const Duration(hours: 23, minutes: 59));
      expect(loaded.isFirst24hTrialActive(withinWindow), isTrue);
      expect(loaded.shouldShowEntryPaywall(withinWindow), isFalse);
    });

    test('After 24h trial expires, entry prompt shows while Basic mode stays available',
        () async {
      final service = TahrirMonetizationService();
      addTearDown(service.dispose);

      final installNow = DateTime.utc(2026, 11, 25, 10, 0);
      final loaded = await service.loadEntitlement(now: installNow);
      final expiredTime = installNow.add(const Duration(hours: 24, minutes: 1));

      expect(loaded.isFirst24hTrialActive(expiredTime), isFalse);
      expect(loaded.isProPassActive(expiredTime), isFalse);
      expect(loaded.isSubscriptionActive(expiredTime), isFalse);
      expect(loaded.hasProAccess(expiredTime), isFalse);
      expect(loaded.shouldShowEntryPaywall(expiredTime), isTrue);
      expect(loaded.activeBadgeLabel(expiredTime), contains('Tahrir Pro'));
    });

    test(
        'Watching 3 consecutive Rewarded Ads unlocks 24h Pro Pass, then enforces 4h IVT cooldown until expired',
        () async {
      final service = TahrirMonetizationService();
      addTearDown(service.dispose);

      final installTime = DateTime.utc(2026, 11, 25, 8, 0);
      final initial = await service.loadEntitlement(now: installTime);
      final ad1Time = installTime.add(const Duration(hours: 25));

      expect(initial.shouldShowEntryPaywall(ad1Time), isTrue);
      expect(initial.rewardedAdWatchProgress, equals(0));

      // Ad 1 -> 1/3 progress, still Basic mode
      final step1 = await service.watchRewardedAdAndUnlockProPass(
        current: initial,
        now: ad1Time,
      );
      expect(step1.success, isTrue);
      expect(step1.entitlement.rewardedAdWatchProgress, equals(1));
      expect(step1.entitlement.isProPassActive(ad1Time), isFalse);
      expect(step1.entitlement.hasProAccess(ad1Time), isFalse);

      // Ad 2 (immediately consecutive) -> 2/3 progress, not blocked by cooldown
      final ad2Time = ad1Time.add(const Duration(minutes: 1));
      final step2 = await service.watchRewardedAdAndUnlockProPass(
        current: step1.entitlement,
        now: ad2Time,
      );
      expect(step2.success, isTrue);
      expect(step2.entitlement.rewardedAdWatchProgress, equals(2));
      expect(step2.entitlement.isProPassActive(ad2Time), isFalse);
      expect(step2.entitlement.hasProAccess(ad2Time), isFalse);

      // Ad 3 (immediately consecutive) -> 3/3 unlocks 24h Pro Pass and resets progress to 0
      final ad3Time = ad2Time.add(const Duration(minutes: 1));
      final step3 = await service.watchRewardedAdAndUnlockProPass(
        current: step2.entitlement,
        now: ad3Time,
      );
      expect(step3.success, isTrue);
      expect(step3.entitlement.rewardedAdWatchProgress, equals(0));
      expect(step3.entitlement.isProPassActive(ad3Time), isTrue);
      expect(step3.entitlement.hasProAccess(ad3Time), isTrue);
      expect(step3.entitlement.shouldShowEntryPaywall(ad3Time), isFalse);
      expect(
        step3.entitlement.activeBadgeLabel(ad3Time),
        contains('24s Pro'),
      );

      // Inside 4h IVT cooldown while 24h Pass is active: blocked
      final withinCooldown = ad3Time.add(const Duration(hours: 2));
      final blockedResult = await service.watchRewardedAdAndUnlockProPass(
        current: step3.entitlement,
        now: withinCooldown,
      );
      expect(blockedResult.success, isFalse);

      // After 24h Rewarded Pass expires: fresh 1/3 progress begins cleanly
      final passExpired = ad3Time.add(const Duration(hours: 24, minutes: 1));
      expect(step3.entitlement.shouldShowEntryPaywall(passExpired), isTrue);

      final renewStep1 = await service.watchRewardedAdAndUnlockProPass(
        current: step3.entitlement,
        now: passExpired,
      );
      expect(renewStep1.success, isTrue);
      expect(renewStep1.entitlement.rewardedAdWatchProgress, equals(1));
      expect(renewStep1.entitlement.isProPassActive(passExpired), isFalse);
    });

    test('All 4 paid plans map to SKUs, grant Pro access, and respect expiry',
        () async {
      final service = TahrirMonetizationService();
      addTearDown(service.dispose);

      expect(TahrirProProductCatalog.skuForTier(TahrirPlanTier.weeklyPro),
          equals('tahrir_pro_weekly'));
      expect(TahrirProProductCatalog.skuForTier(TahrirPlanTier.monthlyPro),
          equals('tahrir_pro_monthly'));
      expect(TahrirProProductCatalog.skuForTier(TahrirPlanTier.yearlyPro),
          equals('tahrir_pro_yearly'));
      expect(
          TahrirProProductCatalog.skuForTier(TahrirPlanTier.lifetimeMuderris),
          equals('tahrir_pro_lifetime'));

      final now = DateTime.utc(2026, 11, 25, 12, 0);
      final base = TahrirEntitlementState(
        firstInstallEpochMs:
            now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
      );

      final weekly = await service.purchaseTier(
        tier: TahrirPlanTier.weeklyPro,
        current: base,
        now: now,
      );
      expect(weekly.success, isTrue);
      expect(weekly.entitlement.effectivePaidTier(now),
          equals(TahrirPlanTier.weeklyPro));
      expect(weekly.entitlement.hasProAccess(now.add(const Duration(days: 6))),
          isTrue);
      expect(weekly.entitlement.hasProAccess(now.add(const Duration(days: 8))),
          isFalse);

      final monthly = await service.purchaseTier(
        tier: TahrirPlanTier.monthlyPro,
        current: base,
        now: now,
      );
      expect(monthly.success, isTrue);
      expect(monthly.entitlement.effectivePaidTier(now),
          equals(TahrirPlanTier.monthlyPro));

      final yearly = await service.purchaseTier(
        tier: TahrirPlanTier.yearlyPro,
        current: base,
        now: now,
      );
      expect(yearly.success, isTrue);
      expect(yearly.entitlement.effectivePaidTier(now),
          equals(TahrirPlanTier.yearlyPro));

      final lifetime = await service.purchaseTier(
        tier: TahrirPlanTier.lifetimeMuderris,
        current: base,
        now: now,
      );
      expect(lifetime.success, isTrue);
      expect(lifetime.entitlement.isProLifetime, isTrue);
      expect(
        lifetime.entitlement.hasProAccess(now.add(const Duration(days: 3650))),
        isTrue,
      );
    });

    test('SHA-256 tamper detection blocks forged SharedPreferences payloads',
        () async {
      final service = TahrirMonetizationService();
      addTearDown(service.dispose);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        TahrirMonetizationService.vaultPrefsKey,
        '{"payload":"{\\"isProLifetime\\":true,\\"rewardedAdWatchProgress\\":3,\\"firstInstallEpochMs\\":9999999999999}","sig":"forged_signature"}',
      );

      final checkTime = DateTime.utc(2026, 11, 25, 12, 0);
      final loaded = await service.loadEntitlement(now: checkTime);
      expect(loaded.isProLifetime, isFalse);
      expect(loaded.rewardedAdWatchProgress, equals(0));
      expect(loaded.hasProAccess(checkTime), isFalse);
      expect(loaded.shouldShowEntryPaywall(checkTime), isTrue);
    });

    testWidgets(
        'TahrirProSheet is dismissible (App Store compliant), shows 3-ad progress, Basic continue CTA, and all 4 plans',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TahrirProSheet(isEntryPrompt: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('24 Saatlik Ücretsiz Pro Süreniz Doldu'), findsOneWidget);
      expect(find.text('24 Saat Ücretsiz Pro (3 Ödüllü Reklam)'), findsOneWidget);
      expect(find.text('0 / 3 Reklam'), findsOneWidget);
      expect(
        find.text('1. Reklamı İzle (0/3) → 24 Saat Pro'),
        findsOneWidget,
      );
      expect(
        find.text('Temel Modda Devam Et (Sadece PDF & Günlük Seri)'),
        findsOneWidget,
      );
      expect(find.text('Ömür Boyu Pro (Tek Seferlik)'), findsOneWidget);
      expect(find.text('Yıllık Pro'), findsOneWidget);
      expect(find.text('Aylık Pro'), findsOneWidget);
      expect(find.text('Haftalık Pro'), findsOneWidget);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isTrue);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
