import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/pdks/domain/pdks_models.dart';

/// Doğrulanmış ve kalıcı depolamaya hazırlanmış şirket logosu sonucu.
@immutable
class PreparedCompanyLogo {
  final String? storedPath;
  final String? base64Data;
  final Uint8List? previewBytes;
  final String? errorMessage;
  final String? warningMessage;

  const PreparedCompanyLogo({
    this.storedPath,
    this.base64Data,
    this.previewBytes,
    this.errorMessage,
    this.warningMessage,
  });

  bool get isValid => errorMessage == null;
}

/// Platform bağımsız logo dosyası seçme kapısı (DIP).
abstract interface class CompanyLogoPickerGateway {
  Future<String?> pickLogoImagePath();
}

/// Windows'ta PowerShell -Sta + UTF-8 Base64 ile Türkçe karakter bozulması olmadan
/// dosya/klasör seçimi yapan yardımcı fonksiyon.
Future<String?> pickWindowsPathWithPowerShell(String dialogScript) async {
  if (!Platform.isWindows) return null;
  try {
    final fullScript = '''
Add-Type -AssemblyName System.Windows.Forms
\$owner = New-Object System.Windows.Forms.Form
\$owner.TopMost = \$true
\$owner.ShowInTaskbar = \$false
\$owner.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
$dialogScript
if (\$selectedPath -and \$selectedPath.Trim().Length -gt 0) {
  [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(\$selectedPath.Trim()))
}
\$owner.Dispose()
''';
    final result = await Process.run(
      'power' 'shell.exe',
      <String>['-NoProfile', '-Sta', '-Command', fullScript],
    );
    final encoded = result.stdout.toString().trim();
    if (encoded.isEmpty) return null;
    final decoded = utf8.decode(base64Decode(encoded), allowMalformed: true).trim();
    return decoded.isEmpty ? null : decoded;
  } catch (e) {
    debugPrint('pickWindowsPathWithPowerShell hatası: $e');
    return null;
  }
}

/// Windows, Android ve iOS için platform görsel seçici adaptörü.
class PlatformCompanyLogoPickerGateway implements CompanyLogoPickerGateway {
  static const MethodChannel _filesChannel = MethodChannel(
    'com.akarworks.hasibu/files',
  );

  @override
  Future<String?> pickLogoImagePath() async {
    try {
      if (Platform.isWindows) {
        return pickWindowsPathWithPowerShell(r'''
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Title = 'Şirket Logosu Seçin'
$f.Filter = 'Logo Görselleri (*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif|Tüm Dosyalar (*.*)|*.*'
$selectedPath = ''
if ($f.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
  $selectedPath = $f.FileName
}
''');
      }

      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final path = await _filesChannel.invokeMethod<String>('pickImageFile');
          final clean = path?.trim() ?? '';
          return clean.isEmpty ? null : clean;
        } on MissingPluginException catch (e) {
          debugPrint('PlatformCompanyLogoPickerGateway: kanal bulunamadı ($e)');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('PlatformCompanyLogoPickerGateway.pickLogoImagePath hatası: $e');
      return null;
    }
  }
}

/// Şirket logosu doğrulama, kalıcı kopyalama ve Base64 hazırlama servisi.
class CompanyLogoService {
  CompanyLogoService._();

  static const int maxFileSizeBytes = 8 * 1024 * 1024;
  static const int maxBase64EmbedBytes = 2 * 1024 * 1024;

