import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../domain/bio_rpg_service.dart';
import 'bio_arena_screen.dart';
import 'bio_rhythm_screen.dart';
import 'pixar_avatar_studio_screen.dart';

class BioRpgHubController {
  static final ValueNotifier<int> activeTabIndex = ValueNotifier<int>(0);

  static void switchToTab(int index) {
    activeTabIndex.value = index.clamp(0, 3);
  }
}

class BioRpgHubScreen extends StatefulWidget {
  final Widget? arenaTabOverride;
  final Widget? rhythmTabOverride;
  final Widget? avatarTabOverride;

  const BioRpgHubScreen({
    super.key,
    this.arenaTabOverride,
    this.rhythmTabOverride,
    this.avatarTabOverride,
  });

  @override
  State<BioRpgHubScreen> createState() => _BioRpgHubScreenState();
}

class _BioRpgHubScreenState extends State<BioRpgHubScreen> {
  @override
  void initState() {
    super.initState();
    BioRpgService.instance.loadState();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BioRpgHubController.activeTabIndex,
      builder: (context, currentIndex, _) {
        return Scaffold(
          body: Column(
            children: [
              const _BioRpgTopHudBar(),
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: [
                    const ScannerScreen(),
                    widget.arenaTabOverride ?? const BioArenaScreen(),
                    widget.rhythmTabOverride ?? const BioRhythmScreen(),
                    widget.avatarTabOverride ?? const PixarAvatarStudioScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _BioRpgBottomDock(
            currentIndex: currentIndex,
            onTabSelected: (idx) => BioRpgHubController.switchToTab(idx),
          ),
        );
      },
    );
  }
}

class _BioRpgTopHudBar extends StatelessWidget {
  const _BioRpgTopHudBar();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final Color scoreColor = state.personalOrganicScore >= 75
            ? AppColors.primaryEmerald
            : (state.personalOrganicScore >= 50 ? AppColors.cautionGold : AppColors.dangerRed);

        return Container(
          padding: EdgeInsets.fromLTRB(14, topPadding + 8, 14, 10),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(
              bottom: BorderSide(color: context.cardBorderColor, width: 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Personal Living OrganicScore Pill
                  GestureDetector(
                    onTap: () => BioRpgHubController.switchToTab(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scoreColor.withValues(alpha: 0.22),
                            scoreColor.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.65), width: 1.4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_moon_rounded, color: scoreColor, size: 17),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BİYOLOJİK SKOR',
                                style: TextStyle(
                                  color: scoreColor,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                '${state.personalOrganicScore}/100',
                                style: TextStyle(
                                  color: context.textPrimaryColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Active Guardian Pill
                  Expanded(
                    child: GestureDetector(
                      onTap: () => BioRpgHubController.switchToTab(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: state.activeGuardian.primaryColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: state.activeGuardian.primaryColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_motion_rounded,
                              color: state.activeGuardian.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${state.activeGuardian.name} (Sv.${state.activeGuardian.level})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.textPrimaryColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '🔥 ${state.willpowerStreak} İrade Serisi • ${state.activeBosses.length} Boss',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.textSecondaryColor,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Step Stamina / Bio-Energy
                  GestureDetector(
                    onTap: () => BioRpgHubController.switchToTab(2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.cautionGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cautionGold.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.cautionGold, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            '${state.bioEnergy}',
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Bio-Crystals Currency
                  GestureDetector(
                    onTap: () => BioRpgHubController.switchToTab(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.toxicPurple.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.toxicPurple.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: AppColors.toxicPurple, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${state.bioCrystals}',
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (state.hasActiveDetoxQuest) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => BioRpgHubController.switchToTab(2),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.dangerRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_run_rounded, color: AppColors.dangerRed, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '☠️ Aktif Detoks Görevi: ${state.detoxCurrentSteps}/${state.activeDetoxTargetSteps} Adım (Toksik Yükü Temizle!)',
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BioRpgBottomDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const _BioRpgBottomDock({
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final int bossCount = state.activeBosses.length;
        return NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTabSelected,
          backgroundColor: context.surfaceColor,
          indicatorColor: AppColors.primaryEmerald.withValues(alpha: 0.22),
          height: 68,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_rounded),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryEmerald),
              label: 'Biyo-Radar',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: bossCount > 0,
                label: Text('$bossCount'),
                child: const Icon(Icons.sports_mma_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: bossCount > 0,
                label: Text('$bossCount'),
                child: const Icon(Icons.sports_mma_rounded, color: AppColors.toxicPurple),
              ),
              label: 'Bio-Arena',
            ),
            const NavigationDestination(
              icon: Icon(Icons.directions_walk_rounded),
              selectedIcon: Icon(Icons.directions_walk_rounded, color: AppColors.cautionGold),
              label: 'Biyo-Ritim',
            ),
            const NavigationDestination(
              icon: Icon(Icons.face_retouching_natural_rounded),
              selectedIcon: Icon(Icons.face_retouching_natural_rounded, color: AppColors.primaryEmerald),
              label: '3D Karakterim',
            ),
          ],
        );
      },
    );
  }
}
