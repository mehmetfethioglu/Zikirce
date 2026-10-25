import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/services/changelog_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../dashboard/presentation/widgets/whats_new_bottom_sheet.dart';
import 'share_card_screen.dart';
import 'widgets_preview_screen.dart';

class _GuideStepItem {
  final int id;
  final String categoryId;
  final String iconEmoji;
  final IconData iconData;
  final String titleTr;
  final String titleEn;
  final String summaryTr;
  final String summaryEn;
  final List<String> stepsTr;
  final List<String> stepsEn;
  final String proTipTr;
  final String proTipEn;
  final String actionLabelTr;
  final String actionLabelEn;
  final String route;
  final List<String> searchKeywords;

  const _GuideStepItem({
    required this.id,
    required this.categoryId,
    required this.iconEmoji,
    required this.iconData,
    required this.titleTr,
    required this.titleEn,
    required this.summaryTr,
    required this.summaryEn,
    required this.stepsTr,
    required this.stepsEn,
    required this.proTipTr,
    required this.proTipEn,
    required this.actionLabelTr,
    required this.actionLabelEn,
    required this.route,
    required this.searchKeywords,
  });

  String title(bool isTr) => isTr ? titleTr : titleEn;
  String summary(bool isTr) => isTr ? summaryTr : summaryEn;
  List<String> steps(bool isTr) => isTr ? stepsTr : stepsEn;
  String proTip(bool isTr) => isTr ? proTipTr : proTipEn;
  String actionLabel(bool isTr) => isTr ? actionLabelTr : actionLabelEn;

  bool matchesQuery(String rawQuery) {
    if (rawQuery.trim().isEmpty) return true;
    final q = _normalizeSearch(rawQuery);
    final haystack = _normalizeSearch(
      '$titleTr $titleEn $summaryTr $summaryEn '
      '${stepsTr.join(' ')} ${stepsEn.join(' ')} '
      '$proTipTr $proTipEn ${searchKeywords.join(' ')}',
    );
    final tokens = q.split(' ').where((t) => t.isNotEmpty);
    return tokens.every((token) => haystack.contains(token));
  }
}

class _ShowcaseCardItem {
  final String badgeTr;
  final String badgeEn;
  final String titleTr;
  final String titleEn;
  final String descTr;
  final String descEn;
  final List<String> pillsTr;
  final List<String> pillsEn;
  final String buttonTr;
  final String buttonEn;
  final String route;
  final IconData icon;
  final Color accentTint;
  final bool showTrackingPreview;

  const _ShowcaseCardItem({
    required this.badgeTr,
    required this.badgeEn,
    required this.titleTr,
    required this.titleEn,
    required this.descTr,
    required this.descEn,
    required this.pillsTr,
    required this.pillsEn,
    required this.buttonTr,
    required this.buttonEn,
    required this.route,
    required this.icon,
    required this.accentTint,
    this.showTrackingPreview = false,
  });
}

class _FaqGuideItem {
  final int id;
  final String questionTr;
  final String questionEn;
  final String answerTr;
  final String answerEn;
  final String actionLabelTr;
  final String actionLabelEn;
  final String actionKey;
  final IconData icon;

  const _FaqGuideItem({
    required this.id,
    required this.questionTr,
    required this.questionEn,
    required this.answerTr,
    required this.answerEn,
    required this.actionLabelTr,
    required this.actionLabelEn,
    required this.actionKey,
    required this.icon,
  });

  bool matchesQuery(String rawQuery) {
    if (rawQuery.trim().isEmpty) return true;
    final q = _normalizeSearch(rawQuery);
    final haystack = _normalizeSearch(
      '$questionTr $questionEn $answerTr $answerEn $actionLabelTr $actionLabelEn',
    );
    final tokens = q.split(' ').where((t) => t.isNotEmpty);
    return tokens.every((token) => haystack.contains(token));
  }
}

String _normalizeSearch(String input) {
  return input
      .toLowerCase()
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u')
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll("'", '')
      .replaceAll('’', '');
}

class UserGuideScreen extends ConsumerStatefulWidget {
  const UserGuideScreen({super.key});

  @override
  ConsumerState<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends ConsumerState<UserGuideScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  String _runtimeVersionName = ChangelogService.effectiveVersionName;
  int _runtimeVersionCode = ChangelogService.effectiveVersionCode;

  final Set<int> _expandedGuideIds = {1, 6, 10, 13, 17};
  final Set<int> _expandedFaqIds = {1};

  static const List<({String id, String emoji, String labelTr, String labelEn})> _categories = [
    (id: 'all', emoji: '🔍', labelTr: 'Tümü', labelEn: 'All'),
    (id: 'zikir', emoji: '📿', labelTr: 'Zikir & Tesbihat', labelEn: 'Dhikr & Tasbihat'),
    (id: 'kuran', emoji: '📖', labelTr: 'Kur\'ân & Külliyat', labelEn: 'Quran & Corpus'),
    (id: 'hatim_ezber', emoji: '🎧', labelTr: 'Hatim & Hafızlık', labelEn: 'Khatm & Hifz'),
    (id: 'namaz', emoji: '🕌', labelTr: 'Namaz, Kaza & İlmihal', labelEn: 'Prayer, Qada & Fiqh'),
    (id: 'sistem', emoji: '📊', labelTr: 'Panel, Seri & Sistem', labelEn: 'Dashboard, Streak & System'),
  ];

  static const List<_ShowcaseCardItem> _showcaseItems = [
    _ShowcaseCardItem(
      badgeTr: 'MUSHAF & SESLİ TİLAVET',
      badgeEn: 'MUSHAF & AUDIO RECITATION',
      titleTr: '4 Modlu Mushaf & Ok ile Kelime Takibi',
      titleEn: '4-Mode Mushaf & Arrow Word Tracking',
      descTr:
          'Mushaf | Âyet + Meâl | 7 Meâl Kıyaslama | 5 Klasik Tefsir ve sesli tilavette satır zıplatmayan hilâl uçlu Ok ile Takip / Kelime Vurgulama simülasyonu.',
      descEn:
          'Mushaf | Ayah + Translation | 7-Translation Comparison | 5 Classical Tafsirs with zero-layout-shift Crescent Arrow Tracking & Word Highlighting.',
      pillsTr: ['Mushaf', 'Âyet + Meâl', '7 Meâl Kıyaslama', '5 Klasik Tefsir', 'Ok ile Takip'],
      pillsEn: ['Mushaf', 'Ayah + Meal', '7 Translations', '5 Tafsirs', 'Arrow Pointer'],
      buttonTr: 'Mushaf\'ı Aç ➔',
      buttonEn: 'Open Mushaf ➔',
      route: '/mushaf?page=1',
      icon: Icons.auto_stories_rounded,
      accentTint: Color(0xFF10B981),
      showTrackingPreview: true,
    ),
    _ShowcaseCardItem(
      badgeTr: 'İSLÂMÎ İLİMLER KÜLLİYATI',
      badgeEn: 'ISLAMIC SCIENCES CORPUS',
      titleTr: '23 Eserlik İslâmî İlimler Külliyatı',
      titleEn: '23-Volume Islamic Sciences Library',
      descTr:
          'Kütüb-i Sitte (Buhârî, Müslim, Tirmizî, Ebû Dâvûd, Nesâî, İbn Mâce, Riyâzü\'s-Sâlihîn), 5 Klasik Tefsir (Kur\'ân Yolu, Râzî, Mâtürîdî, Keşşâf, Beyzâvî) ve DİB Tashihli Risale-i Nur Külliyatı + 4 renk metin vurgulama & ayraç.',
      descEn:
          'Kutub al-Sittah (Bukhari, Muslim, Tirmidhi, Abu Dawud, Nasa\'i, Ibn Majah, Riyad as-Salihin), 5 Classical Tafsirs, and Risale-i Nur Collection + 4-color text highlighting & bookmarks.',
      pillsTr: ['Kütüb-i Sitte', '5 Klasik Tefsir', 'Risale-i Nur', '4 Renk Vurgu & Ayraç'],
      pillsEn: ['Kutub al-Sittah', '5 Classical Tafsirs', 'Risale-i Nur', '4-Color Highlights'],
      buttonTr: 'Külliyat\'a Git ➔',
      buttonEn: 'Go to Corpus ➔',
      route: '/kuran',
      icon: Icons.local_library_rounded,
      accentTint: Color(0xFFD97706),
    ),
    _ShowcaseCardItem(
      badgeTr: 'AKILLI TESBİHAT & FAZİLET',
      badgeEn: 'SMART TASBIH & VIRTUES',
      titleTr: 'Akıllı Zikirmatik, Odak Modu & 146 Sahih Zikir',
      titleEn: 'Smart Dhikr Counter, Focus Mode & 146 Sahih Dhikrs',
      descTr:
          'Bülbül/Kumru sesli dairesel tesbih, gece zikri için tam ekran Odak Modu, sahih hadis/âyet fazilet çekmecesi, fiziksel zikirmatikten sayı aktarma ve Manevi Paylaşım Stüdyosu.',
      descEn:
          'Nightingale/Dove acoustic circular tasbih, full-screen night Focus Mode, authentic Hadith/Quran virtue drawer, physical counter import, and Spiritual Share Studio.',
      pillsTr: ['Bülbül & Kumru Sesi', 'Odak Modu', '146 Sahih Zikir', 'Paylaşım Stüdyosu'],
      pillsEn: ['Nightingale Sound', 'Focus Mode', '146 Sahih Dhikrs', 'Sharing Studio'],
      buttonTr: 'Zikirmatik\'i Aç ➔',
      buttonEn: 'Open Dhikr Counter ➔',
      route: '/zikir',
      icon: Icons.fingerprint_rounded,
      accentTint: Color(0xFF059669),
    ),
    _ShowcaseCardItem(
      badgeTr: 'TALİM & HAFIZLIK EĞİTİMİ',
      badgeEn: 'RECITATION & HIFZ TRAINING',
      titleTr: '5 İnteraktif Hafızlık & Talim Modu',
      titleEn: '5 Interactive Hifz & Recitation Modes',
      descTr:
          'Kelime Takipli Dinleme (arka planda/kilit ekranında kesintisiz), Kelime Bulmaca, Boşluk Doldurma, Sonraki Âyet ve Hafızlık Takibi ile sağlam ezber.',
      descEn:
          'Word-Tracked Listening (gapless background & lock-screen playback), Word Puzzle, Fill in the Blanks, Next Ayah quiz, and Hifz Progress Tracker.',
      pillsTr: ['Kelime Takipli Dinleme', 'Kelime Bulmaca', 'Boşluk Doldurma', 'Arka Plan Ses'],
      pillsEn: ['Word-Tracked Audio', 'Word Puzzle', 'Fill in Blanks', 'Background Audio'],
      buttonTr: 'Kur\'ân & Talim\'e Git ➔',
      buttonEn: 'Go to Quran & Talim ➔',
      route: '/kuran',
      icon: Icons.headphones_rounded,
      accentTint: Color(0xFF2563EB),
    ),
    _ShowcaseCardItem(
      badgeTr: 'VAKİT, KAZA & İLMİHAL',
      badgeEn: 'PRAYER, QADA & FIQH',
      titleTr: 'Hassas Vakitler, Kaza Havuzu & 32 Farz İlmihal',
      titleEn: 'Precise Times, Qada Pool & 32 Fard Fiqh Library',
      descTr:
          'Selçuklu analog namaz saati, vakit çıkmadan önce "Namazınızı Kıldınız mı?" hatırlatıcısı, Kaza Eritme Havuzu, Kıble Pusulası ve 32 Farz İlmihal Rehberi.',
      descEn:
          'Seljuk analog prayer clock, pre-exit "Did you pray?" smart reminder, Qada Debt Melting Pool, Qibla Compass, and 32 Fard Fiqh Manual.',
      pillsTr: ['Selçuklu Analog Saat', 'Kaza Havuzu', 'Kıble Pusulası', '32 Farz İlmihal'],
      pillsEn: ['Seljuk Analog Clock', 'Qada Pool', 'Qibla Compass', '32 Fard Fiqh'],
      buttonTr: 'Namaz Vakitleri\'ne Git ➔',
      buttonEn: 'Go to Prayer Times ➔',
      route: '/namaz',
      icon: Icons.mosque_rounded,
      accentTint: Color(0xFF7C3AED),
    ),
  ];

