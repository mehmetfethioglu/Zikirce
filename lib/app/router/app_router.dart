import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../core/layout/foldable_layout_info.dart';
import '../../core/layout/foldable_two_pane.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/tv_mode_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/dashboard/presentation/screens/bismillah_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/detailed_stats_screen.dart';
import 'app_startup_route_config.dart';
export 'app_startup_route_config.dart';
import '../../features/zikir/presentation/screens/zikir_counter_screen.dart';
import '../../features/zikir/providers/zikir_providers.dart';
import '../../features/irfan/presentation/screens/irfan_meydani_screen.dart';
import '../../features/irfan/presentation/screens/irfan_quiz_session_screen.dart';
import '../../features/kuran/presentation/screens/kuran_page_screen.dart';
import '../../features/kuran/presentation/screens/mushaf_screen.dart';
import '../../features/namaz_vakitleri/presentation/screens/prayer_times_screen.dart';
import '../../features/namaz_vakitleri/presentation/screens/qibla_compass_screen.dart';
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
  initialLocation: AppStartupRouteConfig.resolveInitialLocation(
    isHardwareTv: TvModeService.isHardwareTv,
  ),
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
          builder: (context, state) {
            final openSheet = state.uri.queryParameters['openSheet'] == '1';
            return ZikirCounterScreen(openSelectionSheetOnMount: openSheet);
          },
        ),
        GoRoute(
          path: '/irfan',
          builder: (context, state) {
            final tab = state.uri.queryParameters['tab'];
            final farzId = int.tryParse(state.uri.queryParameters['farzId'] ?? '');
            return IrfanMeydaniScreen(
              initialTab: tab,
              initialFarzId: farzId,
            );
          },
        ),
        GoRoute(
          path: '/zikirlist',
          redirect: (context, state) => '/zikir?openSheet=1',
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
      path: '/irfan/quiz',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IrfanQuizSessionScreen(),
    ),
    GoRoute(
      path: '/fiqh',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final farzId = int.tryParse(state.uri.queryParameters['farzId'] ?? '');
        return FiqhLibraryScreen(initialFarzId: farzId);
      },
    ),
    GoRoute(
      path: '/stats',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DetailedStatsScreen(),
    ),
    GoRoute(
      path: '/qibla',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '');
        final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '');
        return QiblaCompassScreen(userLat: lat, userLng: lng);
      },
    ),
  ],
);

class _MainScaffoldWithNavBar extends ConsumerWidget {
  final Widget child;
  final GoRouterState state;

  const _MainScaffoldWithNavBar({required this.child, required this.state});

