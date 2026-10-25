import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/hatim_providers.dart';
import 'hatim_detail_screen.dart';
import 'hatim_qr_screen.dart';
import 'mukabele_hatim_screen.dart';
import '../widgets/hatim_sync_gate.dart';
import '../widgets/hatim_duasi_modal.dart';

class HatimListScreen extends ConsumerWidget {
  const HatimListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hatimsAsync = ref.watch(hatimListStreamProvider);
    final hatimNotifier = ref.read(hatimNotifierProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF090D10) : const Color(0xFFF4EFE6);
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFFFFDF8);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);
    final goldAccent = isDark ? AppColors.gold400 : const Color(0xFFB57D15);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
        title: Text('Hatim Takibi', style: AppTypography.headingSmall(color: primaryTextColor)),
        actions: [
          IconButton(
            icon: const Text('🤲', style: TextStyle(fontSize: 20)),
            tooltip: 'Sadece Hatim Duası Oku',
            onPressed: () => HatimDuasiModal.show(context),
          ),
          IconButton(
            icon: Icon(Icons.headset_mic_rounded, color: goldAccent),
            tooltip: 'Mukabele Çalar',
            onPressed: () {
              HatimSyncGate.checkAndProceed(
                context: context,
                ref: ref,
                onProceed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MukabeleHatimScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: primaryTextColor),
            tooltip: 'QR ile Hatme Katıl',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HatimQrScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: primaryTextColor),
            tooltip: 'Yeni Hatim Başlat',
            onPressed: () => _showCreateHatimDialog(context, hatimNotifier, isDark),
          ),
        ],
      ),
      body: hatimsAsync.when(
        data: (hatims) {
          if (hatims.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded, color: goldAccent, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Aktif Hatim Bulunmuyor',
                    style: TextStyle(color: primaryTextColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bireysel veya arkadaşlarınızla ortak grup hatmi başlatın.',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.gold500 : AppColors.emerald700,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Hatim Başlat', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showCreateHatimDialog(context, hatimNotifier, isDark),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: goldAccent.withValues(alpha: 0.65)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    icon: const Text('🤲', style: TextStyle(fontSize: 16)),
                    label: const Text(
                      'Sadece Hatim Duası Oku (Harici Hatim)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => HatimDuasiModal.show(context),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hatims.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final hatim = hatims[index];
              final progress = (hatim.completedPages / 604.0).clamp(0.0, 1.0);

              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HatimDetailScreen(hatim: hatim),
                      ),
                    );
                  },
                  leading: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: hatim.isCompleted ? AppColors.emeraldGradient : AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      hatim.isCompleted ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                      color: hatim.isCompleted ? Colors.white : Colors.black,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    hatim.title,
                    style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        hatim.isGroup ? 'Grup Hatmi • ${hatim.completedPages} / 604 Sayfa' : 'Bireysel Hatim • ${hatim.completedPages} / 604 Sayfa',
                        style: TextStyle(color: secondaryTextColor, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFE8E5DC),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            hatim.isCompleted ? AppColors.emerald400 : (isDark ? AppColors.gold500 : AppColors.emerald700),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white30 : const Color(0xFF9E9E9E), size: 14),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: goldAccent)),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  void _showCreateHatimDialog(BuildContext context, HatimNotifier notifier, bool isDark) {
    final titleController = TextEditingController(text: 'Ramazan Hatmi');
    bool isGroup = false;

    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFFFFDF8);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Yeni Hatim Başlat', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Hatim Başlığı',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280)),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF4EFE6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: Text('Grup Hatmi (QR Paylaşımlı)', style: TextStyle(color: textColor, fontSize: 14)),
                  value: isGroup,
                  activeThumbColor: isDark ? AppColors.gold500 : AppColors.emerald700,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setModalState(() => isGroup = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('İptal', style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF6B7280))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.gold500 : AppColors.emerald700,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                ),
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isNotEmpty) {
                    notifier.createHatim(title: title, isGroup: isGroup);
                    Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Başlat', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
