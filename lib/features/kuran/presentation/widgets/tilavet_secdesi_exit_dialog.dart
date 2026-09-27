import 'package:flutter/material.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/tilavet_secdesi_data.dart';

enum TilavetExitChoice {
  edaEttim,
  borcaEkle,
  okumadanGectim,
}

class TilavetSecdesiExitDialog extends StatelessWidget {
  final List<TilavetSecdeItem> encounteredSecdes;

  const TilavetSecdesiExitDialog({
    super.key,
    required this.encounteredSecdes,
  });

  static Future<TilavetExitChoice?> show(
    BuildContext context, {
    required List<TilavetSecdeItem> encounteredSecdes,
  }) {
    return showDialog<TilavetExitChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TilavetSecdesiExitDialog(
        encounteredSecdes: encounteredSecdes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF22262E) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor =
        isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final count = encounteredSecdes.length;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D7D76).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🕌', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tilâvet Secdesi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu okuma oturumunuzda $count adet secde âyetinden geçtiniz:',
            style: TextStyle(
              fontSize: 13.5,
              color: secondaryTextColor,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // List of verses
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B20) : const Color(0xFFF3F6F4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: ListView(
              shrinkWrap: true,
              children: encounteredSecdes.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Text('✨ ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          '${item.sureName} Sûresi, ${item.ayetId}. Âyet (${item.page}. Sayfa)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFFFD56B)
                                : const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Tilâvet secdesini eda ettiniz mi?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),

          // Button 1: Evet, Eda Ettim
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7D76),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text(
                'Evet, Eda Ettim',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                HapticService.targetReached();
                Navigator.of(context).pop(TilavetExitChoice.edaEttim);
              },
            ),
          ),
          const SizedBox(height: 8),

          // Button 2: Sonra Yapacağım (+Borca Ekle)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(
                'Sonra Yapacağım (+$count Borca Ekle)',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                HapticService.tapClick();
                Navigator.of(context).pop(TilavetExitChoice.borcaEkle);
              },
            ),
          ),
          const SizedBox(height: 6),

          // Button 3: Okumadan Geçtim / Sayma
          Center(
            child: TextButton(
              onPressed: () {
                HapticService.selectionClick();
                Navigator.of(context).pop(TilavetExitChoice.okumadanGectim);
              },
              child: Text(
                'Bu Âyetleri Okumadan Geçtim (Sayma)',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
