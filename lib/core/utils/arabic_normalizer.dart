class ArabicNormalizer {
  // Regex to remove Tashkeel (harakat / diacritics)
  static final RegExp _tashkeelRegex = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]');

  /// Removes all harakat (diacritics) from Arabic text
  static String removeTashkeel(String input) {
    if (input.isEmpty) return '';
    return input.replaceAll(_tashkeelRegex, '');
  }

  /// Normalizes Arabic characters for robust search and comparison
  static String normalize(String input) {
    if (input.isEmpty) return '';
    var text = removeTashkeel(input);
    
    // Normalize Alefs
    text = text.replaceAll(RegExp(r'[إأآٱ]'), 'ا');
    // Normalize Taa Marbuta
    text = text.replaceAll('ة', 'ه');
    // Normalize Yaa
    text = text.replaceAll('ى', 'ي');
    // Normalize Tatweel (Kashida)
    text = text.replaceAll('ـ', '');

    return text.trim();
  }

  /// Check if text contains Arabic characters
  static bool isArabic(String input) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(input);
  }

  /// Check if query matches normalized Arabic text
  static bool containsMatch(String source, String query) {
    final normSource = normalize(source);
    final normQuery = normalize(query);
    return normSource.contains(normQuery);
  }
}
