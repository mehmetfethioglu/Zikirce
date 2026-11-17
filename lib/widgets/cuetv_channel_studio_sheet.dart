import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cue_models.dart';
import '../providers/cuedeck_providers.dart';

/// Opens the CueTV National Channel Studio & Live Zap Controller modal sheet on the phone.
Future<void> showCueTvChannelStudioSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CueTvChannelStudioSheet(),
  );
}

class CueTvChannelStudioSheet extends ConsumerStatefulWidget {
  const CueTvChannelStudioSheet({super.key});

  @override
  ConsumerState<CueTvChannelStudioSheet> createState() =>
      _CueTvChannelStudioSheetState();
}

class _CueTvChannelStudioSheetState
    extends ConsumerState<CueTvChannelStudioSheet> {
  bool _isLoading = true;
  bool _bridgeConnected = false;
  String _statusMessage = 'TV üzerindeki CueTV köprüsüne bağlanılıyor...';
  String _selectedCountryCode = 'TR';
  bool _onlyNationalFilter = true;
  String _activeChannelId = 'trt1_tr';

  List<Map<String, dynamic>> _countries = <Map<String, dynamic>>[
    <String, dynamic>{'code': 'TR', 'nameTr': 'Türkiye', 'flag': '🇹🇷', 'isEnabled': true},
    <String, dynamic>{'code': 'AZ', 'nameTr': 'Azerbaycan', 'flag': '🇦🇿', 'isEnabled': true},
    <String, dynamic>{'code': 'GB', 'nameTr': 'İngiltere', 'flag': '🇬🇧', 'isEnabled': true},
    <String, dynamic>{'code': 'DE', 'nameTr': 'Almanya', 'flag': '🇩🇪', 'isEnabled': true},
    <String, dynamic>{'code': 'US', 'nameTr': 'ABD', 'flag': '🇺🇸', 'isEnabled': true},
    <String, dynamic>{'code': 'FR', 'nameTr': 'Fransa', 'flag': '🇫🇷', 'isEnabled': true},
    <String, dynamic>{'code': 'QA', 'nameTr': 'Uluslararası', 'flag': '🌍', 'isEnabled': true},
    <String, dynamic>{'code': 'JP', 'nameTr': 'Japonya', 'flag': '🇯🇵', 'isEnabled': true},
    <String, dynamic>{'code': 'KR', 'nameTr': 'Güney Kore', 'flag': '🇰🇷', 'isEnabled': true},
  ];

  List<Map<String, dynamic>> _channels = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'trt1_tr', 'number': 1, 'name': 'TRT 1', 'countryCode': 'TR', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'trthaber_tr', 'number': 2, 'name': 'TRT Haber', 'countryCode': 'TR', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'trtspor_tr', 'number': 3, 'name': 'TRT Spor', 'countryCode': 'TR', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'trtbelgesel_tr', 'number': 4, 'name': 'TRT Belgesel', 'countryCode': 'TR', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'ntv_tr', 'number': 5, 'name': 'NTV', 'countryCode': 'TR', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'haberturk_tr', 'number': 6, 'name': 'Habertürk TV', 'countryCode': 'TR', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'cnnturk_tr', 'number': 7, 'name': 'CNN Türk', 'countryCode': 'TR', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'startv_tr', 'number': 8, 'name': 'Star TV', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'kanald_tr', 'number': 9, 'name': 'Kanal D', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'showtv_tr', 'number': 10, 'name': 'Show TV', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'atv_tr', 'number': 11, 'name': 'ATV', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'now_tr', 'number': 12, 'name': 'NOW TV', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'tv8_tr', 'number': 13, 'name': 'TV8', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'tlc_tr', 'number': 14, 'name': 'TLC Türkiye', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'dmax_tr', 'number': 15, 'name': 'DMAX Türkiye', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'bloomberght_tr', 'number': 16, 'name': 'Bloomberg HT', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'halktv_tr', 'number': 17, 'name': 'Halk TV', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'sozcutv_tr', 'number': 18, 'name': 'Sözcü TV', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'ahaber_tr', 'number': 19, 'name': 'A Haber', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'kanal7_tr', 'number': 20, 'name': 'Kanal 7', 'countryCode': 'TR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'aztv_az', 'number': 25, 'name': 'AzTV (Azərbaycan TV)', 'countryCode': 'AZ', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'ictimai_az', 'number': 26, 'name': 'İctimai TV (İTV)', 'countryCode': 'AZ', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'cbcsport_az', 'number': 27, 'name': 'CBC Sport HD', 'countryCode': 'AZ', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'bbcnews_gb', 'number': 29, 'name': 'BBC News HD', 'countryCode': 'GB', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'skynews_gb', 'number': 30, 'name': 'Sky News International', 'countryCode': 'GB', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'dw_en_de', 'number': 32, 'name': 'DW (Deutsche Welle)', 'countryCode': 'DE', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'tagesschau24_de', 'number': 33, 'name': 'ARD tagesschau24', 'countryCode': 'DE', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'abcnews_us', 'number': 35, 'name': 'ABC News Live', 'countryCode': 'US', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'cbsnews_us', 'number': 36, 'name': 'CBS News 24/7', 'countryCode': 'US', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'nasatv_us', 'number': 38, 'name': 'NASA TV HD', 'countryCode': 'US', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'france24_en_fr', 'number': 39, 'name': 'France 24 English', 'countryCode': 'FR', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'aljazeera_en_qa', 'number': 40, 'name': 'Al Jazeera English', 'countryCode': 'QA', 'isFavorite': true, 'isHidden': false},
    <String, dynamic>{'id': 'nhkworld_jp', 'number': 41, 'name': 'NHK World Japan', 'countryCode': 'JP', 'isFavorite': false, 'isHidden': false},
    <String, dynamic>{'id': 'arirang_kr', 'number': 42, 'name': 'Arirang TV Korea', 'countryCode': 'KR', 'isFavorite': false, 'isHidden': false},
  ];

  final TextEditingController _customTitleController = TextEditingController();
  final TextEditingController _customUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromTvBridge();
    });
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _customUrlController.dispose();
    super.dispose();
  }

  String get _tvIp => ref.read(cueDeckProvider).selectedDevice.ip.trim();

  Future<void> _syncFromTvBridge() async {
    final ip = _tvIp;
    if (ip.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _bridgeConnected = false;
          _statusMessage = 'Önce üstten TV bağlantısını seçin (Örn: 192.168.1.125)';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1400);
    try {
      final req = await client
          .getUrl(Uri.parse('http://$ip:8765/api/catalog'))
          .timeout(const Duration(milliseconds: 1500));
      final resp = await req.close().timeout(const Duration(milliseconds: 1500));
      if (resp.statusCode == 200) {
        final raw = await resp.transform(utf8.decoder).join();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded['ok'] == true) {
          final rawCountries = decoded['countries'];
          final rawChannels = decoded['channels'];
          final activeCh = decoded['activeChannel'];
          if (mounted) {
            setState(() {
              _bridgeConnected = true;
              _isLoading = false;
              if (rawCountries is List && rawCountries.isNotEmpty) {
                _countries = rawCountries
                    .whereType<Map<String, dynamic>>()
                    .toList();
              }
              if (rawChannels is List && rawChannels.isNotEmpty) {
                _channels = rawChannels
                    .whereType<Map<String, dynamic>>()
                    .toList();
              }
              if (activeCh is Map && activeCh['id'] != null) {
                _activeChannelId = activeCh['id'].toString();
              }
              _onlyNationalFilter =
                  decoded['onlyNationalFilter'] as bool? ?? true;
              _statusMessage =
                  '✅ CueTV Canlı Köprü Aktif ($ip:8765) • ${_channels.length} Kanal';
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('CueTV studio probe fallback: $e');
    } finally {
      client.close(force: true);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _bridgeConnected = false;
        _statusMessage =
            '💡 TV\'de CueTV kapalıysa "TV\'de CueTV Başlat" veya herhangi bir kanala dokunun (ADB üzerinden otomatik açılır).';
      });
    }
  }

  Future<void> _zapChannelOnTv(String channelId, String channelName) async {
    HapticFeedback.lightImpact();
    setState(() {
      _activeChannelId = channelId;
      _statusMessage = '📺 "$channelName" TV ekranına ışınlanıyor...';
    });

    final ip = _tvIp;
    if (ip.isNotEmpty) {
      final ok = await _postToBridge('/api/zap', <String, dynamic>{
        'channelId': channelId,
      });
      if (ok) {
        if (mounted) {
          setState(() {
            _bridgeConnected = true;
            _statusMessage = '✅ "$channelName" TV\'de oynatılıyor!';
          });
        }
        return;
      }
    }

    // Fallback: Launch CueTV directly into that channel via ADB Port 5555 deep link!
    await ref.read(cueDeckProvider.notifier).launchPlatformApp(
          StreamingPlatform.cueTv,
          deepLinkUrl: 'cuetv://channel/$channelId',
        );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _syncFromTvBridge();
  }

  Future<bool> _postToBridge(
    String path,
    Map<String, dynamic> body,
  ) async {
    final ip = _tvIp;
    if (ip.isEmpty) return false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1400);
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip:8765$path'))
          .timeout(const Duration(milliseconds: 1500));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close().timeout(const Duration(milliseconds: 1600));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _pushCustomizationToTv() async {
    final enabledCountries = _countries
        .where((c) => c['isEnabled'] == true)
        .map((c) => c['code'].toString())
        .toList();
    final favoriteIds = _channels
        .where((c) => c['isFavorite'] == true)
        .map((c) => c['id'].toString())
        .toList();
    final hiddenIds = _channels
        .where((c) => c['isHidden'] == true)
        .map((c) => c['id'].toString())
        .toList();
    final channelOrder = _channels.map((c) => c['id'].toString()).toList();

    final ok = await _postToBridge('/api/customize', <String, dynamic>{
      'enabledCountries': enabledCountries,
      'favoriteIds': favoriteIds,
      'hiddenIds': hiddenIds,
      'channelOrder': channelOrder,
      'onlyNationalFilter': _onlyNationalFilter,
    });
    if (mounted) {
      setState(() {
        _statusMessage = ok
            ? '✅ Kanal sıralaması ve ülke tercihleri TV\'ye kaydedildi!'
            : '⚠️ TV\'de CueTV açık olduğunda tercihler otomatik eşitlenir.';
      });
    }
  }

  void _moveChannelInList(int oldIdx, int newIdx, List<Map<String, dynamic>> visible) {
    if (newIdx < 0 || newIdx >= visible.length) return;
    final itemA = visible[oldIdx];
    final itemB = visible[newIdx];
    final fullIdxA = _channels.indexWhere((c) => c['id'] == itemA['id']);
    final fullIdxB = _channels.indexWhere((c) => c['id'] == itemB['id']);
    if (fullIdxA < 0 || fullIdxB < 0) return;

    setState(() {
      final temp = _channels[fullIdxA];
      _channels[fullIdxA] = _channels[fullIdxB];
      _channels[fullIdxB] = temp;
    });
    _pushCustomizationToTv();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bgColor = isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFF3F5F9);
    final cardColor = isDarkMode ? const Color(0xFF131926) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final visibleChannels = _channels.where((c) {
      if (_selectedCountryCode == 'FAV') {
        return c['isFavorite'] == true;
      }
      return (c['countryCode']?.toString().toUpperCase() ?? 'TR') ==
          _selectedCountryCode;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDarkMode
                  ? const Color(0xFF262F45)
                  : const Color(0xFFD8DEE8),
            ),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: subTextColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0x22E2A84B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2A84B)),
                      ),
                      child: const Icon(
                        Icons.live_tv_rounded,
                        color: Color(0xFFE2A84B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'CueTV • Ulusal Kanal Stüdyosu',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _statusMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _bridgeConnected
                                  ? const Color(0xFF00E676)
                                  : subTextColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'TV ile Eşitle',
                      onPressed: _syncFromTvBridge,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.sync_rounded, color: textColor),
                    ),
                  ],
                ),
              ),

              // Quick Action Row: Launch CueTV on TV | Switch Backup Source | Sync iptv-org
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(cueDeckProvider.notifier)
                              .launchPlatformApp(StreamingPlatform.cueTv);
                          Future<void>.delayed(
                            const Duration(milliseconds: 900),
                            _syncFromTvBridge,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2A84B),
                          foregroundColor: const Color(0xFF0B0D14),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.tv_rounded, size: 16),
                        label: const Text(
                          'TV\'de CueTV Aç',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          await _postToBridge('/api/command', <String, dynamic>{
                            'action': 'nextSource',
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE2A84B),
                          side: const BorderSide(color: Color(0x66E2A84B)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text(
                          'Yedek Kaynak Seç',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Country Selector Chips (Tap to filter, Long-press to Enable/Disable on TV)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: <Widget>[
                    _buildCountryChip(
                      code: 'FAV',
                      flag: '⭐',
                      label: 'Favoriler',
                      isEnabledOnTv: true,
                      isDarkMode: isDarkMode,
                    ),
                    for (final c in _countries)
                      _buildCountryChip(
                        code: c['code']?.toString() ?? 'TR',
                        flag: c['flag']?.toString() ?? '🌍',
                        label: c['nameTr']?.toString() ?? 'Ülke',
                        isEnabledOnTv: c['isEnabled'] as bool? ?? true,
                        isDarkMode: isDarkMode,
                      ),
                  ],
                ),
              ),

              // Add Custom Stream (.m3u8 / YouTube Live) Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF222B3D)
                          : const Color(0xFFD8DEE8),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _customTitleController,
                          style: TextStyle(color: textColor, fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Kanal Adı',
                            hintStyle: TextStyle(color: subTextColor, fontSize: 11),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _customUrlController,
                          style: TextStyle(color: textColor, fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Özel .m3u8 veya Canlı Yayın URL yapıştırın',
                            hintStyle: TextStyle(color: subTextColor, fontSize: 11),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'TV\'ye Ekle ve Oynat',
                        onPressed: () async {
                          final url = _customUrlController.text.trim();
                          if (url.isEmpty) return;
                          final title = _customTitleController.text.trim().isNotEmpty
                              ? _customTitleController.text.trim()
                              : 'Özel Kanal';
                          _customUrlController.clear();
                          _customTitleController.clear();
                          final ok = await _postToBridge('/api/zap', <String, dynamic>{
                            'streamUrl': url,
                            'title': title,
                            'countryCode': _selectedCountryCode == 'FAV'
                                ? 'TR'
                                : _selectedCountryCode,
                          });
                          if (!ok) {
                            await ref.read(cueDeckProvider.notifier).launchPlatformApp(
                                  StreamingPlatform.cueTv,
                                  deepLinkUrl:
                                      'cuetv://stream?url=${Uri.encodeComponent(url)}&title=${Uri.encodeComponent(title)}',
                                );
                          }
                          await _syncFromTvBridge();
                        },
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF00E676),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Channel List (Tap to Zap on TV, Star to Favorite, Up/Down to Reorder, Eye to Hide)
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: visibleChannels.length,
                  itemBuilder: (context, idx) {
                    final ch = visibleChannels[idx];
                    final id = ch['id']?.toString() ?? '';
                    final name = ch['name']?.toString() ?? 'Kanal';
                    final numVal = (ch['number'] as num?)?.toInt() ?? (idx + 1);
                    final isFav = ch['isFavorite'] as bool? ?? false;
                    final isHidden = ch['isHidden'] as bool? ?? false;
                    final isPlaying = id == _activeChannelId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: isPlaying
                            ? const Color(0x2200E676)
                            : cardColor,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _zapChannelOnTv(id, name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPlaying
                                    ? const Color(0xFF00E676)
                                    : (isDarkMode
                                          ? const Color(0xFF1E2638)
                                          : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0x220284C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    numVal.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: isHidden
                                              ? subTextColor
                                              : textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          decoration: isHidden
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        isPlaying
                                            ? '🟢 Şu An TV\'de Açık'
                                            : 'Dokun -> TV\'de Anında Aç',
                                        style: TextStyle(
                                          color: isPlaying
                                              ? const Color(0xFF00E676)
                                              : subTextColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  tooltip: 'Yukarı Taşı',
                                  onPressed: () =>
                                      _moveChannelInList(idx, idx - 1, visibleChannels),
                                  icon: Icon(
                                    Icons.arrow_upward_rounded,
                                    color: subTextColor,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  tooltip: 'Aşağı Taşı',
                                  onPressed: () =>
                                      _moveChannelInList(idx, idx + 1, visibleChannels),
                                  icon: Icon(
                                    Icons.arrow_downward_rounded,
                                    color: subTextColor,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 19,
                                  tooltip: 'Favori',
                                  onPressed: () {
                                    setState(() {
                                      ch['isFavorite'] = !isFav;
                                    });
                                    _pushCustomizationToTv();
                                  },
                                  icon: Icon(
                                    isFav
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: isFav
                                        ? const Color(0xFFFFD54F)
                                        : subTextColor,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  tooltip: isHidden ? 'Göster' : 'Gizle',
                                  onPressed: () {
                                    setState(() {
                                      ch['isHidden'] = !isHidden;
                                    });
                                    _pushCustomizationToTv();
                                  },
                                  icon: Icon(
                                    isHidden
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: isHidden
                                        ? Colors.redAccent
                                        : subTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountryChip({
    required String code,
    required String flag,
    required String label,
    required bool isEnabledOnTv,
    required bool isDarkMode,
  }) {
    final isSelected = _selectedCountryCode == code;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: code == 'FAV'
            ? null
            : () {
                HapticFeedback.heavyImpact();
                setState(() {
                  for (final c in _countries) {
                    if (c['code'] == code) {
                      c['isEnabled'] = !(c['isEnabled'] as bool? ?? true);
                    }
                  }
                });
                _pushCustomizationToTv();
              },
        child: ActionChip(
          onPressed: () {
            setState(() {
              _selectedCountryCode = code;
            });
            if (code != 'FAV') {
              _postToBridge('/api/command', <String, dynamic>{
                'action': 'selectCountry',
                'countryCode': code,
              });
            }
          },
          backgroundColor: isSelected
              ? const Color(0xFF0284C7)
              : (isDarkMode
                    ? const Color(0xFF182032)
                    : const Color(0xFFE2E8F0)),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : (isEnabledOnTv
                      ? Colors.transparent
                      : Colors.redAccent.withValues(alpha: 0.5)),
          ),
          label: Text(
            '$flag $label${isEnabledOnTv ? "" : " (Gizli)"}',
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : const Color(0xFF1E293B)),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
