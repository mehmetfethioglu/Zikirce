import 'dart:io';

void main() {
  final trFile = File(r'C:\Users\theak\source\repos\Zikirce\Zikirce\Resources\Strings\AppResources.resx');
  final enFile = File(r'C:\Users\theak\source\repos\Zikirce\Zikirce\Resources\Strings\AppResources.en.resx');

  final trContent = trFile.readAsStringSync();
  final enContent = enFile.readAsStringSync();

  final regex = RegExp(r'<data name="([^"]+)"[^>]*>\s*<value>(.*?)</value>', dotAll: true);

  final trMap = <String, String>{};
  for (final match in regex.allMatches(trContent)) {
    trMap[match.group(1)!] = match.group(2)!.trim();
  }

  final enMap = <String, String>{};
  for (final match in regex.allMatches(enContent)) {
    enMap[match.group(1)!] = match.group(2)!.trim();
  }

  print('Total TR keys: ${trMap.length}');
  print('Total EN keys: ${enMap.length}');

  // Check prefix categories
  final categories = <String, int>{};
  for (final key in trMap.keys) {
    final prefix = key.split('_').first;
    categories[prefix] = (categories[prefix] ?? 0) + 1;
  }
  print('Categories: $categories');
}
