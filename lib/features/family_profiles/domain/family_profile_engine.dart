import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../scoring/domain/organic_score_calculator.dart';

class ProfileViolation {
  final String restrictionKey;
  final String title;
  final String message;
  final String severity; // HIGH, CRITICAL

  ProfileViolation({
    required this.restrictionKey,
    required this.title,
    required this.message,
    required this.severity,
  });
}

class FamilyProfile {
  final int id;
  final String profileName;
  final bool isActive;
  final List<String> restrictions;
  final PersonalSensitivityConfig sensitivity;

  FamilyProfile({
    required this.id,
    required this.profileName,
    required this.isActive,
    required this.restrictions,
    this.sensitivity = const PersonalSensitivityConfig(),
  });

  factory FamilyProfile.fromMap(Map<String, dynamic> map) {
    List<String> resList = [];
    if (map['restrictions_json'] != null) {
      final List<dynamic> parsed = jsonDecode(map['restrictions_json']);
      resList = parsed.cast<String>();
    }

    PersonalSensitivityConfig sens = const PersonalSensitivityConfig();
    if (map['sensitivity_json'] != null && (map['sensitivity_json'] as String).isNotEmpty) {
      try {
        final dynamic parsedSens = jsonDecode(map['sensitivity_json']);
        if (parsedSens is Map<String, dynamic>) {
          sens = PersonalSensitivityConfig.fromMap(parsedSens);
        }
      } catch (_) {}
    } else {
      // Inferred defaults from existing profile restrictions if sensitivity_json wasn't set
      if (resList.contains('HIGH_SUGAR')) {
        sens = sens.copyWith(sugarStrictness: 'strict');
      }
      if (resList.contains('SYNTHETIC_COLORS')) {
        sens = sens.copyWith(additiveStrictness: 'strict');
      }
      if (resList.contains('PALM_OIL')) {
        sens = sens.copyWith(avoidPalmOil: true);
      }
      if (resList.contains('HIGH_SODIUM')) {
        sens = sens.copyWith(sodiumStrictness: 'strict');
      }
    }

    return FamilyProfile(
      id: map['id'] as int,
      profileName: map['profile_name'] as String,
      isActive: (map['is_active'] as int) == 1,
      restrictions: resList,
      sensitivity: sens,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'profile_name': profileName,
        'is_active': isActive ? 1 : 0,
        'restrictions_json': jsonEncode(restrictions),
        'sensitivity_json': jsonEncode(sensitivity.toMap()),
      };
}

class FamilyProfileEngine {
  /// Evaluates product ingredients & nutrition against the active family profile.
  static List<ProfileViolation> evaluateViolations({
    required FamilyProfile activeProfile,
    required String ingredientsText,
    required List<String> detectedRiskLevels,
    required double sugarPer100g,
    required double sodiumPer100g,
  }) {
    final List<ProfileViolation> violations = [];
    final String lowerIngredients = ingredientsText.toLowerCase();

    for (final restriction in activeProfile.restrictions) {
      switch (restriction) {
        case 'SYNTHETIC_COLORS':
          if (detectedRiskLevels.contains('HIGH') ||
              detectedRiskLevels.contains('TOXIC') ||
              lowerIngredients.contains('renklendirici') ||
              lowerIngredients.contains('tartrazin') ||
              lowerIngredients.contains('e102') ||
              lowerIngredients.contains('e110')) {
            violations.add(ProfileViolation(
              restrictionKey: 'SYNTHETIC_COLORS',
              title: 'Sentetik Renklendirici İhlali',
              message: '${activeProfile.profileName} için sentetik azo boyası / E-kodu renklendiricisi tespit edildi.',
              severity: 'CRITICAL',
            ));
          }
          break;

        case 'HIGH_SUGAR':
          if (sugarPer100g > 10.0 || lowerIngredients.contains('glikoz şurubu') || lowerIngredients.contains('fruktoz')) {
            violations.add(ProfileViolation(
              restrictionKey: 'HIGH_SUGAR',
              title: 'Yüksek Şeker / Glikoz İhlali',
              message: '${activeProfile.profileName} profilinde yüksek şeker veya nişasta bazlı sıvı şeker uyarısı.',
              severity: 'HIGH',
            ));
          }
          break;

        case 'PALM_OIL':
          if (lowerIngredients.contains('palmiye') || lowerIngredients.contains('palm yağı') || lowerIngredients.contains('palm oil')) {
            violations.add(ProfileViolation(
              restrictionKey: 'PALM_OIL',
              title: 'Palmiye Yağı İhlali',
              message: '${activeProfile.profileName} için doymuş palm yağı tespit edildi.',
              severity: 'HIGH',
            ));
          }
          break;

        case 'GLUTEN':
          if (lowerIngredients.contains('buğday') || lowerIngredients.contains('gluten') || lowerIngredients.contains('arpa') || lowerIngredients.contains('çavdar')) {
            violations.add(ProfileViolation(
              restrictionKey: 'GLUTEN',
              title: 'Gluten Uyarısı',
              message: '${activeProfile.profileName} için gluten içeren tahıl maddesi tespit edildi.',
              severity: 'CRITICAL',
            ));
          }
          break;

        case 'LACTOSE':
          if (lowerIngredients.contains('süt') || lowerIngredients.contains('laktoz') || lowerIngredients.contains('peynir altı suyu')) {
            violations.add(ProfileViolation(
              restrictionKey: 'LACTOSE',
              title: 'Laktoz İntoleransı Uyarısı',
              message: '${activeProfile.profileName} için süt bileşeni / laktoz tespit edildi.',
              severity: 'HIGH',
            ));
          }
          break;

        case 'HALAL':
          if (lowerIngredients.contains('domuz') || lowerIngredients.contains('jelatin') || lowerIngredients.contains('alkol') || lowerIngredients.contains('e120')) {
            violations.add(ProfileViolation(
              restrictionKey: 'HALAL',
              title: 'Helal Hassasiyeti İhlali',
              message: '${activeProfile.profileName} için sığır/domuz jelatini veya şüpheli katkı (E120) uyarısı.',
              severity: 'CRITICAL',
            ));
          }
          break;

        case 'HIGH_SODIUM':
          if (sodiumPer100g > 0.4 || lowerIngredients.contains('monosodyum glutamat') || lowerIngredients.contains('e621')) {
            violations.add(ProfileViolation(
              restrictionKey: 'HIGH_SODIUM',
              title: 'Yüksek Sodyum / Tuz Uyarısı',
              message: '${activeProfile.profileName} için yüksek sodyum oranı (${sodiumPer100g.toStringAsFixed(2)}g) tespit edildi.',
              severity: 'HIGH',
            ));
          }
          break;

        case 'VEGAN':
          if (lowerIngredients.contains('et ') ||
              lowerIngredients.contains('tavuk') ||
              lowerIngredients.contains('balık') ||
              lowerIngredients.contains('jelatin') ||
              lowerIngredients.contains('süt') ||
              lowerIngredients.contains('peynir') ||
              lowerIngredients.contains('tereyağ') ||
              lowerIngredients.contains('yumurta') ||
              lowerIngredients.contains('bal')) {
            violations.add(ProfileViolation(
              restrictionKey: 'VEGAN',
              title: 'Hayvansal İçerik / Vegan İhlali',
              message: '${activeProfile.profileName} için hayvansal kökenli gıda bileşeni tespit edildi.',
              severity: 'CRITICAL',
            ));
          }
          break;
      }
    }

    return violations;
  }

