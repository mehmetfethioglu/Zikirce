import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/services/quran_page_repository.dart';
import 'package:zikirce/core/utils/quran_tracking_scroll_helper.dart';
import 'package:zikirce/core/utils/quran_word_highlighter.dart';
import 'package:zikirce/features/kuran/presentation/widgets/quran_tracked_paragraph.dart';
import 'package:zikirce/features/kuran/presentation/widgets/synchronized_arabic_ayah_wrap.dart';
import 'package:zikirce/features/kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';

QuranAyatModel _makeVerse({
  required int surahId,
  required int ayahId,
  required String text,
  String? arabicNumber,
}) {
  return QuranAyatModel(
    id: surahId * 1000 + ayahId,
    sureId: surahId,
    ayetId: ayahId,
    ayetNumber: arabicNumber ?? QuranWordHighlighter.toArabicDigits('$ayahId'),
    ayetText: text,
    page: 1,
  );
}

Rect _rectInScrollableViewport(BuildContext targetContext) {
  final scrollable = Scrollable.of(targetContext);
  final viewportBox = scrollable.context.findRenderObject()! as RenderBox;
  final targetBox = targetContext.findRenderObject()! as RenderBox;
  final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: viewportBox);
  final bottomRight = targetBox.localToGlobal(
    Offset(targetBox.size.width, targetBox.size.height),
    ancestor: viewportBox,
  );
  return Rect.fromPoints(topLeft, bottomRight);
}

Rect _subRectInScrollableViewport(BuildContext paragraphContext, Rect localRect) {
  final scrollable = Scrollable.of(paragraphContext);
  final viewportBox = scrollable.context.findRenderObject()! as RenderBox;
  final targetBox = paragraphContext.findRenderObject()! as RenderBox;
  final topLeft = targetBox.localToGlobal(localRect.topLeft, ancestor: viewportBox);
  final bottomRight = targetBox.localToGlobal(
    localRect.bottomRight,
    ancestor: viewportBox,
  );
  return Rect.fromPoints(topLeft, bottomRight);
}

