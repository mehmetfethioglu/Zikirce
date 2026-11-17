import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cue_models.dart';
import '../providers/cuedeck_providers.dart';
import '../widgets/modals/cue_pro_paywall_sheet.dart';
import '../widgets/modals/share_to_tv_beam_sheet.dart';
import '../widgets/remote/cue_ad_banner.dart';
import '../widgets/remote/g10_remote_chassis.dart';
import '../widgets/remote/quick_launch_app_dock.dart';
import 'cuedeck_settings_screen.dart';

export '../widgets/modals/cue_pro_paywall_sheet.dart'
    show CueProPaywallSheet, showCueProPaywallSheet;
export '../widgets/modals/share_to_tv_beam_sheet.dart'
    show ShareToTvBeamSheet, showShareToTvBeamSheet;
export '../widgets/modals/tv_discovery_pairing_sheets.dart'
    show showIrBlasterBrandPickerSheet, showTvDiscoveryModal;
export '../widgets/planner/watch_planner_widgets.dart'
    show AddWatchCueSheet, WatchCueCard, WatchPlanMasteryHeader;
export '../widgets/remote/g10_remote_chassis.dart'
    show G10PhysicalRemoteChassis;
export '../widgets/remote/quick_launch_app_dock.dart'
    show CueDeckBrandBadge, QuickLaunchAppDock, ReminderAlertBanner;
export '../widgets/remote/remote_shortcut_picker_sheet.dart'
    show showRemoteShortcutPickerSheet;
export '../widgets/remote/tactile_dpad_touchpad.dart' show TactileDpadDialWidget;
export 'cuedeck_settings_screen.dart'
    show CueDeckSettingsScreen, showCueWhatsNewModal;

/// Main screen for CueDeck: Google TV G10 Reference Physical Remote Control Chassis
/// supporting True Black (`#000000`) Dark Mode and Classic White Light Mode,
/// automatic OS Share Sheet link-to-TV beaming, and Paywall / Release Notes sheets.
class CueDeckHomeScreen extends ConsumerStatefulWidget {
  const CueDeckHomeScreen({super.key});

  @override
  ConsumerState<CueDeckHomeScreen> createState() => _CueDeckHomeScreenState();
}

class _CueDeckHomeScreenState extends ConsumerState<CueDeckHomeScreen> {
  bool _checkedStartupReleaseNotes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowStartupReleaseNotes();
      final pending = ref.read(cueDeckProvider).pendingSharedPayload;
      if (pending != null && mounted) {
        showShareToTvBeamSheet(context, pending);
      }
    });
  }

  Future<void> _maybeShowStartupReleaseNotes() async {
    if (_checkedStartupReleaseNotes || !mounted) return;
    _checkedStartupReleaseNotes = true;
    final releaseNotesService = ref.read(cueReleaseNotesServiceProvider);
    final shouldShow = await releaseNotesService.shouldShowWhatsNewOnStartup();
    if (!shouldShow || !mounted) return;
    await releaseNotesService.markCurrentVersionSeen();
    if (!mounted) return;
    final isDarkMode = ref.read(cueDeckProvider).isDarkMode;
    await showCueWhatsNewModal(
      context,
      isDarkMode: isDarkMode,
      initialStartupMode: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SharedCuePayload?>(
      cueDeckProvider.select((s) => s.pendingSharedPayload),
      (SharedCuePayload? previous, SharedCuePayload? next) {
        if (next != null && next != previous && mounted) {
          showShareToTvBeamSheet(context, next);
        }
      },
    );

    ref.listen<bool>(
      cueDeckProvider.select((s) => s.shouldPromptPaywall),
      (bool? previous, bool next) {
        if (next && mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          ref.read(cueDeckProvider.notifier).dismissPaywallPrompt();
          showCueProPaywallSheet(context);
        }
      },
    );

    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF000000) : const Color(0xFFECEEF2),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const ReminderAlertBanner(),
                      G10PhysicalRemoteChassis(isDarkMode: isDarkMode),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CueNonIntrusiveAdBanner(showQuickRemoveAction: true),
            ),
          ],
        ),
      ),
    );
  }
}
