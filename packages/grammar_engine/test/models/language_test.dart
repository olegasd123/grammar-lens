import 'package:grammar_engine/grammar_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SupportedLanguage', () {
    test('fromCode supports all required language codes', () {
      const codes = [
        'ar',
        'zh',
        'cs',
        'nl',
        'en',
        'fr',
        'de',
        'el',
        'he',
        'hi',
        'id',
        'it',
        'ja',
        'ko',
        'fa',
        'pl',
        'pt',
        'ro',
        'ru',
        'es',
        'tr',
        'uk',
        'vi',
      ];

      for (final code in codes) {
        expect(() => SupportedLanguage.fromCode(code), returnsNormally);
      }
    });

    test('fromCode normalizes Chinese aliases', () {
      expect(
        SupportedLanguage.fromCode('zh-Hans'),
        SupportedLanguage.chineseSimplified,
      );
      expect(
        SupportedLanguage.fromCode('zh-CN'),
        SupportedLanguage.chineseSimplified,
      );
      expect(
        SupportedLanguage.fromCode('zh-Hant'),
        SupportedLanguage.chineseTraditional,
      );
      expect(
        SupportedLanguage.fromCode('zh-TW'),
        SupportedLanguage.chineseTraditional,
      );
    });
  });
}
