import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/models/badge_models.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/services/custom_badge_service.dart';
import '../../../gamification/services/golden_day_service.dart';
import '../../../../core/session/session_providers.dart';

class AddCustomQuranBadgeSheet extends ConsumerStatefulWidget {
  final VoidCallback? onBadgeCreated;
  final int? initialSurahId;
  final CustomQuranBadge? badgeToEdit;

  const AddCustomQuranBadgeSheet({
    super.key,
    this.onBadgeCreated,
    this.initialSurahId,
    this.badgeToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onBadgeCreated,
    int? initialSurahId,
    CustomQuranBadge? badgeToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCustomQuranBadgeSheet(
        onBadgeCreated: onBadgeCreated,
        initialSurahId: initialSurahId,
        badgeToEdit: badgeToEdit,
      ),
    );
  }

  @override
  ConsumerState<AddCustomQuranBadgeSheet> createState() => _AddCustomQuranBadgeSheetState();
}

class _AddCustomQuranBadgeSheetState extends ConsumerState<AddCustomQuranBadgeSheet> {
  final _titleController = TextEditingController();
  String _selectedScope = 'Sure Okuma';
  int _selectedSurahIndex = 55; // Default Vakıa (index 55 -> Surah 56)
  int _selectedJuzIndex = 28; // Default 29. Cüz (index 28 -> Juz 29)
  String _selectedPageOption = '5 Sayfa/Gün';
  int _selectedTargetDays = 40;
  int _selectedDailyTarget = 1;
  String _selectedEmoji = '📖';
  final String _selectedColorHex = '#FF5252';

  final List<String> _scopes = ['Sure Okuma', 'Cüz Okuma', 'Sayfa Okuma', 'Hatim Takibi'];
  final List<String> _pageOptions = ['1 Sayfa/Gün', '3 Sayfa/Gün', '5 Sayfa/Gün', '10 Sayfa/Gün', '20 Sayfa/Gün'];
  final List<int> _targetDaysPresets = [0, 7, 14, 21, 33, 40, 70, 99, 100, 313, 500, 1000, -1];
  final List<int> _dailyTargetPresets = [1, 2, 3, 5, 7, 10, 21, 33, 40, 0, -1];
  final List<String> _emojis = ['📖', '✨', '🕌', '🌟', '📜', '🕊️'];

  List<int> get _targetDaysOptions {
    if (_targetDaysPresets.contains(_selectedTargetDays)) {
      return _targetDaysPresets;
    }
    final list = List<int>.from(_targetDaysPresets);
    list.insert(list.length - 1, _selectedTargetDays);
    return list;
  }

  List<int> get _dailyTargetOptions {
    if (_dailyTargetPresets.contains(_selectedDailyTarget)) {
      return _dailyTargetPresets;
    }
    final list = List<int>.from(_dailyTargetPresets);
    list.insert(list.length - 1, _selectedDailyTarget);
    return list;
  }

