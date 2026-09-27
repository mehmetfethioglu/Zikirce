import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/kuran_providers.dart';

class AudioSyncPlayerBar extends ConsumerWidget {
  const AudioSyncPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(kuranAudioNotifierProvider);
    final audioNotifier = ref.read(kuranAudioNotifierProvider.notifier);

    if (!audioState.isPlaying &&
        !audioState.isLoading &&
        audioState.currentAyahId == 1 &&
        audioState.playbackProgress == 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF121418).withOpacity(0.96) : const Color(0xFFFFFDF8).withOpacity(0.97);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final borderColor = isDark ? AppColors.gold500.withOpacity(0.4) : const Color(0xFFC5A358);
    final trackColor = isDark ? const Color(0xFF1C222A) : const Color(0xFFE5DFC9);
    final progressColor = isDark ? AppColors.gold500 : const Color(0xFF165241);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play / Pause Button
          IconButton(
            icon: audioState.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: isDark ? AppColors.gold400 : AppColors.emerald700,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(
                    audioState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: isDark ? AppColors.gold400 : AppColors.emerald700,
                    size: 36,
                  ),
            onPressed: () => audioNotifier.togglePlayPause(),
          ),
          const SizedBox(width: 8),
          // Info & Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${audioState.currentSurahId}. Sûre • ${audioState.currentAyahId}. Âyet',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: audioState.playbackProgress,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stop Button
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              size: 20,
            ),
            onPressed: () => audioNotifier.stop(),
          ),
        ],
      ),
    );
  }
}
