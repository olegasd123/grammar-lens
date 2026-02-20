import 'package:grammar_engine/grammar_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TextDiffer', () {
    test('identical texts produce equal-only diff', () {
      final result = TextDiffer.diff('hello', 'hello');
      expect(result.isIdentical, isTrue);
      expect(result.segments, hasLength(1));
      expect(result.segments[0].operation, DiffOperation.equal);
    });

    test('detects simple insertion', () {
      final result = TextDiffer.diff('hllo', 'hello');
      expect(result.insertions, isNotEmpty);
      expect(result.modifiedText, 'hello');
      expect(result.originalText, 'hllo');
    });

    test('detects simple deletion', () {
      final result = TextDiffer.diff('hello', 'hllo');
      expect(result.deletions, isNotEmpty);
      expect(result.originalText, 'hello');
      expect(result.modifiedText, 'hllo');
    });

    test('detects replacement', () {
      final result = TextDiffer.diff('dont', "don't");
      expect(result.isIdentical, isFalse);
      expect(result.originalText, 'dont');
      expect(result.modifiedText, "don't");
    });

    test('handles empty original', () {
      final result = TextDiffer.diff('', 'hello');
      expect(result.insertions, hasLength(1));
      expect(result.insertions[0].text, 'hello');
    });

    test('handles empty modified', () {
      final result = TextDiffer.diff('hello', '');
      expect(result.deletions, hasLength(1));
      expect(result.deletions[0].text, 'hello');
    });

    test('handles both empty', () {
      final result = TextDiffer.diff('', '');
      expect(result.segments, hasLength(1));
      expect(result.segments[0].text, '');
    });

    test('preserves common prefix and suffix', () {
      final result = TextDiffer.diff(
        'The cat sat on the mat.',
        'The dog sat on the mat.',
      );
      expect(result.segments.first.isEqual, isTrue);
      expect(result.segments.first.text, 'The ');
      expect(result.segments.last.isEqual, isTrue);
      expect(result.segments.last.text, ' sat on the mat.');
    });
  });
}
