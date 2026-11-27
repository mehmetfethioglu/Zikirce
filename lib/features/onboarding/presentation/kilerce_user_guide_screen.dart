import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/config/kilerce_contact_config.dart';
import '../../../../core/services/kilerce_notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kilerce_logo_mark.dart';
import '../../settings/presentation/widgets/recipe_photo_feedback_sheet.dart';
import '../domain/user_guide_service.dart';

class _GuideSlide {
  final IconData icon;
  final Color accentColor;
  final String badge;
  final String title;
  final String description;
  final List<String> bullets;
  final bool showLogo;
  final bool isNotificationSlide;
  final bool isPhotoContributionSlide;

  const _GuideSlide({
    required this.icon,
    required this.accentColor,
    required this.badge,
    required this.title,
    required this.description,
    required this.bullets,
    this.showLogo = false,
    this.isNotificationSlide = false,
    this.isPhotoContributionSlide = false,
  });
}

/// Interactive 5-step first-launch user guide explaining pantry, morning alerts,
/// profile menu, and representative recipe photo contributions.
class KilerceUserGuideScreen extends StatefulWidget {
  final bool markCompletedOnClose;

  const KilerceUserGuideScreen({
    super.key,
    this.markCompletedOnClose = true,
  });

  static Future<void> show(
    BuildContext context, {
    bool markCompletedOnClose = true,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KilerceUserGuideScreen(
          markCompletedOnClose: markCompletedOnClose,
        ),
      ),
    );
  }

  @override
  State<KilerceUserGuideScreen> createState() => _KilerceUserGuideScreenState();
}