  static const List<_GuideStepItem> _guideItems = [
    // ================= 1. ZİKİR & TESBİHAT KILAVUZU =================
    _GuideStepItem(
      id: 1,
      categoryId: 'zikir',
      iconEmoji: '📿',
      iconData: Icons.fingerprint_rounded,
      titleTr: '1. Zikir Çekme, Hedef & Sonsuz Mod',
      titleEn: '1. Counting Dhikr, Target & Endless Mode',
      summaryTr:
          'Dairesel tesbih halkası, akustik ses modları (Bülbül, Kumru, Klasik) ve Hedefli/Sonsuz sayaç kullanımı.',
      summaryEn:
          'Circular tasbih ring, acoustic sound modes (Nightingale, Dove, Classic), and Target/Endless counter usage.',
      stepsTr: [
        'Zikirmatik ekranındaki büyük dairesel tesbih halkasına dokunarak (masaüstünde Boşluk tuşu veya fare tekerleği ile) zikir çekin.',
        'Ekranın sol ve sağ yanındaki hızlı kontrol kulelerinden Ses (Bülbül, Kumru, Klasik Tıklama, Sessiz) ve Titreşim (Hafif, Orta, Güçlü) modunu anında değiştirin.',
        'Hedefli modda (ör. 33, 99, 100) hedefe ulaştığınızda özel titreşim ve tebrik bildirimi alırsınız; "Sonsuz (∞)" moduna geçerek sınır olmadan tesbihat yapabilirsiniz.',
        'Sayacı sıfırlamak veya mevcut turu kaydetmek için kontrol kulesindeki sıfırlama (↺) butonunu kullanın.',
      ],
      stepsEn: [
        'Tap anywhere on the central circular tasbih ring (or use Spacebar / mouse wheel on desktop) to increment your dhikr count.',
        'Use the left and right quick-control towers to toggle Sound (Nightingale, Dove, Classic Click, Silent) and Vibration intensity.',
        'In Target mode (e.g., 33, 99, 100), receive celebratory haptic feedback upon completion, or switch to Endless (∞) mode for unrestricted counting.',
        'Tap the reset (↺) button on the control tower whenever you wish to reset the current round.',
      ],
      proTipTr:
          'Gözünüz ekrana bakmadan zikir çekerken her 33\'lük devirde farklı bir titreşim deseni hissedersiniz; böylece tesbihi elinizde tutuyormuş gibi takip edebilirsiniz.',
      proTipEn:
          'When counting without looking at the screen, every 33rd bead triggers a distinct haptic pulse so you can track rounds by touch alone.',
      actionLabelTr: 'Zikirmatik\'i Aç',
      actionLabelEn: 'Open Dhikr Counter',
      route: '/zikir',
      searchKeywords: ['zikir', 'tesbih', 'bülbül', 'kumru', 'ses', 'titreşim', 'sonsuz', 'hedef', 'sayaç'],
    ),
    _GuideStepItem(
      id: 2,
      categoryId: 'zikir',
      iconEmoji: '🌙',
      iconData: Icons.center_focus_strong_rounded,
      titleTr: '2. Odak Modu (Tam Ekran Gece Zikri)',
      titleEn: '2. Focus Mode (Full-Screen Night Dhikr)',
      summaryTr:
          'Alt menüyü ve dikkat dağıtıcı tüm öğeleri gizleyerek dev sayaçla huşû içinde tesbihat yapma.',
      summaryEn:
          'Hide the bottom navigation bar and distractions to perform dhikr in serenity with a giant counter.',
      stepsTr: [
        'Zikirmatik ekranının üst kontrol şeridinde yer alan "Odak Modu" (ekran genişletme) ikonuna dokunun.',
        'Alt navigasyon çubuğu ve yan paneller gizlenir; ekranda yalnızca okuduğunuz zikrin Arapça/Türkçe metni ve dev sayaç kalır.',
        'Gece karanlığında göz yormadan ekranın herhangi bir yerine dokunarak zikir çekmeye devam edin.',
        'Normal görünüme dönmek için üstteki "Odak Modundan Çık" butonuna dokunmanız yeterlidir.',
      ],
      stepsEn: [
        'Tap the "Focus Mode" (expand icon) located in the top control bar of the Dhikr Counter screen.',
        'The bottom navigation bar and side panels gracefully hide, leaving only the dhikr text and an oversized counter.',
        'Tap anywhere on the dimmed canvas during night worship without straining your eyes.',
        'Tap the top exit button anytime to restore the standard interface.',
      ],
      proTipTr:
          'Odak Modu\'nu "Koyu (Kahve Gece)" veya "Gece Mavisi" temasıyla birlikte kullandığınızda OLED ekranlarda pil tasarrufu maksimuma çıkar.',
      proTipEn:
          'Pairing Focus Mode with the "Dark Coffee" or "Midnight Blue" theme maximizes battery savings on OLED displays.',
      actionLabelTr: 'Zikirmatik\'te Dene',
      actionLabelEn: 'Try in Dhikr Counter',
      route: '/zikir',
      searchKeywords: ['odak', 'focus', 'gece', 'tam ekran', 'gizle', 'huşu'],
    ),
    _GuideStepItem(
      id: 3,
      categoryId: 'zikir',
      iconEmoji: '📜',
      iconData: Icons.auto_awesome_rounded,
      titleTr: '3. Sahih Fazilet, Hadis & Âyet Kaynakları (146 Zikir)',
      titleEn: '3. Authentic Virtues, Hadith & Quran Sources (146 Dhikrs)',
      summaryTr:
          '36 Peygamber duası, 12 Hadis zikri ve 99 Esmâü\'l-Hüsnâ\'nın Kütüb-i Sitte kaynakları ve tasavvufî şerhleri.',
      summaryEn:
          'Explore Kutub al-Sittah references and spiritual commentaries for 36 Prophetic Duas, 12 Hadith Dhikrs, and 99 Asma ul-Husna.',
      stepsTr: [
        'Zikirmatik ekranında üstteki zikir başlığına/kutusuna dokunun veya alt menüden "Zikir Listesi" (2. sekme) ekranına geçin.',
        'Açılan Fazilet ve Şerh çekmecesinde zikrin Arapça harekeli metnini, Türkçe okunuşunu ve sahih meâlini okuyun.',
        'Dualar kategorisindeki 36 peygamber duasının Kur\'ân sûre/âyet referanslarını; Esmâü\'l-Hüsnâ ve Hadis zikirlerinin Buhârî, Müslim, Tirmizî, Ebû Dâvûd, Nesâî ve İbn Mâce kaynaklarını inceleyin.',
        'Dilerseniz bu fazilet metnini doğrudan "Paylaş" butonuyla manevi kart olarak sevdiklerinize gönderin.',
      ],
      stepsEn: [
        'Tap the dhikr title card at the top of the counter screen or open the "Dhikr List" (2nd tab).',
        'Read the vocalized Arabic text, transliteration, and authentic translation inside the Virtue & Commentary drawer.',
        'Review exact Quranic Surah/Ayah citations for 36 Prophetic Duas and Kutub al-Sittah Hadith references for 99 Names of Allah.',
        'Tap "Share" to turn any dhikr and its authentic source into a high-resolution spiritual card.',
      ],
      proTipTr:
          'Zikir Listesi\'nde kategori sekmelerini (Esmâü\'l-Hüsnâ, Dualar, Hadislerden, Sabah-Akşam) kullanarak o vakte uygun tesbihatı saniyeler içinde seçebilirsiniz.',
      proTipEn:
          'Use the category tabs in the Dhikr List (Asma ul-Husna, Duas, From Hadith, Morning-Evening) to quickly pick the right litany for the time of day.',
      actionLabelTr: 'Zikir Listesi\'ni Aç',
      actionLabelEn: 'Open Dhikr List',
      route: '/zikirlist',
      searchKeywords: ['fazilet', 'hadis', 'esma', 'esmaül hüsna', 'dua', 'buhari', 'müslim', '146', 'kaynak', 'mana'],
    ),
    _GuideStepItem(
      id: 4,
      categoryId: 'zikir',
      iconEmoji: '📥',
      iconData: Icons.playlist_add_check_circle_rounded,
      titleTr: '4. Özel Zikir Ekleme & Fiziksel Zikirmatikten Aktarma',
      titleEn: '4. Custom Dhikrs & Importing from Physical Counter',
      summaryTr:
          'Kendi virdinizi oluşturma ve elinizdeki fiziksel tesbihte/zikirmatikte çektiğiniz sayıyı uygulamaya aktarma.',
      summaryEn:
          'Create personal litanies and import counts from your physical hand counter or prayer beads.',
      stepsTr: [
        'Alt menüden "Zikir Listesi" ekranına gidin ve sağ üstteki "+" (Yeni Zikir Ekle) butonuna dokunun.',
        'Zikir adını, isteğe bağlı Arapça metnini, anlamını, günlük hedef sayısını ve kategorisini girerek kendi özel zikrinizi kaydedin.',
        'Elinizdeki fiziksel tesbihte veya yüzük zikirmatikte çektiğiniz sayıyı eklemek için zikir kartındaki "Arşiv / Sayı Ekle (📥)" ikonuna dokunun.',
        'Çektiğiniz adedi yazıp onayladığınızda sayı hem o zikrin toplamına hem de günlük/haftalık istatistiklerinize anında eklenir.',
      ],
      stepsEn: [
        'Navigate to the "Dhikr List" tab and tap the "+" (Add New Dhikr) button at the top right.',
        'Enter the dhikr title, optional Arabic script, meaning, target count, and category to save your custom litany.',
        'To import counts from a physical ring counter or prayer beads, tap the "Import Count (📥)" icon on any dhikr card.',
        'Enter the number you recited; it will immediately be added to your daily statistics and total dhikr history.',
      ],
      proTipTr:
          'Dışarıda yürürken yüzük zikirmatikle çektiğiniz binlerce salavatı akşam tek dokunuşla Zikirce\'ye aktararak günlük serinizi (streak) koruyabilirsiniz.',
      proTipEn:
          'You can count on a physical ring counter during the day and import the total in the evening with a single tap to keep your daily streak alive.',
      actionLabelTr: 'Zikir Listesi\'ne Git',
      actionLabelEn: 'Go to Dhikr List',
      route: '/zikirlist',
      searchKeywords: ['özel zikir', 'ekle', 'fiziksel', 'aktarma', 'arşiv', 'sayı ekle', 'yüzük', 'tesbih'],
    ),
    _GuideStepItem(
      id: 5,
      categoryId: 'zikir',
      iconEmoji: '🎨',
      iconData: Icons.share_rounded,
      titleTr: '5. Manevi Paylaşım Stüdyosu (Story & Kare Kartlar)',
      titleEn: '5. Spiritual Sharing Studio (Story & Square Cards)',
      summaryTr:
          'Zikir, seri ve istatistiklerinizi Story (9:16) veya Kare (1:1) formatında, Cuma/Kandil rozetleriyle paylaşma.',
      summaryEn:
          'Share your dhikr, streak, and stats in Story (9:16) or Square (1:1) format with Friday/Kandil badges.',
      stepsTr: [
        'Zikirmatik, Zikir Listesi veya Panel ekranındaki "Paylaş" ikonuna dokunarak Manevi Paylaşım Stüdyosu\'nu açın.',
        'Üstten kart formatını seçin: Instagram/WhatsApp Durum için "Story (9:16)" veya gönderi/sohbet için "Kare (1:1)".',
        'Tahrir/Selçuklu sanat temalarından birini seçin; Cuma veya Kandil günlerinde otomatik eklenen tebrik rozetlerini ve âyet/hadis alıntılarını önizleyin.',
        '"Paylaş" butonuyla 4x yüksek çözünürlüklü (kesintisiz/taşmasız) PNG kartı WhatsApp, Instagram veya Telegram\'a gönderin.',
      ],
      stepsEn: [
        'Tap the "Share" icon on the Counter, Dhikr List, or Dashboard screen to launch the Spiritual Sharing Studio.',
        'Choose your aspect ratio: "Story (9:16)" for WhatsApp/Instagram Stories or "Square (1:1)" for feeds and chats.',
        'Pick from Tahrir/Seljuk artistic themes and preview automatic Friday/Holy Night badges with full Quran/Hadith citations.',
        'Tap "Share" to export a crisp 4x high-resolution PNG card directly to WhatsApp, Instagram, or Telegram.',
      ],
      proTipTr:
          'Günlük zikir, namaz veya Kur\'ân hedefinizi tamamladığınızda açılan tebrik penceresinden tek dokunuşla o güne özel başarı kartı oluşturabilirsiniz.',
      proTipEn:
          'Whenever you complete your daily dhikr, prayer, or Quran goal, the celebration prompt lets you generate a milestone card in one tap.',
      actionLabelTr: 'Paylaşım Stüdyosu\'nu Aç',
      actionLabelEn: 'Open Sharing Studio',
      route: 'ACTION_SHARE_STUDIO',
      searchKeywords: ['paylaş', 'story', 'hikaye', 'kare', 'cuma', 'kandil', 'kart', 'stüdyo', 'instagram', 'whatsapp'],
    ),

    // ================= 2. KUR'ÂN-I KERÎM & KÜLLİYAT KILAVUZU =================
    _GuideStepItem(
      id: 6,
      categoryId: 'kuran',
      iconEmoji: '📖',
      iconData: Icons.menu_book_rounded,
      titleTr: '6. 4 Modlu Kur\'ân Okuma (Mushaf / Âyet+Meâl / Meâl / Tefsir)',
      titleEn: '6. 4-Mode Quran Reading (Mushaf / Ayah+Meal / Meal / Tafsir)',
      summaryTr:
          'Tek ekranda Diyanet Mushaf düzeni, satır altı Âyet+Meâl, akıcı Tahrir kitap meâli ve sayfa içi Tefsir modu.',
      summaryEn:
          'Switch seamlessly between Diyanet Mushaf layout, Ayah+Translation, Tahrir book-style translation, and inline Tafsir.',
      stepsTr: [
        'Alt menüden "Kur\'ân" (5. sekme) ekranına gidin ve "Mushaf Oku" kartına veya istediğiniz sûreye/cüze dokunun.',
        'Mushaf ekranının üst barındaki 4\'lü mod seçiciyi kullanın: "Mushaf" (tam sayfa Arapça), "Âyet+Meâl", "Meâl" veya "Tefsir".',
        '"Meâl" modunda ister Tahrir stili akıcı kitap paragrafları halinde, ister âyet kartları halinde Türkçe meâl okuyun.',
        'Üst bardaki "Aa" butonuna dokunarak Arapça (AmasyaAbay) ve Türkçe yazı boyutlarını, satır aralıklarını ve görünüm temasını kendinize göre ayarlayın.',
      ],
      stepsEn: [
        'Open the "Quran" tab (5th tab) and tap "Read Mushaf" or select any Surah/Juz from the grid.',
        'Use the 4-way mode switcher in the top bar: "Mushaf" (full Arabic page), "Ayah+Meal", "Meal", or "Tafsir".',
        'In "Meal" mode, toggle between flowing Tahrir book-style paragraphs and structured verse cards.',
        'Tap the "Aa" button in the top bar to customize Arabic (AmasyaAbay) and translation font sizes, line spacing, and reading themes.',
      ],
      proTipTr:
          'Sûre başlıklarındaki bilgi (ℹ️) rozetine dokunarak o sûrenin nüzul sebebini, faziletini ve ana konularını özetleyen Sûre Tanıtım kartını okuyabilirsiniz.',
      proTipEn:
          'Tap the info (ℹ️) badge on any Surah header to read its revelation background, virtues, and key themes.',
      actionLabelTr: 'Mushaf\'ı Aç',
      actionLabelEn: 'Open Mushaf',
      route: '/mushaf?page=1',
      searchKeywords: ['mushaf', 'kuran', 'okuma', '4 mod', 'ayet', 'meal', 'tefsir', 'font', 'punto', 'aa'],
    ),
    _GuideStepItem(
      id: 7,
      categoryId: 'kuran',
      iconEmoji: '🏹',
      iconData: Icons.ads_click_rounded,
      titleTr: '7. Kelime Vurgulama & Ok ile Takip (İşaretçi Sistemi)',
      titleEn: '7. Word Highlighting & Crescent Arrow Pointer Tracking',
      summaryTr:
          'Sesli tilavet sırasında okunan kelimenin renkli vurgulanması veya satır zıplatmayan hilâl uçlu Ok ile Takip.',
      summaryEn:
          'Highlight the active spoken word or track it with a smooth crescent-tipped arrow underneath without shifting lines.',
      stepsTr: [
        'Mushaf, Mukabele veya Kelime Takipli Dinleme ekranında alt oynatıcıdan "Oynat (▶)" butonuna basarak sesli tilaveti başlatın.',
        'Kâri (Osman Şahin) âyeti okurken, gerçek MP3 ses dalgası senkronizasyonu ile okunan Arapça kelime anlık olarak takip edilir.',
        'Takip stilini değiştirmek için Mushaf üst barındaki "Aa" çekmecesini açın veya "Ayarlar > Kur\'ân-ı Kerîm" bölümüne gidin.',
        '"Kelime İşaretleme (Vurgulu)" veya satır yüksekliğini hiç değiştirmeden kelimenin tam altında süzülen "Ok ile Takip (İşaretçi)" modundan dilediğinizi seçin.',
      ],
      stepsEn: [
        'Press "Play (▶)" on the bottom audio bar in Mushaf, Mukabele, or Word-Tracked Listening screens.',
        'As the reciter reads, acoustic waveform timestamps track each exact Arabic word in real time.',
        'To switch tracking styles, open the "Aa" typography drawer in Mushaf or visit "Settings > Quran".',
        'Choose between "Word Highlighting" or the zero-layout-shift "Arrow Pointer" that glides smoothly beneath the active word.',
      ],
      proTipTr:
          'Ok ile Takip (İşaretçi) modu, geleneksel rahle başı Kur\'ân eğitimindeki "hilâl uçlu elifbâ işaretçisi" hissiyatını dijital ekrana taşır ve göz takibini çok kolaylaştırır.',
      proTipEn:
          'The Crescent Arrow Pointer replicates the traditional wooden Quran pointer used in classical study circles, keeping line heights 100% stable.',
      actionLabelTr: 'Mushaf\'ta Gör',
      actionLabelEn: 'Try in Mushaf',
      route: '/mushaf?page=1',
      searchKeywords: ['ok ile takip', 'işaretçi', 'kelime takip', 'vurgulama', 'sesli', 'tilavet', 'hilal', 'ok', 'senkron'],
    ),
    _GuideStepItem(
      id: 8,
      categoryId: 'kuran',
      iconEmoji: '⚖️',
      iconData: Icons.compare_arrows_rounded,
      titleTr: '8. 7 Türkçe Meâl Kıyaslama & 5 Klasik Tefsir Kütüphanesi',
      titleEn: '8. 7 Turkish Translations Comparison & 5 Classical Tafsirs',
      summaryTr:
          '7 seçkin meâli alt alta kıyaslama ve Kur\'ân Yolu, Râzî, Mâtürîdî, Keşşâf ve Beyzâvî tefsirlerini okuma.',
      summaryEn:
          'Compare 7 translations side-by-side and read full-text Kur\'an Yolu, Razi, Maturidi, Kashshaf, and Baydawi tafsirs.',
      stepsTr: [
        'Mushaf\'ta herhangi bir âyete dokunun veya "Aa" görünüm menüsünden aktif meâl kaynağını seçin (Diyanet, Elmalılı Orijinal/Sadeleştirilmiş, Hasan Basri Çantay, TDV, Ali Fikri Yavuz, Suat Yıldırım + Türkçe Okunuş).',
        'Bir âyetin farklı âlimlerce nasıl tercüme edildiğini görmek için âyet menüsünden "Meâl Karşılaştırma" seçeneğine dokunun.',
        'Derinlemesine âyet açıklaması için üst bardan "Tefsir" moduna geçin veya âyet detayından "Tefsir Oku" çekmecesini açın.',
        '5 büyük tefsir kaynağından (DİB Kur\'ân Yolu, Fahreddin er-Râzî Mefâtîhu\'l-Gayb, İmam Mâtürîdî Te\'vîlâtü\'l-Kur\'ân, Zemahşerî el-Keşşâf, Beyzâvî Envârü\'t-Tenzîl) dilediğinizi seçip tam metin okuyun.',
      ],
      stepsEn: [
        'Tap any verse in Mushaf or open the "Aa" menu to select from 7 Turkish translations plus Latin transliteration.',
        'Select "Compare Translations" on any verse to view multiple scholars\' renderings side by side.',
        'Switch to the top "Tafsir" mode or tap "Read Tafsir" on a verse to access deep exegesis.',
        'Switch freely between 5 complete classical tafsirs: Kur\'an Yolu, Fakhr al-Din al-Razi, Imam al-Maturidi, al-Zamakhshari (Kashshaf), and al-Baydawi.',
      ],
      proTipTr:
          'Seçtiğiniz tefsir kaynağı ilk açılışta saniyeler içinde cihazınıza indirilir ve sonrasında internet bağlantısı olmadan (çevrimdışı) 6.236 âyetin tamamında çalışır.',
      proTipEn:
          'Each Tafsir volume downloads automatically in seconds on first use and works 100% offline across all 6,236 verses thereafter.',
      actionLabelTr: 'Kur\'ân Sayfasına Git',
      actionLabelEn: 'Go to Quran Page',
      route: '/kuran',
      searchKeywords: ['meal', 'kıyaslama', 'karşılaştırma', 'tefsir', 'razi', 'maturidi', 'keşşaf', 'beyzavi', 'kuran yolu', 'elmalılı', 'diyanet'],
    ),
    _GuideStepItem(
      id: 9,
      categoryId: 'kuran',
      iconEmoji: '📚',
      iconData: Icons.bookmarks_rounded,
      titleTr: '9. 23 Eserlik Külliyat Okuyucu, Vurgulama & Ayraç',
      titleEn: '9. 23-Volume Corpus Reader, 4-Color Highlights & Bookmarks',
      summaryTr:
          'Kütüb-i Sitte, 5 Tefsir ve DİB Tashihli Risale-i Nur Külliyatı\'nda kitap okuma, 4 renk kalemle çizme ve raf düzenleme.',
      summaryEn:
          'Read Kutub al-Sittah, 5 Tafsirs, and Risale-i Nur on the wooden bookshelf with 4-color highlights, bookmarks, and custom bindings.',
      stepsTr: [
        'Kur\'ân sayfasındaki ahşap "Külliyat" rafından Kütüb-i Sitte (Buhârî, Müslim, Tirmizî, Ebû Dâvûd, Nesâî, İbn Mâce, Riyâzü\'s-Sâlihîn) veya Risale-i Nur (Sözler, Mektubat, Lem\'alar, Şuâlar vb.) eserlerinden birine dokunun.',
        'Rafın sağ üstündeki "Düzenle" butonuna dokunarak kitapların raf sırasını, cilt/kapak renklerini ve sayfa tipografisini özelleştirin.',
        'Kitap okurken önemli bir cümleye basılı tutup metni seçin; açılan menüden 4 farklı renkle (Altın, Zümrüt, Mercan, Gök Mavisi) metni vurgulayın veya Paylaşım Kartı oluşturun.',
        'Üst bardaki Ayraç (🔖) ikonuna dokunarak önemli sayfalara notlu ayraç ekleyin ve İçindekiler/Arama panelinden tüm vurgularınıza tek tıkla ulaşın.',
      ],
      stepsEn: [
        'On the Quran screen, browse the "Külliyat" bookshelf and tap any volume from Kutub al-Sittah, Classical Tafsirs, or Risale-i Nur.',
        'Tap "Edit" at the top right of the shelf to customize book order, leather binding colors, and page typography.',
        'Long-press to select text inside any book, then highlight it in 4 colors (Gold, Emerald, Coral, Sky Blue) or share it as an art card.',
        'Tap the Bookmark (🔖) icon to save pages and access all your saved highlights and bookmarks from the index drawer.',
      ],
      proTipTr:
          'Tefsir ciltlerini Külliyat rafından açtığınızda her sayfa doğrudan 1 âyete (1..6236) karşılık gelir; sûre ve âyet seçerek istediğiniz âyetin tefsirine anında gidebilirsiniz.',
      proTipEn:
          'When opening Tafsir volumes from the bookshelf, pages map 1-to-1 with the 6,236 Quran verses so you can jump straight to any Surah and Ayah.',
      actionLabelTr: 'Külliyat Rafını Aç',
      actionLabelEn: 'Open Corpus Bookshelf',
      route: '/kuran',
      searchKeywords: ['külliyat', 'kitap', 'buhari', 'müslim', 'risale', 'sözler', 'mektubat', 'vurgulama', 'ayraç', 'cilt', 'raf'],
    ),

    // ================= 3. HATİM, MUKABELE & HAFIZLIK KILAVUZU =================
    _GuideStepItem(
      id: 10,
      categoryId: 'hatim_ezber',
      iconEmoji: '🎧',
      iconData: Icons.record_voice_over_rounded,
      titleTr: '10. Şahsi Hatim, Sesli Mukabele & Hatim Duası',
      titleEn: '10. Personal Khatm, Audio Mukabele & Khatm Prayer',
      summaryTr:
          '30 cüzlük hatim takibi, sesli takipli Mukabele okuma, cüz kartına basılı tutarak dinleme ve Matbû Hatim Duası.',
      summaryEn:
          '30-Juz Khatm tracking, audio-synced Mukabele, long-press Juz listening, and traditional Khatm Prayer.',
      stepsTr: [
        'Kur\'ân ekranındaki "Hatim & Mukabele" bölümünden yeni bir Şahsi Hatim başlatın veya mevcut hatminize devam edin.',
        'Sesli takipli okuma için "Mukabele" modunu açın; sayfalar ve âyetler okundukça kelime kelime takip edilir ve cüz ilerlemeniz otomatik kaydedilir.',
        'Kur\'ân sayfasındaki 30 Cüz ızgarasında herhangi bir Cüz kartına basılı tutarak doğrudan o cüzü sesli dinlemeye başlayın.',
        'Hatminiz tamamlandığında otomatik açılan (veya Kur\'ân ekranındaki "Hatim Duası" kartından her zaman ulaşılabilen) 5 bölümlük Matbû Hatim ve Bağışlama Duası\'nı okuyun.',
      ],
      stepsEn: [
        'Start a new Personal Khatm or continue your active Khatm from the "Khatm & Mukabele" section on the Quran screen.',
        'Open "Mukabele" mode for audio-synced reading where verses are tracked word-by-word and your Juz progress saves automatically.',
        'Long-press any Juz card in the 30-Juz grid on the Quran screen to immediately start audio playback for that Juz.',
        'Read the 5-part traditional Khatm & Dedication Prayer ("Dua Khatm al-Quran"), which opens automatically upon completion or anytime from the Quran quick-access strip.',
      ],
      proTipTr:
          'Zikirce dışında (fiziksel Mushaf\'tan) yaptığınız hatimler için de Kur\'ân sayfasındaki "Hatim Duası" kartına dokunarak Arapça, okunuş ve Türkçe meâlli duayı okuyabilirsiniz.',
      proTipEn:
          'Even if you completed a Khatm on a physical printed Mushaf, you can open the "Khatm Prayer" card anytime from the Quran screen.',
      actionLabelTr: 'Mukabele\'yi Aç',
      actionLabelEn: 'Open Mukabele',
      route: '/mukabele?page=1',
      searchKeywords: ['hatim', 'mukabele', 'cüz', 'hatim duası', 'bağışlama', 'sesli hatim', 'dinle'],
    ),
    _GuideStepItem(
      id: 11,
      categoryId: 'hatim_ezber',
      iconEmoji: '🧠',
      iconData: Icons.psychology_rounded,
      titleTr: '11. 5 İnteraktif Hafızlık & Talim Modu (Arka Plan Destekli)',
      titleEn: '11. 5 Interactive Hifz & Talim Modes (Background Audio)',
      summaryTr:
          'Kelime Takipli Dinleme, Kelime Bulmaca, Boşluk Doldurma, Sonraki Âyet testi ve kilit ekranında kesintisiz talim.',
      summaryEn:
          'Word-Tracked Listening, Word Puzzle, Fill in the Blanks, Next Ayah quiz, and gapless lock-screen playback.',
      stepsTr: [
        'Kur\'ân ekranındaki "Hafızlık & Talim" konsolundan 5 eğitim modundan birini seçin: Kelime Takipli Dinleme, Kelime Bulmaca, Boşluk Doldurma, Sonraki Âyet veya Hafızlık Takibi.',
        '"Kelime Takipli Dinleme" modunda sûre, sayfa, cüz veya âyet aralığı belirleyin; okuma hızını (0.75x - 1.5x) ve âyet tekrar sayısını (1x, 2x, 3x, 5x, ∞) ayarlayın.',
        'Ekranı kapatsanız veya başka uygulamaya geçseniz bile tilavet kesintisiz devam eder; Kilit Ekranı ve Dynamic Island üzerinden âyet geçişlerini kontrol edebilirsiniz.',
        '"Kelime Bulmaca" ve "Boşluk Doldurma" modlarında âyetin kelimelerini doğru sıraya dizerek ezberinizi oyunlaştırılmış testlerle pekiştirin.',
      ],
      stepsEn: [
        'Choose from 5 training modes on the Quran screen: Word-Tracked Listening, Word Puzzle, Fill in the Blanks, Next Ayah, or Hifz Tracker.',
        'In "Word-Tracked Listening", select a Surah, Page, Juz, or Ayah range, then set playback speed (0.75x–1.5x) and verse repeat count.',
        'Playback continues gaplessly when the screen is locked or in the background, with full Lock Screen & Dynamic Island media controls.',
        'Use "Word Puzzle" and "Fill in the Blanks" to test your memory by reconstructing verses word by word.',
      ],
      proTipTr:
          'Ezberlemek istediğiniz bir sayfayı "Kelime Takipli Dinleme" modunda 3 tekrar ve "Ok ile Takip" açık şekilde dinledikten sonra hemen "Kelime Bulmaca" moduna geçmek ezber süresini yarı yarıya kısaltır.',
      proTipEn:
          'Listening to a target page with 3x verse repeat and Arrow Tracking followed immediately by "Word Puzzle" cuts memorization time in half.',
      actionLabelTr: 'Hafızlık Ekranını Aç',
      actionLabelEn: 'Open Hifz Screen',
      route: '/ezber',
      searchKeywords: ['ezber', 'hafızlık', 'talim', 'kelime bulmaca', 'boşluk doldurma', 'sonraki ayet', 'arka plan', 'kilit ekranı', 'tekrar'],
    ),
    _GuideStepItem(
      id: 12,
      categoryId: 'hatim_ezber',
      iconEmoji: '🙇',
      iconData: Icons.spa_rounded,
      titleTr: '12. Tilâvet Secdesi Rehberi & Secde Âyetleri Sayacı',
      titleEn: '12. Sajdah Tilawah Guide & Prostration Verses Tracker',
      summaryTr:
          'Kur\'ân\'daki 14 secde âyetini görüntüleme, okunan/yapılan secdeleri kaydetme ve adım adım uygulama rehberi.',
      summaryEn:
          'View all 14 prostration verses in the Quran, track pending/completed sajdahs, and read the step-by-step guide.',
      stepsTr: [
        'Kur\'ân sayfasının üst hızlı erişim şeridindeki "Tilâvet Secdesi" ikonuna dokunun.',
        'Kur\'ân-ı Kerîm\'de yer alan 14 secde âyetinin sûre, âyet ve cüz numaralarını liste halinde inceleyin.',
        'Okuduğunuz secde âyetlerini "+" ile kaydedin ve tilâvet secdesini yaptığınızda "Secde Yapıldı" olarak işaretleyip üzerinizdeki borcu takip edin.',
        'Rehber sekmesinden tilâvet secdesinin niyetini, rükünlerini ve okunacak tesbih dualarını ("Secede vechiye lillezî halakahû...") adım adım okuyun.',
      ],
      stepsEn: [
        'Tap the "Sajdah Tilawah" icon in the top quick-access ribbon of the Quran screen.',
        'Browse all 14 Quranic prostration verses with their exact Surah, Ayah, and Juz numbers.',
        'Log verses you have recited/heard and mark them as completed once you perform the prostration.',
        'Read the built-in step-by-step fiqh guide covering intention, posture, and authentic supplications.',
      ],
      proTipTr:
          'Mushaf\'ta veya Mukabele\'de secde âyeti bulunan bir sayfayı okurken sistem sizi zarif bir rozetle bilgilendirir.',
      proTipEn:
          'When reading a page containing a prostration verse in Mushaf or Mukabele, a subtle badge reminds you of the Sajdah verse.',
      actionLabelTr: 'Kur\'ân Ekranına Git',
      actionLabelEn: 'Go to Quran Screen',
      route: '/kuran',
      searchKeywords: ['tilavet secdesi', 'secde', '14 secde', 'secde ayetleri'],
    ),

    // ================= 4. NAMAZ, KAZA & İLMİHAL KILAVUZU =================
    _GuideStepItem(
      id: 13,
      categoryId: 'namaz',
      iconEmoji: '🕌',
      iconData: Icons.access_time_filled_rounded,
      titleTr: '13. Konum Seçimi, Selçuklu Analog Saati & Vakit Takibi',
      titleEn: '13. Location Selection, Seljuk Analog Clock & Prayer Tracking',
      summaryTr:
          'Diyanet uyumlu hassas namaz vakitleri, canlı vakit dilimli Selçuklu analog saati ve günlük 5 vakit eda çizelgesi.',
      summaryEn:
          'Diyanet-accurate prayer times, live sector-highlighted Seljuk analog clock, and daily 5-prayer completion log.',
      stepsTr: [
        'Alt menüden "Namaz Vakitleri" (4. sekme) ekranına gidin; üstteki şehir/ilçe adına dokunarak GPS ile otomatik konum bulun veya 81 il / dünya şehirlerinden seçim yapın.',
        'Vakit kartındaki 8 köşeli Selçuklu yıldızı motifli Analog Namaz Saati üzerinden mevcut vaktin dilimini ve kalan süreyi canlı izleyin.',
        'Gün içinde kıldığınız her vaktin yanındaki onay kutusuna dokunarak (İmsak/Sabah, Öğle, İkindi, Akşam, Yatsı) günlük namaz hedefinizi tamamlayın.',
        '5 vaktin tamamını işaretlediğinizde günlük namaz seriniz (streak) güçlenir ve manevi tebrik kartı paylaşabilirsiniz.',
      ],
      stepsEn: [
        'Open the "Prayer Times" tab (4th tab) and tap the city name at the top to detect GPS location or pick from cities worldwide.',
        'Watch the 8-pointed Seljuk star Analog Prayer Clock dial highlighting the active prayer sector and live countdown.',
        'Check off each daily prayer (Fajr, Dhuhr, Asr, Maghrib, Isha) as you perform it throughout the day.',
        'Completing all 5 daily prayers reinforces your spiritual streak and unlocks daily milestone sharing.',
      ],
      proTipTr:
          'Seyahate çıktığınızda şehir adına dokunup "GPS ile Konumu Güncelle" demeniz hem uygulama içi vakitleri hem de kilit ekranı widget\'larını anında yeni şehre göre ayarlar.',
      proTipEn:
          'When traveling, tapping the city name and refreshing GPS updates both in-app prayer times and all Home/Lock Screen widgets instantaneously.',
      actionLabelTr: 'Namaz Vakitleri\'ni Aç',
      actionLabelEn: 'Open Prayer Times',
      route: '/namaz',
      searchKeywords: ['namaz', 'vakit', 'konum', 'şehir', 'selçuklu', 'analog saat', 'ezan', 'imsak', 'yatsı'],
    ),
    _GuideStepItem(
      id: 14,
      categoryId: 'namaz',
      iconEmoji: '🔔',
      iconData: Icons.notifications_active_rounded,
      titleTr: '14. Merkezi Namaz Bildirimleri & Kaza Takip Sorusu',
      titleEn: '14. Central Prayer Notifications & Missed Prayer Prompt',
      summaryTr:
          'Vakit girdiğinde ve vakit çıkmadan önce bildirim alma; "Namazınızı Kıldınız mı?" hatırlatıcısı ile kaza önleme.',
      summaryEn:
          'Receive alerts at prayer entry and before exit, plus the smart "Did you pray?" prompt to prevent missed prayers.',
      stepsTr: [
        'Namaz Vakitleri ekranının sağ üst köşesindeki Zil (🔔) ikonuna (veya Ayarlar > Namaz Bildirimleri\'ne) dokunarak merkezi bildirim panelini açın.',
        'Her vakit için ayrı ayrı "Vakit Girdiğinde Bildir" ve "Vakit Çıkmadan Önce Uyarı" (15, 30 veya 45 dk önce) seçeneklerini ayarlayın.',
        '"Kaza Takip Hatırlatıcısı (Namazınızı Kıldınız mı? 🕌)" özelliğini aktif edin.',
        'Eğer o vakti henüz işaretlemediyseniz vakit çıkmadan önce gelen bildirime dokunarak namazınızı eda edebilir veya unuttuysanız kaza havuzuna kaydedebilirsiniz.',
      ],
      stepsEn: [
        'Tap the Bell (🔔) icon at the top right of the Prayer Times screen (or in Settings) to open the notification sheet.',
        'Configure "At Prayer Time" alerts and "Before Prayer Ends" warnings (15, 30, or 45 mins prior) per prayer.',
        'Enable the "Qada Tracking Reminder (Did you pray? 🕌)" toggle.',
        'If a prayer isn\'t checked off before its window closes, Zikirce gently reminds you so no prayer is accidentally missed.',
      ],
      proTipTr:
          'Paneldeki "Test Bildirimi Gönder" butonuna dokunarak cihazınızın ses ve bildirim izinlerinin sorunsuz çalıştığını anında doğrulayabilirsiniz.',
      proTipEn:
          'Use the "Send Test Notification" button inside the notification sheet to verify your device\'s sound and alert permissions immediately.',
      actionLabelTr: 'Bildirimleri Yönet',
      actionLabelEn: 'Manage Notifications',
      route: '/namaz',
      searchKeywords: ['bildirim', 'ezan sesi', 'uyarı', 'namazınızı kıldınız mı', 'hatırlatıcı', 'vakit çıkmadan'],
    ),
    _GuideStepItem(
      id: 15,
      categoryId: 'namaz',
      iconEmoji: '⏳',
      iconData: Icons.explore_rounded,
      titleTr: '15. Kaza Eritme Havuzu & Hassas Kıble Pusulası',
      titleEn: '15. Qada Debt Melting Pool & Precision Qibla Compass',
      summaryTr:
          'Geçmiş kaza namazı borçlarını hesaplama, kıldıkça eritme yüzdesini izleme ve manyetik Kıble Pusulası.',
      summaryEn:
          'Calculate past missed prayers, track your weekly/overall completion percentage, and find Qibla direction.',
      stepsTr: [
        'Namaz Vakitleri ekranında aşağı kaydırarak "Kaza Namazı Havuzu" kartını açın.',
        'Geçmiş kaza borçlarınızı yıl/ay/gün bazında toplu hesaplayın veya Sabah, Öğle, İkindi, Akşam, Yatsı ve Vitir sayılarını elle girin.',
        'Her kaza namazı kıldığınızda "-" butonuna dokunarak borcunuzdan düşün; haftalık eritme grafiğinizi ve genel tamamlanma yüzdesini takip edin.',
        'Aynı ekrandaki "Kıble Pusulası" kartını açarak bulunduğunuz konuma göre Kâbe açısını (derece) ve pusula ibresini canlı görün; ibre Kâbe ile hizalandığında yeşil yanar ve titreşim verir.',
      ],
      stepsEn: [
        'Scroll down on the Prayer Times screen to locate the "Qada Prayer Pool" card.',
        'Calculate past missed prayers by duration or manually set counts for Fajr, Dhuhr, Asr, Maghrib, Isha, and Witr.',
        'Tap "-" each time you pray a make-up prayer to watch your debt melt away with weekly progress analytics.',
        'Open the "Qibla Compass" card to see your exact Kaaba bearing angle; the dial glows emerald and vibrates when aligned with Qibla.',
      ],
      proTipTr:
          'Her farz namazın ardından sadece 1 kaza namazı kılarak yılda 365 günlük (1 yıllık) kaza borcunu kolaylıkla eritebilirsiniz.',
      proTipEn:
          'Praying just 1 Qada prayer after each of the 5 daily prayers melts away 1 full year (365 days) of missed prayers every single year.',
      actionLabelTr: 'Kaza & Kıble\'ye Git',
      actionLabelEn: 'Go to Qada & Qibla',
      route: '/namaz',
      searchKeywords: ['kaza', 'kaza namazı', 'havuz', 'borç', 'vitir', 'kıble', 'pusula', 'kabe'],
    ),
    _GuideStepItem(
      id: 16,
      categoryId: 'namaz',
      iconEmoji: '🏛️',
      iconData: Icons.account_balance_rounded,
      titleTr: '16. 32 Farz İlmihal Kütüphanesi',
      titleEn: '16. 32 Fard Fiqh & Catechism Library',
      summaryTr:
          'İmanın, İslam\'ın, Abdestin, Guslün, Teyemmümün ve Namazın farzlarını delilleriyle okuma ve ilerleme takibi.',
      summaryEn:
          'Study the 32 Fards of Faith, Islam, Wudu, Ghusl, Tayammum, and Prayer with clear explanations and read tracking.',
      stepsTr: [
        'Namaz Vakitleri ekranından veya Ayarlar > Fıkıh Kitaplığı menüsünden "32 Farz İlmihal Kütüphanesi" ekranını açın.',
        'İmanın Şartları (6), İslam\'ın Şartları (5), Abdestin Farzları (4), Guslün Farzları (3), Teyemmümün Farzları (2) ve Namazın Farzları (12: Dışından 6, İçinden 6) kategorileri arasında geçiş yapın.',
        'Üstteki arama çubuğuyla merak ettiğiniz fıkhî konuyu (ör. "mesh", "kıraat", "kade-i ahire", "niyet") anında arayın.',
        'Okuduğunuz maddeleri "Okundu" olarak işaretleyerek 32 Farz ilmihal bilginizi %100\'e tamamlayın.',
      ],
      stepsEn: [
        'Open the "32 Fard Fiqh Library" from the Prayer Times screen or Settings > Fiqh Library.',
        'Filter by Pillars of Faith (6), Islam (5), Wudu (4), Ghusl (3), Tayammum (2), and Prayer (12).',
        'Use the instant search bar to look up any ruling or pillar.',
        'Mark items as "Read" to track your catechism mastery up to 100%.',
      ],
      proTipTr:
          'Çocuklarınıza veya aile bireylerine temel dini bilgileri öğretirken 32 Farz ekranındaki ilerleme çubuğunu eğitici bir kontrol listesi olarak kullanabilirsiniz.',
      proTipEn:
          'The 32 Fard progress bar serves as an engaging educational checklist when teaching foundational Islamic knowledge to family members.',
      actionLabelTr: '32 Farz İlmihal\'i Aç',
      actionLabelEn: 'Open 32 Fard Library',
      route: '/fiqh',
      searchKeywords: ['32 farz', 'ilmihal', 'fıkıh', 'abdest', 'gusül', 'teyemmüm', 'iman', 'islam', 'şart'],
    ),

    // ================= 5. PANEL, SERİ, BULUT & SİSTEM KILAVUZU =================
    _GuideStepItem(
      id: 17,
      categoryId: 'sistem',
      iconEmoji: '🔥',
      iconData: Icons.local_fire_department_rounded,
      titleTr: '17. Manevi Seri (Streak), Makam Rütbeleri & 40 Okuma Rozetleri',
      titleEn: '17. Spiritual Streak, Spiritual Ranks & 40-Recitation Badges',
      summaryTr:
          'Günlük ibadet zincirini koruma, Elmas ile seri kurtarma, Sâlik\'ten Velî\'ye makamlar ve Yâsîn/Mülk/Vâkıa/Kehf rozetleri.',
      summaryEn:
          'Maintain your daily worship chain, freeze/restore streaks with Diamonds, rise through Spiritual Ranks, and unlock Surah badges.',
      stepsTr: [
        'Alt menünün ilk sekmesi olan "Panel (Bismillah Dashboard)" ekranını açarak günlük zikir, namaz, Kur\'ân ve ezber hedeflerinizin doluluk oranını izleyin.',
        'Her gün ibadet hedefinizi tamamladığınızda "Manevi Seri (🔥)" sayacınız artar ve kazandığınız puanlarla rütbeniz Mübtedi ➔ Sâlik ➔ Ârif ➔ Velî makamlarına yükselir.',
        'Unutulan bir günde seriniz bozulursa Panel\'deki seri kartından "Elmas (💎)" kullanarak serinizi kaldığı yerden kurtarabilirsiniz.',
        'Yâsîn, Mülk (Tebâreke), Vâkıa, Kehf, Fetih, Rahmân ve Amme (Nebe) sûrelerini düzenli okuyarak özel "40 Okuma Manevi Rozetleri"ni açın.',
      ],
      stepsEn: [
        'Open the "Dashboard" (1st tab) to monitor your daily dhikr, prayer, Quran, and Hifz goal rings.',
        'Completing daily worship increments your Spiritual Streak (🔥) and elevates your rank from Mubtadi ➔ Salik ➔ Arif ➔ Wali.',
        'If you miss a day, use earned Diamonds (💎) on the streak card to restore your broken chain.',
        'Unlock special "40-Recitation Badges" by consistently reading Surahs Yasin, Mulk, Waqiah, Kahf, Fath, Rahman, and Naba.',
      ],
      proTipTr:
          'Panel ekranındaki "Hızlı İstatistik" ve "Seri" kartlarının sağ üstündeki paylaşım ikonuna dokunarak haftalık ibadet özetinizi zarif bir kart olarak paylaşabilirsiniz.',
      proTipEn:
          'Tap the share icon on the Dashboard\'s Quick Stats or Streak card to export a weekly spiritual summary card.',
      actionLabelTr: 'Panel\'e Git',
      actionLabelEn: 'Go to Dashboard',
      route: '/',
      searchKeywords: ['panel', 'seri', 'streak', 'elmas', 'makam', 'rütbe', 'salik', 'arif', 'veli', 'rozet', 'yasin', 'mülk', 'vakıa', 'kehf'],
    ),
    _GuideStepItem(
      id: 18,
      categoryId: 'sistem',
      iconEmoji: '☁️',
      iconData: Icons.cloud_done_rounded,
      titleTr: '18. Google Drive Bulut Senkronizasyonu & Yerel Yedekleme',
      titleEn: '18. Google Drive Cloud Sync & Local JSON Backup',
      summaryTr:
          'Telefon değiştirseniz bile zikir, seri, hatim ve kaza verilerinizi Google Drive veya yerel dosya ile güvenle koruma.',
      summaryEn:
          'Keep your dhikrs, streaks, Khatms, and Qada logs safe across devices with Google Drive Cloud Sync or local JSON export.',
      stepsTr: [
        'Ayarlar ekranındaki "Bulut Yedekleme & Senkronizasyon" kartından "Google ile Bağlan" butonuna dokunarak kendi Google hesabınızı bağlayın.',
        '"Otomatik Yedekleme" anahtarını açtığınızda verileriniz kendi kişisel Google Drive uygulama klasörünüze şifreli/güvenli şekilde yedeklenir.',
        'Yeni bir cihaza geçtiğinizde aynı Google hesabıyla giriş yapıp "Buluttan Geri Yükle / Eşitle" butonuna dokunarak tüm geçmişinizi saniyeler içinde geri getirin.',
        'Google hesabı kullanmak istemiyorsanız "Yerel Yedek Dışa Aktar (.json)" butonuyla yedek dosyasını telefonunuza kaydedebilir ve istediğiniz zaman "İçe Aktar" ile yükleyebilirsiniz.',
      ],
      stepsEn: [
        'In Settings under "Cloud Backup & Sync", tap "Connect with Google" to link your personal Google account.',
        'Enable "Auto Backup" so your dhikr counts, streaks, Khatms, and Qada logs sync privately to your own Google Drive app folder.',
        'When switching phones, sign in with the same Google account and tap "Restore / Sync from Cloud" to recover everything.',
        'Alternatively, use "Export Local Backup (.json)" and "Import Backup" for offline file-based backups.',
      ],
      proTipTr:
          'Zikirce hiçbir verinizi dış sunuculara göndermez; yedekleriniz yalnızca telefonunuzda ve izin verirseniz kendi şahsi Google Drive alanınızda saklanır.',
      proTipEn:
          'Zikirce never uploads your personal data to third-party servers; backups live strictly on your device and your private Google Drive.',
      actionLabelTr: 'Ayarlar\'a Git',
      actionLabelEn: 'Go to Settings',
      route: '/settings',
      searchKeywords: ['yedek', 'yedekleme', 'bulut', 'google drive', 'senkronizasyon', 'geri yükle', 'json', 'telefon değiştirme'],
    ),
    _GuideStepItem(
      id: 19,
      categoryId: 'sistem',
      iconEmoji: '👨‍👩‍👧‍👦',
      iconData: Icons.manage_accounts_rounded,
      titleTr: '19. Çoklu Oturum (Aile Modu) & PIN Kilidi',
      titleEn: '19. Multi-Session (Family Mode) & PIN Lock',
      summaryTr:
          'Aynı cihazda eşiniz, çocuklarınız veya ebeveynleriniz için bağımsız profiller açma ve PIN ile koruma.',
      summaryEn:
          'Create isolated profiles for family members on a single device with optional 4-digit PIN protection.',
      stepsTr: [
        'Ayarlar ekranındaki "Oturum & Profil Yönetimi" kartına dokunarak Oturum Yönetimi sayfasını açın.',
        '"Yeni Oturum Oluştur" butonuyla aile bireyleriniz için isim ve avatar seçerek yeni bir profil açın.',
        'Her profilin zikir sayacı, hatim ilerlemesi, kaza havuzu ve serisi birbirinden tamamen bağımsız (izole) tutulur.',
        'Özel profilinizi korumak isterseniz 4 haneli "PIN Kilidi" belirleyerek oturum geçişlerini güvenli hale getirin.',
      ],
      stepsEn: [
        'Open "Session & Profile Management" from the Settings screen.',
        'Tap "Create New Session" to set up a separate profile with its own name and avatar for a spouse, child, or parent.',
        'Every profile maintains completely isolated dhikr counters, Khatm progress, Qada pools, and streaks.',
        'Optionally set a 4-digit PIN code to lock your personal profile.',
      ],
      proTipTr:
          'Tabletinizi evde ortak kullanıyorsanız Aile Modu sayesinde her aile ferdi kendi hatmini ve zikirlerini karıştırmadan takip edebilir.',
      proTipEn:
          'Family Mode is ideal for shared home tablets so every family member can track their own Khatm and dhikr targets independently.',
      actionLabelTr: 'Oturum Yönetimi\'ni Aç',
      actionLabelEn: 'Open Session Manager',
      route: '/sessions',
      searchKeywords: ['oturum', 'profil', 'aile', 'çoklu', 'pin', 'kilit', 'şifre', 'çocuk'],
    ),
    _GuideStepItem(
      id: 20,
      categoryId: 'sistem',
      iconEmoji: '📱',
      iconData: Icons.widgets_rounded,
      titleTr: '20. Ana Ekran / Kilit Ekranı Widget\'ları & Pil İzinleri',
      titleEn: '20. Home / Lock Screen Widgets & Battery Optimization',
      summaryTr:
          '9 farklı iOS/Android widget\'ını (Selçuklu Saati, Vakit Sayacı, Zikir Zinciri) ekleme ve gecikmesiz bildirim ayarı.',
      summaryEn:
          'Add 9 custom iOS/Android widgets (Seljuk Clock, Prayer Countdown, Streak Chain) and configure battery permissions.',
      stepsTr: [
        'Ayarlar > "Ana Ekran Widget\'ları" ekranını açarak 9 farklı widget tasarımını (Selçuklu Analog Saati, Büyük Vakit Tablosu, Mini Vakit Şeridi, Zikir Sayacı, Seri Zinciri, Manevi Kalp, Hicri Takvim) canlı önizleyin.',
        'Telefonunuzun ana ekranında veya iOS Kilit Ekranında boş bir yere basılı tutup "+" (Widget Ekle) menüsünden "Zikirce"yi seçerek istediğiniz aracı ekleyin.',
        'Widget verilerini anında tazelemek için önizleme ekranının sağ üstündeki "Senkronize Et (🔄)" butonunu kullanın.',
        'Android (Xiaomi, Samsung, Huawei, Oppo) cihazlarda namaz bildirimlerinin ve widget\'ların gecikmemesi için Ayarlar\'daki "Pil Kısıtlamasını Kaldır" adımlarını tamamlayın.',
      ],
      stepsEn: [
        'Open Settings > "Home Screen Widgets" to preview all 9 widgets (Seljuk Analog Clock, Prayer Table, Mini Countdown, Dhikr Counter, Streak Chain, Spiritual Heart, Hijri Calendar).',
        'Long-press an empty area on your phone\'s Home Screen or iOS Lock Screen, tap "+", and select "Zikirce" to place any widget.',
        'Tap the "Sync (🔄)" icon in the widget preview screen anytime to force an immediate refresh.',
        'On Android devices (Xiaomi, Samsung, Huawei, Oppo), complete the "Unrestricted Battery" steps in Settings so prayer alerts never get delayed.',
      ],
      proTipTr:
          'iOS 16+ cihazlarda Kilit Ekranı\'na "Dairesel Sıradaki Vakit" ve "Zikir Zinciri" araçlarını ekleyerek telefonun kilidini bile açmadan vakti takip edebilirsiniz.',
      proTipEn:
          'On iOS 16+, add the circular "Next Prayer Countdown" and "Streak Chain" widgets to your Lock Screen to check prayer times at a glance.',
      actionLabelTr: 'Widget\'ları İncele',
      actionLabelEn: 'Explore Widgets',
      route: 'ACTION_WIDGETS_PREVIEW',
      searchKeywords: ['widget', 'ana ekran', 'kilit ekranı', 'ios', 'android', 'pil', 'xiaomi', 'samsung', 'huawei', 'hicri takvim', 'saat'],
    ),
  ];

