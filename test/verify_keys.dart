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
    // decode xml entities
    val = val.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'");
    trMap[match.group(1)!] = val;
  }

  final enMap = <String, String>{};
  for (final match in regex.allMatches(enContent)) {
    var val = match.group(2)!.trim();
    val = val.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'");
    enMap[match.group(1)!] = val;
  }

  print('TR count: ${trMap.length}, EN count: ${enMap.length}');

  // Verify missing keys
  final missingInEn = trMap.keys.where((k) => !enMap.containsKey(k)).toList();
  final missingInTr = enMap.keys.where((k) => !trMap.containsKey(k)).toList();
  print('Missing in EN: $missingInEn');
  print('Missing in TR: $missingInTr');

  // Let's print all Settings keys
  final settingsKeys = trMap.keys.where((k) => k.startsWith('Settings_') || k.startsWith('Common_') || k.startsWith('Onboarding_') || k.startsWith('Namaz_') || k.startsWith('Quran_') || k.startsWith('Zikir_') || k.startsWith('ZikirPage_') || k.startsWith('Bismillah_')).toList();
  print('Found ${settingsKeys.length} matching primary keys.');
}
