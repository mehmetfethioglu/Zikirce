import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/features/reader/engine/glyph_reverse_mapper.dart';
import 'package:tahrir/features/reader/engine/hybrid_page_parser.dart';
import 'package:tahrir/features/reader/services/onnx_arabic_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layer 1: GlyphReverseMapper Tests', () {
    test('1. Resolves PostScript glyph names to canonical Arabic Unicode', () {
      const psInput = '/alef.init/beh.medi/lam_meem.liga /ornament.head';
      final mapped = GlyphReverseMapper.reverseMap(psInput);

      expect(mapped, contains('\u0627')); // alef
      expect(mapped, contains('\u0628')); // beh
      expect(mapped, contains(' ❖ ')); // ornament
    });

    test('2. Resolves /uni0628 and 8-digit ligature hex strings', () {
      const hexInput = '/uni0628 /uni06440645';
      final mapped = GlyphReverseMapper.reverseMap(hexInput);

      expect(mapped, contains('\u0628')); // uni0628 = beh
      expect(mapped, contains('\u0644\u0645')); // uni06440645 = lam + meem
    });

    test('3. Resolves Presentation Forms (A & B) into canonical Arabic characters', () {
      // FE8D = Presentation Form Alef Isolated -> should become 0627
      // FE91 = Presentation Form Beh Initial -> should become 0628
      final presentationText = String.fromCharCodes([0xFE8D, 0xFE91]);
      final normalized = GlyphReverseMapper.normalizePresentationForms(presentationText);

      expect(normalized, equals('\u0627\u0628'));
    });

    test('4. Corrects corrupted 8-bit ANSI / Windows-1256 byte representations', () {
      // 0xC7 = Alef in CP1256, 0xC8 = Beh in CP1256
      final cp1256Corrupted = String.fromCharCodes([0xC7, 0xC8]);
      final mapped = GlyphReverseMapper.reverseMap(cp1256Corrupted);

      expect(mapped, contains('\u0627\u0628'));
    });
  });

  group('Layer 2: OnnxArabicRecognizer CTC Greedy Decoder Tests', () {
    test('5. CTC Greedy Decoder suppresses blank tokens and collapses duplicates', () {
      final dictionary = ['<blank>', 'ا', 'ل', 'ل', 'ه', ' '];
      
      // Simulating [1, 5, numClasses] output
      final fakeOutput = [
        [
          [0.1, 0.9, 0.0, 0.0, 0.0, 0.0], // step 0: 'ا' (index 1)
          [0.1, 0.9, 0.0, 0.0, 0.0, 0.0], // step 1: 'ا' (duplicate, should collapse)
          [0.8, 0.1, 0.0, 0.0, 0.0, 0.0], // step 2: <blank> (index 0)
          [0.1, 0.0, 0.9, 0.0, 0.0, 0.0], // step 3: 'ل' (index 2)
          [0.1, 0.0, 0.0, 0.0, 0.9, 0.0], // step 4: 'ه' (index 4)
        ]
      ];

      final result = OnnxArabicRecognizer.decodeCtcOutput(
        outputData: fakeOutput,
        dictionary: dictionary,
      );

      expect(result.isSuccessful, isTrue);
      expect(result.text, equals('اله'));
      expect(result.confidence, greaterThanOrEqualTo(0.85));
    });
  });

  group('Layer 3: HybridPageParser Tests', () {
    const parser = HybridPageParser();

    test('6. De-hyphenates line breaks and joins broken Turkish words', () {
      const hyphenatedInput = 'Bu meselede müste-\nşar bey ile görüşüldü.';
      final cleaned = HybridPageParser.sanitizeAndDehyphenate(hyphenatedInput);

      expect(cleaned, contains('müsteşar bey'));
      expect(cleaned, isNot(contains('müste-')));
    });

    test('7. Applies BiDi isolation (\u2067 and \u2069) to pure Arabic lines', () {
      const mixedText = '''
Müellif şöyle buyurmuştur:
إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ
Bu hadis tüm amellerin niyetlere bağlı olduğunu bildirir.
''';

      final isolated = HybridPageParser.applyBidiIsolation(mixedText);

      expect(isolated, contains('\u2067إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ\u2069'));
    });

    test('8. Confidence scoring heavily penalizes garbage noise sequences', () {
      const noisyText = 'J o ,.. \'\'\' ,,. J 1;ii \'! <:1 -. 1 1;.._ 0 J l,j ! <:1 r 1.f"\' Y, r- ts-1; J> ,L>- . ! _il\' :; - ..:..__i1 1...r----J . ,.';
      final noiseScore = HybridPageParser.calculateConfidenceScore(noisyText);
      expect(noiseScore, lessThan(0.70));

      const cleanText = 'İslam ahlak ve adabında tevazu en yüce hasletlerden biridir.';
      final cleanScore = HybridPageParser.calculateConfidenceScore(cleanText);
      expect(cleanScore, greaterThanOrEqualTo(0.95));
    });

    test('9. Critical fallback generates InlineImageCrop block when text is unresolvable noise', () async {
      const noisyText = 'J o ,.. \'\'\' ,,. J 1;ii \'! <:1 -. 1 1;.._ 0 J l,j ! <:1 r 1.f"\' Y, r- ts-1; J> ,L>- . ! _il\' :; - ..:..__i1 1...r----J . ,.';
      final dummyCropBytes = Uint8List.fromList([0, 1, 2, 3]);

      final blocks = await parser.parsePage(
        rawExtractedText: noisyText,
        pageIndex: 19,
        pageImageBytes: dummyCropBytes,
      );

      expect(blocks, isNotEmpty);
      expect(blocks.first.type, equals(HybridSegmentType.inlineImageCrop));
    });
  });
}
