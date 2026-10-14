import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/ambient_audio_service.dart';

class AmbientSoundSheet extends StatefulWidget {
  final AmbientAudioService ambientService;

  const AmbientSoundSheet({super.key, required this.ambientService});

  static void show(BuildContext context, AmbientAudioService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AmbientSoundSheet(ambientService: service),
    );
  }

  @override
  State<AmbientSoundSheet> createState() => _AmbientSoundSheetState();
}

class _AmbientSoundSheetState extends State<AmbientSoundSheet> {
  late AmbientSoundType _selected;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _selected = widget.ambientService.currentType;
    _volume = widget.ambientService.volume;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '🎧 Ambiyans & Odak Sesleri',
                  style: GoogleFonts.literata(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_selected != AmbientSoundType.none)
                  TextButton.icon(
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Durdur'),
                    onPressed: () {
                      setState(() => _selected = AmbientSoundType.none);
                      widget.ambientService.stop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TTS Konuşurken Otomatik Kısma (Audio Ducking) Aktif',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AmbientSoundType.values.map((type) {
                final isSelected = _selected == type;
                return ChoiceChip(
                  avatar: Text(type.icon, style: const TextStyle(fontSize: 16)),
                  label: Text(
                    type == AmbientSoundType.ney ? '${type.title} ✨' : type.title,
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selected = type);
                    widget.ambientService.playSound(type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.volume_down, size: 20),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: (val) {
                      setState(() => _volume = val);
                      widget.ambientService.setVolume(val);
                    },
                  ),
                ),
                const Icon(Icons.volume_up, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
