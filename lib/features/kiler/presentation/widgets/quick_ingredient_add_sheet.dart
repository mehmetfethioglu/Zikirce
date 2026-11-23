import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/kiler_models.dart';
import '../../domain/kiler_service.dart';

enum _FreshnessPreset {
  standard('Standart', '✨', null),
  freshShort('Taze 2-3g', '🌿', 3),
  homemadeLong('Ev Yapımı 6 Ay', '🏺', 180);

  final String label;
  final String emoji;
  final int? overrideShelfDays;

  const _FreshnessPreset(this.label, this.emoji, this.overrideShelfDays);
}

/// Multi-channel unbarcoded pantry intake sheet supporting natural-language
/// batch parsing, freshness presets, and one-tap starter home packs.
class QuickIngredientAddSheet extends StatefulWidget {
  final UnbarcodedSourceChannel? initialChannel;
  final Future<int> Function(List<DraftPantryAddition> drafts)? onBatchAdd;

  const QuickIngredientAddSheet({
    super.key,
    this.initialChannel,
    this.onBatchAdd,
  });

  static Future<void> show(
    BuildContext context, {
    UnbarcodedSourceChannel? initialChannel,
    Future<int> Function(List<DraftPantryAddition> drafts)? onBatchAdd,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickIngredientAddSheet(
        initialChannel: initialChannel,
        onBatchAdd: onBatchAdd,
      ),
    );
  }

  @override
  State<QuickIngredientAddSheet> createState() =>
      _QuickIngredientAddSheetState();
}

class _QuickIngredientAddSheetState extends State<QuickIngredientAddSheet> {
  late UnbarcodedSourceChannel _selectedChannel;
  StorageZone? _overrideZone;
  _FreshnessPreset _freshnessPreset = _FreshnessPreset.standard;
  final TextEditingController _inputController = TextEditingController();
  final List<DraftPantryAddition> _draftCart = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedChannel =
        widget.initialChannel ?? UnbarcodedSourceChannel.manavPazar;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  DraftPantryAddition _applyFreshnessAndZone(DraftPantryAddition draft) {
    final effectiveZone = _overrideZone ??
        (_freshnessPreset == _FreshnessPreset.homemadeLong &&
                draft.storageZone != StorageZone.freezer
            ? StorageZone.pantry
            : draft.storageZone);

    final effectiveDays = effectiveZone == StorageZone.freezer
        ? 90
        : (_freshnessPreset.overrideShelfDays ?? draft.shelfDays);

    return draft.copyWith(
      storageZone: effectiveZone,
      shelfDays: effectiveDays,
    );
  }

  DraftPantryAddition _createDraftFromTemplate(QuickIngredientTemplate tpl) {
    final effectiveZone = _overrideZone ??
        (_freshnessPreset == _FreshnessPreset.homemadeLong &&
                tpl.defaultZone != StorageZone.freezer
            ? StorageZone.pantry
            : tpl.defaultZone);

    final effectiveDays = effectiveZone == StorageZone.freezer
        ? 90
        : (_freshnessPreset.overrideShelfDays ?? tpl.defaultShelfDays);

    return DraftPantryAddition.fromTemplate(
      tpl,
      overrideZone: effectiveZone,
      overrideShelfDays: effectiveDays,
      sourceChannel: _selectedChannel,
    );
  }

  void _upsertDraftIntoCart(DraftPantryAddition incoming) {
    final incomingLower = incoming.name.toLowerCase();
    final idx = _draftCart.indexWhere(
      (d) => d.tag == incoming.tag && d.name.toLowerCase() == incomingLower,
    );
    if (idx >= 0) {
      _draftCart[idx] = incoming;
    } else {
      _draftCart.add(incoming);
    }
  }

  void _handleNaturalInputSubmit() {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) return;

    final parsed = NaturalPantryInputParser.parseBatch(
      raw,
      fallbackChannel: _selectedChannel,
      overrideZone: _overrideZone,
    );

    if (parsed.isEmpty) return;

