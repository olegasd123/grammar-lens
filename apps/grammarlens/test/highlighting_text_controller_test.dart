import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_engine/grammar_engine.dart';

import 'package:grammarlens/features/editor/presentation/widgets/highlighting_text_controller.dart';

void main() {
  group('HighlightingTextController', () {
    testWidgets(
      'highlights changed word for broad sentence correction',
      (tester) async {
        final controller = HighlightingTextController();
        const text =
            'Вчора ми зустрілися з друзями і довго говорили про наші плани на майбутнього.';
        controller.text = text;
        controller.updateCorrections([
          Correction(
            startOffset: 0,
            endOffset: text.length,
            originalText: text,
            correctedText:
                'Вчора ми зустрілися з друзями і довго говорили про наші плани на майбутнє.',
            type: CorrectionType.grammar,
            explanation: 'Incorrect noun declension.',
          ),
        ]);

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(),
          ),
        );
        final context = tester.element(find.byType(SizedBox));

        final span = controller.buildTextSpan(
          context: context,
          withComposing: false,
        );

        expect(_highlightedTexts(span), ['майбутнього']);
      },
    );

    testWidgets('highlights punctuation mark for comma removal',
        (tester) async {
      final controller = HighlightingTextController();
      const text =
          'Вона не знала, що робити, тому що її брат сказав їй неправду.';
      controller.text = text;
      controller.updateCorrections([
        Correction(
          startOffset: 0,
          endOffset: text.length,
          originalText: text,
          correctedText:
              'Вона не знала що робити, тому що її брат сказав їй неправду.',
          type: CorrectionType.punctuation,
          explanation: 'Unnecessary comma.',
        ),
      ]);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );

      expect(_highlightedTexts(span), [',']);
    });

    testWidgets('expands partial letter diff to the full word', (tester) async {
      final controller = HighlightingTextController();
      const text = 'Я пішов в магазин і купила хліб та молоко.';
      const wrongWord = 'купила';
      final wordStart = text.indexOf(wrongWord);
      controller.text = text;
      controller.updateCorrections([
        Correction(
          startOffset: wordStart,
          endOffset: wordStart + wrongWord.length,
          originalText: wrongWord,
          correctedText: 'купив',
          type: CorrectionType.grammar,
          explanation: 'Incorrect verb agreement.',
        ),
      ]);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );

      expect(_highlightedTexts(span), [wrongWord]);
    });

    testWidgets(
      'uses changed chunk nearest to offset for sentence-wide corrections',
      (tester) async {
        final controller = HighlightingTextController();
        const line1 = 'Я пішов в магазин і купила хліб та молоко.';
        const line2 =
            'Вчора ми зустрілися з друзями і довго говорили про наші плани на майбутнього.';
        const line3 =
            'Вона не знала що робити, тому що її брат сказав їй неправду.';
        const text = '$line1\n\n$line2\n\n$line3';

        controller.text = text;
        controller.updateCorrections([
          Correction(
            startOffset: 19,
            endOffset: 19 + line1.length,
            originalText: line1,
            correctedText: 'Я пішов до магазину і купив хліб і молоко.',
            type: CorrectionType.grammar,
            explanation: 'Incorrect verb agreement.',
          ),
          Correction(
            startOffset: 51,
            endOffset: 51 + line2.length,
            originalText: line2,
            correctedText:
                'Вчора ми зустрілися з друзями і довго говорили про наші плани на майбутнє.',
            type: CorrectionType.grammar,
            explanation: 'Incorrect noun declension.',
          ),
        ]);

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(),
          ),
        );
        final context = tester.element(find.byType(SizedBox));

        final span = controller.buildTextSpan(
          context: context,
          withComposing: false,
        );
        final highlights = _highlightedTexts(span);

        expect(highlights, ['купила', 'майбутнього']);
      },
    );
  });
}

List<String> _highlightedTexts(TextSpan root) {
  final highlighted = <String>[];

  void visit(InlineSpan span) {
    if (span is! TextSpan) return;

    final children = span.children;
    if (children != null && children.isNotEmpty) {
      for (final child in children) {
        visit(child);
      }
      return;
    }

    final text = span.text;
    if (text == null || text.isEmpty) return;

    if (span.style?.decoration == TextDecoration.underline) {
      highlighted.add(text);
    }
  }

  visit(root);
  return highlighted;
}
