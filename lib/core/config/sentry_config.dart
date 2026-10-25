import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../services/changelog_service.dart';

/// Configuration and filtering provider for Sentry crash and ANR telemetry monitoring.
class SentryConfig {
  /// Sentry DSN (Data Source Name) ingest endpoint (From Zikirce production project).
  static const String dsn =
      'https://3ae37c951dc70b1c39701f8f954e81eb@o4511836028338176.ingest.de.sentry.io/4511836041969744';

  /// Release name formatted according to Sentry standards.
  static const String release =
      'com.akarworks.zikirce@${ChangelogService.currentVersionName}+${ChangelogService.currentVersionCode}';

  /// Telemetry is enabled in Release and Profile modes when DSN is present.
  static bool get isEnabled => !kDebugMode && dsn.isNotEmpty;

  /// Custom BeforeSend callback to filter out transient/ignorable exceptions.
  static SentryEvent? beforeSend(SentryEvent event, Hint hint) {
    if (!isEnabled) {
      return null;
    }

    // Inspect exception message or formatted text
    final excMessage = event.throwable?.toString() ?? event.message?.formatted ?? '';
    final lower = excMessage.toLowerCase();

    // 1. Filter out known transient socket/network cancellations
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection closed before full header was received') ||
        lower.contains('connection timed out') ||
        lower.contains('handshakeexception') ||
        lower.contains('software caused connection abort')) {
      // Demote transient network drops to Warning level
      return event.copyWith(level: SentryLevel.warning);
    }

    // 2. Drop font loading failures (offline font downloads or CDN unreachable)
    if (lower.contains('failed to load font with url') ||
        lower.contains('fonts.gstatic.com')) {
      return null;
    }

    return event;
  }
}
