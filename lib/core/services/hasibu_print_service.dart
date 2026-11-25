import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Yazdırılabilir veya HTML/PDF olarak dışa aktarılabilir belge sözleşmesi.
@immutable
class PrintableDocument {
  final String jobName;
  final String title;
  final String subtitle;
  final String htmlContent;
  final String plainTextSummary;
  final bool landscape;

  const PrintableDocument({
    required this.jobName,
    required this.title,
    required this.subtitle,
    required this.htmlContent,
    required this.plainTextSummary,
    this.landscape = false,
  });
}

/// Yazdırma veya dosya kaydetme işleminin sonucu.
@immutable
class PrintDispatchResult {
  final bool success;
  final String message;
  final String? outputPath;

  const PrintDispatchResult({
    required this.success,
    required this.message,
    this.outputPath,
  });
}

/// Platform bağımsız yazdırma ve çıktı kaydetme kapısı (DIP arayüzü).
abstract interface class HasibuPrintGateway {
  Future<PrintDispatchResult> printDocument(PrintableDocument document);

  Future<PrintDispatchResult> savePrintableFile(
    PrintableDocument document, {
    String? customPath,
  });
}

/// HTML özel karakterlerini güvenli biçimde kaçırır.
String escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Türkçe karakterleri ve boşlukları dosya adı için güvenli ASCII biçimine çevirir.
String sanitizePrintFileName(String raw) {
  final map = <String, String>{
    'ç': 'c',
    'Ç': 'C',
    'ğ': 'g',
    'Ğ': 'G',
    'ı': 'i',
    'İ': 'I',
    'I': 'I',
    'ö': 'o',
    'Ö': 'O',
    'ş': 's',
    'Ş': 'S',
    'ü': 'u',
    'Ü': 'U',
  };
  final buf = StringBuffer();
  for (final rune in raw.trim().runes) {
    final ch = String.fromCharCode(rune);
    final mapped = map[ch] ?? ch;
    if (RegExp(r'[a-zA-Z0-9_-]').hasMatch(mapped)) {
      buf.write(mapped);
    } else if (mapped == ' ' || mapped == '.' || mapped == '/' || mapped == r'\') {
      buf.write('_');
    }
  }
  final cleaned = buf.toString().replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'Hasibu_Belge' : cleaned;
}

/// Windows, Android, iOS, macOS ve Linux için yerel yazdırma adaptörü.
class PlatformHasibuPrintGateway implements HasibuPrintGateway {
  static const MethodChannel _printChannel = MethodChannel(
    'com.akarworks.hasibu/print',
  );

  @override
  Future<PrintDispatchResult> printDocument(PrintableDocument document) async {
    try {
      final safeJob = sanitizePrintFileName(document.jobName);

      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final ok = await _printChannel.invokeMethod<bool>(
            'printHtml',
            <String, dynamic>{
              'html': document.htmlContent,
              'jobName': safeJob,
              'landscape': document.landscape,
            },
          );
          if (ok == true) {
            return const PrintDispatchResult(
              success: true,
              message: 'Sistem yazdırma ekranı açıldı.',
            );
          }
          return const PrintDispatchResult(
            success: false,
            message: 'Sistem yazdırma isteği tamamlanamadı.',
          );
        } on MissingPluginException catch (e) {
          debugPrint('PlatformHasibuPrintGateway: printHtml kanalı bulunamadı ($e)');
          return savePrintableFile(document);
        }
      }

      if (Platform.isWindows) {
        final tempDir = await getTemporaryDirectory();
        final printDir = Directory(p.join(tempDir.path, 'Hasibu_Print'));
        if (!await printDir.exists()) {
          await printDir.create(recursive: true);
        }
        final filePath = p.join(
          printDir.path,
          '${safeJob}_${DateTime.now().millisecondsSinceEpoch}.html',
        );
        final file = File(filePath);
        await file.writeAsString(_injectAutoPrintScript(document.htmlContent));

        try {
          await Process.start(
            'cmd',
            <String>['/c', 'start', '', file.path],
            runInShell: false,
          );
        } catch (e) {
          debugPrint('PlatformHasibuPrintGateway: cmd start hatası ($e), explorer deneniyor');
          await Process.start('explorer', <String>[file.path], runInShell: false);
        }

        return PrintDispatchResult(
          success: true,
          message: 'Yazdırma penceresi açıldı.',
          outputPath: file.path,
        );
      }

      if (Platform.isMacOS || Platform.isLinux) {
        final tempDir = await getTemporaryDirectory();
        final printDir = Directory(p.join(tempDir.path, 'Hasibu_Print'));
        if (!await printDir.exists()) {
          await printDir.create(recursive: true);
        }
        final filePath = p.join(
          printDir.path,
          '${safeJob}_${DateTime.now().millisecondsSinceEpoch}.html',
        );
        final file = File(filePath);
        await file.writeAsString(_injectAutoPrintScript(document.htmlContent));
        await Process.start(
          Platform.isMacOS ? 'open' : 'xdg-open',
          <String>[file.path],
          runInShell: false,
        );
        return PrintDispatchResult(
          success: true,
          message: 'Yazdırma penceresi açıldı.',
          outputPath: file.path,
        );
      }

      return savePrintableFile(document);
    } catch (e) {
      debugPrint('PlatformHasibuPrintGateway.printDocument hatası: $e');
      return PrintDispatchResult(
        success: false,
        message: 'Yazdırma başlatılamadı: $e',
      );
    }
  }

  @override
  Future<PrintDispatchResult> savePrintableFile(
    PrintableDocument document, {
    String? customPath,
  }) async {
    try {
      final File targetFile;
      if (customPath != null && customPath.trim().isNotEmpty) {
        targetFile = File(customPath.trim());
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        final outDir = Directory(p.join(docsDir.path, 'Hasibu_Ciktilar'));
        if (!await outDir.exists()) {
          await outDir.create(recursive: true);
        }
        final now = DateTime.now();
        final stamp =
            '${now.year.toString().padLeft(4, '0')}'
            '${now.month.toString().padLeft(2, '0')}'
            '${now.day.toString().padLeft(2, '0')}_'
            '${now.hour.toString().padLeft(2, '0')}'
            '${now.minute.toString().padLeft(2, '0')}';
        final safeJob = sanitizePrintFileName(document.jobName);
        targetFile = File(p.join(outDir.path, '${safeJob}_$stamp.html'));
      }

      final parent = targetFile.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await targetFile.writeAsString(document.htmlContent);
      return PrintDispatchResult(
        success: true,
        message: 'Yazdırılabilir belge kaydedildi: ${targetFile.path}',
        outputPath: targetFile.path,
      );
    } catch (e) {
      debugPrint('PlatformHasibuPrintGateway.savePrintableFile hatası: $e');
      return PrintDispatchResult(
        success: false,
        message: 'Belge kaydedilemedi: $e',
      );
    }
  }

  String _injectAutoPrintScript(String html) {
    const script =
        '<script>window.addEventListener("load",function(){setTimeout(function(){window.print();},250);});</script>';
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$script</body>');
    }
    return '$html$script';
  }
}
