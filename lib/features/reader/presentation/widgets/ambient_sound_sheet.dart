import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/ambient_audio_service.dart';

class AmbientSoundSheet extends StatefulWidget {
  final AmbientAudioService ambientService;

  const AmbientSoundSheet({super.key, required this.ambientService});

  static void show(BuildContext context, AmbientAudioService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => AmbientSoundSheet(ambientService: service),
    );
  }

  @override
  State<AmbientSoundSheet> createState() => _AmbientSoundSheetState();
}

class _AmbientSoundSheetState extends State<AmbientSoundSheet> {
  late AmbientSoundType _selectedPrimary;
  late AmbientSoundType _selectedSecondary;
  late double _primaryVolume;
  late double _secondaryVolume;
  String _selectedCategory = 'Tümü';

  static const List<String> _categories = [
    'Tümü',
    'Doğa',
    'Klasik & Mekân',
    'Odak & Sıcaklık',
  ];

  static const List<(String, AmbientSoundType, AmbientSoundType)> _presetMixes = [
    (
      '🕯️ Medrese Gecesi (Yağmur + Ney)',
      AmbientSoundType.rain,
      AmbientSoundType.ney,
    ),
    (
      '🏛️ Kış Kütüphanesi (Şömine + Beyazıt)',
      AmbientSoundType.fireplace,
      AmbientSoundType.library,
    ),
    (
      '🌙 Şadırvan & Tefekkür (Şadırvan + Odak)',
      AmbientSoundType.nightGarden,
      AmbientSoundType.binauralFocus,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPrimary = widget.ambientService.currentType;
    _selectedSecondary = widget.ambientService.secondaryType;
    _primaryVolume = widget.ambientService.volume;
    _secondaryVolume = widget.ambientService.secondaryVolume;
  }

  List<AmbientSoundType> get _filteredSounds {
    final all = AmbientSoundType.values
        .where((t) => t != AmbientSoundType.none)
        .toList();
    if (_selectedCategory == 'Tümü') return all;
    return all.where((t) => t.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎧 Stüdyo Ambiyans & Çift Katman Mikseri',
                          style: GoogleFonts.literata(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '44.1 kHz Kesintisiz Sonsuz Döngü (Zero-Seam Circular DSP)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedPrimary != AmbientSoundType.none ||
                      _selectedSecondary != AmbientSoundType.none)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.stop_circle_outlined, size: 16),
                      label: const Text('Durdur'),
                      onPressed: () {
                        setState(() {
                          _selectedPrimary = AmbientSoundType.none;
                          _selectedSecondary = AmbientSoundType.none;
                        });
                        widget.ambientService.stop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Hazır Mütalaa Karışımları (1-Tap Dual Mix Presets)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _presetMixes.map((mix) {
                    final (label, pType, sType) = mix;
                    final isMixActive = _selectedPrimary == pType &&
                        _selectedSecondary == sType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: isMixActive
                            ? AppColors.amberGold.withValues(alpha: 0.22)
                            : theme.colorScheme.surface,
                        side: BorderSide(
                          color: isMixActive
                              ? AppColors.amberGold
                              : theme.colorScheme.outline.withValues(alpha: 0.6),
                        ),
                        label: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight:
                                isMixActive ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedPrimary = pType;
                            _selectedSecondary = sType;
                          });
                          widget.ambientService.playSound(pType);
                          widget.ambientService.playSecondarySound(sType);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Kategori Sekmeleri
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(cat, style: const TextStyle(fontSize: 11.5)),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // 10 Stüdyo Ses Kartı Listesi
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _filteredSounds.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final type = _filteredSounds[idx];
                    final isPrimary = _selectedPrimary == type;
                    final isSecondary = _selectedSecondary == type;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (isPrimary || isSecondary)
                            ? theme.colorScheme.primary.withValues(alpha: 0.10)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPrimary
                              ? AppColors.amberGold
                              : isSecondary
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline
                                      .withValues(alpha: 0.45),
                          width: (isPrimary || isSecondary) ? 1.6 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(type.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.title,
                                  style: GoogleFonts.literata(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  type.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Ana Ses Seçimi
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (isPrimary) {
                                setState(
                                  () => _selectedPrimary = AmbientSoundType.none,
                                );
                                widget.ambientService.stop();
                              } else {
                                setState(() => _selectedPrimary = type);
                                widget.ambientService.playSound(type);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isPrimary
                                    ? AppColors.amberGold
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPrimary ? 'Ana Ses ✓' : 'Ana Ses',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isPrimary
                                      ? Colors.black87
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 2. Katman (Eşlikçi) Seçimi
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (isSecondary) {
                                setState(
                                  () =>
                                      _selectedSecondary = AmbientSoundType.none,
                                );
                                widget.ambientService
                                    .playSecondarySound(AmbientSoundType.none);
                              } else {
                                setState(() => _selectedSecondary = type);
                                if (_selectedPrimary == AmbientSoundType.none) {
                                  _selectedPrimary = AmbientSoundType.rain;
                                  widget.ambientService
                                      .playSound(AmbientSoundType.rain);
                                }
                                widget.ambientService.playSecondarySound(type);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isSecondary
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline
                                        .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSecondary ? '+Katman ✓' : '+Katman',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSecondary
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Ses Seviyesi Kontrolleri
              Row(
                children: [
                  const Icon(Icons.volume_down, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Ana Ses',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _primaryVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (val) {
                        setState(() => _primaryVolume = val);
                        widget.ambientService.setVolume(val);
                      },
                    ),
                  ),
                ],
              ),
              if (_selectedSecondary != AmbientSoundType.none)
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '2. Katman',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _secondaryVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (val) {
                          setState(() => _secondaryVolume = val);
                          widget.ambientService.setSecondaryVolume(val);
                        },
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
}
