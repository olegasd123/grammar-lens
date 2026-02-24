import 'package:grammar_engine/grammar_engine.dart';
import 'package:test/test.dart';

void main() {
  group('GrammarAnalyzer', () {
    test('analyze filters no-op corrections', () async {
      final analyzer = GrammarAnalyzer(
        onInfer: (_) async => '''
<corrections>
<item>
  <original>Hola mi amiga</original>
  <corrected>Hola mi amiga</corrected>
  <type>spelling</type>
  <explanation>No error found.</explanation>
  <offset>0</offset>
</item>
</corrections>''',
      );

      final result = await analyzer.analyze(
        'Hola mi amiga',
        language: SupportedLanguage.spanish,
      );

      expect(result.corrections, isEmpty);
    });

    test('analyze keeps only meaningful corrections', () async {
      final analyzer = GrammarAnalyzer(
        onInfer: (_) async => '''
<corrections>
<item>
  <original>Helo</original>
  <corrected>Hello</corrected>
  <type>spelling</type>
  <explanation>Fix typo.</explanation>
  <offset>0</offset>
</item>
<item>
  <original>world</original>
  <corrected>world</corrected>
  <type>style</type>
  <explanation>No error found.</explanation>
  <offset>5</offset>
</item>
</corrections>''',
      );

      final result = await analyzer.analyze(
        'Helo world',
        language: SupportedLanguage.english,
      );

      expect(result.corrections, hasLength(1));
      expect(result.corrections.first.originalText, 'Helo');
      expect(result.corrections.first.correctedText, 'Hello');
    });

    test('analyze drops no-error items with empty type', () async {
      final analyzer = GrammarAnalyzer(
        onInfer: (_) async => '''
<corrections>
<item>
  <original>I had already eaten breakfast.</original>
  <corrected>I had already eaten breakfast. (no correction needed)</corrected>
  <type></type>
  <explanation>(no error found)</explanation>
  <offset>0</offset>
</item>
</corrections>''',
      );

      final result = await analyzer.analyze(
        'I had already eaten breakfast.',
        language: SupportedLanguage.english,
      );

      expect(result.corrections, isEmpty);
    });

    test('analyzeSentence filters no-op corrections', () async {
      final analyzer = GrammarAnalyzer(
        onInfer: (_) async => '''
<corrections>
<item>
  <original>Hola</original>
  <corrected>Hola</corrected>
  <type>spelling</type>
  <explanation>No error found.</explanation>
  <offset>0</offset>
</item>
</corrections>''',
      );

      final corrections = await analyzer.analyzeSentence(
        'Hola',
        language: SupportedLanguage.spanish,
      );

      expect(corrections, isEmpty);
    });

    test('analyze filters template placeholder corrections', () async {
      final analyzer = GrammarAnalyzer(
        onInfer: (_) async => '''
<corrections>
<item>
  <original>erroneous text span</original>
  <corrected>fixed text span</corrected>
  <type>grammar</type>
  <explanation>brief explanation of the error</explanation>
  <offset>0</offset>
</item>
</corrections>''',
      );

      final result = await analyzer.analyze(
        'Здровствуй, друг',
        language: SupportedLanguage.english,
      );

      expect(result.corrections, isEmpty);
    });

    test('analyze filters corrections with original text not in source',
        () async {
      final analyzer = GrammarAnalyzer(
        onInfer: (_) async => '''
<corrections>
<item>
  <original>missing phrase</original>
  <corrected>fixed phrase</corrected>
  <type>grammar</type>
  <explanation>Fix.</explanation>
  <offset>0</offset>
</item>
</corrections>''',
      );

      final result = await analyzer.analyze(
        'Hello world',
        language: SupportedLanguage.english,
      );

      expect(result.corrections, isEmpty);
    });

    test('analyze exposes raw model output for debugging', () async {
      const raw = '<corrections></corrections>';
      final analyzer = GrammarAnalyzer(
        onInfer: (_) async => raw,
      );

      final result = await analyzer.analyze(
        'Hello world',
        language: SupportedLanguage.english,
      );

      expect(result.rawModelOutput, contains(raw));
    });

    test('analyze includes request parameters in debug output', () async {
      const raw = '<corrections></corrections>';
      final analyzer = GrammarAnalyzer(
        debugRequestMetadata: () => {
          'temperature': 0.15,
          'top_p': 0.9,
          'repeat_penalty': 1.1,
        },
        onInfer: (_) async => raw,
      );

      final result = await analyzer.analyze(
        'Hello world',
        language: SupportedLanguage.english,
      );

      expect(result.rawModelOutput, contains('=== REQUEST PARAMETERS ==='));
      expect(result.rawModelOutput, contains('"temperature": 0.15'));
      expect(result.rawModelOutput, contains('"top_p": 0.9'));
      expect(result.rawModelOutput, contains('"repeat_penalty": 1.1'));
    });
  });
}