  @override
  void initState() {
    super.initState();
    if (widget.badgeToEdit != null) {
      final b = widget.badgeToEdit!;
      _titleController.text = b.title;
      _selectedEmoji = b.iconEmoji;
      _selectedTargetDays = b.targetDays;
      _selectedDailyTarget = b.dailyTarget;
      _selectedScope = b.scope == 'Surah'
          ? 'Sure Okuma'
          : (b.scope == 'Juz'
              ? 'Cüz Okuma'
              : (b.scope == 'Page' ? 'Sayfa Okuma' : 'Hatim Takibi'));
      if (b.scope == 'Surah') {
        final sid = int.tryParse(b.scopeValue);
        if (sid != null) {
          final idx = SurahDataProvider.surahs.indexWhere((s) => s.id == sid);
          if (idx >= 0) _selectedSurahIndex = idx;
        }
      } else if (b.scope == 'Juz') {
        final jid = int.tryParse(b.scopeValue);
        if (jid != null && jid >= 1 && jid <= 30) {
          _selectedJuzIndex = jid - 1;
        }
      } else if (b.scope == 'Page') {
        _selectedPageOption = b.scopeValue;
      }
    } else if (widget.initialSurahId != null) {
      _selectedScope = 'Sure Okuma';
      final idx = SurahDataProvider.surahs.indexWhere((s) => s.id == widget.initialSurahId);
      if (idx >= 0) {
        _selectedSurahIndex = idx;
        final s = SurahDataProvider.surahs[idx];
        _titleController.text = '${s.name} Sûresi Rozeti';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _getTargetDayLabel(int days) {
    switch (days) {
      case 0:
        return 'Sonsuz (∞ - Sürekli Vird)';
      case 7:
        return '7 Okuma / Gün';
      case 14:
        return '14 Okuma / Gün';
      case 21:
        return '21 Okuma / Gün';
      case 33:
        return '33 Okuma (Tesbihat)';
      case 40:
        return '40 Okuma (Muhafız Sırrı)';
      case 70:
        return '70 Okuma (İstiğfar Eşiği)';
      case 99:
        return '99 Okuma (Esma Mertebesi)';
      case 100:
        return '100 Okuma (Dost Menzili)';
      case 313:
        return '313 Okuma (Bedir Ashabı)';
      case 500:
        return '500 Okuma';
      case 1000:
        return '1000 Okuma (Büyük Vird)';
      case -1:
        return '✏️ Özel Hedef Sayısı Gir...';
      default:
        return '$days Okuma Hedefi';
    }
  }

  String _getDailyTargetLabel(int count) {
    switch (count) {
      case 0:
        return 'Serbest (Hedefsiz Okuma)';
      case 1:
        return 'Günde 1 Kez (Standart)';
      case 2:
        return 'Günde 2 Kez';
      case 3:
        return 'Günde 3 Kez (Sünnet)';
      case 5:
        return 'Günde 5 Kez (Vakit Başı)';
      case 7:
        return 'Günde 7 Kez';
      case 10:
        return 'Günde 10 Kez';
      case 21:
        return 'Günde 21 Kez';
      case 33:
        return 'Günde 33 Kez';
      case 40:
        return 'Günde 40 Kez';
      case -1:
        return '✏️ Özel Günlük Sayı Gir...';
      default:
        return 'Günde $count Kez';
    }
  }

  Future<void> _showCustomNumberDialog({
    required String title,
    required String hintText,
    required int initialValue,
    required ValueChanged<int> onConfirm,
  }) async {
    final controller = TextEditingController(text: initialValue > 0 ? initialValue.toString() : '');
    final colors = context.colors;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.primaryText),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(fontSize: 16, color: colors.primaryText),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: colors.secondaryTextAlt),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('İptal', style: TextStyle(color: colors.secondaryTextAlt)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result != null) {
      onConfirm(result);
    }
  }

  Future<void> _saveBadge() async {
    String title = _titleController.text.trim();
    if (title.isEmpty) {
      title = widget.badgeToEdit?.title ?? 'Özel Kur\'an Rozetim';
    }

    String scope = 'Surah';
    String scopeValue = '56';
    String scopeDisplayName = 'Vakıa Sûresi';

    if (_selectedScope == 'Sure Okuma') {
      scope = 'Surah';
      if (_selectedSurahIndex < 0 || _selectedSurahIndex >= SurahDataProvider.surahs.length) {
        scopeValue = 'All';
        scopeDisplayName = 'Tüm Sureler';
      } else {
        final surah = SurahDataProvider.surahs[_selectedSurahIndex];
        scopeValue = surah.id.toString();
        scopeDisplayName = '${surah.id}. ${surah.name}';
      }
    } else if (_selectedScope == 'Cüz Okuma') {
      scope = 'Juz';
      final juzNum = _selectedJuzIndex + 1;
      scopeValue = juzNum.toString();
      scopeDisplayName = '$juzNum. Cüz';
    } else if (_selectedScope == 'Sayfa Okuma') {
      scope = 'Page';
      scopeValue = _selectedPageOption;
      scopeDisplayName = _selectedPageOption;
    } else {
      scope = 'Hatim';
      scopeValue = 'Hatim';
      scopeDisplayName = 'Hatim Okuma';
    }

    final activeSession = ref.read(activeSessionProvider);

    if (widget.badgeToEdit != null) {
      final existing = widget.badgeToEdit!;
      existing.title = title;
      existing.targetDays = _selectedTargetDays;
      existing.dailyTarget = _selectedDailyTarget;
      if (existing.targetDays <= 0) {
        existing.isUnlocked = true;
      }
      await CustomBadgeService.saveCustomBadge(existing, activeSession.id);
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
      widget.onBadgeCreated?.call();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ "$title" rozeti güncellendi!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
      return;
    }

    final isFromImmediateReading = widget.initialSurahId != null;

    final newBadge = CustomQuranBadge(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      scope: scope,
      scopeValue: scopeValue,
      scopeDisplayName: scopeDisplayName,
      targetDays: _selectedTargetDays,
      dailyTarget: _selectedDailyTarget,
      todayReadCount: isFromImmediateReading ? 1 : 0,
      todayDate: GoldenDayService.getTodayStr(),
      totalReadCount: isFromImmediateReading ? 1 : 0,
      currentStreak: isFromImmediateReading ? 1 : 0,
      bestStreak: isFromImmediateReading ? 1 : 0,
      lastReadDate: isFromImmediateReading ? GoldenDayService.getTodayStr() : '',
      iconEmoji: _selectedEmoji,
      glowColorHex: _selectedColorHex,
      isUnlocked: _selectedTargetDays <= 0,
    );

    await CustomBadgeService.saveCustomBadge(newBadge, activeSession.id);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
    widget.onBadgeCreated?.call();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ "$title" rozeti başarıyla oluşturuldu!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      widget.badgeToEdit != null ? 'Rozet Hedefini Düzenle' : 'Özel Kur\'an Rozeti Oluştur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.cardBackgroundAlt,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.close, size: 16, color: colors.secondaryTextAlt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Rozet Adı
            Text(
              'Rozet Adı',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _titleController,
                style: TextStyle(fontSize: 13.5, color: colors.primaryText),
                decoration: InputDecoration(
                  hintText: 'Örn: 29. Cüz Takibim / Yatsı Vakıa',
                  hintStyle: TextStyle(fontSize: 12.5, color: colors.secondaryTextAlt.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Okuma Türü (Kapsam)
            Text(
              'Okuma Türü',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedScope,
                  isExpanded: true,
                  dropdownColor: colors.cardBackground,
                  style: TextStyle(fontSize: 13.5, color: colors.primaryText),
                  items: _scopes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedScope = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Detay Seçimi (Sure / Cüz / Sayfa)
            if (_selectedScope == 'Sure Okuma') ...[
              Text(
                'Sure Seçimi',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: colors.cardBackgroundAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderStroke),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedSurahIndex,
                    isExpanded: true,
                    dropdownColor: colors.cardBackground,
                    style: TextStyle(fontSize: 13.5, color: colors.primaryText),
                    items: List.generate(
                      SurahDataProvider.surahs.length,
                      (idx) {
                        final s = SurahDataProvider.surahs[idx];
                        return DropdownMenuItem(
                          value: idx,
                          child: Text('${s.id}. ${s.name} (${s.ayetSayisi} Ayet)'),
                        );
                      },
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSurahIndex = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else if (_selectedScope == 'Cüz Okuma') ...[
              Text(
                'Cüz Seçimi',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: colors.cardBackgroundAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderStroke),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedJuzIndex,
                    isExpanded: true,
                    dropdownColor: colors.cardBackground,
                    style: TextStyle(fontSize: 13.5, color: colors.primaryText),
                    items: List.generate(
                      30,
                      (idx) => DropdownMenuItem(
                        value: idx,
                        child: Text('${idx + 1}. Cüz'),
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedJuzIndex = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else if (_selectedScope == 'Sayfa Okuma') ...[
              Text(
                'Günlük Sayfa Hedefi',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: colors.cardBackgroundAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderStroke),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPageOption,
                    isExpanded: true,
                    dropdownColor: colors.cardBackground,
                    style: TextStyle(fontSize: 13.5, color: colors.primaryText),
                    items: _pageOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPageOption = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. Hedef Okuma Sayısı (Toplam Hedef)
            Text(
              'Hedef Okuma Sayısı (Toplam Hedef)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedTargetDays,
                  isExpanded: true,
                  dropdownColor: colors.cardBackground,
                  style: TextStyle(fontSize: 13.5, color: colors.primaryText),
                  items: _targetDaysOptions
                      .map((d) => DropdownMenuItem(value: d, child: Text(_getTargetDayLabel(d))))
                      .toList(),
                  onChanged: (val) {
                    if (val == -1) {
                      _showCustomNumberDialog(
                        title: 'Özel Hedef Sayısı',
                        hintText: 'Örn: 50, 77, 500, 1000...',
                        initialValue: _selectedTargetDays > 0 ? _selectedTargetDays : 100,
                        onConfirm: (customVal) {
                          setState(() => _selectedTargetDays = customVal);
                        },
                      );
                    } else if (val != null) {
                      setState(() => _selectedTargetDays = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 5. Günlük Okuma Hedefi
            Text(
              'Günlük Okuma Hedefi (Günde Kaç Adet?)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedDailyTarget,
                  isExpanded: true,
                  dropdownColor: colors.cardBackground,
                  style: TextStyle(fontSize: 13.5, color: colors.primaryText),
                  items: _dailyTargetOptions
                      .map((d) => DropdownMenuItem(value: d, child: Text(_getDailyTargetLabel(d))))
                      .toList(),
                  onChanged: (val) {
                    if (val == -1) {
                      _showCustomNumberDialog(
                        title: 'Özel Günlük Okuma Hedefi',
                        hintText: 'Örn: 3, 5, 10, 50...',
                        initialValue: _selectedDailyTarget > 0 ? _selectedDailyTarget : 3,
                        onConfirm: (customVal) {
                          setState(() => _selectedDailyTarget = customVal);
                        },
                      );
                    } else if (val != null) {
                      setState(() => _selectedDailyTarget = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 6. Rozet Simgesi
            Text(
              'Rozet Simgesi',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _emojis.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF5252).withValues(alpha: 0.15) : colors.cardBackgroundAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFF5252) : colors.borderStroke,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5252),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: _saveBadge,
                child: Text(
                  widget.badgeToEdit != null ? 'Değişiklikleri Kaydet ✨' : 'Rozeti Oluştur ✨',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
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
