import 'package:flutter/material.dart';

import '../../../../core/release/hasibu_release_notes.dart';

class _ReleaseNotesPalette {
  final bool isDark;

  const _ReleaseNotesPalette(this.isDark);

  factory _ReleaseNotesPalette.of(BuildContext context) =>
      _ReleaseNotesPalette(Theme.of(context).brightness == Brightness.dark);

  Color get card => isDark ? const Color(0xFF09090B) : Colors.white;
  Color get subtle =>
      isDark ? const Color(0xFF121216) : const Color(0xFFF8FAFC);
  Color get chip => isDark ? const Color(0xFF18181D) : const Color(0xFFF1F5F9);
  Color get border =>
      isDark ? const Color(0xFF232329) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
}

/// Uygulama içi Sürüm Notları (Yenilikler) penceresini açar ve sürümü görüldü işaretler.
Future<void> showHasibuReleaseNotesDialog(BuildContext context) async {
  // Dialog açıldığında da işaretle; kapatıldığında kalıcı yazımı kesinleştir.
  final markFuture = HasibuReleaseNotesTracker.markCurrentVersionSeen();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final pal = _ReleaseNotesPalette.of(dialogContext);
      return Dialog(
        backgroundColor: pal.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: pal.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.new_releases_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hasibu Sürüm Notları',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Güncel Sürüm: $hasibuFullVersionLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: pal.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0;
                          i < hasibuReleaseNotesRegistry.length;
                          i++) ...[
                        _ReleaseNoteVersionCard(
                          entry: hasibuReleaseNotesRegistry[i],
                          isLatest: i == 0,
                        ),
                        if (i < hasibuReleaseNotesRegistry.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: pal.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FilledButton(
                        key: const ValueKey('release_notes_close_button'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Kapat'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  await markFuture;
  await HasibuReleaseNotesTracker.markCurrentVersionSeen();
}

class _ReleaseNoteVersionCard extends StatelessWidget {
  final HasibuReleaseNoteEntry entry;
  final bool isLatest;

  const _ReleaseNoteVersionCard({
    required this.entry,
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context) {
    final pal = _ReleaseNotesPalette.of(context);
    final accent =
        isLatest ? const Color(0xFF0284C7) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLatest
              ? const Color(0xFF0284C7).withValues(alpha: 0.45)
              : pal.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.versionLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              if (isLatest)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'YENİ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: pal.chip,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.categoryTag,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: pal.textSecondary,
                  ),
                ),
              ),
              Text(
                entry.releaseDate,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pal.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in entry.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: isLatest ? const Color(0xFF0284C7) : pal.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: pal.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Üst çubukta görünen ve görülmemiş sürüm varsa bildirim noktası gösteren buton.
class ReleaseNotesAppBarButton extends StatefulWidget {
  const ReleaseNotesAppBarButton({super.key});

  @override
  State<ReleaseNotesAppBarButton> createState() =>
      _ReleaseNotesAppBarButtonState();
}

class _ReleaseNotesAppBarButtonState extends State<ReleaseNotesAppBarButton> {
  bool _hasUnseen = false;

  @override
  void initState() {
    super.initState();
    _loadUnseenState();
  }

  Future<void> _loadUnseenState() async {
    final unseen = await HasibuReleaseNotesTracker.hasUnseenReleaseNotes();
    if (!mounted) return;
    if (_hasUnseen != unseen) {
      setState(() => _hasUnseen = unseen);
    }
  }

  Future<void> _openDialog() async {
    await showHasibuReleaseNotesDialog(context);
    if (!mounted) return;
    if (_hasUnseen) {
      setState(() => _hasUnseen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = _ReleaseNotesPalette.of(context);
    return IconButton(
      key: const ValueKey('appbar_release_notes_button'),
      visualDensity: VisualDensity.compact,
      tooltip: 'Sürüm Notları ($hasibuFullVersionLabel)',
      onPressed: _openDialog,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.new_releases_outlined,
            size: 19,
            color: _hasUnseen ? const Color(0xFF0284C7) : pal.textSecondary,
          ),
          if (_hasUnseen)
            const Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 7, height: 7),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ayarlar ekranı altında gösterilen kompakt Sürüm Notları özet kartı.
class HasibuReleaseNotesQuickCard extends StatelessWidget {
  const HasibuReleaseNotesQuickCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = _ReleaseNotesPalette.of(context);
    final latest = hasibuReleaseNotesRegistry.first;

    return Container(
      key: const ValueKey('settings_release_notes_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.new_releases_outlined,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Sürüm Notları & Yenilikler • $hasibuFullVersionLabel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const ValueKey('settings_open_release_notes_button'),
                onPressed: () => showHasibuReleaseNotesDialog(context),
                icon: const Icon(Icons.article_outlined, size: 16),
                label: const Text('Sürüm Notlarını Gör'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Son Güncelleme (${latest.releaseDate}): ${latest.title}',
            style: TextStyle(
              fontSize: 11.5,
              color: pal.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
