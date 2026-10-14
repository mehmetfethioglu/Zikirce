import 'dart:collection';

/// PDF gömülü fontlarındaki bozuk CMap, PostScript glif isimleri (AGL) ve
/// standart dışı 8-bit ANSI karakter haritalarını gerçek harekeli Arapça
/// Unicode karakterlerine dönüştüren ultra hafif, mikrosaniye hızında çalışan ters eşleme motoru.
class GlyphReverseMapper {
  const GlyphReverseMapper._();

  /// PostScript & Adobe Glyph List (AGL) -> Kanonik Arapça Unicode eşlemesi
  static final Map<String, String> _aglToUnicode = UnmodifiableMapView({
    // Temel Harfler & İsim Formları
    'alef': '\u0627',
    'alef.init': '\u0627',
    'alef.fina': '\uFE8E',
    'alef.isol': '\u0627',
    'alefhamza': '\u0623',
    'alefhamza.init': '\u0623',
    'alefhamza.fina': '\uFE84',
    'alefhamzabelow': '\u0625',
    'alefhamzabelow.fina': '\uFE88',
    'alefmaddah': '\u0622',
    'alefmaddah.fina': '\uFE82',
    'alefwasla': '\u0671',
    'beh': '\u0628',
    'beh.init': '\uFE91',
    'beh.medi': '\uFE92',
    'beh.fina': '\uFE90',
    'beh.isol': '\u0628',
    'teh': '\u062A',
    'teh.init': '\uFE97',
    'teh.medi': '\uFE98',
    'teh.fina': '\uFE96',
    'theh': '\u062B',
    'theh.init': '\uFE9B',
    'theh.medi': '\uFE9C',
    'theh.fina': '\uFE9A',
    'jeem': '\u062C',
    'jeem.init': '\uFE9F',
    'jeem.medi': '\uFEA0',
    'jeem.fina': '\uFE9E',
    'hah': '\u062D',
    'hah.init': '\uFEA3',
    'hah.medi': '\uFEA4',
    'hah.fina': '\uFEA2',
    'khah': '\u062E',
    'khah.init': '\uFEA7',
    'khah.medi': '\uFEA8',
    'khah.fina': '\uFEA6',
    'dal': '\u062F',
    'thal': '\u0630',
    'reh': '\u0631',
    'zain': '\u0632',
    'seen': '\u0633',
    'seen.init': '\uFEB3',
    'seen.medi': '\uFEB4',
    'seen.fina': '\uFEB2',
    'sheen': '\u0634',
    'sheen.init': '\uFEB7',
    'sheen.medi': '\uFEB8',
    'sheen.fina': '\uFEB6',
    'sad': '\u0635',
    'sad.init': '\uFEBB',
    'sad.medi': '\uFEBC',
    'sad.fina': '\uFEBA',
    'dad': '\u0636',
    'dad.init': '\uFEBF',
    'dad.medi': '\uFEC0',
    'dad.fina': '\uFEBE',
    'tah': '\u0637',
    'tah.init': '\uFEC3',
    'tah.medi': '\uFEC4',
    'tah.fina': '\uFEC2',
    'zah': '\u0638',
    'zah.init': '\uFEC7',
    'zah.medi': '\uFEC8',
    'zah.fina': '\uFEC6',
    'ain': '\u0639',
    'ain.init': '\uFECB',
    'ain.medi': '\uFECC',
    'ain.fina': '\uFECA',
    'ghain': '\u063A',
    'ghain.init': '\uFECF',
    'ghain.medi': '\uFED0',
    'ghain.fina': '\uFECE',
    'feh': '\u0641',
    'feh.init': '\uFED3',
    'feh.medi': '\uFED4',
    'feh.fina': '\uFED2',
    'qaf': '\u0642',
    'qaf.init': '\uFED7',
    'qaf.medi': '\uFED8',
    'qaf.fina': '\uFED6',
    'kaf': '\u0643',
    'kaf.init': '\uFEDB',
    'kaf.medi': '\uFEDC',
    'kaf.fina': '\uFEDA',
    'lam': '\u0644',
    'lam.init': '\uFEDF',
    'lam.medi': '\uFEE0',
    'lam.fina': '\uFEDE',
    'meem': '\u0645',
    'meem.init': '\uFEE3',
    'meem.medi': '\uFEE4',
    'meem.fina': '\uFEE2',
    'noon': '\u0646',
    'noon.init': '\uFEE7',
    'noon.medi': '\uFEE8',
    'noon.fina': '\uFEE6',
    'heh': '\u0647',
    'heh.init': '\uFEEB',
    'heh.medi': '\uFEEC',
    'heh.fina': '\uFEEA',
    'tehmarbuta': '\u0629',
    'tehmarbuta.fina': '\uFE94',
    'waw': '\u0648',
    'yeh': '\u064A',
    'yeh.init': '\uFEF3',
    'yeh.medi': '\uFEF4',
    'yeh.fina': '\uFEF2',
    'alefmaksura': '\u0649',

    // Ligatürler (Birleşik Karakterler)
    'lam_alef': '\uFEFB',
    'lam_alef.isol': '\uFEFB',
    'lam_alef.fina': '\uFEFC',
    'lam_alefhamza': '\uFEF7',
    'lam_alefmaddah': '\uFEF5',
    'lam_meem.liga': '\uFDFC',
    'allah.liga': '\uFDF2',
    'sallallahou_alayhi_wasallam.liga': '\uFDFA',
    'jalla_jalalouhou.liga': '\uFDFB',
    'bismillah.liga': '\uFDFD',
    'ornament.head': ' ❖ ',
    'ornament.ayahend': ' ۝ ',

    // Harekeler (Diacritics / Harakat)
    'fatha': '\u064E',
    'damma': '\u064F',
    'kasra': '\u0650',
    'shadda': '\u0651',
    'sukun': '\u0652',
    'fathatan': '\u064B',
    'dammatan': '\u064C',
    'kasratan': '\u064D',
    'maddah': '\u0653',
    'hamzaabove': '\u0654',
  });

