import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/tv_mode_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/widgets/tv_focusable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/dashboard/presentation/screens/bismillah_dashboard_screen.dart';
import '../../features/zikir/presentation/screens/zikir_counter_screen.dart';
import '../../features/zikir/presentation/screens/zikir_list_screen.dart';
import '../../features/zikir/providers/zikir_providers.dart';
import '../../features/kuran/presentation/screens/kuran_page_screen.dart';
import '../../features/kuran/presentation/screens/mushaf_screen.dart';
import '../../features/namaz_vakitleri/presentation/screens/prayer_times_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/settings/presentation/screens/session_management_screen.dart';
import '../../features/settings/presentation/screens/user_guide_screen.dart';
import '../../features/kuran/presentation/screens/islamic_book_reader_screen.dart';
import '../../features/ezber/presentation/screens/memorization_screen.dart';
import '../../features/namaz_vakitleri/presentation/screens/fiqh_library_screen.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../features/hatim/presentation/screens/mukabele_hatim_screen.dart';
import '../../features/tv/presentation/screens/zikirce_tv_hub_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [
    SentryNavigatorObserver(),
  ],
  initialLocation: TvModeService.isHardwareTv ? '/' : '/zikir',
  redirect: (context, state) async {
    if (TvModeService.isHardwareTv && state.uri.path == '/onboarding') {
      return '/';
    }
    if (state.uri.path == '/onboarding' || state.uri.path == '/privacy') {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final isCompleted = prefs.getBool('IsOnboardingCompleted') ?? false;
    if (!isCompleted) {
      return '/onboarding';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final fromSettings = state.uri.queryParameters['fromSettings'] == 'true';
        return OnboardingScreen(isFromSettings: fromSettings);
      },
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return _MainScaffoldWithNavBar(state: state, child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const BismillahDashboardScreen(),
        ),
        GoRoute(
          path: '/zikir',
          builder: (context, state) => const ZikirCounterScreen(),
        ),
        GoRoute(
          path: '/zikirlist',
          builder: (context, state) => const ZikirListScreen(),
        ),
        GoRoute(
          path: '/namaz',
          builder: (context, state) => const PrayerTimesScreen(),
        ),
        GoRoute(
          path: '/kuran',
          builder: (context, state) => const KuranPageScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/tv-ambient',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => TvEvMescidiAmbientScreen(
        onClose: () => Navigator.of(context).maybePop(),
      ),
    ),
    GoRoute(
      path: '/mushaf',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final pageStr = state.uri.queryParameters['page'];
        final page = int.tryParse(pageStr ?? '') ?? 1;
        return MushafScreen(initialPage: page);
      },
    ),
    GoRoute(
      path: '/mukabele',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final pageStr = state.uri.queryParameters['page'];
        final page = int.tryParse(pageStr ?? '') ?? 1;
        final juzStr = state.uri.queryParameters['juz'];
        final juz = int.tryParse(juzStr ?? '');
        return MukabeleHatimScreen(initialPage: page, initialJuz: juz);
      },
    ),
    GoRoute(
      path: '/ezber',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MemorizationScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/sessions',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SessionManagementScreen(),
    ),
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/guide',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const UserGuideScreen(),
    ),
    GoRoute(
      path: '/kulliyat',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final bookId = state.uri.queryParameters['bookId'] ?? 'book_tafseer_kuran_yolu';
        if (bookId == 'book_mushaf') {
          final pageStr = state.uri.queryParameters['page'];
          final page = int.tryParse(pageStr ?? '') ?? 1;
          return MushafScreen(initialPage: page);
        }
        return IslamicBookReaderScreen(bookId: bookId);
      },
    ),
    GoRoute(
      path: '/fiqh',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FiqhLibraryScreen(),
    ),
  ],
);

class _MainScaffoldWithNavBar extends ConsumerWidget {
  final Widget child;
  final GoRouterState state;

  const _MainScaffoldWithNavBar({required this.child, required this.state});

