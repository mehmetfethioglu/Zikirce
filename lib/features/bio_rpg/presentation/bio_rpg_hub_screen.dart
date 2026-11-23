import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import '../domain/bio_rpg_service.dart';
import 'bio_arena_screen.dart';
import 'bio_rhythm_screen.dart';
import 'pixar_avatar_studio_screen.dart';

class BioRpgHubScreen extends StatefulWidget {
  final int initialTabIndex;

  const BioRpgHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<BioRpgHubScreen> createState() => _BioRpgHubScreenState();
}

class _BioRpgHubScreenState extends State<BioRpgHubScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    BioRpgService.instance.loadState();
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ScannerScreen(
        embeddedInHub: true,
        onOpenArenaTab: () => _switchTab(1),
        onOpenCharacterTab: () => _switchTab(3),
      ),
      const BioArenaScreen(),
      const BioRhythmScreen(),
      const PixarAvatarStudioScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _BioRpgTopHudBar(
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
      bottomNavigationBar: _BioRpgBottomDock(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}

class _BioRpgTopHudBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const _BioRpgTopHudBar({
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final int loggedCount = state.scanHistory.length;
        final int avgLoggedScore = loggedCount == 0
            ? 0
            : (state.scanHistory
                        .map((e) => e.productScore)
                        .reduce((a, b) => a + b) /
                    loggedCount)
                .round();

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(color: context.cardBorderColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Brand + Subtitle
              GestureDetector(
                onTap: () => onTabSelected(0),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color:
                              AppColors.primaryEmerald.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primaryEmerald,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'OrganicScore',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Helal & Temiz Beslenme Rehberi',
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Real Logged Scan Status Pill (jumps to Günlüğüm)
              GestureDetector(
                onTap: () => onTabSelected(2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.subtleSurfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.cardBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 14,
                        color: loggedCount > 0
                            ? AppColors.primaryEmerald
                            : context.textSecondaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        loggedCount > 0
                            ? 'Ort. $avgLoggedScore/100'
                            : 'Günlük (0)',
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Quick Menu (Bakanlık Kara Liste, Aile Profilleri, Tema, Bulut)
              PopupMenuButton<String>(
                tooltip: 'Menü & Ayarlar',
                color: context.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.cardBorderColor),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: context.subtleSurfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: context.textPrimaryColor,
                  ),
                ),
                onSelected: (val) {
                  if (val == 'tagsis') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TaklitTagsisScreen(),
                      ),
                    );
                  } else if (val == 'family') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FamilyProfilesScreen(),
                      ),
                    );
                  } else if (val == 'theme') {
                    ThemeController.instance.setThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'tagsis',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gavel_rounded,
                          color: AppColors.dangerRed,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Bakanlık Taklit & Tağşiş Listesi',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'family',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.family_restroom_rounded,
                          color: AppColors.primaryEmerald,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Aile & Alerjen Profilleri',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'theme',
                    child: Row(
                      children: [
                        Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: AppColors.cautionGold,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isDark ? 'Aydınlık Tema' : 'Karanlık Tema',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BioRpgBottomDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BioRpgBottomDock({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.cardBorderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDockItem(
                context: context,
                index: 0,
                icon: Icons.qr_code_scanner_rounded,
                label: 'Tarayıcı',
              ),
              _buildDockItem(
                context: context,
                index: 1,
                icon: Icons.verified_user_outlined,
                label: 'Helal & E-Kod',
              ),
              _buildDockItem(
                context: context,
                index: 2,
                icon: Icons.insights_rounded,
                label: 'Günlüğüm',
              ),
              _buildDockItem(
                context: context,
                index: 3,
                icon: Icons.tune_rounded,
                label: 'Sağlık Profilim',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryEmerald.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? AppColors.primaryEmerald
                  : context.textSecondaryColor,
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryEmerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
