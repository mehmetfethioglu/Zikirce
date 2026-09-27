import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/ezber_providers.dart';

class HafizlikTrackerScreen extends ConsumerWidget {
  const HafizlikTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayLogAsync = ref.watch(todayHafizlikLogProvider);
    final ezberNotifier = ref.read(ezberNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Hâfızlık Takip Defteri', style: AppTypography.headingSmall(color: Colors.white)),
      ),
      body: todayLogAsync.when(
        data: (log) {
          final isHam = log?.isHamDone ?? false;
          final isPismis = log?.isPismisDone ?? false;
          final isHas = log?.isHasDone ?? false;
          final isVird = log?.isAsgariVirdDone ?? false;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Daily Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.gold500.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bugünkü Hâfızlık Vazifeleri',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '“Kur’an’ı ezberleyen ve okuyan kimse, şerefli ve itaatkâr meleklerle beraberdir.”',
                      style: TextStyle(color: Color(0xFFD4EBE4), fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildTaskTile(
                title: '1. Ham (Yeni Ders)',
                subtitle: 'Bugün ezberlenecek yeni Mushaf sayfası',
                isDone: isHam,
                onChanged: (val) => ezberNotifier.updateHafizlikTask(taskType: 'ham', isDone: val),
              ),
              const SizedBox(height: 12),
              _buildTaskTile(
                title: '2. Pişmiş (Yakın Tekrar)',
                subtitle: 'Dün ve bu hafta verilen son 5 sayfa tekrarı',
                isDone: isPismis,
                onChanged: (val) => ezberNotifier.updateHafizlikTask(taskType: 'pismis', isDone: val),
              ),
              const SizedBox(height: 12),
              _buildTaskTile(
                title: '3. Has (Eski Cüzler)',
                subtitle: 'Daha önce ezberlenmiş cüzlerin sağlamlaştırılması',
                isDone: isHas,
                onChanged: (val) => ezberNotifier.updateHafizlikTask(taskType: 'has', isDone: val),
              ),
              const SizedBox(height: 12),
              _buildTaskTile(
                title: '4. Asgarî Vird (Tilavet)',
                subtitle: 'Günlük en az 1 cüz veya vird tilaveti',
                isDone: isVird,
                onChanged: (val) => ezberNotifier.updateHafizlikTask(taskType: 'vird', isDone: val),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold500)),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildTaskTile({
    required String title,
    required String subtitle,
    required bool isDone,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? AppColors.emerald500 : AppColors.darkBorder,
          width: isDone ? 1.5 : 1.0,
        ),
      ),
      child: CheckboxListTile(
        value: isDone,
        activeColor: AppColors.emerald500,
        checkColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8A9BAE), fontSize: 13),
          ),
        ),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }
}
