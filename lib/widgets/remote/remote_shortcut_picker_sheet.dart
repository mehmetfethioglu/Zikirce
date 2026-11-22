import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';

/// Opens the bottom sheet to change which streaming app is assigned to [slotIndex]
/// on the G10 physical remote chassis.
void showRemoteShortcutPickerSheet(
  BuildContext context, {
  required int slotIndex,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RemoteShortcutPickerSheet(slotIndex: slotIndex),
  );
}

/// Compact 2-slot quick-launch customization row for the simplified Settings card.
class RemoteShortcutSlotPairRow extends ConsumerWidget {
  const RemoteShortcutSlotPairRow({super.key});

  static const List<String> _slotPositionLabels = <String>[
    '1. Sol Tuş',
    '2. Sağ Tuş',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final shortcuts = ref.watch(
      cueDeckProvider.select((s) => s.remoteShortcuts),
    );
    final slots = shortcuts.length >= 2
        ? shortcuts
        : StreamingPlatform.defaultRemoteShortcuts;

    final subSurfaceBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    Widget buildSlot(int index) {
      final platform = slots[index];
      return Expanded(
        child: InkWell(
          key: Key('settings_shortcut_slot_$index'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            showRemoteShortcutPickerSheet(context, slotIndex: index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: subSurfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: <Widget>[
                Icon(platform.icon, color: platform.brandColor, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _slotPositionLabels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        platform.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.swap_horiz_rounded,
                  color: goldText,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        buildSlot(0),
        const SizedBox(width: 8),
        buildSlot(1),
      ],
    );
  }
}

/// Standalone settings card allowing users to customize the 2 active app shortcut buttons.
class RemoteShortcutCustomizationCard extends ConsumerWidget {
  const RemoteShortcutCustomizationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.apps_rounded, color: goldText, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hızlı Uygulama Tuşları (2 Yuva)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: goldText,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(cueDeckProvider.notifier)
                      .resetRemoteShortcutsToDefault();
                },
                child: const Text(
                  'Sıfırla',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Değiştirmek istediğiniz tuşa dokunun (veya kumandada basılı tutun).',
            style: TextStyle(color: secondaryText, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          const RemoteShortcutSlotPairRow(),
        ],
      ),
    );
  }
}

/// Modal sheet letting the user reassign either of the 2 physical shortcut slots.
class RemoteShortcutPickerSheet extends ConsumerWidget {
  const RemoteShortcutPickerSheet({super.key, required this.slotIndex});

  final int slotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final shortcuts = ref.watch(
      cueDeckProvider.select((s) => s.remoteShortcuts),
    );
    final currentPlatform = (slotIndex >= 0 && slotIndex < shortcuts.length)
        ? shortcuts[slotIndex]
        : StreamingPlatform.youtube;

    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F6FA);
    final itemBg = isDarkMode ? const Color(0xFF11141E) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.tune_rounded, color: goldText, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${slotIndex + 1}. Kumanda Tuşunu Değiştir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: secondaryText),
                  ),
                ],
              ),
              Text(
                'Bu tuşa bastığınızda TV\'de açılacak uygulamayı seçin:',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: StreamingPlatform.values.map((platform) {
                      final isSelected = platform == currentPlatform;
                      return ChoiceChip(
                        avatar: Icon(
                          platform.icon,
                          color: platform.brandColor,
                          size: 16,
                        ),
                        label: Text(platform.label),
                        selected: isSelected,
                        backgroundColor: itemBg,
                        selectedColor: isDarkMode
                            ? const Color(0xFF2D2920)
                            : const Color(0xFFFEF3C7),
                        checkmarkColor: goldText,
                        side: BorderSide(
                          color: isSelected
                              ? goldText.withValues(alpha: 0.75)
                              : borderColor,
                        ),
                        labelStyle: TextStyle(
                          color: primaryText,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(cueDeckProvider.notifier)
                              .updateRemoteShortcutSlot(slotIndex, platform);
                          Navigator.of(context).pop();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
