import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kilerce_logo_mark.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/domain/user_guide_service.dart';
import '../../onboarding/presentation/kilerce_user_guide_screen.dart';
import '../../profile/presentation/widgets/profile_avatar_menu_button.dart';
import '../../recipes/domain/meal_module_notifier.dart';
import '../../recipes/presentation/recipe_explorer_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
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
  final bool autoShowUserGuide;

  const KilerceHubScreen({
    super.key,
    this.initialTabIndex = 0,
    this.autoShowUserGuide = true,
  });

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
    if (KilerService.instance.value.pantryItems.isEmpty &&
        !KilerService.instance.value.isLoading) {
      KilerService.instance.loadAll();
    }
    if (widget.autoShowUserGuide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowFirstLaunchGuide();
      });
    }
  }

  Future<void> _maybeShowFirstLaunchGuide() async {
    final completed = await UserGuideService.instance.hasCompleted();
    if (completed || !mounted) return;
    await KilerceUserGuideScreen.show(context);
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
            KilerceTopHudBar(
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

class KilerceTopHudBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const KilerceTopHudBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  size: 32,
                  borderRadius: 10,
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kilerce',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.brandTagline ??
                          'BARKOD • DOLAP • TARİF',
                      style: TextStyle(
                        color: context.accentPrimary,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          const ProfileAvatarMenuButton(),
        ],
      ),
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
                    label: AppLocalizations.of(context)?.tabPantry ?? 'Kilerim',
                    badgeText: rescueCount > 0 ? '$rescueCount' : null,
                    onTap: () => onTap(0),
                  ),
                  _DockTabItem(
                    index: 1,
                    currentIndex: currentIndex,
                    icon: Icons.restaurant_menu_rounded,
                    label: AppLocalizations.of(context)?.tabRecipes ?? 'Yemek & Tarif',
                    badgeText: promptCount > 0 ? '$promptCount' : null,
                    onTap: () => onTap(1),
                  ),
                  _DockTabItem(
                    index: 2,
                    currentIndex: currentIndex,
                    icon: Icons.qr_code_scanner_rounded,
                    label: AppLocalizations.of(context)?.tabScanner ?? 'Barkod & Analiz',
                    onTap: () => onTap(2),
                  ),
                  _DockTabItem(
                    index: 3,
                    currentIndex: currentIndex,
                    icon: Icons.shopping_cart_checkout_rounded,
                    label: AppLocalizations.of(context)?.tabShoppingProfile ?? 'Alışveriş & Profil',
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
    final Color activeColor = context.accentPrimary;
    final Color inactiveColor = context.textSecondaryColor;

    return Semantics(
      button: true,
      selected: isSelected,
      label: badgeText != null ? '$label ($badgeText)' : label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? context.pastelSageTint : Colors.transparent,
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
                          color: context.pastelPeachTint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.accentWarm.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            color: context.accentWarm,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}
