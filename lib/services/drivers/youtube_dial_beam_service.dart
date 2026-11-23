import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import 'tv_driver_registry.dart';

/// Universal Smart TV YouTube & Streaming DIAL v2 / Lounge Beamer.
/// Routes deep-links and YouTube Playlist payloads cleanly across LG webOS SSAP,
/// Roku ECP (`837`), Samsung Tizen WS/REST, Universal DIAL (`56789`/`56791` `/apps/YouTube`),
/// and Vestel/Regal post-DIAL keycode fallbacks (`1064` Netflix / `1046` Smart Portal).
class YoutubeDialBeamService {
  YoutubeDialBeamService({
    required this._dialAppUrls,
    required this._registry,
    TvDiagLogger? logger,
  })  : _log = logger;

  final Map<String, String> _dialAppUrls;
  final TvDriverRegistry _registry;
  final TvDiagLogger? _log;

  /// Builds the standard DIAL v2 form body (`v=<vid>&list=<pid>` or `vq=<query>`) for YouTube.
  static String buildYoutubeDialPayload({
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) {
    final normalized = WatchCueItem.normalizeContentLink(
      StreamingPlatform.youtube,
      deepLinkUrl,
    );
    if (normalized.isNotEmpty) {
      final uri = Uri.tryParse(normalized);
      final v = uri?.queryParameters['v'] ?? '';
      final list = uri?.queryParameters['list'] ?? '';
      if (v.isNotEmpty && list.isNotEmpty) {
        return 'v=${Uri.encodeQueryComponent(v)}&list=${Uri.encodeQueryComponent(list)}';
      }
      if (list.isNotEmpty) {
        return 'list=${Uri.encodeQueryComponent(list)}';
      }
      if (v.isNotEmpty) {
        return 'v=${Uri.encodeQueryComponent(v)}';
      }
      // Handle youtu.be/<videoId> or /shorts/<videoId>
      if (uri != null && uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return 'v=${Uri.encodeQueryComponent(uri.pathSegments.first)}';
      }
      if (uri != null &&
          uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'live')) {
        return 'v=${Uri.encodeQueryComponent(uri.pathSegments[1])}';
      }
    }
    if (fallbackSearchQuery.trim().isNotEmpty) {
      return 'vq=${Uri.encodeQueryComponent(fallbackSearchQuery.trim())}';
    }
    return '';
  }

  Future<bool> launchOnSmartTv(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
    Future<bool> Function(String ip, int keyCode)? sendVestelRawKey,
  }) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;

    // 1. Try native protocol driver launch first (Samsung Tizen, LG webOS, Roku, Philips)
    final driver = _registry.driverFor(device.protocol);
    if (driver != null &&
        driver.capabilities.contains(TvCapability.appLaunch)) {
      final ok = await driver.launchContent(
        device,
        platform: platform,
        deepLinkUrl: deepLinkUrl,
        fallbackSearchQuery: fallbackSearchQuery,
      );
      if (ok) return true;
    }

    // 2. Universal DIAL v2 Protocol (`POST <Application-URL>/YouTube` or common DIAL ports)
    String? dialAppName;
    String dialPayload = '';
    if (platform == StreamingPlatform.youtube) {
      dialAppName = 'YouTube';
      dialPayload = buildYoutubeDialPayload(
        deepLinkUrl: deepLinkUrl,
        fallbackSearchQuery: fallbackSearchQuery,
      );
    } else if (platform == StreamingPlatform.netflix) {
      dialAppName = 'Netflix';
    } else if (platform == StreamingPlatform.primeVideo) {
      dialAppName = 'AmazonInstantVideo';
    }

    if (dialAppName != null) {
      final candidateUrls = <String>[];
      final cachedAppUrl = _dialAppUrls[ip]?.trim() ?? '';
      if (cachedAppUrl.isNotEmpty) {
        final base = cachedAppUrl.endsWith('/')
            ? cachedAppUrl
            : '$cachedAppUrl/';
        candidateUrls.add('$base$dialAppName');
      }

      final dialPorts = <int>{
        device.port,
        56789,
        56790,
        56791,
        8008,
        8060,
        8085,
        3697,
        7676,
        8080,
      };
      for (final dPort in dialPorts) {
        if (dPort <= 0) continue;
        candidateUrls.add('http://$ip:$dPort/apps/$dialAppName');
      }

      for (final targetUrl in candidateUrls) {
        if (await _postDialRequest(targetUrl, dialPayload)) {
          return true;
        }
        final isVestelDial = device.protocol == TvConnectionProtocol.vestelSmart56789 ||
            targetUrl.contains(':56789/') ||
            targetUrl.contains(':56791/');
        if (isVestelDial &&
            dialPayload.isEmpty &&
            await _postDialRequest(
              targetUrl,
              dialPayload,
              contentType: 'application/x-www-form-urlencoded',
            )) {
          return true;
        }
      }
    }

    // 3. Post-DIAL Vestel / Regal SmartCenter fallback (never sends 1067 Settings)
    if ((device.protocol == TvConnectionProtocol.vestelSmart56789 ||
            device.port == 56789 ||
            device.port == 56791) &&
        sendVestelRawKey != null) {
      if (platform == StreamingPlatform.netflix) {
        return sendVestelRawKey(ip, 1064);
      }
      if (platform == StreamingPlatform.youtube && deepLinkUrl.trim().isEmpty) {
        return sendVestelRawKey(ip, 1046);
      }
    }

    return false;
  }

  Future<bool> _postDialRequest(
    String url,
    String dialPayload, {
    String contentType = 'text/plain; charset=utf-8',
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 520);
    try {
      final req = await client
          .postUrl(Uri.parse(url))
          .timeout(const Duration(milliseconds: 560));
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      req.headers.set(HttpHeaders.connectionHeader, 'close');
      final bodyBytes = utf8.encode(dialPayload);
      req.contentLength = bodyBytes.length;
      if (bodyBytes.isNotEmpty) req.add(bodyBytes);
      final resp = await req.close().timeout(const Duration(milliseconds: 560));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _log?.call('DIAL POST hatası ($url): $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
