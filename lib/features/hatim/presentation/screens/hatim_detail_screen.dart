import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../kuran/presentation/screens/mushaf_screen.dart';
import '../screens/mukabele_hatim_screen.dart';
import '../../providers/hatim_providers.dart';
import 'hatim_qr_screen.dart';
import '../widgets/hatim_sync_gate.dart';
import '../widgets/hatim_duasi_modal.dart';

class HatimDetailScreen extends ConsumerWidget {
  final Hatim hatim;

  const HatimDetailScreen({super.key, required this.hatim});

  void _showJuzOptions(BuildContext context, WidgetRef ref, Hatim hatim, int juzNo) {
    final startPage = SurahDataProvider.getJuzStartPage(juzNo);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1E24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$juzNo. Cüz ($startPage. Sayfa)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E2B27),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF2D7D76)),
                title: const Text('Mushaf Sayfasını Aç (Oku)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MushafScreen(
                        initialPage: startPage,
                        activeHatim: hatim,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.headset_mic_rounded, color: Color(0xFFD4AF37)),
                title: const Text('Mukabele ile Dinle / Takip Et', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Kelime takipli ve sesli tilavet'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  HatimSyncGate.checkAndProceed(
                    context: context,
                    ref: ref,
                    onProceed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MukabeleHatimScreen(
                            activeHatim: hatim,
                            initialPage: startPage,
                            initialJuz: juzNo,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juzListAsync = ref.watch(hatimJuzProgressProvider(hatim.id));
    final hatimNotifier = ref.read(hatimNotifierProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF090D10) : const Color(0xFFF4EFE6);
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFFFFDF8);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);
    final goldAccent = isDark ? AppColors.gold400 : const Color(0xFFB57D15);

    final resumePage = (hatim.completedPages + 1).clamp(1, 604);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
        title: Text(hatim.title, style: AppTypography.headingSmall(color: primaryTextColor)),
        actions: [
          IconButton(
            icon: const Text('🤲', style: TextStyle(fontSize: 20)),
            tooltip: 'Matbû Hatim Duası',
            onPressed: () {
              HatimDuasiModal.show(
                context,
                completedHatim: hatim.isCompleted ? hatim : null,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.headset_mic_rounded, color: goldAccent),
            tooltip: 'Mukabele ile Dinle',
            onPressed: () {
              HatimSyncGate.checkAndProceed(
                context: context,
                ref: ref,
                onProceed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MukabeleHatimScreen(
                        activeHatim: hatim,
                        initialPage: resumePage,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (hatim.isGroup)
            IconButton(
              icon: Icon(Icons.qr_code_2_rounded, color: goldAccent),
              tooltip: 'Grup QR Kodu',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HatimQrDisplayScreen(hatim: hatim)),
                );
              },
            ),
        ],
      ),
      body: juzListAsync.when(
        data: (juzList) {
          final completedJuz = juzList.where((j) => j.isCompleted).length;

          return Column(
            children: [
              // Progress Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.cardDarkGradient
                      : const LinearGradient(
                          colors: [Color(0xFF165241), Color(0xFF0F3B2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFF2A876E)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tamamlanan Cüz', style: TextStyle(color: isDark ? const Color(0xFF8A9BAE) : const Color(0xFFD4EBE4), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '$completedJuz / 30 Cüz',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      '%${((completedJuz / 30.0) * 100).toStringAsFixed(0)}',
                      style: TextStyle(color: isDark ? AppColors.gold400 : AppColors.gold300, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // 30 Juz Visual Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: juzList.length,
                  itemBuilder: (context, index) {
                    final juz = juzList[index];
                    final isComp = juz.isCompleted;

                    return GestureDetector(
                      onTap: () async {
                        HapticService.selectionClick();
                        final willCompleteAll30 = !isComp && completedJuz == 29;
                        await hatimNotifier.toggleJuzCompletion(
                          hatim.id,
                          juz.juzNo,
                          !isComp,
                        );
                        if (willCompleteAll30 && context.mounted) {
                          await HatimDuasiModal.show(
                            context,
                            completedHatim: hatim,
                            isCompletionCelebration: true,
                          );
                        }
                      },
                      onLongPress: () {
                        HapticService.selectionClick();
                        _showJuzOptions(context, ref, hatim, juz.juzNo);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isComp ? AppColors.emeraldGradient : null,
                          color: isComp ? null : cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isComp ? AppColors.emerald400 : borderColor,
                            width: 1.2,
                          ),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${juz.juzNo}',
                              style: TextStyle(
                                color: isComp ? Colors.white : primaryTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isComp ? 'Okundu' : 'Boş',
                              style: TextStyle(
                                color: isComp ? AppColors.gold300 : secondaryTextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: goldAccent)),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
