import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bookshelf/presentation/providers/bookshelf_provider.dart';

class TahrirOnboardingDialog extends ConsumerStatefulWidget {
  const TahrirOnboardingDialog({super.key});

  static const String _onboardingCompletedKey = 'tahrir_onboarding_completed_v1';

  static Future<void> checkAndShow(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_onboardingCompletedKey) ?? false;
    if (completed || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TahrirOnboardingDialog(),
    );
  }

  @override
  ConsumerState<TahrirOnboardingDialog> createState() =>
      _TahrirOnboardingDialogState();
}

class _TahrirOnboardingDialogState
    extends ConsumerState<TahrirOnboardingDialog> {
  int _currentStep = 0;
  int _selectedDailyGoal = 20;
  bool _isSaving = false;

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        TahrirOnboardingDialog._onboardingCompletedKey,
        true,
      );
      await ref.read(habitRepositoryProvider).setDailyGoal(_selectedDailyGoal);
      await ref.read(bookshelfProvider.notifier).loadBooks();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: AppColors.amberGold.withValues(alpha: 0.45),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Adım Göstergesi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amberGold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ADIM ${_currentStep + 1} / 3',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.amberGold,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(3, (idx) {
                      final active = idx == _currentStep;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 5),
                        width: active ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.terracotta
                              : theme.colorScheme.outline.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Adım İçeriği
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildStepBody(theme),
              ),

              const SizedBox(height: 22),

              // Alt Aksiyon Butonları
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Geri'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_currentStep < 2) {
                                setState(() => _currentStep++);
                              } else {
                                _completeOnboarding();
                              }
                            },
                      icon: Icon(
                        _currentStep < 2
                            ? Icons.arrow_forward_rounded
                            : Icons.auto_awesome_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _currentStep < 2 ? 'Devam Et' : 'Tahrir\'e Başla',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey('step_0'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.terracotta.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                size: 32,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bozuk ve Çift Sütunlu PDF\'lere Son',
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '300 DPI yüksek çözünürlüklü cihaz içi OCR motoru, Word tarzı otomatik tashih ve sıcak parşömen akışıyla taranmış ağır PDF\'leri bile göz yormayan kitap sayfalarına dönüştürün.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey('step_1'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.amberGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 34,
                color: AppColors.amberGold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kitap Hızınızla Koordine 21 Kademeli Hızlı Okuma Serüveni',
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Kitap okurken ölçülen gerçek kelime/dakika (WPM) hızınızla senkronize çalışan 21 kademeli adaptif antrenman ile anlayarak okuma hızınızı 2 katına çıkarın.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey('step_2'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 34,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Günlük Okuma Hedefinizi Seçin',
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Her gün düzenli okuma alışkanlığı kazanmak için başlangıç hedef sürenizi belirleyin:',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [10, 20, 30].map((mins) {
                final isSelected = _selectedDailyGoal == mins;
                return ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '$mins dk / gün',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedDailyGoal = mins);
                  },
                );
              }).toList(),
            ),
          ],
        );
    }
  }
}
