import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/family_profile_engine.dart';
import '../../scoring/presentation/personal_sensitivity_modal.dart';

class FamilyProfilesScreen extends StatefulWidget {
  const FamilyProfilesScreen({super.key});

  @override
  State<FamilyProfilesScreen> createState() => _FamilyProfilesScreenState();
}

class _FamilyProfilesScreenState extends State<FamilyProfilesScreen> {
  List<FamilyProfile> _profiles = [];
  bool _isLoading = true;

  String _getPresetName(String presetId) {
    switch (presetId) {
      case 'diabetes':
        return '🩺 Diyabet & Az Şeker';
      case 'clean_eating':
        return '🌿 Temiz & Katkısız';
      case 'heart_health':
        return '🫀 Kalp & Tansiyon';
      case 'child_safe':
        return '👶 Çocuk Güvenli';
      case 'custom':
      default:
        return '⚙️ Özel Hassasiyet';
    }
  }

  final Map<String, String> _restrictionLabels = {
    'SYNTHETIC_COLORS': 'Sentetik Renklendiriciler (Azo Boyaları)',
    'HIGH_SUGAR': 'Yüksek Şeker & Glikoz Şurubu',
    'PALM_OIL': 'Palmiye (Palm) Yağı',
    'GLUTEN': 'Gluten İçeren Tahıllar',
    'LACTOSE': 'Laktoz / Süt Ürünleri',
    'HALAL': 'Helal Hassasiyeti (Jelatin/E120)',
    'HIGH_SODIUM': 'Yüksek Sodyum / Tuz',
    'VEGAN': 'Vejetaryen / Vegan İhlali',
  };

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    final Database db = await DatabaseHelper().database;
    // Clean up duplicate profiles
    try {
      await db.rawDelete('DELETE FROM family_profiles WHERE id NOT IN (SELECT MIN(id) FROM family_profiles GROUP BY profile_name)');
    } catch (_) {}

    final List<Map<String, dynamic>> maps = await db.query('family_profiles');

