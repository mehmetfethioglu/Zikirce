import 'package:flutter/material.dart';

/// Supported streaming platforms and TV apps with Android TV package identifiers
/// and verified leanback/main launcher activities.
enum StreamingPlatform {
  youtube(
    label: 'YouTube',
    packageName: 'com.google.android.youtube.tv',
    leanbackActivity:
        'com.google.android.apps.youtube.tv.activity.ShellActivity',
    brandColor: Color(0xFFFF1744),
    icon: Icons.smart_display_rounded,
  ),
  beinConnect(
    label: 'beIN',
    packageName: 'com.digiturk.iq.mobil',
    leanbackActivity: 'com.digiturk.iq.mobil.view.activities.SplashActivity',
    brandColor: Color(0xFF7C4DFF),
    icon: Icons.sports_soccer_rounded,
  ),
  tabii(
    label: 'tabii',
    packageName: 'com.trt.tabii.android',
    leanbackActivity: 'com.trt.tabii.android.tv.MainActivity',
    brandColor: Color(0xFF00E676),
    icon: Icons.play_circle_fill_rounded,
  ),
  netflix(
    label: 'Netflix',
    packageName: 'com.netflix.ninja',
    leanbackActivity: 'com.netflix.ninja.MainActivity',
    brandColor: Color(0xFFE50914),
    icon: Icons.movie_filter_rounded,
  ),
  tivibu(
    label: 'Tivibu',
    packageName: 'com.ttnet.tivibu.tv',
    leanbackActivity: '',
    brandColor: Color(0xFF00B0FF),
    icon: Icons.live_tv_rounded,
  ),
  zikirce(
    label: 'Zikirce',
    packageName: 'com.akarworks.zikirce',
    leanbackActivity: 'com.akarworks.zikirce.MainActivity',
    brandColor: Color(0xFFE2A84B),
    icon: Icons.auto_awesome_rounded,
  ),
  primeVideo(
    label: 'Prime Video',
    packageName: 'com.amazon.amazonvideo.livingroom',
    leanbackActivity: '',
    brandColor: Color(0xFF00A8E1),
    icon: Icons.ondemand_video_rounded,
  ),
  disneyPlus(
    label: 'Disney+',
    packageName: 'com.disney.disneyplus',
    leanbackActivity: '',
    brandColor: Color(0xFF113CCF),
    icon: Icons.stars_rounded,
  ),
  exxen(
    label: 'Exxen',
    packageName: 'com.exxen.android',
    leanbackActivity: '',
    brandColor: Color(0xFFFFD600),
    icon: Icons.bolt_rounded,
  ),
  blutv(
    label: 'Max / BluTV',
    packageName: 'com.blutv.androidtv',
    leanbackActivity: '',
    brandColor: Color(0xFF2979FF),
    icon: Icons.theaters_rounded,
  ),
  ssportPlus(
    label: 'S Sport+',
    packageName: 'com.ssportplus.android',
    leanbackActivity: '',
    brandColor: Color(0xFF00C853),
    icon: Icons.sports_basketball_rounded,
  ),
  todTv(
    label: 'TOD TV',
    packageName: 'com.todtv.turkiye',
    leanbackActivity: '',
    brandColor: Color(0xFFFF6D00),
    icon: Icons.sports_soccer_rounded,
  ),
  spotify(
    label: 'Spotify',
    packageName: 'com.spotify.tv.android',
    leanbackActivity: '',
    brandColor: Color(0xFF1DB954),
    icon: Icons.music_note_rounded,
  ),
  twitch(
    label: 'Twitch',
    packageName: 'tv.twitch.android.app',
    leanbackActivity: '',
    brandColor: Color(0xFF9146FF),
    icon: Icons.videogame_asset_rounded,
  ),
  kodi(
    label: 'Kodi / IPTV',
    packageName: 'org.xbmc.kodi',
    leanbackActivity: '',
    brandColor: Color(0xFF17B2E7),
    icon: Icons.settings_input_antenna_rounded,
  ),
  vlc(
    label: 'VLC Player',
    packageName: 'org.videolan.vlc',
    leanbackActivity: '',
    brandColor: Color(0xFFFF8800),
    icon: Icons.video_library_rounded,
  );

