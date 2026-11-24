import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../marginalia/services/dictionary_service.dart';
import '../../engine/ocr_proofreader_engine.dart';

typedef OcrWordSuggestion = OcrSuggestionItem;

/// Okuyucu ekranda herhangi bir kelimeye tek dokunuş yaptığında açılan,
/// Tahrir'in sıcak parşömen ve karanlık mod temalarıyla uyumlu Popup Lügat & Tashih Kartı.
class PopupLugatCard extends StatefulWidget {
  final String word;
  final String? surroundingParagraph;
  final OcrCorrectionItem? ocrCorrection;
  final OcrSuggestionItem? ocrSuggestion;
  final ValueChanged<String> onCorrectWord;
  final void Function(String originalWord, String correctedWord)?
      onApplyDirectCorrection;
  final ValueChanged<String> onOpenFullDictionary;
  final ValueChanged<String> onOpenConceptRadar;
  final ValueChanged<String> onAddHighlight;

  const PopupLugatCard({
    super.key,
    required this.word,
    this.surroundingParagraph,
    this.ocrCorrection,
    this.ocrSuggestion,
    required this.onCorrectWord,
    this.onApplyDirectCorrection,
    required this.onOpenFullDictionary,
    required this.onOpenConceptRadar,
    required this.onAddHighlight,
  });

  static Future<void> show(
    BuildContext context, {
    required String word,
    String? surroundingParagraph,
    OcrCorrectionItem? ocrCorrection,
    OcrSuggestionItem? ocrSuggestion,
    required ValueChanged<String> onCorrectWord,
    void Function(String originalWord, String correctedWord)?
        onApplyDirectCorrection,
    required ValueChanged<String> onOpenFullDictionary,
    required ValueChanged<String> onOpenConceptRadar,
    required ValueChanged<String> onAddHighlight,
  }) async {
    final cleaned = _cleanPunctuation(word);
    if (cleaned.isEmpty) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Popup Lügat Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 20),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: PopupLugatCard(
                    word: cleaned,
                    surroundingParagraph: surroundingParagraph,
                    ocrCorrection: ocrCorrection,
                    ocrSuggestion: ocrSuggestion,
                    onCorrectWord: onCorrectWord,
                    onApplyDirectCorrection: onApplyDirectCorrection,
                    onOpenFullDictionary: onOpenFullDictionary,
                    onOpenConceptRadar: onOpenConceptRadar,
                    onAddHighlight: onAddHighlight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static String _cleanPunctuation(String raw) {
    return raw
        .replaceAll(
          RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
          '',
        )
        .trim();
  }

  @override
  State<PopupLugatCard> createState() => _PopupLugatCardState();
}

class _PopupLugatCardState extends State<PopupLugatCard> {
  final DictionaryService _dictionaryService = DictionaryService();
  late String _activeWord;
  bool _isViewingInitialWord = true;

