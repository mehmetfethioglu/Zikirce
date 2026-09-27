import 'package:flutter/foundation.dart';

/// 32 Farz kategorileri
enum FarzCategory {
  iman(
    displayName: 'İmanın Şartları',
    shortName: 'İman',
    count: 6,
    iconCode: 0xe574, // verified / school / auto_stories
  ),
  islam(
    displayName: 'İslam\'ın Şartları',
    shortName: 'İslam',
    count: 5,
    iconCode: 0xe3e6, // mosque
  ),
  abdest(
    displayName: 'Abdestin Farzları',
    shortName: 'Abdest',
    count: 4,
    iconCode: 0xe6e8, // water_drop
  ),
  gusul(
    displayName: 'Guslün Farzları',
    shortName: 'Gusül',
    count: 3,
    iconCode: 0xf0719, // clean_hands
  ),
  teyemmum(
    displayName: 'Teyemmümün Farzları',
    shortName: 'Teyemmüm',
    count: 2,
    iconCode: 0xe370, // landscape
  ),
  namazSart(
    displayName: 'Namazın Şartları (Dışındakiler)',
    shortName: 'Namaz Şartları',
    count: 6,
    iconCode: 0xe84f, // access_time / task_alt
  ),
  namazRukun(
    displayName: 'Namazın Rükünleri (İçindekiler)',
    shortName: 'Namaz Rükünleri',
    count: 6,
    iconCode: 0xe3e6, // temple_buddhist / mosque
  );

  final String displayName;
  final String shortName;
  final int count;
  final int iconCode;

  const FarzCategory({
    required this.displayName,
    required this.shortName,
    required this.count,
    required this.iconCode,
  });
}

/// Diyanet İşleri Başkanlığı İlmihali (Cilt 1) kaynaklı 32 Farz bilgi modeli
@immutable
class FarzKnowledgeItem {
  /// 1 ile 32 arası tekil farz numarası
  final int id;

  /// Farzın ait olduğu fıkhi grup
  final FarzCategory category;

  /// Grubundaki sıra numarası (Örn: Abdestin 4 farzından 1.'si)
  final int orderInGroup;

  /// Farzın Türkçe açık başlığı
  final String title;

  /// Varsa fıkhi / Arapça ıstılah adı (Örn: Mazmaza, Hadesten Taharet, Ka'de-i Ahire)
  final String term;

  /// Ezan / Namaz bildirimlerinde görünen 1-2 cümlelik öz ve bilgilendirici metin
  final String notificationSummary;

  /// Diyanet İlmihali Cilt 1'den titizlikle derlenmiş güvenilir fıkhi makale metni
  final String fullContent;

  /// Diyanet İlmihali Cilt 1 sayfa referansı
  final String sourceCitation;

  /// Hızlı hatırlatıcı maddeler
  final List<String> keyPoints;

  const FarzKnowledgeItem({
    required this.id,
    required this.category,
    required this.orderInGroup,
    required this.title,
    this.term = '',
    required this.notificationSummary,
    required this.fullContent,
    required this.sourceCitation,
    this.keyPoints = const [],
  });

  /// Başlık ile fıkhi terimi birleştiren gösterim adı
  String get displayTitle => term.isNotEmpty ? '$title ($term)' : title;
}
