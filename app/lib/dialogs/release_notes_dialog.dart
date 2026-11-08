import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/camera_colors.dart';
import '../models/app_version_info.dart';

/// Modal dialog showing Zamera General Features (onboarding) or Version Release Notes.
class ReleaseNotesDialog extends StatefulWidget {
  final bool initialShowFeatures;
  final VoidCallback? onDismissed;

  const ReleaseNotesDialog({
    super.key,
    this.initialShowFeatures = false,
    this.onDismissed,
  });

  /// Static helper to display the dialog easily anywhere in the app.
  static Future<void> show(
    BuildContext context, {
    bool showFeatures = false,
    VoidCallback? onDismissed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReleaseNotesDialog(
        initialShowFeatures: showFeatures,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  State<ReleaseNotesDialog> createState() => _ReleaseNotesDialogState();
}

class _ReleaseNotesDialogState extends State<ReleaseNotesDialog> {
  late bool _showFeatures;

  @override
  void initState() {
    super.initState();
    _showFeatures = widget.initialShowFeatures;
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AppVersionInfo.privacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch privacy URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = AppVersionInfo.latestRelease;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        decoration: BoxDecoration(
          color: kSurfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorderDark, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with App Badge & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kIosYellow, Color(0xFFFF9F0A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kIosYellow.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Z',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: kObsidianBg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Zamera',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kIosYellow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: kIosYellow.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                'v${AppVersionInfo.currentVersion}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: kIosYellow,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Gerçek Renk (ΔE₀₀) & Profesyonel Kamera',
                          style: TextStyle(
                            fontSize: 11,
                            color: kZameraCyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDismissed?.call();
                    },
                  ),
                ],
              ),
            ),

            // Tab Selector: "Genel Özellikler" vs "Sürüm Notları"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: kCardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showFeatures = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _showFeatures
                                ? kIosYellow
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Genel Özellikler',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _showFeatures ? kObsidianBg : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showFeatures = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_showFeatures
                                ? kIosYellow
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sürüm ${latest.version}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: !_showFeatures ? kObsidianBg : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: kBorderDark, height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: _showFeatures
                    ? _buildFeaturesList()
                    : _buildChangelogContent(latest),
              ),
            ),

            const Divider(color: kBorderDark, height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Flexible(
                    child: TextButton.icon(
                      onPressed: _openPrivacyPolicy,
                      icon: const Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: kZameraCyan,
                      ),
                      label: const Text(
                        'Gizlilik',
                        style: TextStyle(
                          fontSize: 11,
                          color: kZameraCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDismissed?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kIosYellow,
                      foregroundColor: kObsidianBg,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Başla / Anladım',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _buildFeaturesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ZAMERA PROFESYONEL ÖZELLİKLERİ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        for (final feat in AppVersionInfo.generalFeatures) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kCardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: feat.accentColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: feat.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(feat.icon, color: feat.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feat.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: feat.accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feat.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChangelogContent(ReleaseNote note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SÜRÜM ${note.version} (DERLEME ${note.buildNumber})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: kIosYellow,
              ),
            ),
            Text(
              note.releaseDate,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          note.titleTr,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final bp in note.bulletPointsTr) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✦ ',
                        style: TextStyle(
                          color: kIosYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bp,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'GEÇMİŞ SÜRÜMLER',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 8),
        for (final oldNote in AppVersionInfo.releaseHistory.skip(1)) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  'v${oldNote.version}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    oldNote.titleTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
