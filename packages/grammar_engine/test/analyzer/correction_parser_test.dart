import 'package:grammar_engine/grammar_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CorrectionParser', () {
    test('parses valid XML corrections', () {
      const xml = '''
<corrections>
<item>
  <original>dont</original>
  <corrected>don't</corrected>
  <type>grammar</type>
  <explanation>Missing apostrophe in contraction</explanation>
  <offset>3</offset>
</item>
</corrections>''';

      final sentences = [
        const SentenceSpan(text: 'He dont like it.', startOffset: 0, endOffset: 16),
      ];

      final corrections = CorrectionParser.parse(xml, sentences);
      expect(corrections, hasLength(1));
      expect(corrections[0].originalText, 'dont');
      expect(corrections[0].correctedText, "don't");
      expect(corrections[0].type, CorrectionType.grammar);
      expect(corrections[0].explanation, 'Missing apostrophe in contraction');
    });

    test('parses multiple corrections', () {
      const xml = '''
<corrections>
<item>
  <original>dont</original>
  <corrected>don't</corrected>
  <type>grammar</type>
  <explanation>Missing apostrophe</explanation>
  <offset>3</offset>
</item>
<item>
  <original>teh</original>
  <corrected>the</corrected>
  <type>spelling</type>
  <explanation>Misspelled word</explanation>
  <offset>14</offset>
</item>
</corrections>''';

      final sentences = [
        const SentenceSpan(text: 'He dont like teh cake.', startOffset: 0, endOffset: 22),
      ];

      final corrections = CorrectionParser.parse(xml, sentences);
      expect(corrections, hasLength(2));
      expect(corrections[0].type, CorrectionType.grammar);
      expect(corrections[1].type, CorrectionType.spelling);
    });

    test('handles empty corrections block', () {
      const xml = '<corrections></corrections>';
      final sentences = [
        const SentenceSpan(text: 'Correct sentence.', startOffset: 0, endOffset: 17),
      ];

      final corrections = CorrectionParser.parse(xml, sentences);
      expect(corrections, isEmpty);
    });

    test('handles malformed XML gracefully', () {
      const xml = '<corrections><item><original>bad</item></corrections>';
      final sentences = [
        const SentenceSpan(text: 'Some text.', startOffset: 0, endOffset: 10),
      ];

      // Should not throw, just return empty or partial results
      final corrections = CorrectionParser.parse(xml, sentences);
      expect(corrections, isA<List<Correction>>());
    });

    test('falls back to text search when offset is invalid', () {
      const xml = '''
<corrections>
<item>
  <original>dont</original>
  <corrected>don't</corrected>
  <type>grammar</type>
  <explanation>Fix</explanation>
  <offset>999</offset>
</item>
</corrections>''';

      final sentences = [
        const SentenceSpan(text: 'He dont like it.', startOffset: 0, endOffset: 16),
      ];

      final corrections = CorrectionParser.parse(xml, sentences);
      expect(corrections, hasLength(1));
      // Should find "dont" by text search
      expect(corrections[0].startOffset, 3);
    });
  });
}