  /// Fetches active profile from SQLite.
  static Future<FamilyProfile?> getActiveProfile() async {
    final Database db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> result = await db.query(
      'family_profiles',
      where: 'is_active = 1',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return FamilyProfile.fromMap(result.first);
    }
    return null;
  }

  /// Updates sensitivity settings of a family profile.
  static Future<void> updateProfileSensitivity(int profileId, PersonalSensitivityConfig sensitivity) async {
    final Database db = await DatabaseHelper().database;
    await db.update(
      'family_profiles',
      {'sensitivity_json': jsonEncode(sensitivity.toMap())},
      where: 'id = ?',
      whereArgs: [profileId],
    );
  }

  /// Comprehensive metadata for all supported restrictions.
  static const Map<String, ({String label, String description, String shortTag})> restrictionMeta = {
    'GLUTEN': (
      label: 'Gluten İçeren Tahıllar',
      description: 'Çölyak & gluten hassasiyeti için buğday, arpa, çavdar uyarısı.',
      shortTag: 'Gluten',
    ),
    'HALAL': (
      label: 'Helal Hassasiyeti (Jelatin / E120)',
      description: 'Domuz, sığır jelatini ve şüpheli karmin/böcek boyası (E120) uyarısı.',
      shortTag: 'Helal',
    ),
    'SYNTHETIC_COLORS': (
      label: 'Sentetik Renklendiriciler (Azo Boyaları)',
      description: 'Yapay gıda boyaları (E102, E110, E122, E124, E129 vb.) uyarısı.',
      shortTag: 'Renklendirici',
    ),
    'HIGH_SUGAR': (
      label: 'Yüksek Şeker & Glikoz Şurubu',
      description: 'Glikoz/fruktoz şurubu ve 100g içinde 15g üzeri aşırı şeker uyarısı.',
      shortTag: 'Şeker/Glikoz',
    ),
    'PALM_OIL': (
      label: 'Palmiye (Palm) Yağı',
      description: 'Doymuş yağ ve hidrojenize palm yağı türevleri uyarısı.',
      shortTag: 'Palm Yağı',
    ),
    'LACTOSE': (
      label: 'Laktoz / Süt Ürünleri',
      description: 'Laktoz intoleransı için süt, peynir altı suyu tozu uyarısı.',
      shortTag: 'Laktoz',
    ),
    'HIGH_SODIUM': (
      label: 'Yüksek Sodyum / Aşırı Tuz',
      description: 'Hipertansiyon koruması için 0.6g üzeri tuz uyarısı.',
      shortTag: 'Tuz/Sodyum',
    ),
    'VEGAN': (
      label: 'Vejetaryen / Vegan İhlali',
      description: 'Et, süt, yumurta, bal gibi hayvansal bileşen uyarısı.',
      shortTag: 'Vegan',
    ),
  };