    setState(() {
      _profiles = maps.map((m) => FamilyProfile.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  Future<void> _setActiveProfile(int id) async {
    final Database db = await DatabaseHelper().database;
    await db.update('family_profiles', {'is_active': 0});
    await db.update('family_profiles', {'is_active': 1}, where: 'id = ?', whereArgs: [id]);
    _loadProfiles();
  }

  Future<void> _deleteProfile(int id) async {
    final Database db = await DatabaseHelper().database;
    await db.delete('family_profiles', where: 'id = ?', whereArgs: [id]);
    _loadProfiles();
  }

  void _showAddProfileDialog() {
    final TextEditingController nameController = TextEditingController();
    final Set<String> selectedRestrictions = {'SYNTHETIC_COLORS', 'HIGH_SUGAR'};
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.borderColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
                      child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryEmerald, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yeni Aile Profili Ekle',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Aileniz için özel sağlık ve hassasiyet profili oluşturun',
                            style: TextStyle(color: textSecondary, fontSize: 11),
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Profil Adı', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ör: Küçük Ali, Eşim, Annem',
                        hintStyle: TextStyle(color: textSecondary),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryEmerald),
                        filled: true,
                        fillColor: borderColor.withValues(alpha: 0.15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 1.8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alerji & Diyet Kısıtlamaları (Kırmızı Çizgiler)',
                            style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: selectedRestrictions.isNotEmpty
                                ? AppColors.primaryEmerald.withValues(alpha: 0.15)
                                : borderColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${selectedRestrictions.length} Seçili',
                            style: TextStyle(
                              color: selectedRestrictions.isNotEmpty ? AppColors.primaryEmerald : textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu profile özel kısıtlamaları seçin. Taramalarda bu içerikler anında tespit edilir.',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    ...FamilyProfileEngine.restrictionMeta.entries.map((entry) {
                      final key = entry.key;
                      final meta = entry.value;
                      final isSelected = selectedRestrictions.contains(key);
                      final icon = FamilyProfileEngine.getRestrictionIcon(key);

                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              selectedRestrictions.remove(key);
                            } else {
                              selectedRestrictions.add(key);
                            }
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
                                  color: isSelected ? AppColors.primaryEmerald.withValues(alpha: 0.16) : borderColor.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, size: 20, color: isSelected ? AppColors.primaryEmerald : textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(meta.label, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(meta.description, style: TextStyle(color: textSecondary, fontSize: 11, height: 1.25)),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isSelected,
                                activeThumbColor: AppColors.primaryEmerald,
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val) {
                                      selectedRestrictions.add(key);
                                    } else {
                                      selectedRestrictions.remove(key);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Profili Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        final Database db = await DatabaseHelper().database;
                        await db.insert(
                          'family_profiles',
                          {
                            'profile_name': name,
                            'is_active': 0,
                            'restrictions_json': jsonEncode(selectedRestrictions.toList()),
                          },
                          conflictAlgorithm: ConflictAlgorithm.replace,
                        );
                        if (context.mounted) Navigator.pop(context);
                        _loadProfiles();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileModal(FamilyProfile profile) {
    final TextEditingController nameController = TextEditingController(text: profile.profileName);
    final Set<String> selectedRestrictions = Set<String>.from(profile.restrictions);
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.borderColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.primaryEmerald, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profili Düzenle',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            profile.profileName,
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Profil Adı', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ör: Küçük Ali, Eşim, Annem',
                        hintStyle: TextStyle(color: textSecondary),
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primaryEmerald),
                        filled: true,
                        fillColor: borderColor.withValues(alpha: 0.15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 1.8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!profile.isActive)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _setActiveProfile(profile.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Bu Profili Aktif Profil Yap'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryEmerald,
                            side: const BorderSide(color: AppColors.primaryEmerald),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alerji & Diyet Kısıtlamaları',
                            style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: selectedRestrictions.isNotEmpty
                                ? AppColors.primaryEmerald.withValues(alpha: 0.15)
                                : borderColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${selectedRestrictions.length} Seçili',
                            style: TextStyle(
                              color: selectedRestrictions.isNotEmpty ? AppColors.primaryEmerald : textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu profile özel kırmızı çizgileri seçin. Üründe tespit edildiğinde anında uyarı verilir.',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    ...FamilyProfileEngine.restrictionMeta.entries.map((entry) {
                      final key = entry.key;
                      final meta = entry.value;
                      final isSelected = selectedRestrictions.contains(key);
                      final icon = FamilyProfileEngine.getRestrictionIcon(key);

                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              selectedRestrictions.remove(key);
                            } else {
                              selectedRestrictions.add(key);
                            }
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
                                  color: isSelected ? AppColors.primaryEmerald.withValues(alpha: 0.16) : borderColor.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, size: 20, color: isSelected ? AppColors.primaryEmerald : textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(meta.label, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(meta.description, style: TextStyle(color: textSecondary, fontSize: 11, height: 1.25)),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isSelected,
                                activeThumbColor: AppColors.primaryEmerald,
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val) {
                                      selectedRestrictions.add(key);
                                    } else {
                                      selectedRestrictions.remove(key);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        PersonalSensitivityModal.show(
                          context,
                          profile: profile,
                          onSaved: _loadProfiles,
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryEmerald),
                      label: const Text(
                        'Puanlama Hassasiyetleri (Şeker, Tuz, Katkı) ➔',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryEmerald),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primaryEmerald.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Değişiklikleri Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        await FamilyProfileEngine.updateProfile(
                          profileId: profile.id,
                          profileName: name,
                          restrictions: selectedRestrictions.toList(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$name profili başarıyla güncellendi.'),
                              backgroundColor: AppColors.primaryEmerald,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        _loadProfiles();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aile Çoklu Sağlık Profilleri'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryEmerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Profil Ekle'),
        onPressed: _showAddProfileDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: profile.isActive ? AppColors.primaryEmerald : borderColor,
                      width: profile.isActive ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    onTap: () => _showEditProfileModal(profile),
                    leading: CircleAvatar(
                      backgroundColor: profile.isActive ? AppColors.primaryEmerald : borderColor,
                      child: Icon(
                        Icons.person,
                        color: profile.isActive ? Colors.white : textSecondary,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.profileName,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (profile.isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'AKTİF',
                              style: TextStyle(
                                color: AppColors.primaryEmerald,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sensitivity Preset Badge
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMint.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primaryMint.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 11, color: AppColors.primaryMint),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getPresetName(profile.sensitivity.presetId),
                                      style: const TextStyle(
                                        color: AppColors.primaryMint,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (profile.restrictions.isEmpty)
                            Text(
                              'Özel kısıtlama eklenmedi (Düzenlemek için dokunun)',
                              style: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: profile.restrictions.map((rKey) {
                                final meta = FamilyProfileEngine.restrictionMeta[rKey];
                                final icon = FamilyProfileEngine.getRestrictionIcon(rKey);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryEmerald.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, size: 12, color: AppColors.primaryEmerald),
                                      const SizedBox(width: 4),
                                      Text(
                                        meta?.shortTag ?? _restrictionLabels[rKey] ?? rKey,
                                        style: const TextStyle(
                                          color: AppColors.primaryEmerald,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.primaryEmerald, size: 20),
                          tooltip: 'Profili Düzenle',
                          onPressed: () => _showEditProfileModal(profile),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: AppColors.primaryEmerald, size: 20),
                          tooltip: 'Puanlama Hassasiyetleri',
                          onPressed: () {
                            PersonalSensitivityModal.show(
                              context,
                              profile: profile,
                              onSaved: _loadProfiles,
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            profile.isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: profile.isActive ? AppColors.primaryEmerald : textSecondary,
                          ),
                          tooltip: profile.isActive ? 'Aktif Profil' : 'Aktif Yap',
                          onPressed: () => _setActiveProfile(profile.id),
                        ),
                        if (!profile.isActive && _profiles.length > 1)
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: AppColors.dangerRed.withValues(alpha: 0.7), size: 20),
                            onPressed: () => _deleteProfile(profile.id),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
