import 'package:grammar_engine/grammar_engine.dart';
import 'package:test/test.dart';

void main() {
  const detector = LanguageDetector();

  group('LanguageDetector', () {
    test('detects English text', () {
      final result = detector.detect(
        'The quick brown fox jumps over the lazy dog in the park.',
      );
      expect(result, SupportedLanguage.english);
    });

    test('detects Spanish text', () {
      final result = detector.detect(
        'El rápido zorro marrón salta sobre el perro perezoso en el parque.',
      );
      expect(result, SupportedLanguage.spanish);
    });

    test('detects French text', () {
      final result = detector.detect(
        'Le rapide renard brun saute par-dessus le chien paresseux dans le parc.',
      );
      expect(result, SupportedLanguage.french);
    });

    test('detects German text', () {
      final result = detector.detect(
        'Der schnelle braune Fuchs springt über den faulen Hund im Park.',
      );
      expect(result, SupportedLanguage.german);
    });

    test('detects Portuguese text', () {
      final result = detector.detect(
        'A rápida raposa marrom pula sobre o cachorro preguiçoso no parque.',
      );
      expect(result, SupportedLanguage.portuguese);
    });

    test('detects short Russian text by Cyrillic script', () {
      final result = detector.detect('Здровствуй, друг');
      expect(result, SupportedLanguage.russian);
    });

    test('detects Ukrainian text by unique letters', () {
      final result =
          detector.detect('Привіт, друже! Це український текст із літерою ї.');
      expect(result, SupportedLanguage.ukrainian);
    });

    test('detects Arabic text by script', () {
      final result = detector.detect('مرحبا يا صديقي');
      expect(result, SupportedLanguage.arabic);
    });

    test('defaults to English for very short text', () {
      final result = detector.detect('Hi');
      expect(result, SupportedLanguage.english);
    });

    test('defaults to English for empty text', () {
      final result = detector.detect('');
      expect(result, SupportedLanguage.english);
    });

    test('returns confidence scores', () {
      final scores = detector.detectWithConfidence(
        'The quick brown fox jumps over the lazy dog in the park.',
      );
      expect(scores, isNotEmpty);
      expect(scores[SupportedLanguage.english], isNotNull);

      // English should have highest confidence
      final englishScore = scores[SupportedLanguage.english]!;
      for (final entry in scores.entries) {
        if (entry.key != SupportedLanguage.english) {
          expect(englishScore, greaterThanOrEqualTo(entry.value));
        }
      }
    });

    test('returns script-based confidence for short Russian text', () {
      final scores = detector.detectWithConfidence('Здровствуй, друг');
      expect(scores[SupportedLanguage.russian], 1.0);
      expect(scores[SupportedLanguage.english], 0.0);
    });
  });
}