  /// Returns a representative icon for a restriction key.
  static IconData getRestrictionIcon(String key) {
    switch (key) {
      case 'GLUTEN':
        return Icons.grass_rounded;
      case 'HALAL':
        return Icons.verified_user_outlined;
      case 'SYNTHETIC_COLORS':
        return Icons.palette_outlined;
      case 'HIGH_SUGAR':
        return Icons.cookie_outlined;
      case 'PALM_OIL':
        return Icons.spa_outlined;
      case 'LACTOSE':
        return Icons.breakfast_dining_outlined;
      case 'HIGH_SODIUM':
        return Icons.grain_rounded;
      case 'VEGAN':
        return Icons.eco_rounded;
      default:
        return Icons.health_and_safety_outlined;
    }
  }

  /// Updates profile name, restrictions, and optionally sensitivity config.
  static Future<void> updateProfile({
    required int profileId,
    required String profileName,
    required List<String> restrictions,
    PersonalSensitivityConfig? sensitivity,
  }) async {
    final Database db = await DatabaseHelper().database;
    final Map<String, dynamic> data = {
      'profile_name': profileName,
      'restrictions_json': jsonEncode(restrictions),
    };
    if (sensitivity != null) {
      data['sensitivity_json'] = jsonEncode(sensitivity.toMap());
    }
    await db.update(
      'family_profiles',
      data,
      where: 'id = ?',
      whereArgs: [profileId],
    );
  }

  /// Updates restrictions list of a family profile.
  static Future<void> updateProfileRestrictions(int profileId, List<String> restrictions) async {
    final Database db = await DatabaseHelper().database;
    await db.update(
      'family_profiles',
      {'restrictions_json': jsonEncode(restrictions)},
      where: 'id = ?',
      whereArgs: [profileId],
    );
  }
}
