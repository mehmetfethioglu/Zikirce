import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../dashboard/presentation/widgets/streak_share_preview_modal.dart';
import '../../providers/settings_provider.dart';
import '../../../zikir/domain/share_card_data_helper.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';

class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key});

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  late SpiritualQuote _activeQuote;

  @override
  void initState() {
    super.initState();
    _activeQuote = ShareCardDataHelper.nextRandomQuote(
      acrossAllTopics: true,
    );
  }

  void _randomizeQuote() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeQuote = ShareCardDataHelper.nextRandomQuote(
        avoidQuote: _activeQuote,
        acrossAllTopics: true,
      );
    });
  }

  Future<void> _openQuotePicker() async {
    HapticFeedback.selectionClick();
    final picked = await SpiritualQuotePickerSheet.show(
      context: context,
      currentQuote: _activeQuote,
      initialTopic: _activeQuote.topic,
    );
    if (picked != null && mounted) {
      setState(() {
        _activeQuote = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final streakAsync = ref.watch(userStreakStreamProvider);
    final isEzberGoalEnabled = ref.watch(
      userSettingsProvider.select((s) => s.isHafizlikRepeatGoalEnabled),
    );
    final visiblePresets = ShareCardDataHelper.goalPresets
        .where((p) => p.id != 'ezber' || isEzberGoalEnabled)
        .take(6)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(
          'Manevi Paylaşım Stüdyosu',
          style: AppTypography.headingSmall(color: Colors.white),
        ),
      ),
      body: streakAsync.when(
        data: (streak) {
          final currentStreak = streak?.currentStreak ?? 0;
          final rank = streak?.rank ?? 'Mübtedi';

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                // Tahrir Estetiği Canlı Önizleme Kartı (Dinamik + Rastgele & Seç Özellikli)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 26,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EEDB),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFDFD1B8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Üst Rastgele & Seç Kontrol Butonları
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: _randomizeQuote,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFE2C8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD5C3A3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shuffle_rounded,
                                    size: 14,
                                    color: Color(0xFFA64B2A),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Rastgele Değiştir',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF382A1E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _openQuotePicker,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA64B2A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Ayet / Hadis Seç',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '“',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFA64B2A),
                          height: 0.75,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeQuote.text,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: _activeQuote.text.length > 100 ? 17.5 : 20.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF382A1E),
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 44,
                        height: 1.5,
                        color: const Color(0xFFA64B2A).withValues(alpha: 0.65),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _activeQuote.source,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF382A1E),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: visiblePresets.map((preset) {
                          return ActionChip(
                            backgroundColor: const Color(0xFFEFE2C8),
                            side: const BorderSide(color: Color(0xFFD5C3A3)),
                            label: Text(
                              '${preset.emoji} ${preset.labelTr}',
                              style: const TextStyle(
                                color: Color(0xFF382A1E),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () {
                              ZikirSharePreviewModal.show(
                                context: context,
                                zikirName: preset.badgeTitleTr,
                                category: preset.labelTr,
                                initialTheme:
                                    ZikirShareThemeData.themeForGoalOrTask(
                                  goalType: preset.id,
                                ),
                                initialShowCounterStats: false,
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/zikirce_logo.png',
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            isAntiAlias: true,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'Zikirce',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF382A1E),
                              fontSize: 15.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold500,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text(
                      'Manevi Paylaşım Stüdyosunu Aç',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () {
                      ZikirSharePreviewModal.show(
                        context: context,
                        zikirName: 'Günlük Zikir & Kalbin Huzuru',
                        category: 'Zikir',
                        initialQuote: _activeQuote,
                        initialTheme: ZikirShareCardTheme.fajrDawn,
                        initialShowCounterStats: false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: AppColors.gold500.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(
                      'İstikrar & Seri Kartını Aç',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      StreakSharePreviewModal.show(
                        context,
                        currentStreak: currentStreak,
                        bestStreak: streak?.bestStreak ?? 0,
                        totalDays: streak?.totalDays ?? 0,
                        rankName: rank,
                        initialTheme: ZikirShareThemeData.themeForGoalOrTask(
                          goalType: 'streak',
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold500),
        ),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}
