import 'dart:io';

void main() {
  final trFile = File(r'C:\Users\theak\source\repos\Zikirce\Zikirce\Resources\Strings\AppResources.resx');
  final enFile = File(r'C:\Users\theak\source\repos\Zikirce\Zikirce\Resources\Strings\AppResources.en.resx');

  final trContent = trFile.readAsStringSync();
  final enContent = enFile.readAsStringSync();

  final regex = RegExp(r'<data name="([^"]+)"[^>]*>\s*<value>(.*?)</value>', dotAll: true);

  final trMap = <String, String>{};
  for (final match in regex.allMatches(trContent)) {
    var val = match.group(2)!.trim();
    val = val
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    trMap[match.group(1)!] = val;
  }

  final enMap = <String, String>{};
  for (final match in regex.allMatches(enContent)) {
    var val = match.group(2)!.trim();
    val = val
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    enMap[match.group(1)!] = val;
  }

  print('TR: ${trMap.length} entries, EN: ${enMap.length} entries');

  String escapeDartString(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll(r'$', r'\$')
        .replaceAll("'", r"\'")
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n');
  }

  // Generate app_strings_tr.dart
  final trBuffer = StringBuffer();
  trBuffer.writeln('// GENERATED FILE FROM .NET MAUI AppResources.resx');
  trBuffer.writeln('// Total keys: ${trMap.length}');
  trBuffer.writeln();
  trBuffer.writeln('const Map<String, String> appStringsTr = {');
  for (final entry in trMap.entries) {
    trBuffer.writeln("  '${escapeDartString(entry.key)}': '${escapeDartString(entry.value)}',");
  }
  trBuffer.writeln('};');

  final targetDir = Directory(r'c:\Users\theak\source\repos\zikirce_\lib\core\localization\translations');
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
  }

  File(r'c:\Users\theak\source\repos\zikirce_\lib\core\localization\translations\app_strings_tr.dart')
      .writeAsStringSync(trBuffer.toString());
  print('Generated app_strings_tr.dart');

  // Generate app_strings_en.dart
  final enBuffer = StringBuffer();
  enBuffer.writeln('// GENERATED FILE FROM .NET MAUI AppResources.en.resx');
  enBuffer.writeln('// Total keys: ${enMap.length}');
  enBuffer.writeln();
  enBuffer.writeln('const Map<String, String> appStringsEn = {');
  for (final entry in enMap.entries) {
    enBuffer.writeln("  '${escapeDartString(entry.key)}': '${escapeDartString(entry.value)}',");
  }
  enBuffer.writeln('};');

  File(r'c:\Users\theak\source\repos\zikirce_\lib\core\localization\translations\app_strings_en.dart')
      .writeAsStringSync(enBuffer.toString());
  print('Generated app_strings_en.dart');
}