  int _calculateSelectedIndex() {
    final location = state.uri.path;
    if (location.startsWith('/irfan')) return 2;
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
        context.go('/irfan');
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
    final selectedIndex = _calculateSelectedIndex();
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

    // Android TV / Zikirce TV Mode: Yalın Tam Ekran Kur'ân-ı Kerîm & Mukabele Arayüzü
    if (isTvMode) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1410),
        body: ZikirceTvHubScreen(),
      );
    }

    final layout = FoldableLayoutInfo.of(context);
    final isTr = context.l10n.isTurkish;
    final destinations = _buildNavDestinations(isTr);

    if (layout.useNavigationRail && !hideNavBar) {
      final mediaPadding = MediaQuery.paddingOf(context);
      final railContentWidth = layout.useExtendedNavigationRail ? 184.0 : 76.0;
      const railOuterHorizontalMargin = 16.0;
      final railTotalWidth =
          mediaPadding.left + railOuterHorizontalMargin + railContentWidth;

      return Scaffold(
        backgroundColor: colors.pageBackground,
        body: Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdaptiveFoldableNavRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              railWidth: railContentWidth,
              isExtended: layout.useExtendedNavigationRail,
              navBg: navBg,
              borderStroke: colors.borderStroke,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              primaryTextColor: colors.primaryText,
              isDark: isDark,
              onSelect: (index) => _onItemTapped(index, context),
            ),
            Expanded(
              child: FoldableViewportScope(
                windowOriginOffset: Offset(railTotalWidth, 0),
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    if (hideNavBar && layout.useNavigationRail) {
      return Scaffold(
        backgroundColor: colors.pageBackground,
        body: FoldableViewportScope(
          windowOriginOffset: Offset.zero,
          child: child,
        ),
      );
    }

    final navHorizontalMargin = layout.isNarrowCoverScreen ? 8.0 : 14.0;

    return Scaffold(
      extendBody: true,
      backgroundColor: colors.pageBackground,
      body: FoldableViewportScope(
        windowOriginOffset: Offset.zero,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: child,
          ),
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
                    margin: EdgeInsets.only(
                      left: navHorizontalMargin,
                      right: navHorizontalMargin,
                      bottom: 14,
                    ),
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
                      children: [
                        for (int i = 0; i < destinations.length; i++)
                          Expanded(
                            child: _BottomNavBarItem(
                              svgPath: destinations[i].svgPath,
                              fallbackIcon: destinations[i].fallbackIcon,
                              tooltip: destinations[i].label,
                              isSelected: selectedIndex == i,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () => _onItemTapped(i, context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _NavDestinationData {
  final String svgPath;
  final IconData fallbackIcon;
  final String label;

  const _NavDestinationData({
    required this.svgPath,
    required this.fallbackIcon,
    required this.label,
  });
}

List<_NavDestinationData> _buildNavDestinations(bool isTr) {
  return <_NavDestinationData>[
    _NavDestinationData(
      svgPath: 'assets/images/nav_panel.svg',
      fallbackIcon: Icons.home_rounded,
      label: isTr ? 'Ana Sayfa' : 'Home',
    ),
    _NavDestinationData(
      svgPath: 'assets/images/nav_zikir.svg',
      fallbackIcon: Icons.fingerprint_rounded,
      label: isTr ? 'Zikir' : 'Dhikr',
    ),
    _NavDestinationData(
      svgPath: 'assets/images/nav_irfan.svg',
      fallbackIcon: Icons.auto_awesome_rounded,
      label: isTr ? 'İrfan' : 'Irfan',
    ),
    _NavDestinationData(
      svgPath: 'assets/images/nav_vakit.svg',
      fallbackIcon: Icons.access_time_filled_rounded,
      label: isTr ? 'Vakitler' : 'Prayers',
    ),
    _NavDestinationData(
      svgPath: 'assets/images/nav_kuran.svg',
      fallbackIcon: Icons.menu_book_rounded,
      label: isTr ? 'Kur’ân' : 'Qur’an',
    ),
  ];
}

class _AdaptiveFoldableNavRail extends StatelessWidget {
  final List<_NavDestinationData> destinations;
  final int selectedIndex;
  final double railWidth;
  final bool isExtended;
  final Color navBg;
  final Color borderStroke;
  final Color activeColor;
  final Color inactiveColor;
  final Color primaryTextColor;
  final bool isDark;
  final ValueChanged<int> onSelect;

  const _AdaptiveFoldableNavRail({
    required this.destinations,
    required this.selectedIndex,
    required this.railWidth,
    required this.isExtended,
    required this.navBg,
    required this.borderStroke,
    required this.activeColor,
    required this.inactiveColor,
    required this.primaryTextColor,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        mediaPadding.left + 10,
        mediaPadding.top + 12,
        6,
        mediaPadding.bottom + 12,
      ),
      child: SizedBox(
        width: railWidth,
        child: Container(
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderStroke, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.07),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 24).clamp(0.0, double.infinity),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < destinations.length; i++) ...[
                        _RailNavBarItem(
                          destination: destinations[i],
                          isSelected: selectedIndex == i,
                          isExtended: isExtended,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          primaryTextColor: primaryTextColor,
                          onTap: () => onSelect(i),
                        ),
                        if (i < destinations.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RailNavBarItem extends StatelessWidget {
  final _NavDestinationData destination;
  final bool isSelected;
  final bool isExtended;
  final Color activeColor;
  final Color inactiveColor;
  final Color primaryTextColor;
  final VoidCallback onTap;

  const _RailNavBarItem({
    required this.destination,
    required this.isSelected,
    required this.isExtended,
    required this.activeColor,
    required this.inactiveColor,
    required this.primaryTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? activeColor : inactiveColor;
    final textColor = isSelected ? primaryTextColor : inactiveColor;

    return Tooltip(
      message: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: isExtended ? 14 : 0),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: isExtended
                ? Row(
                    children: [
                      SvgPicture.asset(
                        destination.svgPath,
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                        errorBuilder: (_, __, ___) => Icon(
                          destination.fallbackIcon,
                          size: 22,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: AnimatedScale(
                      scale: isSelected ? 1.12 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: SvgPicture.asset(
                        destination.svgPath,
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                        errorBuilder: (_, __, ___) => Icon(
                          destination.fallbackIcon,
                          size: 24,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBarItem extends StatelessWidget {
  final String svgPath;
  final IconData fallbackIcon;
  final String tooltip;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _BottomNavBarItem({
    required this.svgPath,
    required this.fallbackIcon,
    required this.tooltip,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : inactiveColor;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
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
      ),
    );
  }
}
