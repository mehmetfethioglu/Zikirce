import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, Platform;

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

  /// Returns true when [url] represents a YouTube playlist URL.
  static bool isYoutubePlaylistUrl(String url) {
    final uri = Uri.tryParse(url);
    final listId = uri?.queryParameters['list']?.trim() ?? '';
    if (listId.isNotEmpty) return true;
    return uri != null &&
        uri.path.toLowerCase().contains('/playlist') &&
        url.toLowerCase().contains('list=');
  }

  /// Returns true when [url] represents a YouTube Shorts URL.
  static bool isYoutubeShortUrl(String url) {
    final uri = Uri.tryParse(url);
    return (uri?.path.toLowerCase() ?? '').contains('/shorts/');
  }

  static String defaultTitleForUrl(StreamingPlatform platform, String url) {
    if (platform == StreamingPlatform.youtube) {
      if (isYoutubeShortUrl(url)) {
        return 'YouTube Shorts';
      }
      if (isYoutubePlaylistUrl(url)) {
        return 'YouTube Oynatma Listesi';
      }
      return 'YouTube Videosu';
    }
    return '${platform.label} Paylaşımı';
  }

  /// Fetches the real video or playlist title from YouTube oEmbed when available.
  /// Returns `null` in test/web environments or on any network/parsing failure.
  Future<String?> fetchYoutubeTitle(String url) async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty ||
        detectPlatformFromUrl(cleanUrl) != StreamingPlatform.youtube) {
      return null;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final endpoint = Uri.https('www.youtube.com', '/oembed', <String, String>{
        'url': cleanUrl,
        'format': 'json',
      });
      final request = await client
          .getUrl(endpoint)
          .timeout(const Duration(seconds: 3));
      final response = await request
          .close()
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await utf8.decodeStream(response).timeout(
            const Duration(seconds: 3),
          );
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final title = (decoded['title'] as String?)?.trim() ?? '';
        if (title.isNotEmpty) return title;
      }
      return null;
    } catch (e) {
      debugPrint('CueShareIntentService fetchYoutubeTitle skipped: $e');
      return null;
    } finally {
      client.close(force: true);
    }
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
