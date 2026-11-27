import 'package:flutter/material.dart';
import '../../../core/services/changelog_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../monetization/domain/subscription_service.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../../settings/presentation/kilerce_settings_screen.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import '../domain/expiry_reminder_service.dart';
import '../domain/kiler_models.dart';
import '../domain/kiler_service.dart';

class ShoppingAndProfileScreen extends StatefulWidget {
  const ShoppingAndProfileScreen({super.key});

  @override
  State<ShoppingAndProfileScreen> createState() =>
      _ShoppingAndProfileScreenState();
}

class _ShoppingAndProfileScreenState extends State<ShoppingAndProfileScreen> {
  final TextEditingController _addController = TextEditingController();
  bool _sktRemindersEnabled = true;
  bool _isPro = false;
  int _adProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndPro();
  }

  Future<void> _loadPrefsAndPro() async {
    final results = await Future.wait<dynamic>([
      ExpiryReminderService.instance.isEnabled(),
      SubscriptionService.instance.isAdFree(),
      SubscriptionService.instance.getRewardAdProgress(),
    ]);
    if (mounted) {
      setState(() {
        _sktRemindersEnabled = results[0] as bool;
        _isPro = results[1] as bool;
        _adProgress = results[2] as int;
      });
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _handleAddShoppingItem() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    await KilerService.instance.addShoppingItem(
      name: text,
      sourceNote: 'Alışveriş listesine eklendi',
    );
    _addController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;

    return ValueListenableBuilder<KilerState>(
      valueListenable: KilerService.instance,
      builder: (context, kilerState, _) {
        final items = kilerState.shoppingItems;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [
            // 1. Smart Shopping List Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_checkout_rounded,
                          color: AppColors.primaryEmerald,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Akıllı Alışveriş & Eksikler Listesi',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Dolapta bitenler ve tarif eksikleri burada toplanır. Aldığınız ürünü tek dokunuşla kilere aktarın!',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addController,
                          onSubmitted: (_) => _handleAddShoppingItem(),
                          style: TextStyle(color: textPrimary, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Alınacak ürün ekle (örn. Zeytinyağı, Süt)...',
                            hintStyle: TextStyle(
                              color: textSecondary,
                              fontSize: 12.5,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).scaffoldBackgroundColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleAddShoppingItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Ekle',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Shopping Items List
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    const Text('🛍️', style: TextStyle(fontSize: 34)),
                    const SizedBox(height: 8),
                    Text(
                      'Alışveriş listeniz şu an boş',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kilerde biten ürünler veya yemek tariflerindeki eksik malzemeler otomatik olarak buraya eklenir.',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...items.map(
                (item) => _ShoppingItemCard(item: item),
              ),

            const SizedBox(height: 20),

            // 3. Kilerce Pro, Settings & Food Safety Quick Access
            Text(
              'Kilerce Pro, Ayarlar & Güvenlik',
              style: TextStyle(
                color: textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _NavigationFeatureCard(
              icon: Icons.workspace_premium_rounded,
              color: _isPro ? AppColors.primaryEmerald : AppColors.cautionGold,
              title: _isPro
                  ? 'Kilerce Pro Aktif'
                  : 'Kilerce Pro & Reklam Ödülleri',
              subtitle: _isPro
                  ? 'Sınırsız 23.933+ tarif & reklamsız deneyimi yönetin'
                  : 'Abonelik paketleri veya 3 reklam ile +3 saat Pro ($_adProgress/3)',
              onTap: () async {
                await PaywallScreen.show(context);
                if (mounted) _loadPrefsAndPro();
              },
            ),
            const SizedBox(height: 10),
            _NavigationFeatureCard(
              icon: Icons.settings_rounded,
              color: AppColors.primaryMint,
              title: 'Uygulama Ayarları',
              subtitle: 'Tema, yedekleme, profil rozetleri ve gizlilik politikası',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KilerceSettingsScreen(),
                  ),
                );
                if (mounted) _loadPrefsAndPro();
              },
            ),
            const SizedBox(height: 10),
            _NavigationFeatureCard(
              icon: Icons.family_restroom_rounded,
              color: AppColors.primaryEmerald,
              title: 'Aile & Beslenme Profilleri',
              subtitle:
                  'Çocuk profili, Glutensiz, Laktozsuz, Vegan ve Şekersiz filtrelerini yönetin',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FamilyProfilesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _NavigationFeatureCard(
              icon: Icons.gpp_maybe_rounded,
              color: AppColors.dangerRed,
              title: 'Bakanlık Taklit & Tağşiş Kara Listesi',
              subtitle:
                  'Tarım ve Orman Bakanlığı resmi ifşa listesinde markaları sorgulayın',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TaklitTagsisScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _NavigationFeatureCard(
              icon: Icons.new_releases_rounded,
              color: AppColors.primaryMint,
              title: 'Kilerce Sürüm Notları (v${ChangelogService.currentVersionName})',
              subtitle: 'Yeni eklenen akıllı kiler, fiş OCR ve şef özelliklerini inceleyin',
              onTap: () => ChangelogService.showHistory(context),
            ),
            const SizedBox(height: 10),
            Semantics(
              toggled: _sktRemindersEnabled,
              label: 'Son kullanma tarihi hatırlatma bildirimleri',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primaryEmerald,
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cautionGold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.cautionGold,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'SKT Bildirimleri',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Son kullanma tarihi yaklaşan ürünler için günlük hatırlatma',
                    style: TextStyle(color: textSecondary, fontSize: 11.5),
                  ),
                  value: _sktRemindersEnabled,
                  onChanged: (val) async {
                    setState(() => _sktRemindersEnabled = val);
                    await ExpiryReminderService.instance.setEnabled(val);
                    if (val) {
                      await ExpiryReminderService.instance.triggerNow();
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  final ShoppingListItem item;

  const _ShoppingItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final resolved = IngredientNormalizer.resolveMetadata(item.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(resolved.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.sourceNote} • ${resolved.defaultZone.emoji} ${resolved.defaultZone.label}',
                  style: TextStyle(color: textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await KilerService.instance.moveShoppingItemToPantry(item);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ "${item.name}" alındı ve ${resolved.defaultZone.label}na aktarıldı!',
                  ),
                  backgroundColor: AppColors.primaryEmerald,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.kitchen_rounded, size: 15),
            label: const Text(
              'Aldım -> Kilere',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              if (item.id != null) {
                KilerService.instance.deleteShoppingItem(item.id!);
              }
            },
            icon: Icon(
              Icons.delete_outline_rounded,
              color: textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationFeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cardBorderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: context.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