  int _calculateSelectedIndex(BuildContext context) {
    final location = state.uri.path;
    if (location.startsWith('/zikirlist')) return 2;
    if (location.startsWith('/zikir')) return 1;
    if (location.startsWith('/namaz')) return 3;
    if (location.startsWith('/kuran')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/zikir');
        break;
      case 2:
        context.go('/zikirlist');
        break;
      case 3:
        context.go('/namaz');
        break;
      case 4:
        context.go('/kuran');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTvMode = ref.watch(isTvModeProvider);
    final selectedIndex = _calculateSelectedIndex(context);
    final colors = context.colors;
    final isDark = colors.statusBrightness == Brightness.light;

    final navBg = colors.cardBackground;
    final activeColor = colors.accent;
    final inactiveColor = colors.secondaryTextAlt;

    final isFocusMode = ref.watch(isZikirFocusModeProvider);
    final path = state.uri.path;
    final hideNavBar = isFocusMode ||
        path.startsWith('/settings') ||
        path.startsWith('/privacy') ||
        path.startsWith('/mushaf') ||
        path.startsWith('/ezber');

    // Android TV / Zikirce TV Mode: 10-Foot Leanback Navigation Rail + Full-Screen Content
    if (isTvMode) {
      Widget tvContent = child;
      if (path == '/' || path.isEmpty) {
        tvContent = const ZikirceTvHubScreen(initialSection: 0);
      } else if (path.startsWith('/kuran')) {
        tvContent = const ZikirceTvHubScreen(initialSection: 1);
      }

      return Scaffold(
        backgroundColor: const Color(0xFF0A1410),
        body: Row(
          children: [
            if (!hideNavBar)
              _buildTvSideNavigationRail(
                context: context,
                ref: ref,
                selectedIndex: selectedIndex,
              ),
            Expanded(
              child: tvContent,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: colors.pageBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: child,
        ),
      ),
      bottomNavigationBar: hideNavBar
          ? null
          : SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    margin: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                    height: 68,
                    decoration: BoxDecoration(
                      color: navBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.borderStroke, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          index: 0,
                          svgPath: 'assets/images/nav_panel.svg',
                          fallbackIcon: Icons.auto_graph_rounded,
                          isSelected: selectedIndex == 0,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          onTap: () => _onItemTapped(0, context),
                        ),
                        _buildNavItem(
                          index: 1,
                          svgPath: 'assets/images/nav_zikir.svg',
                          fallbackIcon: Icons.fingerprint_rounded,
                          isSelected: selectedIndex == 1,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          onTap: () => _onItemTapped(1, context),
                        ),
                        _buildNavItem(
                          index: 2,
                          svgPath: 'assets/images/nav_liste.svg',
                          fallbackIcon: Icons.format_list_bulleted_rounded,
                          isSelected: selectedIndex == 2,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          onTap: () => _onItemTapped(2, context),
                        ),
                        _buildNavItem(
                          index: 3,
                          svgPath: 'assets/images/nav_vakit.svg',
                          fallbackIcon: Icons.access_time_filled_rounded,
                          isSelected: selectedIndex == 3,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          onTap: () => _onItemTapped(3, context),
                        ),
                        _buildNavItem(
                          index: 4,
                          svgPath: 'assets/images/nav_kuran.svg',
                          fallbackIcon: Icons.menu_book_rounded,
                          isSelected: selectedIndex == 4,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          onTap: () => _onItemTapped(4, context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTvSideNavigationRail({
    required BuildContext context,
    required WidgetRef ref,
    required int selectedIndex,
  }) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 108,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(
          right: BorderSide(
            color: colors.borderStroke,
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/zikirce_logo.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.tv_rounded, color: colors.accent, size: 22),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ZİKİRCE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: colors.accent,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    _buildTvRailButton(
                      context: context,
                      icon: Icons.home_rounded,
                      label: 'Meydan',
                      isSelected: selectedIndex == 0,
                      onSelect: () => _onItemTapped(0, context),
                    ),
                    const SizedBox(height: 8),
                    _buildTvRailButton(
                      context: context,
                      icon: Icons.import_contacts_rounded,
                      label: 'Külliyat',
                      isSelected: selectedIndex == 4,
                      onSelect: () => _onItemTapped(4, context),
                    ),
                    const SizedBox(height: 8),
                    _buildTvRailButton(
                      context: context,
                      icon: Icons.record_voice_over_rounded,
                      label: 'Mukabele',
                      isSelected: false,
                      onSelect: () => context.push('/mukabele'),
                    ),
                    const SizedBox(height: 8),
                    _buildTvRailButton(
                      context: context,
                      icon: Icons.fingerprint_rounded,
                      label: 'Tesbihat',
                      isSelected: selectedIndex == 1,
                      onSelect: () => _onItemTapped(1, context),
                    ),
                    const SizedBox(height: 8),
                    _buildTvRailButton(
                      context: context,
                      icon: Icons.access_time_filled_rounded,
                      label: 'Vakitler',
                      isSelected: selectedIndex == 3,
                      onSelect: () => _onItemTapped(3, context),
                    ),
                    const SizedBox(height: 8),
                    _buildTvRailButton(
                      context: context,
                      icon: Icons.mosque_rounded,
                      label: 'Ev Mescidi',
                      isSelected: false,
                      onSelect: () => context.push('/tv-ambient'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              child: _buildTvRailButton(
                context: context,
                icon: Icons.settings_rounded,
                label: 'Ayarlar',
                isSelected: false,
                onSelect: () => context.push('/settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvRailButton({
    required BuildContext context,
    required IconData icon,
    IconData? fallbackIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    final colors = context.colors;
    final effectiveIcon = fallbackIcon ?? icon;
    return TvFocusable(
      onPressed: onSelect,
      borderRadius: 16.0,
      focusScale: 1.05,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.16)
              : colors.pageBackground.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.borderStroke,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              effectiveIcon,
              size: 22,
              color: isSelected ? colors.accent : colors.secondaryTextAlt,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? colors.accent : colors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String svgPath,
    required IconData fallbackIcon,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: isSelected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: SvgPicture.asset(
            svgPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 24, color: color),
          ),
        ),
      ),
    );
  }
}
