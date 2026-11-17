import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/cue_models.dart';

/// Bridges Android `ACTION_SEND` / `ACTION_VIEW (cuedeck://share)` and iOS URL schemes
/// plus clipboard link extraction into structured [SharedCuePayload] objects (Phase 2).
class CueShareIntentService {
  CueShareIntentService({this.forceEnableChannel = false});

  final bool forceEnableChannel;

  static const MethodChannel _shareChannel = MethodChannel(
    'com.akarworks.cuedeck/share',
  );

  bool get _isChannelSupported =>
      forceEnableChannel ||
      (!kIsWeb &&
          !Platform.environment.containsKey('FLUTTER_TEST') &&
          (Platform.isAndroid || Platform.isIOS));

  static final RegExp _httpUrlRegex = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  /// Extracts the first `http`/`https` link from [rawText] (e.g. YouTube Share Sheet text
  /// `"Watch this video: https://youtu.be/abc123"`) and resolves its [StreamingPlatform].
  static SharedCuePayload? parseSharedText(
    String rawText, {
    String? subject,
    DateTime? now,
  }) {
    final cleanRaw = rawText.trim();
    if (cleanRaw.isEmpty) return null;

    String extractedUrl = '';
    final match = _httpUrlRegex.firstMatch(cleanRaw);
    if (match != null) {
      extractedUrl = match.group(0) ?? '';
    } else if (cleanRaw.startsWith('cuedeck://')) {
      final customUri = Uri.tryParse(cleanRaw);
      final paramUrl = customUri?.queryParameters['url']?.trim() ?? '';
      if (paramUrl.isNotEmpty) {
        extractedUrl = paramUrl;
      }
    } else {
      final candidate = WatchCueItem.normalizeContentLink(
        StreamingPlatform.youtube,
        cleanRaw,
      );
      if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
        extractedUrl = candidate;
      }
    }

    if (extractedUrl.isEmpty) return null;
    // Strip trailing punctuation often appended by messaging apps
    extractedUrl = extractedUrl.replaceAll(RegExp(r'[),.;!?]+$'), '');

    final platform = detectPlatformFromUrl(extractedUrl);
    final normalizedUrl = WatchCueItem.normalizeContentLink(
      platform,
      extractedUrl,
    );

    var resolvedTitle = (subject ?? '').trim();
    if (resolvedTitle.isEmpty) {
      final withoutUrl = cleanRaw.replaceAll(extractedUrl, '').trim();
      if (withoutUrl.isNotEmpty && withoutUrl.length <= 80) {
        resolvedTitle = withoutUrl.replaceAll(RegExp(r'^[-:\s]+|[-:\s]+$'), '');
      }
    }
    if (resolvedTitle.isEmpty) {
      resolvedTitle = defaultTitleForUrl(platform, normalizedUrl);
    }

    return SharedCuePayload(
      url: normalizedUrl,
      title: resolvedTitle,
      platform: platform,
      receivedAtEpochMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// Identifies the streaming platform from a shared URL hostname.
  static StreamingPlatform detectPlatformFromUrl(String url) {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return StreamingPlatform.youtube;
    }
    if (host.contains('netflix.com')) return StreamingPlatform.netflix;
    if (host.contains('primevideo.com') || host.contains('amazon.')) {
      return StreamingPlatform.primeVideo;
    }
    if (host.contains('disneyplus.com')) return StreamingPlatform.disneyPlus;
    if (host.contains('spotify.com')) return StreamingPlatform.spotify;
    if (host.contains('twitch.tv')) return StreamingPlatform.twitch;
    if (host.contains('tabii.com')) return StreamingPlatform.tabii;
    if (host.contains('beinconnect') || host.contains('todtv')) {
      return StreamingPlatform.beinConnect;
    }
    if (host.contains('exxen.com')) return StreamingPlatform.exxen;
    if (host.contains('blutv.com') || host.contains('max.com')) {
      return StreamingPlatform.blutv;
    }
    return StreamingPlatform.tvBrowser;
  }

  static String defaultTitleForUrl(StreamingPlatform platform, String url) {
    final uri = Uri.tryParse(url);
    final listId = uri?.queryParameters['list'] ?? '';
    if (platform == StreamingPlatform.youtube && listId.isNotEmpty) {
      return 'YouTube Oynatma Listesi';
    }
    return '${platform.label} Paylaşımı';
  }

  /// Queries any pending initial Share Intent captured by `MainActivity` / `AppDelegate`
  /// on cold launch and clears it natively.
  Future<SharedCuePayload?> consumeInitialSharedPayload() async {
    if (!_isChannelSupported) return null;
    try {
      final raw = await _shareChannel.invokeMethod<Map<Object?, Object?>>(
        'consumeInitialSharedContent',
      );
      if (raw == null) return null;
      final text = raw['text']?.toString() ?? raw['url']?.toString() ?? '';
      final subject = raw['subject']?.toString();
      return parseSharedText(text, subject: subject);
    } catch (e) {
      debugPrint('CueShareIntentService initial read skipped: $e');
      return null;
    }
  }

  /// Registers a live listener for incoming warm-start Share Intents (`onNewIntent` / `openURL`).
  void listenForIncomingShares(void Function(SharedCuePayload payload) onShare) {
    if (!_isChannelSupported) return;
    _shareChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onSharedContentReceived') {
        final args = call.arguments;
        if (args is Map) {
          final text = args['text']?.toString() ?? args['url']?.toString() ?? '';
          final subject = args['subject']?.toString();
          final parsed = parseSharedText(text, subject: subject);
          if (parsed != null) onShare(parsed);
        }
      }
      return null;
    });
  }

  /// Reads the phone clipboard and parses it as a [SharedCuePayload] when the user
  /// taps "Panodaki Linki Aç / Planla".
  Future<SharedCuePayload?> readClipboardAsSharePayload() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return null;
      return parseSharedText(text);
    } catch (e) {
      debugPrint('CueShareIntentService clipboard read error: $e');
      return null;
    }
  }
}
