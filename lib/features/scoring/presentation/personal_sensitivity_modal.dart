import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../domain/organic_score_calculator.dart';

class PersonalSensitivityModal extends StatefulWidget {
  final FamilyProfile profile;
  final VoidCallback? onSaved;

  const PersonalSensitivityModal({
    super.key,
    required this.profile,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {required FamilyProfile profile, VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonalSensitivityModal(
        profile: profile,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<PersonalSensitivityModal> createState() => _PersonalSensitivityModalState();
}

class _PersonalSensitivityModalState extends State<PersonalSensitivityModal> {
  late PersonalSensitivityConfig _config;
  late Set<String> _restrictions;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _config = widget.profile.sensitivity;
    _restrictions = Set<String>.from(widget.profile.restrictions);
  }

  void _applyPreset(String presetId) {
    setState(() {
      switch (presetId) {
        case 'diabetes':
          _config = PersonalSensitivityConfig.diabetes;
          _restrictions.add('HIGH_SUGAR');
          break;
        case 'clean_eating':
          _config = PersonalSensitivityConfig.cleanEating;
          _restrictions.addAll(['SYNTHETIC_COLORS', 'PALM_OIL']);
          break;
        case 'heart_health':
          _config = PersonalSensitivityConfig.heartHealth;
          _restrictions.addAll(['HIGH_SODIUM', 'PALM_OIL']);
          break;
        case 'child_safe':
          _config = PersonalSensitivityConfig.childSafe;
          _restrictions.addAll(['SYNTHETIC_COLORS', 'HIGH_SUGAR', 'PALM_OIL']);
          break;
        case 'custom':
        default:
          _config = _config.copyWith(presetId: 'custom');
          break;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await FamilyProfileEngine.updateProfile(
      profileId: widget.profile.id,
      profileName: widget.profile.profileName,
      restrictions: _restrictions.toList(),
      sensitivity: _config,
    );
    if (mounted) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.profile.profileName} için sağlık hassasiyetleri ve kısıtlamalar kaydedildi.'),
          backgroundColor: AppColors.primaryEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.borderColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppColors.primaryEmerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Puanlama & Sağlık Hassasiyetleri',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Profil: ${widget.profile.profileName}',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // Scrollable Settings Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMint.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryMint.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_outlined, color: AppColors.primaryMint, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bu ayarlar ürünlerin ana bilimsel OrganicScore (0-100) puanını bozmaz. Sizin için "% Uyum Skoru"nu kişiselleştirir.',
                          style: TextStyle(color: textPrimary, fontSize: 12, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Presets Header
                Text(
                  'Hızlı Sağlık Presetleri',
                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetButton(
                        id: 'diabetes',
                        label: 'Diyabet / Az Şeker',
                        icon: Icons.bloodtype_outlined,
                        color: Colors.blueAccent,
                      ),
                      _buildPresetButton(
                        id: 'clean_eating',
                        label: 'Temiz & Katkısız',
                        icon: Icons.eco_outlined,
                        color: AppColors.primaryEmerald,
                      ),
                      _buildPresetButton(
                        id: 'child_safe',
                        label: 'Çocuk Güvenli',
                        icon: Icons.child_care_rounded,
                        color: Colors.amber.shade700,
                      ),
                      _buildPresetButton(
                        id: 'heart_health',
                        label: 'Kalp & Tansiyon',
                        icon: Icons.favorite_outline_rounded,
                        color: Colors.redAccent,
                      ),
                      _buildPresetButton(
                        id: 'custom',
                        label: 'Özel',
                        icon: Icons.tune,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Allergen & Diet Restrictions Section (Gluten, Halal, Colorants, Glucose, Palm, etc.)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Alerji, Diyet & Özel Kısıtlamalar',
                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _restrictions.isNotEmpty
                            ? AppColors.primaryEmerald.withValues(alpha: 0.15)
                            : borderColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_restrictions.length} Aktif Kural',
                        style: TextStyle(
                          color: _restrictions.isNotEmpty ? AppColors.primaryEmerald : textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bu maddeler ürün içeriğinde tespit edildiğinde anında kırmızı çizgi uyarısı verilir ve uyum skoru düşürülür.',
                  style: TextStyle(color: textSecondary, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 12),

                // All 8 Core Restrictions
                ...FamilyProfileEngine.restrictionMeta.entries.map((entry) {
                  final key = entry.key;
                  final meta = entry.value;
                  final isSelected = _restrictions.contains(key);
                  final icon = FamilyProfileEngine.getRestrictionIcon(key);

                  return _buildRestrictionSwitchTile(
                    key: key,
                    title: meta.label,
                    subtitle: meta.description,
                    icon: icon,
                    isSelected: isSelected,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                  );
                }),
                const SizedBox(height: 20),

                // 3. Granular Controls
                Text(
                  'Detaylı Puanlama Toleransları',
                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                // Sugar Strictness
                _buildSegmentControl(
                  title: 'Şeker ve Glikoz Toleransı',
                  subtitle: _getSugarDescription(_config.sugarStrictness),
                  icon: Icons.cookie_outlined,
                  value: _config.sugarStrictness,
                  options: const {
                    'normal': 'Standart',
                    'moderate': 'Orta (<10g)',
                    'strict': 'Katı / Diyabet (<5g)',
                  },
                  onChanged: (val) {
                    setState(() {
                      _config = _config.copyWith(sugarStrictness: val, presetId: 'custom');
                    });
                  },
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 14),

                // Additive Strictness
                _buildSegmentControl(
                  title: 'Katkı Maddesi (E-Kodu) Katılığı',
                  subtitle: _getAdditiveDescription(_config.additiveStrictness),
                  icon: Icons.science_outlined,
                  value: _config.additiveStrictness,
                  options: const {
                    'normal': 'Standart',
                    'strict': 'Katı Filtre',
                    'zero_tolerance': 'Sıfır Katkı',
                  },
                  onChanged: (val) {
                    setState(() {
                      _config = _config.copyWith(additiveStrictness: val, presetId: 'custom');
                    });
                  },
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 14),

                // Sodium Strictness
                _buildSegmentControl(
                  title: 'Tuz & Sodyum Toleransı',
                  subtitle: _config.sodiumStrictness == 'strict'
                      ? 'Hipertansiyon koruması: 0.3g üzeri sodyum için yüksek ceza.'
                      : 'Standart WHO tuz toleransı (0.6g üzeri ceza).',
                  icon: Icons.grain_rounded,
                  value: _config.sodiumStrictness,
                  options: const {
                    'normal': 'Standart',
                    'strict': 'Düşük Sodyum',
                  },
                  onChanged: (val) {
                    setState(() {
                      _config = _config.copyWith(sodiumStrictness: val, presetId: 'custom');
                    });
                  },
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 16),

                // Palm Oil Switch Tile
                _buildSwitchTile(
                  title: 'Palmiye (Palm) Yağı İstemiyorum',
                  subtitle: 'Formülünde palm yağı bulunan ürünlerin uyum skoru %25 düşürülür.',
                  icon: Icons.spa_outlined,
                  value: _config.avoidPalmOil,
                  onChanged: (val) {
                    setState(() {
                      _config = _config.copyWith(avoidPalmOil: val, presetId: 'custom');
                    });
                  },
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 12),

                // NOVA 4 Ultra Processed Switch Tile
                _buildSwitchTile(
                  title: 'Ultra-İşlenmiş (NOVA 4) Gıdalardan Kaçın',
                  subtitle: 'Endüstriyel lezzet artırıcı ve koyulaştırıcı içeren ürünlerde %25 ceza.',
                  icon: Icons.factory_outlined,
                  value: _config.avoidNova4,
                  onChanged: (val) {
                    setState(() {
                      _config = _config.copyWith(avoidNova4: val, presetId: 'custom');
                    });
                  },
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  _isSaving ? 'Kaydediliyor...' : 'Tercihleri Kaydet & Uygula',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _config.presetId == id;
    return GestureDetector(
      onTap: () => _applyPreset(id),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : context.textSecondaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : context.textPrimaryColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentControl({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
    required Color textPrimary,
    required Color textSecondary,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryEmerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          Row(
            children: options.entries.map((e) {
              final isSelected = value == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryEmerald : borderColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : textPrimary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionSwitchTile({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color textPrimary,
    required Color textSecondary,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _restrictions.remove(key);
            if (key == 'PALM_OIL') _config = _config.copyWith(avoidPalmOil: false);
          } else {
            _restrictions.add(key);
            if (key == 'PALM_OIL') _config = _config.copyWith(avoidPalmOil: true);
            if (key == 'HIGH_SUGAR') _config = _config.copyWith(sugarStrictness: 'strict');
            if (key == 'HIGH_SODIUM') _config = _config.copyWith(sodiumStrictness: 'strict');
            if (key == 'SYNTHETIC_COLORS') _config = _config.copyWith(additiveStrictness: 'strict');
          }
          _config = _config.copyWith(presetId: 'custom');
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryEmerald.withValues(alpha: 0.08) : surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryEmerald : borderColor,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryEmerald.withValues(alpha: 0.16)
                    : borderColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primaryEmerald : textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 11, height: 1.25),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isSelected,
              activeThumbColor: AppColors.primaryEmerald,
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _restrictions.add(key);
                    if (key == 'PALM_OIL') _config = _config.copyWith(avoidPalmOil: true);
                    if (key == 'HIGH_SUGAR') _config = _config.copyWith(sugarStrictness: 'strict');
                    if (key == 'HIGH_SODIUM') _config = _config.copyWith(sodiumStrictness: 'strict');
                    if (key == 'SYNTHETIC_COLORS') _config = _config.copyWith(additiveStrictness: 'strict');
                  } else {
                    _restrictions.remove(key);
                    if (key == 'PALM_OIL') _config = _config.copyWith(avoidPalmOil: false);
                  }
                  _config = _config.copyWith(presetId: 'custom');
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? AppColors.primaryEmerald : textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryEmerald,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _getSugarDescription(String level) {
    switch (level) {
      case 'strict':
        return 'Diyabet & Düşük Şeker Modu: 5g üzeri şeker veya glikoz şurubunda ağır ceza.';
      case 'moderate':
        return 'Orta Hassasiyet: 10g üzeri şeker ve yapay tatlandırıcılarda kesinti.';
      case 'normal':
      default:
        return 'Standart WHO Kriteri: 15g üzeri ilave şekerde kesinti.';
    }
  }

  String _getAdditiveDescription(String level) {
    switch (level) {
      case 'zero_tolerance':
        return 'Sıfır Katkı: Tüm sentetik E-kodları ve koruyucularda uyum skoru düşer.';
      case 'strict':
        return 'Katkı Filtresi: Toksik ve orta riskli tüm katkılar cezalandırılır.';
      case 'normal':
      default:
        return 'Standart: Yalnızca toksik ve yüksek riskli E-kodları cezalandırılır.';
    }
  }
}
