import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/haptic_service.dart';

enum TalimModeType {
  hafizlikTakip,
  kelimeTakip,
  bulmaca,
  bosluk,
  baglama,
  sesli,
}

/// Hafızlık ve Talim Modları Detay, Rehber & İstatistik Bottom Sheet'i
class TalimModeDetailBottomSheet extends StatelessWidget {
  final TalimModeType modeType;
  final int plansCount;
  final HafizlikDailyLog? todayLog;
  final VoidCallback onStart;

  const TalimModeDetailBottomSheet({
    super.key,
    required this.modeType,
    this.plansCount = 0,
    this.todayLog,
    required this.onStart,
  });

  static Future<void> show({
    required BuildContext context,
    required TalimModeType modeType,
    int plansCount = 0,
    HafizlikDailyLog? todayLog,
    required VoidCallback onStart,
  }) {
    HapticService.selectionClick();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TalimModeDetailBottomSheet(
        modeType: modeType,
        plansCount: plansCount,
        todayLog: todayLog,
        onStart: onStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final surfaceBg = isDark ? const Color(0xFF272C35) : const Color(0xFFF3F7F5);
    final borderStroke = isDark ? const Color(0xFF353C48) : const Color(0xFFDEE9E5);

    final config = _getConfig(isDark);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Header (İkon + Tag + Başlık)
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: config.accentColor.withValues(alpha: 0.15),
                      border: Border.all(color: config.accentColor.withValues(alpha: 0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(config.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: config.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            config.tag,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: config.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config.title,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Mod Özel Durum veya İstatistik Kartı
              if (modeType == TalimModeType.hafizlikTakip) ...[
                _buildHafizlikStatusSection(
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  surfaceBg: surfaceBg,
                  borderStroke: borderStroke,
                  accentColor: config.accentColor,
                ),
                const SizedBox(height: 16),
              ],

              // 4. Modun Pedagojik Amacı ve Rehberi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderStroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 18, color: config.accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Modun Amacı ve Faydası',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.purpose,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Nasıl Çalışır / Kurallar Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: config.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: config.accentColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded, size: 18, color: config.accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Nasıl Uygulanır?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: config.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...config.steps.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: config.accentColor,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 6. Başlat / Uygula Butonu
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryTextColor,
                        side: BorderSide(color: borderStroke),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: config.buttonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onStart();
                      },
                      icon: Icon(config.buttonIcon, size: 20),
                      label: Text(
                        config.buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
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

  Widget _buildHafizlikStatusSection({
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color surfaceBg,
    required Color borderStroke,
    required Color accentColor,
  }) {
    final ham = todayLog?.isHamDone ?? false;
    final pismis = todayLog?.isPismisDone ?? false;
    final has = todayLog?.isHasDone ?? false;
    final vird = todayLog?.isAsgariVirdDone ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Osmanlı Usulü Günlük Vird Durumu',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$plansCount Sayfa Kayıtlı',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildHafizlikTaskPill('Ham (Yeni)', ham, const Color(0xFF3B82F6))),
              const SizedBox(width: 6),
              Expanded(child: _buildHafizlikTaskPill('Pişmiş (5s)', pismis, const Color(0xFFF59E0B))),
              const SizedBox(width: 6),
              Expanded(child: _buildHafizlikTaskPill('Has (Cüz)', has, const Color(0xFF10B981))),
              const SizedBox(width: 6),
              Expanded(child: _buildHafizlikTaskPill('Vird', vird, const Color(0xFF8B5CF6))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHafizlikTaskPill(String title, bool isDone, Color activeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDone ? activeColor.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone ? activeColor : Colors.grey.withValues(alpha: 0.25),
          width: isDone ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            isDone ? '✓ Yapıldı' : '○ Bekliyor',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isDone ? activeColor : Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDone ? activeColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  _TalimModeConfig _getConfig(bool isDark) {
    switch (modeType) {
      case TalimModeType.hafizlikTakip:
        return _TalimModeConfig(
          emoji: '📜',
          tag: 'Hafızlık Takibi',
          title: 'Osmanlı Usulü Hafızlık',
          accentColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          buttonColor: const Color(0xFF6366F1),
          buttonLabel: 'Hafızlık Merkezine Git',
          buttonIcon: Icons.workspace_premium_rounded,
          purpose:
              'Geleneksel Osmanlı usulü hafızlık tekniğinde ezberler Ham (çiğ yeni sayfa), Pişmiş (son ezberlenen sayfalar), Has (önceki cüzler) ve Asgari Vird döngüsüyle unutulmaz hale getirilir.',
          steps: [
            'Ham: Günün taze ezberlenecek yeni sayfası üzerinde yoğunlaşın.',
            'Pişmiş: Son ezberlediğiniz 5 sayfayı pürüzsüz akıcılıkla pekiştirin.',
            'Has: Daha önce bitirdiğiniz cüzlerden en az bir cüzü baştan sona tekrar edin.',
            'Asgari Vird: Günlük Kur\'an tilavet kotanızı eksiksiz tamamlayarak sebat edin.',
          ],
        );

      case TalimModeType.kelimeTakip:
        return _TalimModeConfig(
          emoji: '🎧',
          tag: 'Kelime Takip',
          title: 'Kelime Takipli Dinleme',
          accentColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
          buttonColor: const Color(0xFF0D9488),
          buttonLabel: 'Dinlemeyi Başlat',
          buttonIcon: Icons.headphones_rounded,
          purpose:
              'Kâri tilavet ederken okunan kelimenin anlık sarı/vurgulu renkle takip edilmesi, doğru mahreç, tecvid uygulamaları ve görsel hafıza için en etkili dinleme yöntemidir.',
          steps: [
            'Dinlemek istediğiniz Sayfa, Sûre, Cüz veya Aşr-ı Şerif\'i seçin.',
            'Tercih ettiğiniz kâri/hafız sesini belirleyin.',
            'Kelime vurgularını gözünüzle takip ederek okunuş ve tecvidleri zihninize nakşedin.',
          ],
        );

      case TalimModeType.bulmaca:
        return _TalimModeConfig(
          emoji: '⊞',
          tag: 'Kelime Bulmaca',
          title: 'Ayet Kelime Bulmacası',
          accentColor: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
          buttonColor: const Color(0xFF10B981),
          buttonLabel: 'Bulmacayı Başlat',
          buttonIcon: Icons.extension_rounded,
          purpose:
              'Ayetin kelimeleri karışık bir havuzda sunulur. Doğru sırayla basarak ayeti tamamlamanız gerekir. Kelimelerin cümle içindeki tertibini ve ayet bütünlüğünü pekiştirir.',
          steps: [
            'Altta karışık olarak verilen kelimeleri inceleyin.',
            'Ayetin akışına göre kelimeleri sırasıyla seçerek yukarıya dizin.',
            'Yanlış yerleştirdiğiniz kelimenin üstüne dokunarak havuza geri gönderebilirsiniz.',
            'Ayet tamamlandığında doğru tilavet otomatik olarak seslendirilir.',
          ],
        );

      case TalimModeType.bosluk:
        return _TalimModeConfig(
          emoji: '✍️',
          tag: 'Boşluk Doldurma',
          title: 'Ayet Boşluk Doldurma',
          accentColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
          buttonColor: const Color(0xFFF59E0B),
          buttonLabel: 'Boşluk Doldurmayı Başlat',
          buttonIcon: Icons.edit_note_rounded,
          purpose:
              'Ayet içerisinden seçilen kritik kelimeler gizlenir. Verilen seçenekler arasından doğru kelimeyi bulmanız beklenir. Ezberdeki zayıf noktaları ve kelime benzeşmelerini ortaya çıkarır.',
          steps: [
            'Ekranda gösterilen ayetteki boşluk (_____) kısmını dikkatlice okuyun.',
            'Alttaki 3-4 alternatif seçenek arasından eksik olan doğru kelimeyi işaretleyin.',
            'Doğru cevap verildiğinde ayet teyit amaçlı seslendirilir.',
          ],
        );

      case TalimModeType.baglama:
        return _TalimModeConfig(
          emoji: '🔗',
          tag: 'Ayet Bağlama',
          title: 'Sonraki Ayeti Bağlama',
          accentColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
          buttonColor: const Color(0xFF0284C7),
          buttonLabel: 'Ayet Bağlamayı Başlat',
          buttonIcon: Icons.link_rounded,
          purpose:
              'Hafızlıkta ve tilavette en sık takılınan nokta ayet sonlarından sonraki ayete geçiştir. Bu mod, bir ayet bittiğinde peşinden hangi ayetin geldiğini tahmin etme refleksini geliştirir.',
          steps: [
            'Üstte gösterilen mevcut ayeti okuyun.',
            'Hemen peşinden gelen doğru sonraki ayeti seçenekler arasından bulun.',
            'Sayfalar ve ayetler arasındaki kesintisiz geçiş kabiliyetinizi sınayın.',
          ],
        );

      case TalimModeType.sesli:
        return _TalimModeConfig(
          emoji: '🎙️',
          tag: 'Sesli Talim',
          title: 'Ses Tanımalı Tilavet',
          accentColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF6B21A8),
          buttonColor: const Color(0xFFA855F7),
          buttonLabel: 'Ses Tanımayı Başlat',
          buttonIcon: Icons.mic_rounded,
          purpose:
              'Mikrofona sesli tilavet yaparken yapay zeka ses tanıma motoru kelimeleri anlık olarak denetler. Tek başınıza hafızlık tekrarı yaparken hoca kontrolü konforu sunar.',
          steps: [
            'Sessiz bir ortamda mikrofona izin vererek okumaya başlayın.',
            'Okuduğunuz kelimeler doğru telaffuz edildikçe yeşil renkle onaylanır.',
            'Takıldığınızda veya unuttuğunuzda ipucu butonuyla destek alabilirsiniz.',
          ],
        );
    }
  }
}

class _TalimModeConfig {
  final String emoji;
  final String tag;
  final String title;
  final Color accentColor;
  final Color buttonColor;
  final String buttonLabel;
  final IconData buttonIcon;
  final String purpose;
  final List<String> steps;

  const _TalimModeConfig({
    required this.emoji,
    required this.tag,
    required this.title,
    required this.accentColor,
    required this.buttonColor,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.purpose,
    required this.steps,
  });
}