class _KilerceUserGuideScreenState extends State<KilerceUserGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _notificationsActivated = false;

  static const List<_GuideSlide> _slides = [
    _GuideSlide(
      icon: Icons.eco_rounded,
      accentColor: AppColors.primaryEmerald,
      badge: '1 / 5 · Hoş Geldiniz',
      title: 'Kilerce\'ye Hoş Geldiniz',
      description:
          'Barkod tarama, akıllı kiler takibi ve elinizdeki malzemelere göre binlerce yemek tarifi tek yerde.',
      bullets: [
        'Buzdolabı, kiler ve dondurucudaki ürünlerinizi tek dokunuşla yönetin.',
        'Elinizdeki malzemelerle hemen pişirebileceğiniz tarifleri anında keşfedin.',
      ],
      showLogo: true,
    ),
    _GuideSlide(
      icon: Icons.kitchen_rounded,
      accentColor: AppColors.primaryMint,
      badge: '2 / 5 · Akıllı Kiler',
      title: 'Kiler, Fiş & SKT Takibi',
      description:
          'Barkod okutarak, market fişi tarayarak veya hızlı girişle ürün ekleyin; israfı önleyin.',
      bullets: [
        'Barkodsuz manav ve kasap ürünlerini doğal dil girişiyle hızlıca kaydedin.',
        'Son kullanma tarihi yaklaşan ürünler için kurtarma tarifleri önerilir.',
      ],
    ),
    _GuideSlide(
      icon: Icons.notifications_active_rounded,
      accentColor: AppColors.cautionGold,
      badge: '3 / 5 · Sabah Hatırlatıcı',
      title: 'Haftalık Menü & Sabah Bildirimleri',
      description:
          'Bugünkü menünüz için kilerinizde eksik ürün varsa sabah bildirimle hatırlatırız.',
      bullets: [
        'Menü oluşturduğunuzda eksik malzemeler otomatik kontrol edilir.',
        'Sabah saatinde bildirim alarak alışverişinizi erkenden planlayabilirsiniz.',
      ],
      isNotificationSlide: true,
    ),
    _GuideSlide(
      icon: Icons.verified_user_rounded,
      accentColor: AppColors.primaryEmerald,
      badge: '4 / 5 · Güvenlik & Menü',
      title: 'Gıda Güvenliği & Profil Menüsü',
      description:
          'E-kod analizi, aile hassasiyet profilleri ve Bakanlık kara listesi ile güvenle alışveriş yapın.',
      bullets: [
        'Sağ üstteki profil fotoğrafınıza dokunarak hesap, kara liste ve ayarlara ulaşın.',
        'Aile profilleriyle glutensiz, laktozsuz veya vegan uyarıları kişiselleştirin.',
      ],
    ),
    _GuideSlide(
      icon: Icons.add_a_photo_rounded,
      accentColor: AppColors.primaryEmerald,
      badge: '5 / 5 · Gerçek Tarif Görselleri',
      title: 'Yemek Görselleri & Katkınız',
      description: KilerceContactConfig.representativeImageDetailedNotice,
      bullets: [
        'İletişim e-postamız: ${KilerceContactConfig.supportEmail}',
        'Ayarlar > Geri Bildirim > Tarif Fotoğrafı Gönder üzerinden hızlıca paylaşabilirsiniz.',
      ],
      isPhotoContributionSlide: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final enabled =
        await KilerceNotificationService.instance.areNotificationsEnabled();
    if (!mounted) return;
    setState(() => _notificationsActivated = enabled);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _activateNotifications() async {
    final granted = await KilerceNotificationService.instance.requestPermission();
    await KilerceNotificationService.instance.setMorningMenuEnabled(true);
    await KilerceNotificationService.instance.syncAllReminders();
    if (!mounted) return;
    setState(() => _notificationsActivated = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Sabah menü ve SKT bildirimleri aktifleştirildi!'
              : 'Bildirim izni ayarlardan daha sonra açılabilir.',
        ),
        backgroundColor:
            granted ? AppColors.primaryEmerald : AppColors.cautionGold,
      ),
    );
  }

  Future<void> _finishGuide({bool requestPermissionIfLast = false}) async {
    if (widget.markCompletedOnClose) {
      await UserGuideService.instance.markCompleted();
    }
    if (requestPermissionIfLast) {
      unawaited(
        KilerceNotificationService.instance.requestPermissionIfNeededOnce(),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  const KilerceLogoMark(size: 30, borderRadius: 9),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kullanım Kılavuzu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _finishGuide(),
                    child: Text(
                      'Atla',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: slide.accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            slide.badge,
                            style: TextStyle(
                              color: slide.accentColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: slide.accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: slide.accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Center(
                              child: slide.showLogo
                                  ? const KilerceLogoMark(
                                      size: 56,
                                      borderRadius: 16,
                                    )
                                  : Icon(
                                      slide.icon,
                                      size: 46,
                                      color: slide.accentColor,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          slide.title,
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          slide.description,
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...slide.bullets.map(
                          (bullet) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.cardBorderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: slide.accentColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: TextStyle(
                                      color: context.textPrimaryColor,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (slide.isNotificationSlide) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _activateNotifications,
                              icon: Icon(
                                _notificationsActivated
                                    ? Icons.notifications_active_rounded
                                    : Icons.notification_add_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _notificationsActivated
                                    ? 'Bildirimler Aktif'
                                    : 'Bildirimleri Aktifleştir',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryEmerald,
                                side: const BorderSide(
                                  color: AppColors.primaryEmerald,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (slide.isPhotoContributionSlide) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  RecipePhotoFeedbackSheet.show(context),
                              icon: const Icon(
                                Icons.add_a_photo_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Tarif Fotoğrafı Gönder',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryEmerald,
                                side: const BorderSide(
                                  color: AppColors.primaryEmerald,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(_slides.length, (index) {
                        final active = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryEmerald
                                : context.cardBorderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (_currentPage > 0) ...[
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Text('Geri'),
                    ),
                    const SizedBox(width: 6),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      if (isLastPage) {
                        _finishGuide(requestPermissionIfLast: true);
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isLastPage ? 'Başla' : 'İleri',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
