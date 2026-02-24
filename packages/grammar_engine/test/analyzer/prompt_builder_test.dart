import 'package:grammar_engine/grammar_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PromptBuilder', () {
    const sentences = [
      SentenceSpan(
        text: 'helo me freind',
        startOffset: 0,
        endOffset: 14,
      ),
    ];

    test('phi3Chat format includes phi chat markers', () {
      final prompt = PromptBuilder.build(
        sentences,
        SupportedLanguage.english,
        format: PromptFormat.phi3Chat,
      );

      expect(prompt, contains('<|system|>'));
      expect(prompt, contains('<|user|>'));
      expect(prompt, contains('<|assistant|>'));
      expect(prompt, contains('helo me freind'));
    });

    test('plainInstruction format avoids phi chat markers', () {
      final prompt = PromptBuilder.build(
        sentences,
        SupportedLanguage.english,
        format: PromptFormat.plainInstruction,
      );

      expect(prompt, isNot(contains('<|system|>')));
      expect(prompt, isNot(contains('<|user|>')));
      expect(prompt, isNot(contains('<|assistant|>')));
      expect(prompt, contains('Return only XML'));
      expect(prompt, contains('helo me freind'));
    });

    test('supports extended language prompts (russian)', () {
      final prompt = PromptBuilder.build(
        sentences,
        SupportedLanguage.russian,
        format: PromptFormat.plainInstruction,
      );

      expect(prompt, contains('корректор русского языка'));
      expect(prompt, contains('Проверь следующий текст'));
      expect(prompt, contains('helo me freind'));
    });

    test('prompt contract does not include offset tag', () {
      final prompt = PromptBuilder.build(
        sentences,
        SupportedLanguage.english,
        format: PromptFormat.plainInstruction,
      );

      expect(prompt, isNot(contains('<offset>')));
      expect(PromptBuilder.gbnfGrammar, isNot(contains('<offset>')));
    });
  });
}