  /// Bozuk 8-bit ANSI / MacArabic / Custom PDF Encoding Haritası (Windows-1256 / CP1252 bozulmaları)
  static final Map<int, String> _cp1256CorrectionMap = UnmodifiableMapView({
    0xC0: '\u0640', // Tatweel
    0xC1: '\u0621', // Hamza
    0xC2: '\u0622', // Alef Madda
    0xC3: '\u0623', // Alef Hamza Above
    0xC4: '\u0624', // Waw Hamza
    0xC5: '\u0625', // Alef Hamza Below
    0xC6: '\u0626', // Yeh Hamza
    0xC7: '\u0627', // Alef
    0xC8: '\u0628', // Beh
    0xC9: '\u0629', // Teh Marbuta
    0xCA: '\u062A', // Teh
    0xCB: '\u062B', // Theh
    0xCC: '\u062C', // Jeem
    0xCD: '\u062D', // Hah
    0xCE: '\u062E', // Khah
    0xCF: '\u062F', // Dal
    0xD0: '\u0630', // Thal
    0xD1: '\u0631', // Reh
    0xD2: '\u0632', // Zain
    0xD3: '\u0633', // Seen
    0xD4: '\u0634', // Sheen
    0xD5: '\u0635', // Sad
    0xD6: '\u0636', // Dad
    0xD7: '\u0637', // Tah
    0xD8: '\u0638', // Zah
    0xD9: '\u0639', // Ain
    0xDA: '\u063A', // Ghain
    0xE1: '\u0641', // Feh
    0xE2: '\u0642', // Qaf
    0xE3: '\u0643', // Kaf
    0xE4: '\u0644', // Lam
    0xE5: '\u0645', // Meem
    0xE6: '\u0646', // Noon
    0xE7: '\u0647', // Heh
    0xE8: '\u0648', // Waw
    0xE9: '\u0649', // Alef Maksura
    0xEA: '\u064A', // Yeh
    0xEB: '\u064B', // Fathatan
    0xEC: '\u064C', // Dammatan
    0xED: '\u064D', // Kasratan
    0xEE: '\u064E', // Fatha
    0xEF: '\u064F', // Damma
    0xF0: '\u0650', // Kasra
    0xF1: '\u0651', // Shadda
    0xF2: '\u0652', // Sukun
  });