  static String normalizeInputPath(String raw) {
    var trimmed = raw.trim();
    if (trimmed.length >= 2) {
      final startsDouble = trimmed.startsWith('"') && trimmed.endsWith('"');
      final startsSingle = trimmed.startsWith("'") && trimmed.endsWith("'");
      if (startsDouble || startsSingle) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }
    }
    return trimmed;
  }

  static bool hasSupportedImageHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // GIF: GIF8
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }
    // BMP: BM
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true;
    }
    // WEBP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  /// Dosyayı diskte kopyalamadan senkron biçimde doğrular ve önizleme baytlarını döner.
  static PreparedCompanyLogo inspectLogoFile({
    required String rawInput,
    required CompanySettings currentSettings,
  }) {
    final clean = normalizeInputPath(rawInput);
    if (clean.isEmpty) {
      return const PreparedCompanyLogo(storedPath: null, base64Data: null);
    }
    if (clean.startsWith('logo:')) {
      return PreparedCompanyLogo(storedPath: clean, base64Data: null);
    }

    final file = File(clean);
    if (!file.existsSync()) {
      final existingNormalized = normalizeInputPath(currentSettings.logoPath ?? '');
      final existingB64 = currentSettings.logoDataBase64?.trim() ?? '';
      if (clean == existingNormalized && existingB64.isNotEmpty) {
        Uint8List? existingBytes;
        try {
          existingBytes = base64Decode(existingB64);
        } catch (e) {
          debugPrint('CompanyLogoService: mevcut base64 çözülemedi: $e');
        }
        return PreparedCompanyLogo(
          storedPath: clean,
          base64Data: existingB64,
          previewBytes: existingBytes,
        );
      }
      return const PreparedCompanyLogo(
        errorMessage:
            'Seçilen logo dosyası bulunamadı veya erişilemiyor. Lütfen geçerli bir PNG/JPG/WEBP görseli seçin.',
      );
    }

    try {
      final bytes = file.readAsBytesSync();
      if (bytes.isEmpty) {
        return const PreparedCompanyLogo(
          errorMessage: 'Seçilen logo dosyası boş.',
        );
      }
      if (bytes.length > maxFileSizeBytes) {
        return const PreparedCompanyLogo(
          errorMessage: 'Logo dosyası 8 MB sınırını aşıyor.',
        );
      }
      if (!hasSupportedImageHeader(bytes)) {
        return const PreparedCompanyLogo(
          errorMessage:
              'Desteklenmeyen görsel biçimi. Lütfen PNG, JPG, WEBP, GIF veya BMP dosyası seçin.',
        );
      }
      final encoded =
          bytes.length <= maxBase64EmbedBytes ? base64Encode(bytes) : null;
      final warning = bytes.length > maxBase64EmbedBytes
          ? 'Logo cihaza kaydedildi (2 MB üzerindeki logolar bulut yedeğine gömülmez).'
          : null;
      return PreparedCompanyLogo(
        storedPath: clean,
        base64Data: encoded,
        previewBytes: bytes,
        warningMessage: warning,
      );
    } catch (e) {
      debugPrint('CompanyLogoService.inspectLogoFile hatası: $e');
      return PreparedCompanyLogo(
        errorMessage: 'Logo dosyası okunamadı: $e',
      );
    }
  }

  static Future<PreparedCompanyLogo> prepareLogoForSave({
    required String rawInput,
    required CompanySettings currentSettings,
    Directory? storageDirOverride,
  }) async {
    final inspected = inspectLogoFile(
      rawInput: rawInput,
      currentSettings: currentSettings,
    );
    if (!inspected.isValid || inspected.previewBytes == null) {
      return inspected;
    }

    final clean = inspected.storedPath!;
    final bytes = inspected.previewBytes!;
    var persistedPath = clean;
    try {
      final baseDir = storageDirOverride ??
          await getApplicationSupportDirectory().timeout(
            const Duration(milliseconds: 300),
          );
      final logoDir = Directory(p.join(baseDir.path, 'Hasibu_Logos'));
      if (!logoDir.existsSync()) {
        logoDir.createSync(recursive: true);
      }
      final rawExt = p.extension(clean).toLowerCase();
      final safeExt = const <String>{
        '.png',
        '.jpg',
        '.jpeg',
        '.webp',
        '.bmp',
        '.gif',
      }.contains(rawExt)
          ? rawExt
          : '.png';
      final targetFile = File(
        p.join(
          logoDir.path,
          'company_logo_${DateTime.now().millisecondsSinceEpoch}$safeExt',
        ),
      );
      targetFile.writeAsBytesSync(bytes, flush: true);
      persistedPath = targetFile.path;
    } catch (e) {
      debugPrint('CompanyLogoService: kalıcı kopyalama atlandı ($e)');
    }

    return PreparedCompanyLogo(
      storedPath: persistedPath,
      base64Data: inspected.base64Data,
      previewBytes: bytes,
      warningMessage: inspected.warningMessage,
    );
  }
}