  static const Map<String, DictionaryEntry> _ottomanTerkipLexicon = {
    'adab-ı muaşeret': DictionaryEntry(
      word: 'Âdâb-ı Muaşeret',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning:
          'Toplum içinde insanlarla bir arada zarafet, saygı ve nezaket ölçüleri çerçevesinde yaşama ve davranma kuralları; görgü kuralları.',
      example:
          '"Âdâb-ı muaşeret, bir medeniyetin gündelik hayattaki estetik tezahürüdür."',
    ),
    'devlet-i aliyye': DictionaryEntry(
      word: 'Devlet-i Aliyye',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / Özel İsim',
      meaning:
          '"Yüce Devlet"; Osmanlı Devleti\'nin resmi yazışmalarda, fermanlarda ve vakayinamelerde kullanılan asli unvanı.',
      example:
          '"Devlet-i Aliyye\'nin arşiv defterleri asırlar boyunca tahrir usulüyle tutulmuştur."',
    ),
    'nokta-i nazar': DictionaryEntry(
      word: 'Nokta-i Nazar',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning:
          'Bakış açısı, bir meseleyi değerlendirirken durulan fikrî konum, perspektif.',
      example:
          '"Müellif, meseleyi hem felsefi hem de tarihi nokta-i nazardan ele almıştır."',
    ),
    'nizam-ı alem': DictionaryEntry(
      word: 'Nizâm-ı Âlem',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / Kavram',
      meaning:
          'Dünya düzeni, kamu dirliği ve toplumsal adaletin sarsılmadan sürdürülmesi ülküsü.',
      example:
          '"Klasik siyasetnamelerde adalet, nizâm-ı âlemin temeli sayılır."',
    ),
    'hüsn-i zan': DictionaryEntry(
      word: 'Hüsn-i Zan',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning:
          'Bir kimse veya durum hakkında iyi niyetli düşünme, güzel kanaat besleme.',
      example:
          '"İnsanlara karşı hüsn-i zan beslemek, kalbin selametindendir."',
    ),
    'hüsn-i niyet': DictionaryEntry(
      word: 'Hüsn-i Niyet',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning: 'İyi niyet, halis ve samimi maksat.',
      example:
          '"Hüsn-i niyetle başlanan her ilmi gayret, bereketini içinde taşır."',
    ),
    'ilm-i siyaset': DictionaryEntry(
      word: 'İlm-i Siyaset',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning:
          'Devlet yönetimi, kamu düzeni ve adaletle hükmetme bilimi; siyaset felsefesi.',
      example:
          '"Kınalızâde\'ye göre ilm-i siyaset, ahlak ilminin toplumsal boyutudur."',
    ),
    'ehl-i dil': DictionaryEntry(
      word: 'Ehl-i Dil',
      origin: 'Osmanlıca Terkip (Arapça-Farsça)',
      partOfSpeech: 'Terkip / Sıfat',
      meaning:
          'Gönül ehli; incelik, irfan ve söz kıymeti bilen, halden anlayan kimse.',
      example: '"Ehl-i dil olanlar, bir kelimenin ardındaki sükûtu da okur."',
    ),
    'dar-ı beka': DictionaryEntry(
      word: 'Dâr-ı Bekâ',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning: 'Sonsuzluk yurdu, ebedî âlem, ahiret.',
      example: '"Fani dünyadan dâr-ı bekâya irtihal etti."',
    ),
    'ab-ı hayat': DictionaryEntry(
      word: 'Âb-ı Hayat',
      origin: 'Osmanlıca Terkip (Farsça-Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning:
          'İçene ölümsüzlük verdiğine inanılan efsanevi dirilik suyu; mecazen cana can katan hikmetli söz.',
      example:
          '"Hakiki bir kitap, susamış zihinler için âb-ı hayat hükmündedir."',
    ),
    'akl-ı selim': DictionaryEntry(
      word: 'Akl-ı Selim',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning:
          'Sağduyu; önyargıdan ve aşırılıktan uzak, doğruyu yanlıştan ayırt edebilen berrak muhakeme gücü.',
      example: '"Bunalım dönemlerinde en büyük pusula akl-ı selimdir."',
    ),
    'terk-i diyar': DictionaryEntry(
      word: 'Terk-i Diyar',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning: 'Memleketini, yurdunu bırakıp başka bir diyara göç etme.',
      example: '"Derviş, ilim uğruna genç yaşta terk-i diyar eyledi."',
    ),
    'sükut-ı hayal': DictionaryEntry(
      word: 'Sükût-ı Hayâl',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / İsim',
      meaning: 'Hayal kırıklığı, umulan şeyin gerçekleşmemesiyle duyulan hüzün.',
      example:
          '"Büyük beklentiler çoğu zaman derin bir sükût-ı hayâl ile neticelenir."',
    ),
    'hal-i hazır': DictionaryEntry(
      word: 'Hâl-i Hazır',
      origin: 'Osmanlıca Terkip (Arapça)',
      partOfSpeech: 'Terkip / Zarf',
      meaning: 'Şimdiki durum, içinde bulunulan an, mevcut vaziyet.',
      example: '"Hâl-i hazırda elimizdeki en eski nüsha budur."',
    ),
  };

  @override
  void initState() {
    super.initState();
    _activeWord = _resolveContextualWordOrTerkip(
      widget.word,
      widget.surroundingParagraph,
    );
  }

  static String _normalizeForLookup(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Â', 'a')
        .replaceAll('Î', 'i')
        .replaceAll('Û', 'u')
        .toLowerCase()
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .trim();
  }

  /// Tıklanan kelimenin paragraf içindeki sağ veya sol komşusuyla Farsça/Arapça izafet terkibi
  /// (`-ı`, `-i`, `-u`, `-ü`) oluşturup oluşturmadığını denetler.
  String _resolveContextualWordOrTerkip(
    String tappedWord,
    String? paragraph,
  ) {
    final cleanTapped = PopupLugatCard._cleanPunctuation(tappedWord);
    if (paragraph == null || paragraph.trim().isEmpty) {
      return cleanTapped;
    }

    final rawTokens = paragraph
        .split(RegExp(r'\s+'))
        .map(PopupLugatCard._cleanPunctuation)
        .where((t) => t.isNotEmpty)
        .toList();

    final idx = rawTokens.indexWhere(
      (t) => _normalizeForLookup(t) == _normalizeForLookup(cleanTapped),
    );
    if (idx == -1) return cleanTapped;

    final izafetPattern = RegExp(r'.+-[ıiuüîû]$', caseSensitive: false);

    // 1. Tıklanan kelime "devlet-i", "âdâb-ı" gibi izafetle bitiyorsa sağdaki kelimeyle birleştir
    if (izafetPattern.hasMatch(rawTokens[idx]) && idx + 1 < rawTokens.length) {
      return '${rawTokens[idx]} ${rawTokens[idx + 1]}';
    }

    // 2. Soldaki kelime "devlet-i", "âdâb-ı" gibi izafetle bitiyorsa soldakiyle birleştir
    if (idx > 0 && izafetPattern.hasMatch(rawTokens[idx - 1])) {
      return '${rawTokens[idx - 1]} ${rawTokens[idx]}';
    }

    return cleanTapped;
  }