  /// Gömülü PostScript `/glyph_name` veya `uniXXXX` kalıplarını regex ile yakalar
  static final RegExp _postScriptPattern = RegExp(r'/(?:uni([0-9A-Fa-f]{4,8})|([a-zA-Z0-9_\.]+))');
  
  /// Sunum Formlarını (Presentation Forms A/B) standart kanonik Arapça karakterlere indirger
  static final RegExp _presentationFormsRange = RegExp(r'[\uFB50-\uFDFF\uFE70-\uFEFC]');

  /// Ham metindeki bozuk CMap / Glif akışını temiz kanonik Unicode'a dönüştürür.
  static String reverseMap(String input) {
    if (input.isEmpty) return input;

    var result = input;

    // 1. PostScript Glyph Name çözümlemesi (Ör: /alef.init, /uni0628, /lam_meem.liga)
    if (result.contains('/')) {
      result = result.replaceAllMapped(_postScriptPattern, (match) {
        final hexCode = match.group(1);
        final glyphName = match.group(2);

        if (hexCode != null) {
          try {
            if (hexCode.length == 4) {
              final codePoint = int.parse(hexCode, radix: 16);
              return String.fromCharCode(codePoint);
            } else if (hexCode.length == 8) {
              // Bileşik iki Unicode (Ör: uni06440645 -> lam + meem)
              final first = int.parse(hexCode.substring(0, 4), radix: 16);
              final second = int.parse(hexCode.substring(4, 8), radix: 16);
              return '${String.fromCharCode(first)}${String.fromCharCode(second)}';
            }
          } catch (_) {}
        }

        if (glyphName != null && _aglToUnicode.containsKey(glyphName)) {
          return _aglToUnicode[glyphName]!;
        }

        return match.group(0)!;
      });
    }

    // 2. Bozuk Windows-1256 / ANSI ham bayt eşleme tamiri (Yalnızca Latin alfabesi içermeyen saf CP1256 bayt akışlarında)
    final hasAsciiLatinLetters = RegExp(r'[a-zA-Z]').hasMatch(result);
    if (!hasAsciiLatinLetters) {
      final codeUnits = result.codeUnits;
      var hasAnsiCorruption = false;
      for (final unit in codeUnits) {
        if (unit >= 0xC0 && unit <= 0xF2) {
          hasAnsiCorruption = true;
          break;
        }
      }

      if (hasAnsiCorruption) {
        final buffer = StringBuffer();
        for (final unit in codeUnits) {
          if (_cp1256CorrectionMap.containsKey(unit)) {
            buffer.write(_cp1256CorrectionMap[unit]);
          } else {
            buffer.writeCharCode(unit);
          }
        }
        result = buffer.toString();
      }
    }

    // 3. Sunum Formlarını Kanonik Arapça Harflere Normalize Et (HarfBuzz & AOT hijyeni)
    result = normalizePresentationForms(result);

    return result;
  }

  /// Sunum Formlarını (Isolated, Initial, Medial, Final) arama ve TTS uyumlu temel Unicode'a çevirir
  static String normalizePresentationForms(String text) {
    if (!_presentationFormsRange.hasMatch(text)) return text;

    final buffer = StringBuffer();
    for (final rune in text.runes) {
      buffer.write(_presentationToCanonical(rune));
    }
    return buffer.toString();
  }

