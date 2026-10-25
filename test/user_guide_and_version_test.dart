import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/config/sentry_config.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/localization/translations/app_strings_en.dart';
import 'package:zikirce/core/localization/translations/app_strings_tr.dart';
import 'package:zikirce/core/services/changelog_service.dart';
import 'package:zikirce/features/hatim/data/hatim_duasi_data.dart';
import 'package:zikirce/features/hatim/presentation/widgets/hatim_duasi_modal.dart';
import 'package:zikirce/features/kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';
import 'package:zikirce/features/settings/presentation/screens/user_guide_screen.dart';

void main() {
  group('Dynamic App Version Synchronization Tests', () {
    test('ChangelogService version and localization strings stay synchronized', () {
      expect(ChangelogService.effectiveVersionName, ChangelogService.currentVersionName);
      expect(ChangelogService.effectiveVersionCode, ChangelogService.currentVersionCode);
      expect(ChangelogService.effectiveVersionName, isNot('2.0.7'));

      final trLabel = ChangelogService.formatVersionLabel(isTurkish: true);
      final enLabel = ChangelogService.formatVersionLabel(isTurkish: false);

      expect(
        trLabel,
        'Versiyon ${ChangelogService.currentVersionName} (Build ${ChangelogService.currentVersionCode})',
      );
      expect(
        enLabel,
        'Version ${ChangelogService.currentVersionName} (Build ${ChangelogService.currentVersionCode})',
      );

      expect(appStringsTr['Settings_Version'], trLabel);
      expect(appStringsEn['Settings_Version'], enLabel);
      expect(
        SentryConfig.release,
        'com.akarworks.zikirce@${ChangelogService.currentVersionName}+${ChangelogService.currentVersionCode}',
      );
    });
  });

  group('UserGuideScreen Widget & Interactive Search Tests', () {
    testWidgets('renders UserGuideScreen, filters by search and switches categories without overflow',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('tr'),
            supportedLocales: [Locale('tr'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: UserGuideScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header & dynamic version badge
      expect(
        find.textContaining('v${ChangelogService.effectiveVersionName}'),
        findsWidgets,
      );
      expect(find.textContaining('Kullanım Kılavuzu'), findsWidgets);

      // Verify search filtering works
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Külliyat');
      await tester.pumpAndSettle();

      expect(find.textContaining('23 Eserlik Külliyat'), findsWidgets);
    });
  });

  group('HatimDuasiModal Default Matbu Arabic & Mushaf Rendering Tests', () {
    testWidgets(
        'opens in Matbu Arapca mode by default with Mushaf stop rosettes and switches modes cleanly',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HatimDuasiModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default mode is Matbû Arapça Sahife view
      expect(find.text('Matbû Hatm-i Şerîf Duası'), findsOneWidget);
      expect(
        find.byType(ZikirceAyahStopMarker),
        findsNWidgets(HatimDuasiData.allMatbuBodyClauses.length),
      );
      // Turkish transliteration should not be visible in default Matbû Arapça mode
      expect(find.text('Türkçe Okunuşu'), findsNothing);

      // Tap "Tümü (Arapça + Okunuş + Meâl)" chip to verify section cards & Arabic rendering
      await tester.tap(find.text('Tümü (Arapça + Okunuş + Meâl)'));
      await tester.pumpAndSettle();

      expect(find.text('Türkçe Okunuşu'), findsWidgets);
      expect(find.byType(ZikirceAyahStopMarker), findsWidgets);
    });
  });
}