  static const List<_FaqGuideItem> _faqItems = [
    _FaqGuideItem(
      id: 1,
      questionTr: 'Namaz vakti bildirimleri neden bazen gecikiyor veya gelmiyor?',
      questionEn: 'Why are prayer time notifications sometimes delayed or missing?',
      answerTr:
          'Xiaomi (MIUI/HyperOS), Samsung (One UI), Huawei ve Oppo gibi Android telefonlar, pil tasarrufu için arka plandaki zamanlayıcıları uyutabilir. Çözüm için Ayarlar ekranındaki "Pil Optimizasyonu / Arka Plan İzinleri" kartından Zikirce için "Kısıtlama Yok (Unrestricted)" ve "Otomatik Başlatma" izni verin.',
      answerEn:
          'Android OEMs (Xiaomi, Samsung, Huawei, Oppo) often throttle background timers to save battery. Grant "Unrestricted Battery Usage" and "Autostart" permissions via the Battery Optimization guide in Settings.',
      actionLabelTr: 'Pil İzinlerini Kontrol Et',
      actionLabelEn: 'Check Battery Permissions',
      actionKey: 'battery',
      icon: Icons.battery_charging_full_rounded,
    ),
    _FaqGuideItem(
      id: 2,
      questionTr: 'Sesli Kur\'ân / Mukabele okurken kelime takibi nasıl Ok ile Takip yapılır?',
      questionEn: 'How do I switch between Word Highlighting and the Crescent Arrow Pointer?',
      answerTr:
          'Mushaf ekranında sağ üstteki "Aa" (Görünüm Ayarları) çekmecesini açın veya Ayarlar > Kur\'ân-ı Kerîm bölümüne gidin. Buradan "Kelime İşaretleme (Vurgulu)" ile satır yüksekliğini hiç zıplatmayan "Ok ile Takip (İşaretçi)" arasında tek dokunuşla geçiş yapabilirsiniz.',
      answerEn:
          'Open the "Aa" typography drawer at the top right of the Mushaf screen or go to Settings > Quran. You can toggle between "Word Highlighting" and the zero-layout-shift "Arrow Pointer" in one tap.',
      actionLabelTr: 'Mushaf\'ta Gör',
      actionLabelEn: 'Open Mushaf',
      actionKey: 'mushaf',
      icon: Icons.ads_click_rounded,
    ),
    _FaqGuideItem(
      id: 3,
      questionTr: 'Telefonumu değiştirdiğimde zikirlerim, serim ve hatimlerim silinir mi?',
      questionEn: 'Will I lose my dhikrs, streaks, and Khatms when I get a new phone?',
      answerTr:
          'Hayır! Ayarlar ekranından Google Drive Bulut Yedekleme\'yi bağlayıp yedek aldığınızda veya "Yerel Yedek Dışa Aktar (.json)" ile yedek dosyanızı kaydettiğinizde, yeni telefonunuzda tek dokunuşla tüm zikir, seri, hatim ve kaza verilerinizi eksiksiz geri yükleyebilirsiniz.',
      answerEn:
          'No! Connect Google Drive Cloud Sync in Settings or export a local ".json" backup file. On your new phone, sign in or import the file to restore 100% of your progress.',
      actionLabelTr: 'Yedekleme Ayarlarına Git',
      actionLabelEn: 'Go to Backup Settings',
      actionKey: 'settings',
      icon: Icons.cloud_sync_rounded,
    ),
    _FaqGuideItem(
      id: 4,
      questionTr: 'Kur\'ân seslerini ve 23 eserlik Külliyat kitaplarını internetsiz kullanabilir miyim?',
      questionEn: 'Can I use Quran audio and the 23-volume Corpus offline without internet?',
      answerTr:
          'Evet! Ayarlar > "Kur\'ân Ses Yöneticisi" bölümünden istediğiniz cüzlerin veya sûrelerin ses dosyalarını önceden indirebilirsiniz. Külliyat kitapları (Kütüb-i Sitte, Risale-i Nur) ve 5 Klasik Tefsir ise ilk açılışta cihazınıza kaydedilir ve sonrasında tamamen internetsiz çalışır.',
      answerEn:
          'Yes! Download Juz or Surah audio packs ahead of time in Settings > Quran Audio Manager. Any Corpus book or Classical Tafsir volume opened once is cached locally for 100% offline reading.',
      actionLabelTr: 'Kur\'ân & Külliyat\'ı Aç',
      actionLabelEn: 'Open Quran & Corpus',
      actionKey: 'kuran',
      icon: Icons.download_for_offline_rounded,
    ),
    _FaqGuideItem(
      id: 5,
      questionTr: 'Ana ekran ve kilit ekranı widget\'ları güncellenmiyorsa ne yapmalıyım?',
      questionEn: 'What should I do if Home Screen or Lock Screen widgets stop updating?',
      answerTr:
          'Ayarlar > Ana Ekran Widget\'ları sayfasına gidip sağ üstteki "Senkronize Et (🔄)" butonuna dokunun. Ayrıca cihazınızda Zikirce için arka plan yenileme / pil izninin açık olduğundan emin olun.',
      answerEn:
          'Open Settings > Home Screen Widgets and tap the top-right "Sync (🔄)" button. Also ensure Background App Refresh / Unrestricted Battery is enabled for Zikirce.',
      actionLabelTr: 'Widget Önizleme & Senkron',
      actionLabelEn: 'Widget Preview & Sync',
      actionKey: 'widgets',
      icon: Icons.widgets_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _loadRuntimeVersion();
  }

  void _onSearchChanged() {
    final next = _searchController.text;
    if (next != _searchQuery) {
      setState(() {
        _searchQuery = next;
      });
    }
  }

  Future<void> _loadRuntimeVersion() async {
    final info = await ChangelogService.getRuntimeVersion();
    if (mounted) {
      setState(() {
        _runtimeVersionName = info.versionName;
        _runtimeVersionCode = info.versionCode;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleRouteOrAction(String routeOrAction) {
    HapticService.selectionClick();
    if (routeOrAction == 'ACTION_SHARE_STUDIO') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ShareCardScreen()),
      );
      return;
    }
    if (routeOrAction == 'ACTION_WIDGETS_PREVIEW') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WidgetsPreviewScreen()),
      );
      return;
    }
    if (routeOrAction.startsWith('/mushaf') ||
        routeOrAction.startsWith('/mukabele') ||
        routeOrAction.startsWith('/ezber') ||
        routeOrAction.startsWith('/fiqh') ||
        routeOrAction.startsWith('/sessions') ||
        routeOrAction.startsWith('/onboarding') ||
        routeOrAction.startsWith('/privacy')) {
      context.push(routeOrAction);
    } else if (routeOrAction == '/settings') {
      Navigator.of(context).maybePop();
    } else {
      context.go(routeOrAction);
    }
  }

  Future<void> _handleFaqAction(String actionKey) async {
    HapticService.selectionClick();
    switch (actionKey) {
      case 'battery':
        final opened = await BatteryOptimizationService.openBatterySaverNoRestrictions();
        if (!opened && mounted) {
          Navigator.of(context).maybePop();
        }
        break;
      case 'mushaf':
        if (mounted) context.push('/mushaf?page=1');
        break;
      case 'settings':
        if (mounted) Navigator.of(context).maybePop();
        break;
      case 'kuran':
        if (mounted) context.go('/kuran');
        break;
      case 'widgets':
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WidgetsPreviewScreen()),
          );
        }
        break;
    }
  }

  List<_GuideStepItem> get _filteredGuideItems {
    return _guideItems.where((item) {
      final matchesCategory = _selectedCategory == 'all' || item.categoryId == _selectedCategory;
      if (!matchesCategory) return false;
      return item.matchesQuery(_searchQuery);
    }).toList();
  }

  List<_FaqGuideItem> get _filteredFaqItems {
    return _faqItems.where((faq) => faq.matchesQuery(_searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isTr = l10n.isTurkish;
    final isDark = colors.statusBrightness == Brightness.light;
    final filteredGuides = _filteredGuideItems;
    final filteredFaqs = _filteredFaqItems;
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.primaryText, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                isTr ? 'Kullanım Kılavuzu & Rehber' : 'User Guide & Manual',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: colors.primaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                HapticService.selectionClick();
                WhatsNewBottomSheet.showHistory(context);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'v$_runtimeVersionName',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () {
                HapticService.selectionClick();
                context.push('/onboarding?fromSettings=true');
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.accent,
                backgroundColor: colors.accent.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.accent.withValues(alpha: 0.25)),
                ),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: Text(
                isTr ? 'İlk Kurulum Turu' : 'Intro Tour',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          // 1. Özel Selçuklu / Rahle Geometrik Sanat Katmanlı Üst Tanıtım Kartı
          _buildHeroBanner(colors, isTr, isDark),
          const SizedBox(height: 14),

          // 2. Anlık Kılavuz Arama Çubuğu + Hızlı Anahtar Kelimeler
          _buildSearchSection(colors, isTr),
          const SizedBox(height: 12),

          // 3. 6 Kategori Filtre Sekmesi
          _buildCategoryChips(colors, isTr),
          const SizedBox(height: 16),

          // 4. Yatay İnteraktif Tanıtım Vitrini (Arama yokken ve Tümü seçiliyken)
          if (!isSearching && _selectedCategory == 'all') ...[
            _buildSectionHeader(
              icon: Icons.auto_awesome_rounded,
              title: isTr ? 'Öne Çıkan Özellik Vitrini' : 'Interactive Feature Showcase',
              subtitle: isTr
                  ? 'Zikirce\'nin 5 temel mimari modülünü keşfedin ve doğrudan deneyin'
                  : 'Explore Zikirce\'s 5 core architectural pillars and try them live',
              colors: colors,
            ),
            const SizedBox(height: 10),
            _buildShowcaseCarousel(colors, isTr, isDark),
            const SizedBox(height: 22),
          ],

          // 5. Adım Adım Detaylı Kullanım Kılavuzu Kartları
          _buildSectionHeader(
            icon: Icons.menu_book_rounded,
            title: isTr
                ? 'Adım Adım Kullanım Kılavuzu (${filteredGuides.length})'
                : 'Step-by-Step User Manual (${filteredGuides.length})',
            subtitle: isTr
                ? 'Detaylı adımları, püf noktalarını ve hızlı geçiş butonlarını görmek için başlıklara dokunun'
                : 'Tap any topic to view numbered steps, pro tips, and direct navigation buttons',
            colors: colors,
            trailing: TextButton(
              onPressed: () {
                HapticService.selectionClick();
                setState(() {
                  if (_expandedGuideIds.length == filteredGuides.length) {
                    _expandedGuideIds.clear();
                  } else {
                    _expandedGuideIds.addAll(filteredGuides.map((e) => e.id));
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _expandedGuideIds.length == filteredGuides.length
                    ? (isTr ? 'Tümünü Daralt' : 'Collapse All')
                    : (isTr ? 'Tümünü Aç' : 'Expand All'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (filteredGuides.isEmpty)
            _buildEmptySearchState(colors, isTr)
          else
            ..._buildGroupedGuideCards(filteredGuides, colors, isTr, isSearching),

          const SizedBox(height: 24),

          // 6. Sıkça Sorulan Sorular (SSS / Sorun Giderme) Bölümü
          if (filteredFaqs.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.help_outline_rounded,
              title: isTr
                  ? 'Sıkça Sorulan Sorular & Sorun Giderme'
                  : 'Frequently Asked Questions & Troubleshooting',
              subtitle: isTr
                  ? 'En sık karşılaşılan sorular ve tek dokunuşla çözüm kısayolları'
                  : 'Common questions and one-tap resolution shortcuts',
              colors: colors,
            ),
            const SizedBox(height: 10),
            ...filteredFaqs.map((faq) => _buildFaqCard(faq, colors, isTr, isSearching)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroBanner(AppThemeColors colors, bool isTr, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.headerBackground,
            colors.headerGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: CustomPaint(
          painter: _SeljukGuideHeaderPainter(
            accentColor: colors.accent,
            isDark: isDark,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/images/zikirce_logo.png',
                        width: 34,
                        height: 34,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.auto_stories_rounded,
                          color: colors.accent,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                isTr ? 'Zikirce Kapsamlı Rehber' : 'Zikirce Complete Handbook',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primaryText,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  HapticService.selectionClick();
                                  WhatsNewBottomSheet.showHistory(context);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.cardBackground.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    'v$_runtimeVersionName • Build $_runtimeVersionCode',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: colors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            isTr
                                ? '4 modlu Mushaf, hilâl uçlu Ok ile Kelime Takibi, 23 eserlik Külliyat, 146 sahih zikir, 5 hafızlık modu ve namaz/kaza sisteminin tüm incelikleri.'
                                : 'Master the 4-mode Mushaf, Crescent Arrow Word Tracking, 23-volume Corpus, 146 Sahih dhikrs, 5 Hifz modes, and smart prayer/Qada tools.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildStatPill('20', isTr ? 'Adım Adım Kılavuz' : 'Step-by-Step Guides', colors),
                    _buildStatPill('23', isTr ? 'Külliyat & Tefsir Eseri' : 'Corpus & Tafsir Volumes', colors),
                    _buildStatPill('146', isTr ? 'Sahih Zikir & Dua' : 'Authentic Dhikrs & Duas', colors),
                    _buildStatPill('9', isTr ? 'Ana/Kilit Ekran Widget\'ı' : 'Home/Lock Widgets', colors),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String number, String label, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.cardBackground.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(AppThemeColors colors, bool isTr) {
    final quickTags = isTr
        ? const ['Ok ile takip', 'Külliyat', 'Odak modu', 'Kaza havuzu', 'Hafızlık', 'Yedekleme', 'Widget']
        : const ['Arrow pointer', 'Corpus', 'Focus mode', 'Qada pool', 'Hifz', 'Backup', 'Widget'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchQuery.isNotEmpty ? colors.accent : colors.borderStroke,
              width: _searchQuery.isNotEmpty ? 1.4 : 1.0,
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13.5, color: colors.primaryText),
            decoration: InputDecoration(
              hintText: isTr
                  ? 'Kılavuzda ara: "ok ile takip", "kaza", "külliyat", "odak", "yedek"...'
                  : 'Search guide: "arrow pointer", "qada", "corpus", "focus", "backup"...',
              hintStyle: TextStyle(fontSize: 12.5, color: colors.tertiaryText),
              prefixIcon: Icon(Icons.search_rounded, color: colors.accent, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.secondaryTextAlt, size: 18),
                      onPressed: () {
                        HapticService.selectionClick();
                        _searchController.clear();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: quickTags.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final tag = quickTags[index];
              final isSelected = _normalizeSearch(_searchQuery) == _normalizeSearch(tag);
              return InkWell(
                onTap: () {
                  HapticService.selectionClick();
                  if (isSelected) {
                    _searchController.clear();
                  } else {
                    _searchController.text = tag;
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _searchController.text.length),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accent.withValues(alpha: 0.18)
                        : colors.cardBackgroundAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? colors.accent : colors.borderStroke,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '# $tag',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? colors.accent : colors.secondaryTextAlt,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(AppThemeColors colors, bool isTr) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat.id;
          return InkWell(
            onTap: () {
              HapticService.selectionClick();
              setState(() => _selectedCategory = cat.id);
            },
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? colors.accent : colors.cardBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? colors.accent : colors.borderStroke,
                  width: 1.1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    isTr ? cat.labelTr : cat.labelEn,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppThemeColors colors,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: colors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.secondaryTextAlt,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildShowcaseCarousel(AppThemeColors colors, bool isTr, bool isDark) {
    return SizedBox(
      height: 256,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _showcaseItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _showcaseItems[index];
          final pills = isTr ? item.pillsTr : item.pillsEn;
          return Container(
            width: 308,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: item.accentTint.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: item.accentTint.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 18, color: item.accentTint),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTr ? item.badgeTr : item.badgeEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: item.accentTint,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.cardBackgroundAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}/${_showcaseItems.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isTr ? item.titleTr : item.titleEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    isTr ? item.descTr : item.descEn,
                    maxLines: item.showTrackingPreview ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                ),
                if (item.showTrackingPreview) ...[
                  const SizedBox(height: 6),
                  _buildTrackingMiniSimulation(colors, item.accentTint, isTr),
                ],
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: pills.map((pill) {
                      return Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.accentTint.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          pill,
                          style: TextStyle(
                            fontSize: 9.8,
                            fontWeight: FontWeight.w700,
                            color: item.accentTint,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () => _handleRouteOrAction(item.route),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.accentTint,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Text(
                      isTr ? item.buttonTr : item.buttonEn,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackingMiniSimulation(AppThemeColors colors, Color tint, bool isTr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.cardBackgroundAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              isTr ? '🏹 Ok ile Takip:' : '🏹 Arrow Pointer:',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.secondaryTextAlt,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'بِسْمِ ',
                      style: TextStyle(
                        fontFamily: 'AmasyaAbay',
                        fontSize: 13.5,
                        color: colors.primaryText.withValues(alpha: 0.7),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'اللّٰهِ',
                            style: TextStyle(
                              fontFamily: 'AmasyaAbay',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: tint,
                            ),
                          ),
                        ),
                        Icon(Icons.navigation_rounded, size: 10, color: tint),
                      ],
                    ),
                    Text(
                      ' الرَّحْمٰنِ',
                      style: TextStyle(
                        fontFamily: 'AmasyaAbay',
                        fontSize: 13.5,
                        color: colors.primaryText.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedGuideCards(
    List<_GuideStepItem> items,
    AppThemeColors colors,
    bool isTr,
    bool isSearching,
  ) {
    final widgets = <Widget>[];
    String? lastCategory;

    for (final item in items) {
      if (_selectedCategory == 'all' && item.categoryId != lastCategory) {
        lastCategory = item.categoryId;
        final catMeta = _categories.firstWhere(
          (c) => c.id == item.categoryId,
          orElse: () => _categories.first,
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Row(
              children: [
                Text(catMeta.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  isTr ? '${catMeta.labelTr} Kılavuzu' : '${catMeta.labelEn} Guide',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(color: colors.borderStroke, thickness: 1),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(_buildGuideStepCard(item, colors, isTr, isSearching));
      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }

  Widget _buildGuideStepCard(
    _GuideStepItem item,
    AppThemeColors colors,
    bool isTr,
    bool isSearching,
  ) {
    final isExpanded = isSearching || _expandedGuideIds.contains(item.id);
    final steps = item.steps(isTr);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? colors.accent.withValues(alpha: 0.45)
              : colors.borderStroke,
          width: isExpanded ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticService.selectionClick();
              setState(() {
                if (_expandedGuideIds.contains(item.id)) {
                  _expandedGuideIds.remove(item.id);
                } else {
                  _expandedGuideIds.add(item.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(item.iconEmoji, style: const TextStyle(fontSize: 19)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title(isTr),
                          style: TextStyle(
                            fontSize: 13.8,
                            fontWeight: FontWeight.w800,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.summary(isTr),
                          style: TextStyle(
                            fontSize: 11.8,
                            height: 1.35,
                            color: colors.secondaryTextAlt,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.cardBackgroundAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: colors.borderStroke),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Numaralı Adımlar
                  ...List.generate(steps.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: colors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              steps[idx],
                              style: TextStyle(
                                fontSize: 12.4,
                                height: 1.45,
                                color: colors.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),

                  // 💡 Püf Noktası Kutusu
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 11.8,
                                height: 1.4,
                                color: colors.primaryText,
                              ),
                              children: [
                                TextSpan(
                                  text: isTr ? 'Püf Noktası: ' : 'Pro Tip: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: colors.accent,
                                  ),
                                ),
                                TextSpan(text: item.proTip(isTr)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Doğrudan Ekrana Git Butonu
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleRouteOrAction(item.route),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accent,
                        side: BorderSide(color: colors.accent.withValues(alpha: 0.45)),
                        backgroundColor: colors.accent.withValues(alpha: 0.06),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(item.iconData, size: 16),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.actionLabel(isTr),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 15),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaqCard(
    _FaqGuideItem faq,
    AppThemeColors colors,
    bool isTr,
    bool isSearching,
  ) {
    final isExpanded = isSearching || _expandedFaqIds.contains(faq.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? colors.accent.withValues(alpha: 0.4)
              : colors.borderStroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticService.selectionClick();
              setState(() {
                if (_expandedFaqIds.contains(faq.id)) {
                  _expandedFaqIds.remove(faq.id);
                } else {
                  _expandedFaqIds.add(faq.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Icon(faq.icon, size: 20, color: colors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTr ? faq.questionTr : faq.questionEn,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colors.secondaryTextAlt,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: colors.borderStroke),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTr ? faq.answerTr : faq.answerEn,
                    style: TextStyle(
                      fontSize: 12.2,
                      height: 1.45,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _handleFaqAction(faq.actionKey),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.accent,
                        backgroundColor: colors.accent.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(faq.icon, size: 15),
                      label: Text(
                        isTr ? faq.actionLabelTr : faq.actionLabelEn,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(AppThemeColors colors, bool isTr) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: colors.secondaryTextAlt),
          const SizedBox(height: 10),
          Text(
            isTr
                ? '"$_searchQuery" için eşleşen rehber maddesi bulunamadı.'
                : 'No guide topics matched "$_searchQuery".',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isTr
                ? 'Farklı bir kelime deneyin veya tüm kategorileri görüntülemek için filtreyi sıfırlayın.'
                : 'Try another keyword or reset the filter to browse all categories.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              HapticService.selectionClick();
              setState(() {
                _searchController.clear();
                _selectedCategory = 'all';
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(isTr ? 'Aramayı & Filtreyi Sıfırla' : 'Reset Search & Filter'),
          ),
        ],
      ),
    );
  }
}

/// Üst tanıtım kartında 8 köşeli Selçuklu yıldızı ve kubbe kemeri çizgilerini
/// hafif altın/zümrüt tonlarında çizen özgün CustomPainter arka plan dokusu.
class _SeljukGuideHeaderPainter extends CustomPainter {
  final Color accentColor;
  final bool isDark;

  const _SeljukGuideHeaderPainter({
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.14 : 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final subtlePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.08 : 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Sağ üst köşe 8 köşeli Selçuklu yıldızı (Rub el Hizb)
    final center = Offset(size.width - 42, 44);
    _drawSeljukStar(canvas, center, 52, strokePaint);
    _drawSeljukStar(canvas, center, 34, subtlePaint);

    // Sol alt köşe ikincil Selçuklu rozeti
    final secondaryCenter = Offset(34, size.height - 22);
    _drawSeljukStar(canvas, secondaryCenter, 36, subtlePaint);

    // Kubbe kemeri (Mihrap / Rahle kemer yayı)
    final archPath = Path()
      ..moveTo(size.width * 0.55, size.height)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.18,
        size.width,
        size.height * 0.32,
      );
    canvas.drawPath(archPath, subtlePaint);
  }

  void _drawSeljukStar(Canvas canvas, Offset center, double radius, Paint paint) {
    const int points = 8;
    final path1 = Path();
    final path2 = Path();

    for (int i = 0; i < 4; i++) {
      final angle1 = (i * math.pi / 2);
      final angle2 = angle1 + (math.pi / 4);
      final p1 = Offset(
        center.dx + radius * math.cos(angle1),
        center.dy + radius * math.sin(angle1),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle2),
        center.dy + radius * math.sin(angle2),
      );
      if (i == 0) {
        path1.moveTo(p1.dx, p1.dy);
        path2.moveTo(p2.dx, p2.dy);
      } else {
        path1.lineTo(p1.dx, p1.dy);
        path2.lineTo(p2.dx, p2.dy);
      }
    }
    path1.close();
    path2.close();
    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);

    // Merkez sekizgen halka
    final innerPath = Path();
    final innerRadius = radius * 0.42;
    for (int i = 0; i < points; i++) {
      final angle = i * (2 * math.pi / points);
      final pt = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      if (i == 0) {
        innerPath.moveTo(pt.dx, pt.dy);
      } else {
        innerPath.lineTo(pt.dx, pt.dy);
      }
    }
    innerPath.close();
    canvas.drawPath(innerPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SeljukGuideHeaderPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor || oldDelegate.isDark != isDark;
  }
}