  const StreamingPlatform({
    required this.label,
    required this.packageName,
    required this.leanbackActivity,
    required this.brandColor,
    required this.icon,
  });

  /// Default 6 shortcut buttons displayed on the G10 remote chassis (3x2 grid).
  static const List<StreamingPlatform> defaultRemoteShortcuts =
      <StreamingPlatform>[
    StreamingPlatform.youtube,
    StreamingPlatform.netflix,
    StreamingPlatform.beinConnect,
    StreamingPlatform.tabii,
    StreamingPlatform.tivibu,
    StreamingPlatform.zikirce,
  ];

  final String label;
  final String packageName;
  final String leanbackActivity;
  final Color brandColor;
  final IconData icon;

  /// Platform-specific URL hint for the Watch Planner form.
  String get linkHint {
    switch (this) {
      case StreamingPlatform.youtube:
        return 'https://www.youtube.com/playlist?list=PL... veya video linki';
      case StreamingPlatform.netflix:
        return 'https://www.netflix.com/watch/... (veya boş bırakın)';
      case StreamingPlatform.tabii:
        return 'https://www.tabii.com/tr/watch/... (veya boş bırakın)';
      case StreamingPlatform.beinConnect:
        return 'https://beinconnect.com.tr/... veya kanal/maç linki';
      case StreamingPlatform.tivibu:
        return 'https://www.tivibu.com.tr/... (veya boş bırakın)';
      case StreamingPlatform.zikirce:
      case StreamingPlatform.primeVideo:
      case StreamingPlatform.disneyPlus:
      case StreamingPlatform.exxen:
      case StreamingPlatform.blutv:
      case StreamingPlatform.ssportPlus:
      case StreamingPlatform.todTv:
      case StreamingPlatform.spotify:
      case StreamingPlatform.twitch:
      case StreamingPlatform.kodi:
      case StreamingPlatform.vlc:
        return 'https://... (opsiyonel derin bağlantı veya boş bırakın)';
    }
  }

  /// Platform-specific content title hint for the Watch Planner form.
  String get titleHint {
    switch (this) {
      case StreamingPlatform.youtube:
        return 'Örn: Flutter Mimari Playlist veya Tarih Belgeseli Serisi';
      case StreamingPlatform.beinConnect:
      case StreamingPlatform.todTv:
      case StreamingPlatform.ssportPlus:
        return 'Örn: Süper Lig / Premier Lig Maç Yayını';
      case StreamingPlatform.tabii:
        return 'Örn: Gassal veya Kübra • Yeni Sezon';
      case StreamingPlatform.netflix:
      case StreamingPlatform.primeVideo:
      case StreamingPlatform.disneyPlus:
      case StreamingPlatform.exxen:
      case StreamingPlatform.blutv:
        return 'Örn: Favori Dizi veya Film • 1. Sezon';
      case StreamingPlatform.tivibu:
        return 'Örn: Avrupa Ligi Maç Gecesi • Tivibu Spor';
      case StreamingPlatform.zikirce:
        return 'Örn: Akşam Tesbihatı & Günlük Vird';
      case StreamingPlatform.spotify:
      case StreamingPlatform.twitch:
      case StreamingPlatform.kodi:
      case StreamingPlatform.vlc:
        return 'Örn: Canlı Yayın / Çalma Listesi';
    }
  }

  /// Unit label for multi-part content (Video vs Bölüm vs Yayın).
  String get unitLabel {
    switch (this) {
      case StreamingPlatform.youtube:
      case StreamingPlatform.vlc:
        return 'Video';
      case StreamingPlatform.beinConnect:
      case StreamingPlatform.tivibu:
      case StreamingPlatform.ssportPlus:
      case StreamingPlatform.todTv:
      case StreamingPlatform.twitch:
      case StreamingPlatform.kodi:
        return 'Yayın';
      case StreamingPlatform.spotify:
        return 'Parça';
      case StreamingPlatform.zikirce:
      case StreamingPlatform.tabii:
      case StreamingPlatform.netflix:
      case StreamingPlatform.primeVideo:
      case StreamingPlatform.disneyPlus:
      case StreamingPlatform.exxen:
      case StreamingPlatform.blutv:
        return 'Bölüm';
    }
  }

