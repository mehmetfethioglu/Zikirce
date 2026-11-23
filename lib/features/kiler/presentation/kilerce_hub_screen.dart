import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kilerce_logo_mark.dart';
import '../../recipes/domain/meal_module_notifier.dart';
import '../../recipes/presentation/recipe_explorer_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import '../domain/kiler_service.dart';
import 'kiler_pantry_screen.dart';
import 'shopping_and_profile_screen.dart';

class KilerceHubController {
  static ValueChanged<int>? _tabSwitcher;

  static void switchToTab(int index) {
    _tabSwitcher?.call(index);
  }
}

class KilerceHubScreen extends StatefulWidget {
  final int initialTabIndex;

  const KilerceHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<KilerceHubScreen> createState() => _KilerceHubScreenState();
}

class _KilerceHubScreenState extends State<KilerceHubScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    KilerceHubController._tabSwitcher = _switchTab;
    KilerService.instance.loadAll();
  }

  @override
  void dispose() {
    if (KilerceHubController._tabSwitcher == _switchTab) {
      KilerceHubController._tabSwitcher = null;
    }
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      try {
        ProviderScope.containerOf(context, listen: false)
            .read(mealModuleNotifierProvider.notifier)
            .reloadProfile();
      } catch (e) {
        debugPrint('KilerceHubScreen._switchTab reloadProfile note: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      KilerPantryScreen(
        onOpenRecipesTab: () => _switchTab(1),
        onOpenScannerTab: () => _switchTab(2),
        onOpenShoppingTab: () => _switchTab(3),
      ),
      const RecipeExplorerScreen(),
      ScannerScreen(
        embeddedInHub: true,
        onOpenArenaTab: () => _switchTab(1),
        onOpenCharacterTab: () => _switchTab(0),
      ),
      const ShoppingAndProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _KilerceTopHudBar(
              currentIndex: _currentIndex,
              onTabSelected: _switchTab,
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _KilerceBottomDock(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}

class _KilerceTopHudBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const _KilerceTopHudBar({
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return ValueListenableBuilder<KilerState>(
      valueListenable: KilerService.instance,
      builder: (context, state, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(color: context.cardBorderColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onTabSelected(0),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KilerceLogoMark(
                      size: 38,
                      borderRadius: 11,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kilerce',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Text(
                          'BARKOD • DOLAP • TARİF',
                          style: TextStyle(
                            color: AppColors.primaryEmerald,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Pantry item count & health badge
              GestureDetector(
                onTap: () => onTabSelected(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🥗', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        '${state.pantryItems.length} Ürün • Skor ${state.averageHealthScore}',
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Ministry Taklit/Tagsis Button
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaklitTagsisScreen(),
                    ),
                  );
                },
                tooltip: 'Bakanlık Taklit & Tağşiş Listesi',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.dangerRed.withValues(alpha: 0.12),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(34, 34),
                ),
                icon: const Icon(
                  Icons.gpp_maybe_rounded,
                  color: AppColors.dangerRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 4),

              // Theme Toggle
              IconButton(
                onPressed: () => ThemeController.instance.setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: context.surfaceColor,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(34, 34),
                ),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? AppColors.cautionGold : context.textPrimaryColor,
                  size: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KilerceBottomDock extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _KilerceBottomDock({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int promptCount = ref.watch(
      mealModuleNotifierProvider.select((s) => s.activePrompts.length),
    );

    return ValueListenableBuilder<KilerState>(
      valueListenable: KilerService.instance,
      builder: (context, state, _) {
        final shoppingCount = state.shoppingItems.length;
        final rescueCount = state.rescueCandidateItems.length;

        return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(
              top: BorderSide(color: context.cardBorderColor, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DockTabItem(
                    index: 0,
                    currentIndex: currentIndex,
                    icon: Icons.kitchen_rounded,
                    label: 'Kilerim',
                    badgeText: rescueCount > 0 ? '$rescueCount' : null,
                    onTap: () => onTap(0),
                  ),
                  _DockTabItem(
                    index: 1,
                    currentIndex: currentIndex,
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Yemek & Tarif',
                    badgeText: promptCount > 0 ? '$promptCount' : null,
                    onTap: () => onTap(1),
                  ),
                  _DockTabItem(
                    index: 2,
                    currentIndex: currentIndex,
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Barkod & Analiz',
                    onTap: () => onTap(2),
                  ),
                  _DockTabItem(
                    index: 3,
                    currentIndex: currentIndex,
                    icon: Icons.shopping_cart_checkout_rounded,
                    label: 'Alışveriş & Profil',
                    badgeText: shoppingCount > 0 ? '$shoppingCount' : null,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockTabItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final String? badgeText;
  final VoidCallback onTap;

  const _DockTabItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == currentIndex;
    final Color activeColor = AppColors.primaryEmerald;
    final Color inactiveColor = context.textSecondaryColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
                if (badgeText != null)
                  Positioned(
                    right: -8,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cautionGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
