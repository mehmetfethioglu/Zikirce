import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/services/quran_page_repository.dart';
import 'package:zikirce/features/ezber/domain/verse_chunker_service.dart';
import 'package:zikirce/features/ezber/domain/smart_distractors_service.dart';

void main() {
  group('VerseChunkerService Tests', () {
    final chunker = VerseChunkerService();

    test('Short verse under threshold returns 1 chunk', () {
      const shortVerse = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
      final chunks = chunker.chunkVerse(shortVerse, maxWordThreshold: 15);

      expect(chunks.length, equals(1));
      expect(chunks[0].chunkIndex, equals(1));
      expect(chunks[0].totalChunks, equals(1));
      expect(chunks[0].words.length, equals(4));
    });

    test('Long verse with punctuation splits at punctuation', () {
      const longVerse =
          'إِنَّ الَّذِينَ كَفَرُوا سَوَاءٌ عَلَيْهِمْ أَأَنذَرْتَهُمْ أَمْ لَمْ تُنذِرْهُمْ لَا يُؤْمِنُونَ ۚ خَتَمَ اللَّهُ عَلَىٰ قُلُوبِهِمْ وَعَلَىٰ سَمْعِهِمْ ۖ وَعَلَىٰ أَبْصَارِهِمْ غِشَاوَةٌ ۖ وَلَهُمْ عَذَابٌ عَظِيمٌ';
      final chunks = chunker.chunkVerse(longVerse, maxWordThreshold: 10);

      expect(chunks.length, greaterThan(1));
      for (int i = 0; i < chunks.length; i++) {
        expect(chunks[i].chunkIndex, equals(i + 1));
        expect(chunks[i].totalChunks, equals(chunks.length));
      }
    });

    test('Empty verse returns empty chunks list', () {
      final chunks = chunker.chunkVerse('');
      expect(chunks, isEmpty);
    });
  });

  group('SmartDistractorsService Tests', () {
    final sampleVerses = [
      QuranAyatModel(id: 1, sureId: 1, ayetId: 1, ayetNumber: '1', ayetText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
      QuranAyatModel(id: 2, sureId: 1, ayetId: 2, ayetNumber: '2', ayetText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ'),
      QuranAyatModel(id: 3, sureId: 1, ayetId: 3, ayetNumber: '3', ayetText: 'الرَّحْمَٰنِ الرَّحِيمِ'),
      QuranAyatModel(id: 4, sureId: 1, ayetId: 4, ayetNumber: '4', ayetText: 'مَالِكِ يَوْمِ الدِّينِ'),
      QuranAyatModel(id: 5, sureId: 1, ayetId: 5, ayetNumber: '5', ayetText: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ'),
      QuranAyatModel(id: 6, sureId: 2, ayetId: 1, ayetNumber: '1', ayetText: 'الم'),
    ];

    test('Generates requested number of distractors', () {
      final target = sampleVerses[1]; // Ayah 2
      final distractors = SmartDistractorsService.generateDistractors(
        targetVerse: target,
        allAvailableVerses: sampleVerses,
        distractorCount: 3,
      );

      expect(distractors.length, equals(3));
      expect(distractors.any((d) => d.id == target.id), isFalse);
    });

    test('Prioritizes same surah neighbors', () {
      final target = sampleVerses[2]; // Ayah 3
      final distractors = SmartDistractorsService.generateDistractors(
        targetVerse: target,
        allAvailableVerses: sampleVerses,
        distractorCount: 2,
      );

      expect(distractors.length, equals(2));
      expect(distractors.every((d) => d.sureId == 1), isTrue);
    });
  });
}
