import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class ChangelogRelease {
  final String version;
  final String date;
  final String titleTr;
  final String titleEn;
  final List<String> highlightsTr;
  final List<String> highlightsEn;

  const ChangelogRelease({
    required this.version,
    required this.date,
    required this.titleTr,
    required this.titleEn,
    required this.highlightsTr,
    required this.highlightsEn,
  });
}

/// Zikirce_ Standardında çift dilli (TR / EN) sürüm geçmişi servisi.
class ChangelogService {
  const ChangelogService();

  static const String currentVersion = '1.0.0+3';

  static const List<ChangelogRelease> releases = [
    ChangelogRelease(
      version: 'v1.0.0',
      date: '2026-10-14',
      titleTr: 'Klasik Şerh, Etimolojik Lügat & Yüksek Çözünürlüklü Berat Sürümü',
      titleEn: 'Classical Marginalia, Etymological Lexicon & High-Res Seal Release',
      highlightsTr: [
        '165+ maddelik kapsamlı Klasik Türkçe, Osmanlıca, Edebiyat, Felsefe, Tarih ve İslami İlimler Etimolojik Lügati eklendi.',
        'Türkçe çekim eklerini ve ünsüz yumuşamasını çözümleyen akıllı Morfolojik Kök Bulucu (Stemmer) devreye alındı.',
        'Tahrir Alıntı Stüdyosuna 4. şablon olarak "İs Mürekkebi (AMOLED)" eklendi ve 3x çözünürlükte gerçek PNG görsel paylaşımı sağlandı.',
        'Kitap bitirme sertifikası olan "Tahrir Mühür & Okuma Beratı" yüksek çözünürlüklü PNG olarak dışa aktarılabilir hale getirildi.',
        'Şerh & Not Defteri ekranına kategori filtreleri (Düşünce, Alıntı, Soru, Eleştiri), anlık arama, not düzenleme ve gerçek kitap künyesi entegrasyonu eklendi.',
        'Çevrimdışı P2P QR Şerh Takası modülüne mükerrer okuma kilidi ve titreşimli geri bildirim eklendi.',
      ],
      highlightsEn: [
        'Added a comprehensive 165+ entry Etymological Lexicon covering Classical Turkish, Ottoman, Literature, Philosophy, History, and Islamic Sciences.',
        'Introduced an intelligent Turkish Morphological Stemmer handling inflectional suffixes and consonant softening.',
        'Added the "Soot Ink (AMOLED)" template to Tahrir Quote Studio along with true 3x high-resolution PNG image export and sharing.',
        'Upgraded the "Tahrir Completion Seal & Reading Diploma" with high-resolution PNG certificate export.',
        'Enhanced the Marginalia & Highlights notebook with category filter chips, instant search, note editing, and real book metadata.',
        'Hardened Offline P2P QR Marginalia Sync with duplicate scan lock, deterministic scanner lifecycle, and haptic feedback.',
      ],
    ),
    ChangelogRelease(
      version: 'v0.9.0',
      date: '2026-10-01',
      titleTr: 'Akıllı PDF Akışı (Reflow), Çevrimdışı Katip & Mütalaa Temelleri',
      titleEn: 'Smart PDF Reflow, Offline Scribe & Reading Foundations',
      highlightsTr: [
        'Taranmış ve vektörel PDF eserler için çift görünüm (Orijinal Mizanpaj & Akıllı Metin Akışı) motoru kuruldu.',
        'Arapça/Osmanlıca ibare ve hat levhalarını koruyan özel kaligrafi ve dipnot ayrıştırıcı geliştirildi.',
        'Tahrir Parşömeni, İs Mürekkebi (AMOLED), Gece Safiri, Kağıt Beyazı ve Zeytin/Orman okuma temaları eklendi.',
        'Çevrimdışı Bilişsel Özet (Yerel AI Katip), Odak Cetveli, Sesli Okuma (TTS) ve Ambiyans Sesleri entegre edildi.',
      ],
      highlightsEn: [
        'Built the dual-view reading engine (Original Layout & Smart Text Reflow) for vector and scanned PDFs.',
        'Developed specialized calligraphy, inline crop, and footnote parsers preserving Arabic/Ottoman script blocks.',
        'Added 5 curated reading themes: Tahrir Parchment, Soot Ink (AMOLED), Night Sapphire, Paper White, and Olive Forest.',
        'Integrated Offline Cognitive Summary (Local AI Scribe), Line Focus Ruler, Text-to-Speech (TTS), and Ambient Soundscapes.',
      ],
    ),
  ];

  List<ChangelogRelease> getAllReleases() => releases;

  ChangelogRelease get latestRelease => releases.first;
}

class ChangelogModal extends StatefulWidget {
  const ChangelogModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const ChangelogModal(),
    );
  }

  @override
  State<ChangelogModal> createState() => _ChangelogModalState();
}

class _ChangelogModalState extends State<ChangelogModal> {
  bool _isEnglish = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const releases = ChangelogService.releases;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
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
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('📜', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        _isEnglish
                            ? 'Tahrir Release Chronicle'
                            : 'Tahrir Sürüm Sicili',
                        style: GoogleFonts.literata(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('TR')),
                      ButtonSegment(value: true, label: Text('EN')),
                    ],
                    selected: {_isEnglish},
                    onSelectionChanged: (s) =>
                        setState(() => _isEnglish = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: releases.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final rel = releases[index];
                    final title = _isEnglish ? rel.titleEn : rel.titleTr;
                    final items =
                        _isEnglish ? rel.highlightsEn : rel.highlightsTr;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: index == 0
                              ? AppColors.amberGold.withValues(alpha: 0.7)
                              : theme.colorScheme.outline,
                          width: index == 0 ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  rel.version,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              Text(
                                rel.date,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: GoogleFonts.literata(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...items.map(
                            (bullet) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bullet,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }
}
