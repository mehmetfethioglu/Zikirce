import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/changelog_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';

class WhatsNewBottomSheet extends StatefulWidget {
  final bool isHistoryMode;

  const WhatsNewBottomSheet({
    super.key,
    this.isHistoryMode = false,
  });

  /// Güncelleme sonrası otomatik açılan tek sürüm çekmecesi
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WhatsNewBottomSheet(isHistoryMode: false),
    );
    // Kapatıldığında görüldü olarak işaretle
    await ChangelogService.markCurrentVersionAsSeen();
  }

  /// Ayarlar ekranından açılan geçmiş ve tüm sürümleri inceleme çekmecesi
  static Future<void> showHistory(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WhatsNewBottomSheet(isHistoryMode: true),
    );
  }

  @override
  State<WhatsNewBottomSheet> createState() => _WhatsNewBottomSheetState();
}

class _WhatsNewBottomSheetState extends State<WhatsNewBottomSheet> {
  late bool _showHistory;
  int _selectedHistoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _showHistory = widget.isHistoryMode;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const allReleases = ChangelogService.releases;
    final currentRelease = _showHistory 
        ? allReleases[_selectedHistoryIndex.clamp(0, allReleases.length - 1)]
        : ChangelogService.latestRelease;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sürükleme Çubuğu (Drag Handle)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.secondaryTextAlt.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            // Üst Başlık ve Rozet Bölümü
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol İkon Rozeti
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.accent,
                              colors.accentLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Başlık ve Sürüm Bilgisi
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _showHistory 
                                        ? l10n.translate('Changelog_AllReleasesTitle')
                                        : l10n.translate('Changelog_WhatsNewTitle'),
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: colors.primaryText,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Sürüm Etiketi & Tarih
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colors.accent.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'v${currentRelease.versionName} (${currentRelease.versionCode})',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ${currentRelease.getReleaseDate(lang)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colors.secondaryTextAlt,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Kapatma İkon Butonu
                      IconButton(
                        onPressed: () {
                          HapticService.selectionClick();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.close_rounded, color: colors.secondaryTextAlt),
                        splashRadius: 22,
                      ),
                    ],
                  ),

                  // Geçmiş Sürümler Seçim Çubuğu (Varsa ve Geçmiş Modundaysa)
                  if (_showHistory && allReleases.length > 1) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: allReleases.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final rel = allReleases[index];
                          final isSelected = index == _selectedHistoryIndex;
                          return GestureDetector(
                            onTap: () {
                              HapticService.selectionClick();
                              setState(() => _selectedHistoryIndex = index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? colors.accent
                                    : colors.cardBackgroundAlt.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected 
                                      ? colors.accent
                                      : colors.borderStroke.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'v${rel.versionName}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : colors.primaryText,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: colors.borderStroke.withValues(alpha: 0.4)),

            // Yenilik Maddeleri Listesi (Scrollable)
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                itemCount: currentRelease.items.length,
                itemBuilder: (context, index) {
                  final item = currentRelease.items[index];
                  return _buildChangelogCard(
                    context: context,
                    colors: colors,
                    l10n: l10n,
                    lang: lang,
                    item: item,
                    isDark: isDark,
                  );
                },
              ),
            ),

            Divider(height: 1, thickness: 1, color: colors.borderStroke.withValues(alpha: 0.4)),

            // Alt Butonlar Bölümü
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ana Aksiyon Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticService.selectionClick();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: colors.accent.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _showHistory
                            ? l10n.translate('Changelog_ActionClose')
                            : l10n.translate('Changelog_ActionDismiss'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  // Tüm Geçmişi Gör / Tek Sürüme Dön Butonu
                  if (!_showHistory && allReleases.length > 1) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () {
                        HapticService.selectionClick();
                        setState(() => _showHistory = true);
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: colors.secondaryText,
                      ),
                      child: Text(
                        l10n.translate('Changelog_AllHistoryBtn'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogCard({
    required BuildContext context,
    required AppThemeColors colors,
    required AppLocalizations l10n,
    required String lang,
    required ChangelogItem item,
    required bool isDark,
  }) {
    Color tagColor;
    String tagLabel;

    switch (item.type) {
      case ChangelogType.newFeature:
        tagColor = const Color(0xFF10B981); // Emerald
        tagLabel = l10n.translate('Changelog_TagNew');
        break;
      case ChangelogType.improvement:
        tagColor = const Color(0xFF3B82F6); // Blue
        tagLabel = l10n.translate('Changelog_TagImprovement');
        break;
      case ChangelogType.bugFix:
        tagColor = const Color(0xFFF59E0B); // Amber
        tagLabel = l10n.translate('Changelog_TagBugFix');
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.borderStroke.withValues(alpha: isDark ? 0.35 : 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İkon Kutusu
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tagColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(
              item.icon,
              color: tagColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // İçerik (Etiket, Başlık, Açıklama)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        tagLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: tagColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.getTitle(lang),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.getDescription(lang),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: colors.secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
