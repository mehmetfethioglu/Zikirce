/// Semantic category of a local notification tap used to present its detail bottom sheet.
enum NotificationDetailKind {
  prayerTimeFarz,
  prayerQuestion,
  specialSpiritual,
  quranReminder,
  quranAudioDownload,
  zikirReminder,
  kazaReminder,
  irfanReminder,
  statsReminder,
}

/// Immutable payload metadata describing which notification detail bottom sheet to render.
class NotificationDetailSpec {
  final NotificationDetailKind kind;
  final String? prayerName;
  final String? dateStr;
  final int? farzId;
  final String? spiritualVirtueTab;
  final int? reminderItemId;
  final String? customTitle;
  final String? customBody;

  const NotificationDetailSpec({
    required this.kind,
    this.prayerName,
    this.dateStr,
    this.farzId,
    this.spiritualVirtueTab,
    this.reminderItemId,
    this.customTitle,
    this.customBody,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationDetailSpec &&
        other.kind == kind &&
        other.prayerName == prayerName &&
        other.dateStr == dateStr &&
        other.farzId == farzId &&
        other.spiritualVirtueTab == spiritualVirtueTab &&
        other.reminderItemId == reminderItemId &&
        other.customTitle == customTitle &&
        other.customBody == customBody;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        prayerName,
        dateStr,
        farzId,
        spiritualVirtueTab,
        reminderItemId,
        customTitle,
        customBody,
      );

  @override
  String toString() =>
      'NotificationDetailSpec(kind: $kind, prayerName: $prayerName, dateStr: $dateStr, farzId: $farzId, spiritualVirtueTab: $spiritualVirtueTab, reminderItemId: $reminderItemId, customTitle: $customTitle, customBody: $customBody)';
}

/// Resolved in-app navigation target produced from a notification payload or home widget URI.
class AppNavigationIntent {
  final String baseRoute;
  final String? pushRoute;
  final NotificationDetailSpec? notificationDetail;

  String? get spiritualVirtueTab => notificationDetail?.spiritualVirtueTab;

  const AppNavigationIntent({
    required this.baseRoute,
    this.pushRoute,
    this.notificationDetail,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNavigationIntent &&
        other.baseRoute == baseRoute &&
        other.pushRoute == pushRoute &&
        other.notificationDetail == notificationDetail;
  }

  @override
  int get hashCode => Object.hash(baseRoute, pushRoute, notificationDetail);

  @override
  String toString() =>
      'AppNavigationIntent(baseRoute: $baseRoute, pushRoute: $pushRoute, notificationDetail: $notificationDetail)';
}

typedef _PayloadIntentBuilder = AppNavigationIntent Function(List<String> parts);

/// Open-Closed Registry resolving notification payloads and home widget URIs into routes.
class AppDeepLinkRouter {
  const AppDeepLinkRouter._();

  static const Map<String, String?> _allowlistedDirectRoutes = {
    '/': null,
    '/namaz': null,
    '/kuran': null,
    '/zikir': null,
    '/irfan': null,
    '/stats': '/',
    '/mushaf': '/kuran',
    '/mukabele': '/kuran',
    '/ezber': '/',
    '/qibla': '/namaz',
    '/fiqh': '/namaz',
    '/settings': '/',
  };