    setState(() {
      for (final item in parsed) {
        _upsertDraftIntoCart(_applyFreshnessAndZone(item));
      }
      _inputController.clear();
    });
  }

  void _toggleTemplateSelection(QuickIngredientTemplate tpl) {
    setState(() {
      final existingIndex = _draftCart.indexWhere((d) => d.tag == tpl.tag);
      if (existingIndex >= 0) {
        _draftCart.removeAt(existingIndex);
      } else {
        _draftCart.add(_createDraftFromTemplate(tpl));
      }
    });
  }

  void _selectMissingStarterHomeItems(Set<String> existingTags) {
    final missingTemplates = MarketSourceRegistry.starterHomeTemplates()
        .where((tpl) => !existingTags.contains(tpl.tag))
        .toList();

    if (missingTemplates.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tüm temel ev malzemeleri zaten dolabınızda!'),
          backgroundColor: AppColors.primaryEmerald,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      for (final tpl in missingTemplates) {
        final alreadyInCart = _draftCart.any((d) => d.tag == tpl.tag);
        if (!alreadyInCart) {
          _draftCart.add(_createDraftFromTemplate(tpl));
        }
      }
    });
  }

  void _removeDraftAt(int index) {
    setState(() {
      _draftCart.removeAt(index);
    });
  }

  void _clearCart() {
    setState(() {
      _draftCart.clear();
    });
  }

  Future<void> _saveCartToPantry() async {
    if (_draftCart.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    final drafts = List<DraftPantryAddition>.from(_draftCart);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);

    try {
      int savedCount;
      if (widget.onBatchAdd != null) {
        savedCount = await widget.onBatchAdd!(drafts);
      } else {
        for (final draft in drafts) {
          await KilerService.instance.upsertPantryItem(draft.toPantryItem());
        }
        savedCount = drafts.length;
      }

      if (!mounted) return;
      navigator.pop();
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${savedCount > 0 ? savedCount : drafts.length} ürün kilere kaydedildi!',
          ),
          backgroundColor: AppColors.primaryEmerald,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Ürünler kaydedilemedi: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;
    final channelTemplates =
        MarketSourceRegistry.templatesForChannel(_selectedChannel);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: ValueListenableBuilder<KilerState>(
        valueListenable: KilerService.instance,
        builder: (context, kilerState, _) {
          final existingTags = kilerState.availableTags;
          final liveParsedPreview = _inputController.text.trim().isEmpty
              ? const <DraftPantryAddition>[]
              : NaturalPantryInputParser.parseBatch(
                  _inputController.text,
                  fallbackChannel: _selectedChannel,
                  overrideZone: _overrideZone,
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _SheetTitleBar(
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 10),
              _SmartNaturalInputRow(
                controller: _inputController,
                onChanged: (_) => setState(() {}),
                onSubmit: _handleNaturalInputSubmit,
              ),
              if (liveParsedPreview.isNotEmpty) ...[
                const SizedBox(height: 6),
                _LiveParseHintLine(previewItems: liveParsedPreview),
              ],
              const SizedBox(height: 10),
              _ChannelTabStrip(
                selectedChannel: _selectedChannel,
                onSelect: (channel) =>
                    setState(() => _selectedChannel = channel),
              ),
              const SizedBox(height: 6),
              Text(
                '${_selectedChannel.emoji} ${_selectedChannel.subtitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _FreshnessAndZoneControls(
                selectedFreshness: _freshnessPreset,
                overrideZone: _overrideZone,
                onFreshnessChanged: (preset) =>
                    setState(() => _freshnessPreset = preset),
                onZoneChanged: (zone) => setState(() => _overrideZone = zone),
              ),
              if (_selectedChannel == UnbarcodedSourceChannel.temelEvPaketi) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _selectMissingStarterHomeItems(existingTags),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryEmerald,
                      side: BorderSide(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                    label: const Text(
                      'Evdeki Eksik Temel Malzemeleri Toplu Seç',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
              if (_draftCart.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DraftCartPreviewStrip(
                  drafts: _draftCart,
                  onRemoveAt: _removeDraftAt,
                  onClearAll: _clearCart,
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: channelTemplates.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.45,
                  ),
                  itemBuilder: (context, index) {
                    final tpl = channelTemplates[index];
                    final isAlreadyInPantry = existingTags.contains(tpl.tag);
                    final isSelectedInCart =
                        _draftCart.any((d) => d.tag == tpl.tag);
                    final targetZone = _overrideZone ??
                        (_freshnessPreset == _FreshnessPreset.homemadeLong &&
                                tpl.defaultZone != StorageZone.freezer
                            ? StorageZone.pantry
                            : tpl.defaultZone);
                    final targetDays = targetZone == StorageZone.freezer
                        ? 90
                        : (_freshnessPreset.overrideShelfDays ??
                            tpl.defaultShelfDays);

                    return _TemplateSelectTile(
                      template: tpl,
                      targetZone: targetZone,
                      targetDays: targetDays,
                      isAlreadyInPantry: isAlreadyInPantry,
                      isSelected: isSelectedInCart,
                      onTap: () => _toggleTemplateSelection(tpl),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (_draftCart.isEmpty || _isSaving) ? null : _saveCartToPantry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        textPrimary.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _draftCart.isEmpty
                        ? 'Ürün Seçin veya Yukarı Yazın'
                        : 'Seçili ${_draftCart.length} Ürünü Kilere Kaydet',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetTitleBar extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetTitleBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primaryEmerald.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: AppColors.primaryEmerald,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pazar, Kasap & Kiler Girişi',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Barkodsuz taze ürünleri toplu yazın veya dokunup seçin',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, color: context.textSecondaryColor),
        ),
      ],
    );
  }
}

class _SmartNaturalInputRow extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  const _SmartNaturalInputRow({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            textInputAction: TextInputAction.done,
            style: TextStyle(color: context.textPrimaryColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Örn: yarım kilo kıyma, 2 kg domates, ev salçası...',
              hintStyle: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.auto_fix_high_rounded,
                color: AppColors.primaryEmerald,
                size: 19,
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cardBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cardBorderColor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryEmerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Ekle',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _LiveParseHintLine extends StatelessWidget {
  final List<DraftPantryAddition> previewItems;

  const _LiveParseHintLine({required this.previewItems});

  @override
  Widget build(BuildContext context) {
    final summary = previewItems
        .map((d) => '${d.emoji} ${d.name} (${d.unitLabel})')
        .join(', ');
    return Text(
      '✨ Algılanan (${previewItems.length}): $summary',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.primaryEmerald,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChannelTabStrip extends StatelessWidget {
  final UnbarcodedSourceChannel selectedChannel;
  final ValueChanged<UnbarcodedSourceChannel> onSelect;

  const _ChannelTabStrip({
    required this.selectedChannel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: UnbarcodedSourceChannel.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final channel = UnbarcodedSourceChannel.values[index];
          final isSelected = channel == selectedChannel;
          return InkWell(
            onTap: () => onSelect(channel),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryEmerald
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryEmerald
                      : context.cardBorderColor,
                ),
              ),
              child: Text(
                '${channel.emoji} ${channel.label}',
                style: TextStyle(
                  color: isSelected ? Colors.white : context.textPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FreshnessAndZoneControls extends StatelessWidget {
  final _FreshnessPreset selectedFreshness;
  final StorageZone? overrideZone;
  final ValueChanged<_FreshnessPreset> onFreshnessChanged;
  final ValueChanged<StorageZone?> onZoneChanged;

  const _FreshnessAndZoneControls({
    required this.selectedFreshness,
    required this.overrideZone,
    required this.onFreshnessChanged,
    required this.onZoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Tazelik:',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              ..._FreshnessPreset.values.map(
                (preset) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _OptionPillChip(
                    label: '${preset.emoji} ${preset.label}',
                    selected: selectedFreshness == preset,
                    accentColor: AppColors.cautionGold,
                    onTap: () => onFreshnessChanged(preset),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Konum:',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              _OptionPillChip(
                label: '✨ Otomatik',
                selected: overrideZone == null,
                accentColor: AppColors.primaryEmerald,
                onTap: () => onZoneChanged(null),
              ),
              ...StorageZone.values.map(
                (z) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _OptionPillChip(
                    label: '${z.emoji} ${z.label}',
                    selected: overrideZone == z,
                    accentColor: AppColors.primaryEmerald,
                    onTap: () => onZoneChanged(z),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionPillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _OptionPillChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accentColor : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accentColor : context.textSecondaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DraftCartPreviewStrip extends StatelessWidget {
  final List<DraftPantryAddition> drafts;
  final ValueChanged<int> onRemoveAt;
  final VoidCallback onClearAll;

  const _DraftCartPreviewStrip({
    required this.drafts,
    required this.onRemoveAt,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.primaryEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryEmerald.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🧺 Sepet Önizleme (${drafts.length} ürün)',
                style: const TextStyle(
                  color: AppColors.primaryEmerald,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onClearAll,
                child: Text(
                  'Temizle',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: drafts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final draft = drafts[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${draft.emoji} ${draft.name} • ${draft.unitLabel}',
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => onRemoveAt(index),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateSelectTile extends StatelessWidget {
  final QuickIngredientTemplate template;
  final StorageZone targetZone;
  final int targetDays;
  final bool isAlreadyInPantry;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateSelectTile({
    required this.template,
    required this.targetZone,
    required this.targetDays,
    required this.isAlreadyInPantry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.primaryEmerald.withValues(alpha: 0.16)
        : isAlreadyInPantry
            ? AppColors.primaryEmerald.withValues(alpha: 0.06)
            : Theme.of(context).scaffoldBackgroundColor;

    final borderColor = isSelected
        ? AppColors.primaryEmerald
        : isAlreadyInPantry
            ? AppColors.primaryEmerald.withValues(alpha: 0.45)
            : context.cardBorderColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(template.emoji, style: const TextStyle(fontSize: 21)),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSelected
                        ? '✓ Seçildi • ${targetZone.emoji} ${targetDays}g'
                        : isAlreadyInPantry
                            ? 'Dolapta Var • ${template.defaultUnit}'
                            : '${targetZone.emoji} ${targetDays}g • ${template.defaultUnit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected || isAlreadyInPantry
                          ? AppColors.primaryEmerald
                          : context.textSecondaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: AppColors.primaryEmerald,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