  static StreamingPlatform fromName(String? value) {
    for (final p in StreamingPlatform.values) {
      if (p.name == value) return p;
    }
    return StreamingPlatform.youtube;
  }
}

/// Recurrence period for scheduled watch sessions across all platforms.
enum WatchRecurrence {
  daily('Her Gün', <int>[1, 2, 3, 4, 5, 6, 7]),
  weekdays('Hafta İçi', <int>[1, 2, 3, 4, 5]),
  weekends('Hafta Sonu', <int>[6, 7]),
  weekly('Haftada Bir', <int>[1]),
  customDays('Seçili Günler', <int>[1, 3, 5]),
  once('Tek Seferlik', <int>[1, 2, 3, 4, 5, 6, 7]);

  const WatchRecurrence(this.label, this.defaultDays);

  final String label;
  final List<int> defaultDays;

  static WatchRecurrence fromName(String? value) {
    for (final r in WatchRecurrence.values) {
      if (r.name == value) return r;
    }
    return WatchRecurrence.daily;
  }
}

/// Hardware/system remote control key commands mapped to both Android KeyEvent codes
/// and Linux kernel `/dev/input/event0` (`venus_IR_input.kl`) scan codes for
/// zero-lag (<120ms) execution on Android TV.
enum TvKeyCommand {
  up(19, 103, 'Yukarı'),
  down(20, 108, 'Aşağı'),
  left(21, 105, 'Sol'),
  right(22, 106, 'Sağ'),
  ok(23, 28, 'Tamam (OK)'),
  back(4, 158, 'Geri'),
  home(3, 102, 'Ana Ekran'),
  menu(82, 139, 'Menü'),
  inputs(178, 768, 'TV Girişleri (HDMI/AV)'),
  volUp(24, 115, 'Ses +'),
  volDown(25, 114, 'Ses -'),
  mute(164, 113, 'Sessiz'),
  power(26, 116, 'Güç / Uyku'),
  playPause(85, 164, 'Oynat / Duraklat'),
  rewind(89, 168, 'Geri Sar'),
  fastForward(90, 208, 'İleri Sar'),
  channelUp(166, 402, 'Kanal +'),
  channelDown(167, 403, 'Kanal -'),
  voiceAssist(231, 0, 'Sesli Asistan'),
  search(84, 0, 'TV Arama');

  const TvKeyCommand(this.keyCode, this.linuxScanCode, this.label);

  final int keyCode;
  final int linuxScanCode;
  final String label;
}

/// Connection protocol mode for communicating with Android TV / Google TV devices.
enum TvConnectionProtocol {
  /// Port 5555: ADB TCP/IP with RSA-2048 `CMD_AUTH`, `/dev/input/event0` hardware scan-code
  /// injection (<120ms), and direct YouTube Playlist / deep-link URL launching (`am start`).
  adbPort5555('ADB Turbo & Deep-Link (Port 5555)', 5555),

  /// Port 6466/6467: Standard Android TV Remote Protocol v2 (Zero-Config TLS + 6-Digit PIN)
  /// enabled out-of-the-box on retail Google TV & Android TV sets without Developer Options.
  remotePort6466('Standart Kumanda Modu (Port 6466 PIN)', 6466);

  const TvConnectionProtocol(this.label, this.defaultPort);

  final String label;
  final int defaultPort;

  static TvConnectionProtocol fromNameOrPort(String? name, int port) {
    for (final p in TvConnectionProtocol.values) {
      if (p.name == name) return p;
    }
    return port == 6466
        ? TvConnectionProtocol.remotePort6466
        : TvConnectionProtocol.adbPort5555;
  }
}