  static String _presentationToCanonical(int codePoint) {
    switch (codePoint) {
      // Alef Forms
      case 0xFE8D: case 0xFE8E: return '\u0627';
      // Beh Forms
      case 0xFE8F: case 0xFE90: case 0xFE91: case 0xFE92: return '\u0628';
      // Teh Marbuta
      case 0xFE93: case 0xFE94: return '\u0629';
      // Teh Forms
      case 0xFE95: case 0xFE96: case 0xFE97: case 0xFE98: return '\u062A';
      // Theh Forms
      case 0xFE99: case 0xFE9A: case 0xFE9B: case 0xFE9C: return '\u062B';
      // Jeem Forms
      case 0xFE9D: case 0xFE9E: case 0xFE9F: case 0xFEA0: return '\u062C';
      // Hah Forms
      case 0xFEA1: case 0xFEA2: case 0xFEA3: case 0xFEA4: return '\u062D';
      // Khah Forms
      case 0xFEA5: case 0xFEA6: case 0xFEA7: case 0xFEA8: return '\u062E';
      // Dal Forms
      case 0xFEA9: case 0xFEAA: return '\u062F';
      // Thal Forms
      case 0xFEAB: case 0xFEAC: return '\u0630';
      // Reh Forms
      case 0xFEAD: case 0xFEAE: return '\u0631';
      // Zain Forms
      case 0xFEAF: case 0xFEB0: return '\u0632';
      // Seen Forms
      case 0xFEB1: case 0xFEB2: case 0xFEB3: case 0xFEB4: return '\u0633';
      // Sheen Forms
      case 0xFEB5: case 0xFEB6: case 0xFEB7: case 0xFEB8: return '\u0634';
      // Sad Forms
      case 0xFEB9: case 0xFEBA: case 0xFEBB: case 0xFEBC: return '\u0635';
      // Dad Forms
      case 0xFEBD: case 0xFEBE: case 0xFEBF: case 0xFEC0: return '\u0636';
      // Tah Forms
      case 0xFEC1: case 0xFEC2: case 0xFEC3: case 0xFEC4: return '\u0637';
      // Zah Forms
      case 0xFEC5: case 0xFEC6: case 0xFEC7: case 0xFEC8: return '\u0638';
      // Ain Forms
      case 0xFEC9: case 0xFECA: case 0xFECB: case 0xFECC: return '\u0639';
      // Ghain Forms
      case 0xFECD: case 0xFECE: case 0xFECF: case 0xFED0: return '\u063A';
      // Feh Forms
      case 0xFED1: case 0xFED2: case 0xFED3: case 0xFED4: return '\u0641';
      // Qaf Forms
      case 0xFED5: case 0xFED6: case 0xFED7: case 0xFED8: return '\u0642';
      // Kaf Forms
      case 0xFED9: case 0xFEDA: case 0xFEDB: case 0xFEDC: return '\u0643';
      // Lam Forms
      case 0xFEDD: case 0xFEDE: case 0xFEDF: case 0xFEE0: return '\u0644';
      // Meem Forms
      case 0xFEE1: case 0xFEE2: case 0xFEE3: case 0xFEE4: return '\u0645';
      // Noon Forms
      case 0xFEE5: case 0xFEE6: case 0xFEE7: case 0xFEE8: return '\u0646';
      // Heh Forms
      case 0xFEE9: case 0xFEEA: case 0xFEEB: case 0xFEEC: return '\u0647';
      // Waw Forms
      case 0xFEED: case 0xFEEE: return '\u0648';
      // Alef Maksura Forms
      case 0xFEEF: case 0xFEF0: return '\u0649';
      // Yeh Forms
      case 0xFEF1: case 0xFEF2: case 0xFEF3: case 0xFEF4: return '\u064A';
      // Lam-Alef Ligatures
      case 0xFEF5: case 0xFEF6: return '\u0644\u0622';
      case 0xFEF7: case 0xFEF8: return '\u0644\u0623';
      case 0xFEF9: case 0xFEFA: return '\u0644\u0625';
      case 0xFEFB: case 0xFEFC: return '\u0644\u0627';
      // Besmele & Lafzatullah
      case 0xFDF2: return 'الله';
      case 0xFDFD: return 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
      default:
        return String.fromCharCode(codePoint);
    }
  }
}
