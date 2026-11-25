/// Türkçe karakter duyarsız arama normalizasyonu.
///
/// `İ`, `I`, `ı` harflerini ortak `'i'` biçimine indirger; boşlukları kırpar.
String normalizeTurkishSearch(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final buf = StringBuffer();
  for (final rune in trimmed.runes) {
    switch (rune) {
      case 0x0130: // İ
      case 0x0049: // I
      case 0x0131: // ı
        buf.write('i');
      case 0x011E: // Ğ
        buf.write('ğ');
      case 0x00DC: // Ü
        buf.write('ü');
      case 0x015E: // Ş
        buf.write('ş');
      case 0x00D6: // Ö
        buf.write('ö');
      case 0x00C7: // Ç
        buf.write('ç');
      default:
        buf.write(String.fromCharCode(rune).toLowerCase());
    }
  }
  return buf.toString();
}

/// [haystack] değerinin önceden normalize edilmiş [normalizedQuery] ile eşleşip eşleşmediğini döndürür.
bool matchesTurkishSearch(String haystack, String normalizedQuery) {
  if (normalizedQuery.isEmpty) return true;
  return normalizeTurkishSearch(haystack).contains(normalizedQuery);
}