/// Represents a discovered Smart TV device on the local Wi-Fi network.
@immutable
class TvDevice {
  const TvDevice({
    required this.name,
    required this.ip,
    this.port = 5555,
    this.boardInfo = 'Realtek RTD2851P • Android TV',
    this.isOnline = true,
    this.protocol = TvConnectionProtocol.adbPort5555,
    this.isPaired = false,
  });

  final String name;
  final String ip;
  final int port;
  final String boardInfo;
  final bool isOnline;
  final TvConnectionProtocol protocol;
  final bool isPaired;

  TvDevice copyWith({
    String? name,
    String? ip,
    int? port,
    String? boardInfo,
    bool? isOnline,
    TvConnectionProtocol? protocol,
    bool? isPaired,
  }) {
    return TvDevice(
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      boardInfo: boardInfo ?? this.boardInfo,
      isOnline: isOnline ?? this.isOnline,
      protocol: protocol ?? this.protocol,
      isPaired: isPaired ?? this.isPaired,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'port': port,
        'boardInfo': boardInfo,
        'isOnline': isOnline,
        'protocol': protocol.name,
        'isPaired': isPaired,
      };

  factory TvDevice.fromJson(Map<String, dynamic> json) {
    final parsedPort = (json['port'] as int?) ?? 5555;
    return TvDevice(
      name: (json['name'] as String?) ?? 'Redline Android TV',
      ip: (json['ip'] as String?) ?? '192.168.1.123',
      port: parsedPort,
      boardInfo:
          (json['boardInfo'] as String?) ?? 'Realtek RTD2851P • Android TV',
      isOnline: (json['isOnline'] as bool?) ?? true,
      protocol: TvConnectionProtocol.fromNameOrPort(
        json['protocol'] as String?,
        parsedPort,
      ),
      isPaired: (json['isPaired'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvDevice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          ip == other.ip &&
          port == other.port &&
          isOnline == other.isOnline &&
          protocol == other.protocol &&
          isPaired == other.isPaired;

  @override
  int get hashCode =>
      Object.hash(name, ip, port, isOnline, protocol, isPaired);
}

/// Represents a personal scheduled watch plan item with YouTube playlist / deep-link URL,
/// recurrence period (daily, weekdays, weekends, custom days), exact clock time,
/// session duration target, resume point, episode/video index, and reminder lead time.
@immutable
class WatchCueItem {
  const WatchCueItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.platform,
    required this.scheduledTime,
    required this.totalMinutes,
    this.watchedMinutes = 0,
    this.sessionMinutes = 45,
    this.currentEpisode = 1,
    this.totalEpisodes = 1,
    this.deepLinkUrl = '',
    this.recurrence = WatchRecurrence.daily,
    this.activeWeekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
    this.reminderMinutesBefore = 15,
    this.reminderFired = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final StreamingPlatform platform;
  final DateTime scheduledTime;
  final int totalMinutes;
  final int watchedMinutes;
  final int sessionMinutes;
  final int currentEpisode;
  final int totalEpisodes;
  final String deepLinkUrl;
  final WatchRecurrence recurrence;
  final List<int> activeWeekdays;
  final int reminderMinutesBefore;
  final bool reminderFired;

  static const List<String> weekdayShortLabels = <String>[
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  /// Normalizes a raw YouTube playlist ID or partial link into a full HTTPS URL.
  static String normalizeContentLink(
    StreamingPlatform platform,
    String rawInput,
  ) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    if (platform == StreamingPlatform.youtube) {
      // Allow pasting just a YouTube Playlist ID like PLxxxx or UUxxxx
      if (RegExp(r'^(PL|UU|FL|RD|OL)[a-zA-Z0-9_-]{8,}$').hasMatch(trimmed)) {
        return 'https://www.youtube.com/playlist?list=$trimmed';
      }
      // Allow pasting youtube.com/... without scheme
      if (trimmed.startsWith('youtube.com/') ||
          trimmed.startsWith('www.youtube.com/') ||
          trimmed.startsWith('m.youtube.com/') ||
          trimmed.startsWith('youtu.be/')) {
        return 'https://$trimmed';
      }
    } else if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        trimmed.contains('.')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  /// Extracts a YouTube playlist ID (`list=...`) if present in [deepLinkUrl].
  String? get youtubePlaylistId {
    if (deepLinkUrl.isEmpty) return null;
    final uri = Uri.tryParse(deepLinkUrl);
    final listParam = uri?.queryParameters['list'];
    if (listParam != null && listParam.isNotEmpty) return listParam;
    return null;
  }

  /// True when this item represents a YouTube Playlist or multi-video queue.
  bool get isYoutubePlaylist =>
      platform == StreamingPlatform.youtube &&
      (youtubePlaylistId != null || totalEpisodes > 1);

  /// Clamped progress ratio between 0.0 and 1.0.
  double get progressRatio {
    if (totalMinutes <= 0) return 0.0;
    final ratio = watchedMinutes / totalMinutes;
    return ratio.clamp(0.0, 1.0);
  }

  /// Completion percentage (0..100).
  int get progressPercent => (progressRatio * 100).round();

  /// True when the item has been fully watched.
  bool get isCompleted => watchedMinutes >= totalMinutes && totalMinutes > 0;

  /// Remaining minutes left to finish the planned session/playlist.
  int get remainingMinutes =>
      (totalMinutes - watchedMinutes).clamp(0, totalMinutes);

  /// Human-readable recurrence summary (e.g. "Her Gün", "Hafta İçi", "Pzt, Çar, Cum").
  String get recurrenceSummary {
    if (recurrence == WatchRecurrence.customDays ||
        recurrence == WatchRecurrence.weekly) {
      if (activeWeekdays.isEmpty) return recurrence.label;
      final sorted = List<int>.from(activeWeekdays)..sort();
      final names = sorted
          .where((d) => d >= 1 && d <= 7)
          .map((d) => weekdayShortLabels[d - 1])
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return recurrence.label;
  }

  /// Formatted scheduled clock string (HH:mm).
  String get formattedClock {
    final h = scheduledTime.hour.toString().padLeft(2, '0');
    final m = scheduledTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Combined schedule badge text showing clock, recurrence period, and daily session target.
  String get scheduleBadgeText =>
      '⏰ $formattedClock • $recurrenceSummary • ${sessionMinutes}dk/seans';

  /// Human-readable checkpoint summary (where the user left off).
  String get checkpointSummary {
    if (isCompleted) {
      return 'Tamamlandı (%100) • $totalMinutes dk izlendi';
    }
    final unit = platform.unitLabel;
    final epPart =
        totalEpisodes > 1 ? '$unit $currentEpisode/$totalEpisodes • ' : '';
    return '$epPart$watchedMinutes. dk\'da kaldınız ($remainingMinutes dk kaldı)';
  }

  /// Returns true if [now]'s weekday is included in this item's schedule.
  bool isScheduledForWeekday(int weekday) {
    switch (recurrence) {
      case WatchRecurrence.daily:
      case WatchRecurrence.once:
        return true;
      case WatchRecurrence.weekdays:
        return weekday >= 1 && weekday <= 5;
      case WatchRecurrence.weekends:
        return weekday == 6 || weekday == 7;
      case WatchRecurrence.weekly:
      case WatchRecurrence.customDays:
        return activeWeekdays.isEmpty || activeWeekdays.contains(weekday);
    }
  }

  /// Returns true if the scheduled time is within [reminderMinutesBefore] from [now].
  bool isReminderDue(DateTime now) {
    if (isCompleted || reminderFired) return false;
    if (!isScheduledForWeekday(now.weekday)) return false;
    final todayScheduled = DateTime(
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );
    final diffMinutes = todayScheduled.difference(now).inMinutes;
    return diffMinutes <= reminderMinutesBefore && diffMinutes >= -2;
  }

  /// Computes the next upcoming scheduled watch start [DateTime] after [now],
  /// honoring [recurrence] and [activeWeekdays].
  DateTime? nextWatchDateTime(DateTime now) {
    if (isCompleted) return null;
    for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
      final day =
          DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      if (!isScheduledForWeekday(day.weekday)) continue;
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );
      if (candidate.isAfter(now)) return candidate;
    }
    return null;
  }

  /// Computes the next upcoming reminder [DateTime] (`scheduledTime - reminderMinutesBefore`)
  /// after [now], honoring [recurrence] and [activeWeekdays].
  DateTime? nextReminderDateTime(DateTime now) {
    if (isCompleted) return null;
    for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
      final day =
          DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      if (!isScheduledForWeekday(day.weekday)) continue;
      final watchCandidate = DateTime(
        day.year,
        day.month,
        day.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );
      final reminderCandidate = watchCandidate.subtract(
        Duration(minutes: reminderMinutesBefore),
      );
      if (reminderCandidate.isAfter(now)) return reminderCandidate;
    }
    return null;
  }

  WatchCueItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    StreamingPlatform? platform,
    DateTime? scheduledTime,
    int? totalMinutes,
    int? watchedMinutes,
    int? sessionMinutes,
    int? currentEpisode,
    int? totalEpisodes,
    String? deepLinkUrl,
    WatchRecurrence? recurrence,
    List<int>? activeWeekdays,
    int? reminderMinutesBefore,
    bool? reminderFired,
  }) {
    return WatchCueItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      platform: platform ?? this.platform,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      watchedMinutes: watchedMinutes ?? this.watchedMinutes,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      deepLinkUrl: deepLinkUrl ?? this.deepLinkUrl,
      recurrence: recurrence ?? this.recurrence,
      activeWeekdays: activeWeekdays ?? this.activeWeekdays,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      reminderFired: reminderFired ?? this.reminderFired,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'platform': platform.name,
        'scheduledTime': scheduledTime.toIso8601String(),
        'totalMinutes': totalMinutes,
        'watchedMinutes': watchedMinutes,
        'sessionMinutes': sessionMinutes,
        'currentEpisode': currentEpisode,
        'totalEpisodes': totalEpisodes,
        'deepLinkUrl': deepLinkUrl,
        'recurrence': recurrence.name,
        'activeWeekdays': activeWeekdays,
        'reminderMinutesBefore': reminderMinutesBefore,
        'reminderFired': reminderFired,
      };

  factory WatchCueItem.fromJson(Map<String, dynamic> json) {
    final rawDays = json['activeWeekdays'];
    final parsedDays = rawDays is List
        ? rawDays.whereType<int>().where((d) => d >= 1 && d <= 7).toList()
        : const <int>[1, 2, 3, 4, 5, 6, 7];

    return WatchCueItem(
      id: (json['id'] as String?) ?? 'cue_0',
      title: (json['title'] as String?) ?? 'İzleme Planı',
      subtitle: (json['subtitle'] as String?) ?? '',
      platform: StreamingPlatform.fromName(json['platform'] as String?),
      scheduledTime: DateTime.tryParse(
            (json['scheduledTime'] as String?) ?? '',
          ) ??
          DateTime.now().add(const Duration(hours: 1)),
      totalMinutes: (json['totalMinutes'] as int?) ?? 60,
      watchedMinutes: (json['watchedMinutes'] as int?) ?? 0,
      sessionMinutes: (json['sessionMinutes'] as int?) ?? 45,
      currentEpisode: (json['currentEpisode'] as int?) ?? 1,
      totalEpisodes: (json['totalEpisodes'] as int?) ?? 1,
      deepLinkUrl: (json['deepLinkUrl'] as String?) ?? '',
      recurrence: WatchRecurrence.fromName(json['recurrence'] as String?),
      activeWeekdays:
          parsedDays.isNotEmpty ? parsedDays : const <int>[1, 2, 3, 4, 5, 6, 7],
      reminderMinutesBefore: (json['reminderMinutesBefore'] as int?) ?? 15,
      reminderFired: (json['reminderFired'] as bool?) ?? false,
    );
  }
}
