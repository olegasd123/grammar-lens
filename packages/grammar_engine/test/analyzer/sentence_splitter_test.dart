import 'package:grammar_engine/grammar_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SentenceSplitter', () {
    test('splits simple sentences', () {
      final result = SentenceSplitter.split(
        'Hello world. How are you? I am fine!',
      );
      expect(result, hasLength(3));
      expect(result[0].text, 'Hello world.');
      expect(result[1].text, 'How are you?');
      expect(result[2].text, 'I am fine!');
    });

    test('handles abbreviations', () {
      final result = SentenceSplitter.split(
        'Mr. Smith went to Washington. He met Dr. Jones.',
      );
      expect(result, hasLength(2));
      expect(result[0].text, contains('Mr.'));
      expect(result[0].text, contains('Washington.'));
    });

    test('handles empty text', () {
      expect(SentenceSplitter.split(''), isEmpty);
      expect(SentenceSplitter.split('   '), isEmpty);
    });

    test('handles text without sentence terminators', () {
      final result = SentenceSplitter.split('Hello world');
      expect(result, hasLength(1));
      expect(result[0].text, 'Hello world');
    });

    test('handles line breaks as sentence boundaries', () {
      final result = SentenceSplitter.split('First line\nSecond line');
      expect(result, hasLength(2));
    });

    test('tracks correct offsets', () {
      final result = SentenceSplitter.split('Hello. World.');
      expect(result[0].startOffset, 0);
      expect(result[1].text, 'World.');
    });

    test('handles decimal numbers', () {
      final result = SentenceSplitter.split(
        'The value is 3.14 approximately.',
      );
      expect(result, hasLength(1));
    });
  });
}
