import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// iOS (özellikle Xcode 26 / iOS 18–26+ iPhone ve tüm iPad modelleri) üzerinde `share_plus`
/// eklentisinin `UIPopoverPresentationController` doğrulamasında fırlattığı:
/// `PlatformException(error, sharePositionOrigin: argument must be set, {{0, 0}, {0, 0}} must be non-zero and within coordinate space of source view)`
/// hatasını önleyen merkezi yardımcı sınıf.
class ShareUtils {
  ShareUtils._();

  /// Verilen [context] (varsa) veya aktif Flutter görünümü üzerinden her zaman
  /// kaynak görünüm koordinat uzayı (`controller.view.frame` / `bounds`) içinde kalan,
  /// sıfırdan farklı (`non-zero`) güvenli bir [Rect] hesaplar.
  static Rect resolveSharePositionOrigin([BuildContext? context]) {
    Size? viewSize;
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view != null && view.devicePixelRatio > 0) {
      viewSize = view.physicalSize / view.devicePixelRatio;
    }
    if ((viewSize == null || viewSize.isEmpty) &&
        context != null &&
        context.mounted) {
      viewSize = MediaQuery.maybeSizeOf(context);
    }

    final double screenW =
        (viewSize != null && viewSize.width > 32) ? viewSize.width : 393.0;
    final double screenH =
        (viewSize != null && viewSize.height > 32) ? viewSize.height : 852.0;

    final Rect safeScreenBounds = Rect.fromLTWH(
      8.0,
      8.0,
      math.max(16.0, screenW - 16.0),
      math.max(16.0, screenH - 16.0),
    );

    if (context != null && context.mounted) {
      try {
        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.hasSize &&
            !renderObject.size.isEmpty) {
          final Offset topLeft = renderObject.localToGlobal(Offset.zero);
          final Rect rawRect = topLeft & renderObject.size;
          if (rawRect.width >= 2.0 &&
              rawRect.height >= 2.0 &&
              rawRect.width <= screenW * 0.9 &&
              rawRect.height <= 120.0) {
            final Rect clamped = rawRect.intersect(safeScreenBounds);
            if (clamped.width >= 2.0 &&
                clamped.height >= 2.0 &&
                safeScreenBounds.contains(clamped.topLeft) &&
                safeScreenBounds.contains(clamped.bottomRight)) {
              return clamped;
            }
          }
        }
      } catch (_) {}
    }

    final double anchorX =
        (screenW / 2.0).clamp(16.0, math.max(16.0, screenW - 16.0));
    final double anchorY =
        (screenH / 2.0).clamp(16.0, math.max(16.0, screenH - 16.0));
    return Rect.fromCenter(
      center: Offset(anchorX, anchorY),
      width: 2.0,
      height: 2.0,
    );
  }

  /// Dosya paylaşımını (`Share.shareXFiles`) güvenli `sharePositionOrigin` ve
  /// olası koordinat uyuşmazlıklarında otomatik geri dönüş (fallback) ile çalıştırır.
  static Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    final Rect primaryOrigin =
        sharePositionOrigin ?? resolveSharePositionOrigin(context);
    try {
      return await Share.shareXFiles(
        files,
        subject: subject,
        text: text,
        sharePositionOrigin: primaryOrigin,
      );
    } on PlatformException catch (e) {
      if ((e.message ?? '').contains('sharePositionOrigin') ||
          (e.details?.toString() ?? '').contains('sharePositionOrigin')) {
        return await Share.shareXFiles(
          files,
          subject: subject,
          text: text,
          sharePositionOrigin: const Rect.fromLTWH(100.0, 100.0, 2.0, 2.0),
        );
      }
      rethrow;
    }
  }

  /// Metin paylaşımını (`Share.share`) güvenli `sharePositionOrigin` ve
  /// olası koordinat uyuşmazlıklarında otomatik geri dönüş (fallback) ile çalıştırır.
  static Future<ShareResult> shareText(
    String text, {
    String? subject,
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    final Rect primaryOrigin =
        sharePositionOrigin ?? resolveSharePositionOrigin(context);
    try {
      return await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: primaryOrigin,
      );
    } on PlatformException catch (e) {
      if ((e.message ?? '').contains('sharePositionOrigin') ||
          (e.details?.toString() ?? '').contains('sharePositionOrigin')) {
        return await Share.share(
          text,
          subject: subject,
          sharePositionOrigin: const Rect.fromLTWH(100.0, 100.0, 2.0, 2.0),
        );
      }
      rethrow;
    }
  }
}
