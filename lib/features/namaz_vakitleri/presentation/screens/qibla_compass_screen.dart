import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/qibla_math.dart';
import '../../domain/qibla_models.dart';
import '../../providers/qibla_providers.dart';
import '../widgets/city_selection_sheet.dart';
import '../widgets/qibla_3d_scene.dart';
import '../widgets/qibla_finder_card.dart';

class QiblaCompassScreen extends ConsumerWidget {
  final double? userLat;
  final double? userLng;

  const QiblaCompassScreen({
    super.key,
    this.userLat,
    this.userLng,
  });

  static void _openCitySelection(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CitySelectionSheet(),
    );
  }

  static void _openCalibrationSheet(BuildContext context, QiblaState state) {
    final colors = context.colors;
    final l10n = context.l10n;
    final decSign = state.declinationDeg >= 0 ? '+' : '';

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: colors.bottomSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderStroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Icon(Icons.wb_sunny_outlined, color: colors.accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.qiblaCalibrateTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.qiblaCalibrateDesc,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colors.secondaryTextAlt,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _InfoTag(
                    label:
                        '${state.cityName} ($decSign${state.declinationDeg.toStringAsFixed(1)}°)',
                    colors: colors,
                  ),
                  _InfoTag(
                    label: '${state.magneticFieldUt.toStringAsFixed(0)} µT',
                    colors: colors,
                  ),
                  _InfoTag(
                    label: state.isSunVisible
                        ? '☀️ ${l10n.qiblaSunVerifyLabel}: ${state.sunAzimuthDeg.round()}°'
                        : '🌙 ${l10n.qiblaSunNightLabel}',
                    colors: colors,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _figureModeLabel(QiblaFigureMode mode, AppLocalizations l10n) {
    switch (mode) {
      case QiblaFigureMode.male:
        return l10n.qiblaModeMale;
      case QiblaFigureMode.female:
        return l10n.qiblaModeFemale;
      case QiblaFigureMode.prayerRugOnly:
        return l10n.qiblaModeRugOnly;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = QiblaParams(userLat: userLat, userLng: userLng);
    final colors = context.colors;
    final l10n = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showCityInAppBar =
        userLat == null && userLng == null && screenWidth >= 350;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colors.primaryText,
                  size: 20,
                ),
              )
            : null,
        titleSpacing: Navigator.of(context).canPop() ? 0 : 16,
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                l10n.qibla3DTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primaryText,
                  fontSize: screenWidth < 360 ? 15.5 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (showCityInAppBar) ...<Widget>[
              const SizedBox(width: 8),
              Flexible(
                child: _AppBarCityChip(
                  params: params,
                  onTap: () => _openCitySelection(context),
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          _FigureModeAction(params: params),
          _SoundToggleAction(params: params),
          IconButton(
            key: const Key('qibla_calibration_info_btn'),
            tooltip: l10n.qiblaCalibrateTitle,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: const EdgeInsets.only(left: 4, right: 10),
            onPressed: () {
              final currentState = ref.read(qiblaControllerProvider(params));
              _openCalibrationSheet(context, currentState);
            },
            icon: Icon(
              Icons.help_outline_rounded,
              color: colors.secondaryTextAlt,
              size: 20,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSideBySide =
                constraints.maxWidth >= 560 && constraints.maxHeight < 480;
            final isNarrow = constraints.maxWidth < 360;

            if (isSideBySide) {
              final dialSize = math
                  .min(constraints.maxHeight - 20, constraints.maxWidth * 0.48)
                  .clamp(160.0, 320.0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _StatusPillSection(
                              params: params,
                              showInteractiveHint: false,
                            ),
                            const SizedBox(height: 8),
                            _ScenarioStepperBar(
                              params: params,
                              compact: true,
                            ),
                            const SizedBox(height: 10),
                            _MetricsRow(
                              params: params,
                              compact: true,
                            ),
                            const SizedBox(height: 10),
                            _BottomControlsRow(
                              params: params,
                              showCityPill: false,
                              onCityTap: () => _openCitySelection(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      key: const Key('qibla_compass_dial'),
                      width: dialSize,
                      height: dialSize,
                      child: _Qibla3DStage(params: params),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 10 : 16,
                6,
                isNarrow ? 10 : 16,
                12,
              ),
              child: Column(
                children: <Widget>[
                  _StatusPillSection(
                    params: params,
                    showInteractiveHint: true,
                  ),
                  const SizedBox(height: 6),
                  _ScenarioStepperBar(
                    params: params,
                    compact: isNarrow,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, dialBox) {
                        final w = math.min(dialBox.maxWidth, 440.0);
                        final h = math.min(dialBox.maxHeight, 440.0);
                        return Center(
                          child: SizedBox(
                            key: const Key('qibla_compass_dial'),
                            width: w,
                            height: h,
                            child: _Qibla3DStage(params: params),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MetricsRow(
                    params: params,
                    compact: isNarrow,
                  ),
                  const SizedBox(height: 8),
                  _BottomControlsRow(
                    params: params,
                    showCityPill: !showCityInAppBar &&
                        userLat == null &&
                        userLng == null,
                    onCityTap: () => _openCitySelection(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppBarCityChip extends ConsumerWidget {
  final QiblaParams params;
  final VoidCallback onTap;

  const _AppBarCityChip({required this.params, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityName = ref.watch(
      qiblaControllerProvider(params).select((s) => s.cityName),
    );
    final colors = context.colors;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderStroke, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.location_on_rounded, size: 13, color: colors.accent),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                cityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureModeAction extends ConsumerWidget {
  final QiblaParams params;

  const _FigureModeAction({required this.params});

  IconData _iconFor(QiblaFigureMode mode) {
    switch (mode) {
      case QiblaFigureMode.male:
        return Icons.person_outline_rounded;
      case QiblaFigureMode.female:
        return Icons.person_2_outlined;
      case QiblaFigureMode.prayerRugOnly:
        return Icons.mosque_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      qiblaControllerProvider(params).select((s) => s.figureMode),
    );
    final colors = context.colors;
    final l10n = context.l10n;

    return IconButton(
      key: const Key('qibla_figure_mode_btn'),
      tooltip: QiblaCompassScreen._figureModeLabel(mode, l10n),
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: () =>
          ref.read(qiblaControllerProvider(params).notifier).cycleFigureMode(),
      icon: Icon(_iconFor(mode), color: colors.accent, size: 21),
    );
  }
}

class _SoundToggleAction extends ConsumerWidget {
  final QiblaParams params;

  const _SoundToggleAction({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSoundEnabled = ref.watch(
      qiblaControllerProvider(params).select((s) => s.isSoundEnabled),
    );
    final colors = context.colors;
    final l10n = context.l10n;

    return IconButton(
      key: const Key('qibla_sound_toggle_btn'),
      tooltip: isSoundEnabled ? l10n.qiblaSoundOn : l10n.qiblaSoundOff,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: () =>
          ref.read(qiblaControllerProvider(params).notifier).toggleSound(),
      icon: Icon(
        isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        color: isSoundEnabled ? colors.accent : colors.secondaryTextAlt,
        size: 20,
      ),
    );
  }
}

class _Qibla3DStage extends ConsumerWidget {
  final QiblaParams params;

  const _Qibla3DStage({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qiblaControllerProvider(params));
    final isTr = context.l10n.isTurkish;
    final notifier = ref.read(qiblaControllerProvider(params).notifier);
    return Qibla3DScene(
      state: state,
      isTurkish: isTr,
      onManualRotate: notifier.rotateManualBy,
      onTapAligned: notifier.replayTakbir,
    );
  }
}

class _ScenarioStepperBar extends ConsumerWidget {
  final QiblaParams params;
  final bool compact;

  const _ScenarioStepperBar({
    required this.params,
    required this.compact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepState = ref.watch(
      qiblaControllerProvider(params).select(
        (s) => (
          isFlatOrPreview: s.isInteractivePreview || s.isPhoneFlat,
          phase: s.phase,
        ),
      ),
    );
    final colors = context.colors;
    final l10n = context.l10n;
    const goldColor = Color(0xFFD4A574);
    const emeraldColor = Color(0xFF1F7A5C);

    final isFlatDone = stepState.isFlatOrPreview;
    final isFaceDone = stepState.phase == QiblaAlignmentPhase.takbir ||
        stepState.phase == QiblaAlignmentPhase.qiyam;
    final isTakbirDone = stepState.phase == QiblaAlignmentPhase.qiyam;
    final isTakbirActive = stepState.phase == QiblaAlignmentPhase.takbir;

    Widget buildStep({
      required String indexText,
      required String label,
      required bool done,
      required bool active,
      Key? stepKey,
    }) {
      final Color tint = done
          ? emeraldColor
          : (active ? (isTakbirActive ? goldColor : colors.accent) : colors.secondaryTextAlt);
      return Flexible(
        child: Container(
          key: stepKey,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: done || active
                ? tint.withValues(alpha: 0.13)
                : colors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done || active
                  ? tint.withValues(alpha: 0.48)
                  : colors.borderStroke,
              width: 0.85,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                size: compact ? 11.5 : 13,
                color: done || active ? tint : colors.secondaryTextAlt.withValues(alpha: 0.55),
              ),
              SizedBox(width: compact ? 3 : 4),
              Flexible(
                child: Text(
                  '$indexText $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: done || active ? FontWeight.w700 : FontWeight.w500,
                    color: done || active ? colors.primaryText : colors.secondaryTextAlt,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget connector(bool lit) => Container(
          width: compact ? 6 : 12,
          height: 1.3,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: (lit ? emeraldColor : colors.borderStroke).withValues(alpha: lit ? 0.65 : 0.7),
        );

    return Row(
      key: const Key('qibla_scenario_stepper'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        buildStep(
          indexText: '1.',
          label: l10n.qiblaStepFlat,
          done: isFlatDone,
          active: !isFlatDone,
        ),
        connector(isFlatDone),
        buildStep(
          indexText: '2.',
          label: l10n.qiblaStepFace,
          done: isFaceDone,
          active: isFlatDone && !isFaceDone,
        ),
        connector(isFaceDone),
        buildStep(
          indexText: '3.',
          label: l10n.qiblaStepTakbir,
          done: isTakbirDone,
          active: isTakbirActive,
        ),
      ],
    );
  }
}

class _StatusPillSection extends ConsumerWidget {
  final QiblaParams params;
  final bool showInteractiveHint;

  const _StatusPillSection({
    required this.params,
    required this.showInteractiveHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusSlice = ref.watch(
      qiblaControllerProvider(params).select(
        (s) => (
          sensorStatus: s.sensorStatus,
          isInteractivePreview: s.isInteractivePreview,
          isPhoneFlat: s.isPhoneFlat,
          phase: s.phase,
          absRoundedDelta: s.angleDeltaDeg.abs().round(),
          isRight: s.angleDeltaDeg >= 0,
        ),
      ),
    );
    final colors = context.colors;
    final l10n = context.l10n;

    const goldColor = Color(0xFFD4A574);
    const emeraldColor = Color(0xFF1F7A5C);
    const amberColor = Color(0xFFD97706);

    late final IconData icon;
    late final String text;
    late final Color tint;

    if (statusSlice.sensorStatus == QiblaSensorStatus.interference) {
      icon = Icons.warning_amber_rounded;
      text = l10n.qiblaInterferenceHint;
      tint = amberColor;
    } else if (!statusSlice.isInteractivePreview && !statusSlice.isPhoneFlat) {
      icon = Icons.screen_rotation_alt_rounded;
      text = l10n.qiblaHoldFlatHint;
      tint = amberColor;
    } else if (statusSlice.phase == QiblaAlignmentPhase.takbir) {
      icon = Icons.auto_awesome_rounded;
      text = l10n.qiblaTakbirStatus;
      tint = goldColor;
    } else if (statusSlice.phase == QiblaAlignmentPhase.qiyam) {
      icon = Icons.check_circle_rounded;
      text = l10n.qiblaAlignedStatus;
      tint = emeraldColor;
    } else if (statusSlice.phase == QiblaAlignmentPhase.locked ||
        statusSlice.phase == QiblaAlignmentPhase.approaching) {
      icon = Icons.explore_rounded;
      text = l10n.qiblaApproaching.replaceAll(
        '{0}',
        '${statusSlice.absRoundedDelta}',
      );
      tint = goldColor;
    } else {
      icon = statusSlice.isRight
          ? Icons.rotate_right_rounded
          : Icons.rotate_left_rounded;
      final template =
          statusSlice.isRight ? l10n.qiblaTurnRight : l10n.qiblaTurnLeft;
      text = template.replaceAll('{0}', '${statusSlice.absRoundedDelta}');
      tint = colors.accent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tint.withValues(alpha: 0.45),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showInteractiveHint && statusSlice.isInteractivePreview) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l10n.qiblaInteractiveHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.secondaryTextAlt,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricsRow extends ConsumerWidget {
  final QiblaParams params;
  final bool compact;

  const _MetricsRow({
    required this.params,
    required this.compact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(
      qiblaControllerProvider(params).select(
        (s) => (
          qiblaBearingDeg: s.qiblaBearingDeg,
          distanceKm: s.distanceKm,
          sunAzimuthDeg: s.sunAzimuthDeg,
          isSunVisible: s.isSunVisible,
        ),
      ),
    );
    final colors = context.colors;
    final l10n = context.l10n;
    final isTr = l10n.isTurkish;

    final bearingCardinal = QiblaMath.cardinalDirectionLabel(
      metrics.qiblaBearingDeg,
      isTurkish: isTr,
    );
    final sunCardinal = QiblaMath.cardinalDirectionLabel(
      metrics.sunAzimuthDeg,
      isTurkish: isTr,
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricCard(
            label: l10n.qiblaAngleLabel,
            value: '${metrics.qiblaBearingDeg.round()}° $bearingCardinal',
            icon: Icons.explore_outlined,
            colors: colors,
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: _MetricCard(
            label: l10n.qiblaDistanceLabel,
            value: QiblaFinderCard.formatKm(
              metrics.distanceKm,
              isTurkish: isTr,
            ),
            icon: Icons.mosque_outlined,
            colors: colors,
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: _MetricCard(
            label: l10n.qiblaSunVerifyLabel,
            value: metrics.isSunVisible
                ? '☀️ ${metrics.sunAzimuthDeg.round()}° $sunCardinal'
                : '🌙 ${l10n.qiblaSunNightLabel}',
            icon: metrics.isSunVisible
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_round,
            colors: colors,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final AppThemeColors colors;
  final bool compact;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderStroke, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 12.5, color: colors.accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.secondaryTextAlt,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomControlsRow extends ConsumerWidget {
  final QiblaParams params;
  final bool showCityPill;
  final VoidCallback onCityTap;

  const _BottomControlsRow({
    required this.params,
    required this.showCityPill,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controls = ref.watch(
      qiblaControllerProvider(params).select(
        (s) => (
          cityName: s.cityName,
          figureMode: s.figureMode,
          isInteractivePreview: s.isInteractivePreview,
          phase: s.phase,
        ),
      ),
    );
    final colors = context.colors;
    final l10n = context.l10n;
    final controller = ref.read(qiblaControllerProvider(params).notifier);
    final modeLabel = QiblaCompassScreen._figureModeLabel(
      controls.figureMode,
      l10n,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        if (showCityPill)
          InkWell(
            onTap: onCityTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.location_on_rounded, size: 13, color: colors.accent),
                  const SizedBox(width: 4),
                  Text(
                    controls.cityName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        InkWell(
          onTap: controller.cycleFigureMode,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderStroke, width: 0.8),
            ),
            child: Text(
              modeLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.primaryText,
              ),
            ),
          ),
        ),
        InkWell(
          key: const Key('qibla_preview_toggle_btn'),
          onTap: controller.toggleInteractivePreview,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: controls.isInteractivePreview
                  ? colors.accent.withValues(alpha: 0.14)
                  : colors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: controls.isInteractivePreview
                    ? colors.accent.withValues(alpha: 0.45)
                    : colors.borderStroke,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  controls.isInteractivePreview
                      ? Icons.sensors_rounded
                      : Icons.touch_app_rounded,
                  size: 13.5,
                  color: controls.isInteractivePreview
                      ? colors.accent
                      : colors.secondaryTextAlt,
                ),
                const SizedBox(width: 5),
                Text(
                  controls.isInteractivePreview
                      ? l10n.qiblaLiveCompassToggle
                      : l10n.qiblaPreviewToggle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: controls.isInteractivePreview
                        ? colors.accentText
                        : colors.secondaryTextAlt,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (controls.phase == QiblaAlignmentPhase.qiyam)
          InkWell(
            key: const Key('qibla_replay_takbir_btn'),
            onTap: controller.replayTakbir,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD4A574).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFD4A574).withValues(alpha: 0.55),
                  width: 0.85,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.replay_rounded,
                    size: 13.5,
                    color: Color(0xFFD4A574),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    l10n.qiblaReplayTakbir,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String label;
  final AppThemeColors colors;

  const _InfoTag({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.cardBackgroundAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderStroke, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: colors.primaryText,
        ),
      ),
    );
  }
}