  DictionaryEntry _lookupActiveEntry() {
    final norm = _normalizeForLookup(_activeWord);
    for (final entry in _ottomanTerkipLexicon.entries) {
      if (norm.startsWith(entry.key) || entry.key == norm) {
        return entry.value;
      }
    }
    return _dictionaryService.lookup(
      _activeWord,
      surroundingText:
          _isViewingInitialWord ? widget.surroundingParagraph : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _lookupActiveEntry();
    final relatedEntries =
        _dictionaryService.getRelatedEntries(entry.word, limit: 5);

    final isInflected = _normalizeForLookup(_activeWord) !=
            _normalizeForLookup(entry.word) &&
        !entry.word.contains('·');

    final showOcrCorrection =
        _isViewingInitialWord && widget.ocrCorrection != null;
    final showOcrSuggestion =
        _isViewingInitialWord && widget.ocrSuggestion != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.amberGold.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ÜST BAŞLIK: Kelime, Kök, Köken Rozeti, Sözcük Türü ve Kapat
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.amberGold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.amberGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _activeWord,
                            style: GoogleFonts.literata(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (isInflected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Kök: ${entry.word}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.terracotta.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    AppColors.terracotta.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              entry.origin,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.terracotta,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amberGold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              entry.partOfSpeech,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.amberGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // 2. OCR TASHİH / ŞÜPHE BİLGİ BANDI (Varsa)
            if (showOcrCorrection) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_fix_high_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '✨ OCR Tashihi: "${widget.ocrCorrection!.originalWord}" ➔ "${widget.ocrCorrection!.correctedWord}" (${widget.ocrCorrection!.ruleCategory})',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (showOcrSuggestion) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amberGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.amberGold.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.spellcheck_rounded,
                          size: 16,
                          color: AppColors.amberGold,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Olası OCR Dizgi Uyarısı: ${widget.ocrSuggestion!.issueDescription}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.ocrSuggestion!.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            widget.ocrSuggestion!.suggestions.map((candidate) {
                          return ActionChip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            label: Text(
                              candidate,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              if (widget.onApplyDirectCorrection != null) {
                                widget.onApplyDirectCorrection!(
                                  widget.ocrSuggestion!.suspiciousWord,
                                  candidate,
                                );
                              } else {
                                widget.onCorrectWord(
                                  widget.ocrSuggestion!.suspiciousWord,
                                );
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),

            // 3. ANLAM & AÇIKLAMA GÖVDESİ
            Text(
              entry.meaning,
              style: GoogleFonts.literata(
                fontSize: 15,
                height: 1.52,
                color: theme.colorScheme.onSurface,
              ),
            ),

            // Örnek Cümle / Beyit Kutusu
            if (entry.example != null && entry.example!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: AppColors.amberGold.withValues(alpha: 0.85),
                      width: 3.5,
                    ),
                  ),
                ),
                child: Text(
                  '📜 ${entry.example}',
                  style: GoogleFonts.literata(
                    fontSize: 12.5,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],

            // İlgili Kavramlar / Eş Anlamlılar Çipleri (Anında Geçiş)
            if (relatedEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'İlişkili Kavramlar (Dokunarak Geçiş Yapın):',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: relatedEntries.map((rel) {
                  return ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      rel.word,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _activeWord = rel.word;
                        _isViewingInitialWord = false;
                      });
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),

            // 4. ALT HIZLI AKSİYON ÇUBUĞU
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildActionPill(
                  theme: theme,
                  icon: Icons.edit_note_rounded,
                  label: 'Tashih Et',
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onCorrectWord(_activeWord);
                  },
                ),
                _buildActionPill(
                  theme: theme,
                  icon: Icons.bookmark_add_outlined,
                  label: 'Vurgula & Not',
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onAddHighlight(_activeWord);
                  },
                ),
                _buildActionPill(
                  theme: theme,
                  icon: Icons.radar_rounded,
                  label: 'Kavram Radarı',
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onOpenConceptRadar(entry.word);
                  },
                ),
                _buildActionPill(
                  theme: theme,
                  icon: Icons.menu_book_outlined,
                  label: 'Tam Lügat',
                  isPrimary: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onOpenFullDictionary(entry.word);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final fg = isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.85);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : theme.colorScheme.outline.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