void main() {
  group('Word tracking layout stability & ayah boundaries', () {
    testWidgets(
      'QuranTrackedParagraph keeps ZikirceAyahStopMarker stationary across all words in highlight & arrow modes',
      (WidgetTester tester) async {
        final markerKey1 = GlobalKey();
        final markerKey2 = GlobalKey();

        const style = TextStyle(
          fontFamily: 'Hafs',
          fontSize: 22,
          height: 1.85,
          color: Colors.black,
        );

        final accumulator = QuranSpanAccumulator();
        final ayah1WordRanges = <TextRange>[];

        final ayah1Tokens = QuranAyahWordParser.parse(
          'بِسْمِ اللّٰهِ الرَّحْمٰنِ مُسَمًّىۖ الْعَالَمٖينَ اِهْدِنَا الصِّرَاطَ',
        );
        for (int i = 0; i < ayah1Tokens.length; i++) {
          final token = ayah1Tokens[i];
          if (token.pureWord.isNotEmpty) {
            final start = _currentSpanTextLength(accumulator.spans);
            accumulator.addText(token.pureWord, style: style);
            final end = _currentSpanTextLength(accumulator.spans);
            ayah1WordRanges.add(TextRange(start: start, end: end));
          }
          for (int sIdx = 0; sIdx < token.stops.length; sIdx++) {
            final prefix = sIdx == 0 ? '\u2060' : '\u2060\u202F';
            accumulator.addText(
              '$prefix${token.stops[sIdx]}',
              style: style.copyWith(color: Colors.red),
            );
          }
          if (i < ayah1Tokens.length - 1) {
            accumulator.addText(' ', style: style);
          }
        }
        accumulator.addText('\u2060\u00A0\u2060', style: style);
        accumulator.addWidget(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ZikirceAyahStopMarker(
              key: markerKey1,
              number: '١',
              isDark: false,
              isHighlight: true,
              fontFamily: 'Hafs',
              size: 26,
            ),
          ),
        );
        accumulator.addText('\u2060\u200F ', style: style);

        accumulator.addText(
          'ذٰلِكَ الْكِتَابُ لَا رَيْبَ فٖيهِ هُدًى لِلْمُتَّقٖينَ',
          style: style,
        );
        accumulator.addText('\u2060\u00A0\u2060', style: style);
        accumulator.addWidget(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ZikirceAyahStopMarker(
              key: markerKey2,
              number: '٢',
              isDark: false,
              isHighlight: false,
              fontFamily: 'Hafs',
              size: 26,
            ),
          ),
        );
        accumulator.addText('\u2060\u200F ', style: style);

        final paragraphSpan = TextSpan(
          style: style,
          children: accumulator.spans,
        );

        TextRange? activeRange;
        bool isArrowMode = false;
        Object? activeIdentity;
        late StateSetter setHostState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 340,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      setHostState = setState;
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: QuranTrackedParagraph(
                          textSpan: paragraphSpan,
                          textAlign: TextAlign.justify,
                          textDirection: TextDirection.rtl,
                          activeWordRange: activeRange,
                          isArrowMode: isArrowMode,
                          isDark: false,
                          isPlaying: true,
                          activeWordDurationMs: 250,
                          activeWordIdentity: activeIdentity,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final baseline1 = tester.getTopLeft(find.byKey(markerKey1));
        final baseline2 = tester.getTopLeft(find.byKey(markerKey2));

        for (final arrowMode in [false, true]) {
          for (int i = 0; i < ayah1WordRanges.length; i++) {
            setHostState(() {
              isArrowMode = arrowMode;
              activeRange = ayah1WordRanges[i];
              activeIdentity = 'mushaf_${arrowMode ? 'arrow' : 'hl'}_$i';
            });
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 40));

            expect(
              tester.getTopLeft(find.byKey(markerKey1)),
              baseline1,
              reason:
                  'Marker 1 shifted at word index $i (arrowMode=$arrowMode)',
            );
            expect(
              tester.getTopLeft(find.byKey(markerKey2)),
              baseline2,
              reason:
                  'Marker 2 shifted at word index $i (arrowMode=$arrowMode)',
            );
          }
        }
      },
    );

    testWidgets(
      'ZikirceAyahStopMarker stays glued to last word across narrow widths and uses non-breaking joiners in RichText spans',
      (WidgetTester tester) async {
        final spans = QuranWordHighlighter.buildHighlightedSpans(
          rawText: 'ذٰلِكَ الْكِتَابُ لَا رَيْبَ فٖيهِ',
          baseStyle: const TextStyle(fontSize: 22),
          isDark: false,
          ayahNumber: '٢',
          showAyahStopMarker: true,
        );

        final widgetSpanIndex = spans.indexWhere((s) => s is WidgetSpan);
        expect(widgetSpanIndex, greaterThan(0));
        final preSpan = spans[widgetSpanIndex - 1];
        expect(preSpan, isA<TextSpan>());
        expect((preSpan as TextSpan).text, '\u2060\u00A0\u2060');
        final postSpan = spans[widgetSpanIndex + 1];
        expect(postSpan, isA<TextSpan>());
        expect((postSpan as TextSpan).text, '\u2060\u200F ');

        final verse = _makeVerse(
          surahId: 1,
          ayahId: 2,
          text: 'الْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمٖينَ',
        );

        double containerWidth = 220;
        late StateSetter setHostState;
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setHostState = setState;
                    return SizedBox(
                      width: containerWidth,
                      child: SynchronizedArabicAyahWrap(
                        verse: verse,
                        verseIndex: 0,
                        isActiveVerse: true,
                        activeWordOrder: 2,
                        activeWordDurationMs: 400,
                        playbackSpeed: 1.0,
                        isPlaying: false,
                        isDark: false,
                        fontFamily: 'Hafs',
                        fontSize: 24,
                        isBoldArabic: false,
                        isArrowTracking: false,
                        onWordTap: (vIdx, wOrder) => tapCount += vIdx + wOrder,
                        onAyahMarkerTap: () => tapCount += 1,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        for (double w = 220; w <= 360; w += 10) {
          setHostState(() {
            containerWidth = w;
          });
          await tester.pump();

          final lastWordFinder = find.text('الْعَالَمٖينَ');
          final markerFinder = find.byType(ZikirceAyahStopMarker);
          expect(lastWordFinder, findsOneWidget);
          expect(markerFinder, findsOneWidget);

          final lastWordCenter = tester.getCenter(lastWordFinder);
          final markerCenter = tester.getCenter(markerFinder);
          expect(
            (markerCenter.dy - lastWordCenter.dy).abs(),
            lessThan(4.0),
            reason:
                'ZikirceAyahStopMarker orphaned onto a different line at width=$w',
          );
          expect(tapCount, 0);
        }
      },
    );

    testWidgets(
      'SynchronizedArabicAyahWrap maintains 0px marker shift across masking reveal steps',
      (WidgetTester tester) async {
        final verse = _makeVerse(
          surahId: 1,
          ayahId: 3,
          text: 'الْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمٖينَ مَالِكِ يَوْمِ الدّٖينِ',
        );
        final words = QuranAyahWordParser.parse(verse.ayetText);
        int activeWordOrder = 0;
        int interactionCount = 0;
        late StateSetter setHostState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 340,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      setHostState = setState;
                      return SynchronizedArabicAyahWrap(
                        verse: verse,
                        verseIndex: 0,
                        isActiveVerse: true,
                        activeWordOrder: activeWordOrder,
                        activeWordDurationMs: 400,
                        playbackSpeed: 1.0,
                        isPlaying: true,
                        isDark: false,
                        fontFamily: 'Hafs',
                        fontSize: 24,
                        isBoldArabic: false,
                        isArrowTracking: false,
                        maskingMode: true,
                        onWordTap: (vIdx, wOrder) =>
                            interactionCount += vIdx + wOrder,
                        onAyahMarkerTap: () => interactionCount += 1,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final baseline = tester.getTopLeft(find.byType(ZikirceAyahStopMarker));

        for (int order = 1; order <= words.length; order++) {
          setHostState(() {
            activeWordOrder = order;
          });
          await tester.pump();

          expect(
            tester.getTopLeft(find.byType(ZikirceAyahStopMarker)),
            baseline,
            reason:
                'Marker shifted when revealing masked word $order of ${words.length}',
          );
        }
        expect(interactionCount, 0);
      },
    );

    testWidgets(
      'Long 120-word ayah auto-scrolls accurately in Mushaf paragraph and ListView modes',
      (WidgetTester tester) async {
        final words120 = List<String>.generate(
          120,
          (i) => 'كَتَبَ${QuranWordHighlighter.toArabicDigits('${i + 1}')}',
        );
        final longAyahText = words120.join(' ');
        final shortAyahText = List<String>.generate(
          15,
          (i) => 'سَمِعَ${QuranWordHighlighter.toArabicDigits('${i + 1}')}',
        ).join(' ');

        // (a) Mushaf SingleChildScrollView + QuranTrackedParagraph mode
        final mushafController = ScrollController();
        addTearDown(mushafController.dispose);
        final paragraphKey = GlobalKey<QuranTrackedParagraphState>();
        const mushafStyle = TextStyle(
          fontFamily: 'Hafs',
          fontSize: 24,
          height: 1.85,
          color: Colors.black,
        );

        final mushafAccum = QuranSpanAccumulator();
        final mushafRanges = <TextRange>[];
        for (int i = 0; i < words120.length; i++) {
          final start = _currentSpanTextLength(mushafAccum.spans);
          mushafAccum.addText(words120[i], style: mushafStyle);
          final end = _currentSpanTextLength(mushafAccum.spans);
          mushafRanges.add(TextRange(start: start, end: end));
          if (i < words120.length - 1) {
            mushafAccum.addText(' ', style: mushafStyle);
          }
        }
        final mushafSpan = TextSpan(style: mushafStyle, children: mushafAccum.spans);

        TextRange activeRange = mushafRanges.first;
        late StateSetter setMushafState;

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 360,
                height: 420,
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      setMushafState = setState;
                      return SingleChildScrollView(
                        controller: mushafController,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 108),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: QuranTrackedParagraph(
                            key: paragraphKey,
                            textSpan: mushafSpan,
                            textAlign: TextAlign.justify,
                            textDirection: TextDirection.rtl,
                            activeWordRange: activeRange,
                            isArrowMode: false,
                            isDark: false,
                            isPlaying: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(mushafController.position.maxScrollExtent, greaterThan(420));

        for (final wordIdx in [0, 44, 89, 119, 0]) {
          setMushafState(() {
            activeRange = mushafRanges[wordIdx];
          });
          await tester.pump();

          final targetSubRect = paragraphKey.currentState?.activeWordRect;
          expect(targetSubRect, isNotNull);
          QuranTrackingScrollHelper.ensureContextVisibleInViewport(
            paragraphKey.currentContext,
            targetSubRect: targetSubRect,
            topSafePadding: 14.0,
            bottomSafePadding: 96.0,
          );
          await tester.pumpAndSettle();

          final rectInVp = _subRectInScrollableViewport(
            paragraphKey.currentContext!,
            paragraphKey.currentState!.activeWordRect!,
          );
          expect(
            rectInVp.top,
            greaterThanOrEqualTo(14.0 - 1.0),
            reason: 'Mushaf word ${wordIdx + 1} clipped above top safe band',
          );
          expect(
            rectInVp.bottom,
            lessThanOrEqualTo(420.0 - 96.0 + 1.0),
            reason: 'Mushaf word ${wordIdx + 1} covered by bottom player bar',
          );
        }

        // (b) ListView.builder + SynchronizedArabicAyahWrap mode
        final listController = ScrollController();
        addTearDown(listController.dispose);
        final activeWordKey = GlobalKey();
        final verseKeys = <int, GlobalKey>{0: GlobalKey(), 1: GlobalKey()};
        final verses = [
          _makeVerse(surahId: 2, ayahId: 282, text: longAyahText),
          _makeVerse(surahId: 2, ayahId: 283, text: shortAyahText),
        ];

        int activeVerseIndex = 0;
        int activeWordOrder = 1;
        int listInteractionCount = 0;
        late StateSetter setListState;

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 360,
                height: 420,
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      setListState = setState;
                      return ListView.builder(
                        controller: listController,
                        scrollCacheExtent: const ScrollCacheExtent.pixels(1800),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        itemCount: verses.length,
                        itemBuilder: (context, index) {
                          final isCurrent = index == activeVerseIndex;
                          return Container(
                            key: verseKeys[index],
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            child: SynchronizedArabicAyahWrap(
                              verse: verses[index],
                              verseIndex: index,
                              isActiveVerse: isCurrent,
                              activeWordOrder: isCurrent ? activeWordOrder : 0,
                              activeWordDurationMs: 300,
                              playbackSpeed: 1.0,
                              isPlaying: false,
                              isDark: false,
                              fontFamily: 'Hafs',
                              fontSize: 24,
                              isBoldArabic: false,
                              isArrowTracking: false,
                              activeWordKey: isCurrent ? activeWordKey : null,
                              onWordTap: (vIdx, wOrder) =>
                                  listInteractionCount += vIdx + wOrder,
                              onAyahMarkerTap: () => listInteractionCount += 1,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(listController.position.maxScrollExtent, greaterThan(420));

        for (final wOrder in [1, 50, 100, 120]) {
          setListState(() {
            activeVerseIndex = 0;
            activeWordOrder = wOrder;
          });
          await tester.pump();

          QuranTrackingScrollHelper.ensureContextVisibleInViewport(
            activeWordKey.currentContext,
            topSafePadding: 14.0,
            bottomSafePadding: 18.0,
            preferredAlignment: 0.26,
          );
          await tester.pumpAndSettle();

          expect(activeWordKey.currentContext, isNotNull);
          final wordRect = _rectInScrollableViewport(activeWordKey.currentContext!);
          expect(wordRect.top, greaterThanOrEqualTo(14.0 - 1.0));
          expect(wordRect.bottom, lessThanOrEqualTo(420.0 - 18.0 + 1.0));
        }

        // Repeat loop: back to Verse 0 Word 1
        setListState(() {
          activeVerseIndex = 0;
          activeWordOrder = 1;
        });
        QuranTrackingScrollHelper.scrollToVerseCard(
          scrollController: listController,
          verseKeys: verseKeys,
          targetIndex: 0,
          totalCount: verses.length,
          activeWordKey: activeWordKey,
          preferActiveWord: false,
          topSafePadding: 14.0,
          bottomSafePadding: 18.0,
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(activeWordKey.currentContext, isNotNull);
        final repeatedWordRect =
            _rectInScrollableViewport(activeWordKey.currentContext!);
        expect(repeatedWordRect.top, greaterThanOrEqualTo(14.0 - 1.0));
        expect(repeatedWordRect.bottom, lessThanOrEqualTo(420.0 - 18.0 + 1.0));

        // Downward transition to Verse 1 Word 1
        setListState(() {
          activeVerseIndex = 1;
          activeWordOrder = 1;
        });
        QuranTrackingScrollHelper.scrollToVerseCard(
          scrollController: listController,
          verseKeys: verseKeys,
          targetIndex: 1,
          totalCount: verses.length,
          activeWordKey: activeWordKey,
          preferActiveWord: false,
          topSafePadding: 14.0,
          bottomSafePadding: 18.0,
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(activeWordKey.currentContext, isNotNull);
        final nextVerseWordRect =
            _rectInScrollableViewport(activeWordKey.currentContext!);
        expect(nextVerseWordRect.top, greaterThanOrEqualTo(14.0 - 1.0));
        expect(nextVerseWordRect.bottom, lessThanOrEqualTo(420.0 - 18.0 + 1.0));
        expect(listInteractionCount, 0);
      },
    );
  });
}

int _currentSpanTextLength(List<InlineSpan> spans) {
  int total = 0;
  for (final span in spans) {
    if (span is TextSpan && span.text != null) {
      total += span.text!.length;
    } else if (span is WidgetSpan) {
      total += 1;
    }
  }
  return total;
}
