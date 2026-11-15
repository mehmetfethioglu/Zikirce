import 'package:flutter/material.dart';

import '../../constants/camera_colors.dart';

const List<String> kPortraitStudioLightingNames = [
  'DOĞAL IŞIK',
  'STÜDYO IŞIĞI',
  'KONTUR IŞIK',
  'SAHNE IŞIĞI',
  'SAHNE MONO',
  'HIGH-KEY MONO',
  'PANJUR GÖLGESİ',
  'PANJUR MONO',
  'ALTIN SAAT (3500K)',
  'PRİZMA & SİNEMA',
];

/// Atomic post-capture Portrait Refocus & Studio Lighting control dock.
class PortraitRefocusPanel extends StatelessWidget {
  final bool portraitEnabled;
  final double aperture;
  final int lightingIndex;
  final double lightIntensity;
  final bool isProcessing;
  final ValueChanged<bool> onTogglePortrait;
  final ValueChanged<double> onApertureChanged;
  final ValueChanged<double> onApertureCommit;
  final ValueChanged<double> onIntensityChanged;
  final ValueChanged<double> onIntensityCommit;
  final ValueChanged<int> onLightingSelected;
  final VoidCallback onSaveToGallery;

  const PortraitRefocusPanel({
    super.key,
    required this.portraitEnabled,
    required this.aperture,
    required this.lightingIndex,
    required this.lightIntensity,
    required this.isProcessing,
    required this.onTogglePortrait,
    required this.onApertureChanged,
    required this.onApertureCommit,
    required this.onIntensityChanged,
    required this.onIntensityCommit,
    required this.onLightingSelected,
    required this.onSaveToGallery,
  });

  @override
  Widget build(BuildContext context) {
    final intensityPercent = (lightIntensity.clamp(0.0, 1.0) * 100.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141821),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('inspector_portrait_toggle_pill'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTogglePortrait(!portraitEnabled),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: portraitEnabled
                        ? kIosYellow
                        : Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: portraitEnabled ? kIosYellow : Colors.white38,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        portraitEnabled
                            ? Icons.blur_on_rounded
                            : Icons.blur_off_rounded,
                        size: 14,
                        color: portraitEnabled ? Colors.black : Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        portraitEnabled ? 'PORTRE AÇIK' : 'PORTRE KAPALI',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: portraitEnabled
                              ? Colors.black
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                key: const ValueKey('studio_portrait_save_btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: kIosYellow.withValues(alpha: 0.20),
                  foregroundColor: kIosYellow,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isProcessing ? null : onSaveToGallery,
                icon: const Icon(Icons.save_alt_rounded, size: 16),
                label: const Text(
                  'Değişiklikleri Kaydet',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'ÇEKİM SONRASI DİYAFRAM (BOKEH)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                'ƒ ${aperture.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kIosYellow,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kIosYellow,
              inactiveTrackColor: Colors.white24,
              thumbColor: kIosYellow,
            ),
            child: Slider(
              key: const ValueKey('inspector_aperture_slider'),
              value: aperture.clamp(1.4, 16.0),
              min: 1.4,
              max: 16.0,
              onChanged: portraitEnabled ? onApertureChanged : null,
              onChangeEnd: portraitEnabled ? onApertureCommit : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'IŞIK ŞİDDETİ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: lightingIndex > 0 ? Colors.white70 : Colors.white38,
                  ),
                ),
              ),
              Text(
                '${intensityPercent.round()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: lightingIndex > 0 ? kIosYellow : Colors.white38,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kIosYellow,
              inactiveTrackColor: Colors.white24,
              thumbColor: kIosYellow,
              disabledActiveTrackColor: Colors.white12,
              disabledInactiveTrackColor: Colors.white10,
              disabledThumbColor: Colors.white24,
            ),
            child: Slider(
              key: const ValueKey('inspector_light_intensity_slider'),
              value: intensityPercent,
              min: 0.0,
              max: 100.0,
              onChanged: lightingIndex > 0
                  ? (v) => onIntensityChanged((v / 100.0).clamp(0.0, 1.0))
                  : null,
              onChangeEnd: lightingIndex > 0
                  ? (v) => onIntensityCommit((v / 100.0).clamp(0.0, 1.0))
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < kPortraitStudioLightingNames.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        kPortraitStudioLightingNames[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: lightingIndex == i
                              ? Colors.black
                              : Colors.white70,
                        ),
                      ),
                      selected: lightingIndex == i,
                      selectedColor: kIosYellow,
                      backgroundColor: Colors.black45,
                      onSelected: (_) => onLightingSelected(i),
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