  static final Map<String, _PayloadIntentBuilder> _payloadRegistry = {
    'prayer_time': (parts) {
      final prayerName =
          parts.length >= 2 && parts[1].trim().isNotEmpty ? parts[1].trim() : null;
      final farzId = parts.length >= 3 ? int.tryParse(parts[2].trim()) : null;
      return AppNavigationIntent(
        baseRoute: '/namaz',
        notificationDetail: NotificationDetailSpec(
          kind: NotificationDetailKind.prayerTimeFarz,
          prayerName: prayerName,
          farzId: farzId,
        ),
      );
    },
    'farz_article': (parts) {
      final farzId = parts.length >= 2 ? int.tryParse(parts[1].trim()) : null;
      return AppNavigationIntent(
        baseRoute: '/namaz',
        notificationDetail: NotificationDetailSpec(
          kind: NotificationDetailKind.prayerTimeFarz,
          farzId: farzId,
        ),
      );
    },
    'prayer_question': (parts) {
      final prayerName =
          parts.length >= 2 && parts[1].trim().isNotEmpty ? parts[1].trim() : null;
      final dateStr =
          parts.length >= 3 && parts[2].trim().isNotEmpty ? parts[2].trim() : null;
      return AppNavigationIntent(
        baseRoute: '/namaz',
        notificationDetail: NotificationDetailSpec(
          kind: NotificationDetailKind.prayerQuestion,
          prayerName: prayerName,
          dateStr: dateStr,
        ),
      );
    },
    'kaza_reminder': (_) => const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.kazaReminder,
          ),
        ),
    'special_spiritual': (parts) {
      final isFeraciye =
          parts.length >= 2 && parts[1].trim().toLowerCase() == 'feraciye';
      return AppNavigationIntent(
        baseRoute: '/namaz',
        notificationDetail: NotificationDetailSpec(
          kind: NotificationDetailKind.specialSpiritual,
          spiritualVirtueTab: isFeraciye ? 'feraciye' : 'sela',
        ),
      );
    },
    'quran_reminder': (_) => const AppNavigationIntent(
          baseRoute: '/kuran',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.quranReminder,
          ),
        ),
    'quran_audio_download': (parts) {
      final stateKind = parts.length >= 2 ? parts[1].trim().toLowerCase() : '';
      String? customTitle;
      String? customBody;
      if (stateKind == 'completed') {
        final total = parts.length >= 3 ? parts[2].trim() : '';
        customTitle = 'Kur\'an Sesleri İndirildi';
        customBody = total.isNotEmpty
            ? 'Toplam $total ayet cihazınıza indirildi. Çevrimdışı dinleyebilirsiniz.'
            : 'Tüm Kur\'an ses dosyaları cihazınıza indirildi. Çevrimdışı dinleyebilirsiniz.';
      } else if (stateKind == 'progress') {
        final current = parts.length >= 3 ? parts[2].trim() : '';
        final total = parts.length >= 4 ? parts[3].trim() : '';
        customTitle = 'Kur\'an Sesleri İndiriliyor';
        customBody = (current.isNotEmpty && total.isNotEmpty)
            ? '$current / $total ayet indirildi. İndirme arka planda devam ediyor.'
            : 'Ses dosyaları arka planda indirilmeye devam ediyor.';
      }
      return AppNavigationIntent(
        baseRoute: '/kuran',
        notificationDetail: NotificationDetailSpec(
          kind: NotificationDetailKind.quranAudioDownload,
          customTitle: customTitle,
          customBody: customBody,
        ),
      );
    },
    'zikir_reminder': (parts) {
      final itemId = parts.length >= 2 ? int.tryParse(parts[1].trim()) : null;
      return AppNavigationIntent(
        baseRoute: '/zikir',
        notificationDetail: NotificationDetailSpec(
          kind: NotificationDetailKind.zikirReminder,
          reminderItemId: itemId,
        ),
      );
    },
    'irfan_reminder': (_) => const AppNavigationIntent(
          baseRoute: '/irfan',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.irfanReminder,
          ),
        ),
    'stats': (_) => const AppNavigationIntent(
          baseRoute: '/',
          pushRoute: '/stats',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.statsReminder,
          ),
        ),
  };

  static const Map<String, AppNavigationIntent> _widgetTargetRegistry = {
    'kuran': AppNavigationIntent(baseRoute: '/kuran'),
    'quran': AppNavigationIntent(baseRoute: '/kuran'),
    'mushaf': AppNavigationIntent(baseRoute: '/kuran'),
    'namaz': AppNavigationIntent(baseRoute: '/namaz'),
    'prayer': AppNavigationIntent(baseRoute: '/namaz'),
    'kaza': AppNavigationIntent(baseRoute: '/namaz'),
    'hijri': AppNavigationIntent(baseRoute: '/namaz'),
    'takvim': AppNavigationIntent(baseRoute: '/namaz'),
    'zikir': AppNavigationIntent(baseRoute: '/zikir'),
    'dhikr': AppNavigationIntent(baseRoute: '/zikir'),
    'streak': AppNavigationIntent(baseRoute: '/zikir'),
    'seri': AppNavigationIntent(baseRoute: '/zikir'),
    'stats': AppNavigationIntent(baseRoute: '/', pushRoute: '/stats'),
    'kalp': AppNavigationIntent(baseRoute: '/', pushRoute: '/stats'),
    'kalp_sagligi': AppNavigationIntent(baseRoute: '/', pushRoute: '/stats'),
    'istatistik': AppNavigationIntent(baseRoute: '/', pushRoute: '/stats'),
    'irfan': AppNavigationIntent(baseRoute: '/irfan'),
    'home': AppNavigationIntent(baseRoute: '/'),
    'dashboard': AppNavigationIntent(baseRoute: '/'),
  };

  /// Resolves a local notification payload string into an [AppNavigationIntent].
  static AppNavigationIntent? resolveNotificationPayload(String? rawPayload) {
    final trimmed = rawPayload?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('/')) {
      final parsed = Uri.tryParse(trimmed);
      final pathOnly = parsed?.path ?? trimmed.split('?').first;
      if (_allowlistedDirectRoutes.containsKey(pathOnly)) {
        final parentBase = _allowlistedDirectRoutes[pathOnly];
        if (parentBase == null) {
          return AppNavigationIntent(baseRoute: trimmed);
        }
        return AppNavigationIntent(baseRoute: parentBase, pushRoute: trimmed);
      }
    }

    final parts = trimmed.split('|');
    final prefix = parts.first.trim().toLowerCase();
    final builder = _payloadRegistry[prefix];
    return builder?.call(parts);
  }

  /// Resolves a home widget deep-link [Uri] into an [AppNavigationIntent].
  static AppNavigationIntent? resolveWidgetUri(Uri? uri) {
    if (uri == null) return null;

    final host = uri.host.toLowerCase().trim();
    final path = uri.path.toLowerCase();
    final key = host.isNotEmpty
        ? host
        : uri.pathSegments
            .map((s) => s.toLowerCase().trim())
            .firstWhere((s) => s.isNotEmpty, orElse: () => '');

    if (key == 'kulliyat' || path.contains('kulliyat')) {
      final bookId = (uri.queryParameters['bookId'] ?? '').trim();
      final page = (uri.queryParameters['page'] ?? '1').trim();
      if (bookId.isNotEmpty) {
        final pushUri = Uri(
          path: '/kulliyat',
          queryParameters: {
            'bookId': bookId,
            'page': page.isEmpty ? '1' : page,
          },
        ).toString();
        return AppNavigationIntent(baseRoute: '/kuran', pushRoute: pushUri);
      }
      return const AppNavigationIntent(baseRoute: '/kuran');
    }

    if (key.isEmpty) return null;
    return _widgetTargetRegistry[key];
  }
}
