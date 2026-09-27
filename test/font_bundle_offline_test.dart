import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zikirce/core/config/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Font Bundle & Offline Safety Tests', () {
    test('SentryConfig filters out font loading network failure exceptions', () {
      final hint = Hint();
      
      final fontExceptionEvent = SentryEvent(
        throwable: Exception('Failed to load font with url: https://fonts.gstatic.com/s/a/3b9c6753e282f674c8acfa64c24eba2057c1c123830595cba4e3adbf8c5e9f24.ttf'),
        level: SentryLevel.fatal,
      );

      // SentryConfig.beforeSend should drop this exception (return null) so it doesn't log a fatal crash
      final filtered = SentryConfig.beforeSend(fontExceptionEvent, hint);
      expect(filtered, isNull, reason: 'Font download failure must be dropped to prevent fatal crash alert');
    });

    test('GoogleFonts styles can be instantiated with bundled fonts', () {
      final outfitHeading = GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      );
      expect(outfitHeading.fontFamily, contains('Outfit'));

      final interBody = GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );
      expect(interBody.fontFamily, contains('Inter'));

      final cinzelTitle = GoogleFonts.cinzel(
        fontSize: 13,
        fontWeight: FontWeight.bold,
      );
      expect(cinzelTitle.fontFamily, contains('Cinzel'));
    });
  });
}
