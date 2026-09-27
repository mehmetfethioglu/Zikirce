import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Oturum ve profil avatarlarını (yerel dosya, asset veya network URL)
/// çökmelere karşı dayanıklı ve performanslı biçimde gösteren standart bileşen.
class SessionAvatarWidget extends StatefulWidget {
  final String avatarPath;
  final double size;
  final BoxBorder? border;
  final Color? backgroundColor;

  const SessionAvatarWidget({
    super.key,
    required this.avatarPath,
    this.size = 48,
    this.border,
    this.backgroundColor,
  });

  @override
  State<SessionAvatarWidget> createState() => _SessionAvatarWidgetState();
}

class _SessionAvatarWidgetState extends State<SessionAvatarWidget> {
  static String? _cachedDocDir;
  String? _resolvedFilePath;

  @override
  void initState() {
    super.initState();
    _resolvePath();
  }

  @override
  void didUpdateWidget(covariant SessionAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarPath != widget.avatarPath) {
      _resolvePath();
    }
  }

  void _resolvePath() {
    final raw = widget.avatarPath.trim();
    if (raw.isEmpty || raw.startsWith('assets/') || raw.startsWith('http://') || raw.startsWith('https://')) {
      _resolvedFilePath = null;
      return;
    }

    final directFile = File(raw);
    if (directFile.existsSync()) {
      _resolvedFilePath = directFile.path;
      return;
    }

    if (_cachedDocDir != null) {
      final candidate = File(p.join(_cachedDocDir!, p.basename(raw)));
      if (candidate.existsSync()) {
        _resolvedFilePath = candidate.path;
        return;
      }
    }

    // Doküman dizinini asenkron çek ve dene
    getApplicationDocumentsDirectory().then((dir) {
      _cachedDocDir = dir.path;
      final candidate = File(p.join(dir.path, p.basename(raw)));
      if (candidate.existsSync() && mounted) {
        setState(() => _resolvedFilePath = candidate.path);
      }
    }).catchError((_) {});
  }

  Widget _buildFallback() {
    return Icon(
      Icons.person_rounded,
      size: widget.size * 0.6,
      color: Colors.white70,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final path = widget.avatarPath.trim();

    Widget content;

    if (path.isEmpty) {
      content = _buildFallback();
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      content = Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else if (path.startsWith('assets/')) {
      content = Image.asset(
        path,
        width: size,
        height: size,
        cacheWidth: (size * 2.5).toInt(),
        cacheHeight: (size * 2.5).toInt(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      final effectivePath = _resolvedFilePath ?? path;
      final file = File(effectivePath);
      if (file.existsSync()) {
        content = Image.file(
          file,
          width: size,
          height: size,
          cacheWidth: (size * 2.5).toInt(),
          cacheHeight: (size * 2.5).toInt(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else {
        content = _buildFallback();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor,
        border: widget.border,
      ),
      child: ClipOval(child: content),
    );
  }
}
