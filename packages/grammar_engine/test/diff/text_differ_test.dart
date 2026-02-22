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

    // ── Additional tests for Myers O(ND) algorithm ────────────────────

    test('completely different strings', () {
      final result = TextDiffer.diff('abc', 'xyz');
      expect(result.isIdentical, isFalse);
      expect(result.originalText, 'abc');
      expect(result.modifiedText, 'xyz');
    });

    test('single character insertion at start', () {
      final result = TextDiffer.diff('ello', 'hello');
      expect(result.modifiedText, 'hello');
      expect(result.originalText, 'ello');
      expect(result.insertions, isNotEmpty);
      expect(result.insertions.first.text, 'h');
    });

    test('single character insertion at end', () {
      final result = TextDiffer.diff('hell', 'hello');
      expect(result.modifiedText, 'hello');
      expect(result.originalText, 'hell');
    });

    test('single character deletion at start', () {
      final result = TextDiffer.diff('hello', 'ello');
      expect(result.originalText, 'hello');
      expect(result.modifiedText, 'ello');
      expect(result.deletions.first.text, 'h');
    });

    test('multiple scattered edits', () {
      final result = TextDiffer.diff(
        'the quick brown fox',
        'the slow green fox',
      );
      expect(result.originalText, 'the quick brown fox');
      expect(result.modifiedText, 'the slow green fox');
      expect(result.segments.first.isEqual, isTrue);
      expect(result.segments.first.text, 'the ');
      expect(result.segments.last.isEqual, isTrue);
      // Must end with common suffix containing ' fox'
      expect(result.segments.last.text, contains('fox'));
    });

    test('produces minimal edit script', () {
      // "abc" → "aXc" should be delete 'b', insert 'X' (edit distance 2)
      final result = TextDiffer.diff('abc', 'aXc');
      expect(result.originalText, 'abc');
      expect(result.modifiedText, 'aXc');
      // Prefix 'a', suffix 'c', middle: delete 'b' + insert 'X'
      expect(result.deletions, hasLength(1));
      expect(result.deletions[0].text, 'b');
      expect(result.insertions, hasLength(1));
      expect(result.insertions[0].text, 'X');
    });

    test('handles repeated characters', () {
      final result = TextDiffer.diff('aaaa', 'aabaa');
      expect(result.originalText, 'aaaa');
      expect(result.modifiedText, 'aabaa');
    });

    test('handles multi-word sentence correction', () {
      final result = TextDiffer.diff(
        'She dont like apples.',
        "She doesn't like apples.",
      );
      expect(result.originalText, 'She dont like apples.');
      expect(result.modifiedText, "She doesn't like apples.");
      // Common prefix should be 'She do'
      expect(result.segments.first.isEqual, isTrue);
      expect(result.segments.first.text, startsWith('She do'));
    });

    test('handles longer paragraph-level diff', () {
      const original = 'The weather is nice today. '
          'I will go to the park. '
          'The birds are singing.';
      const modified = 'The weather is wonderful today. '
          'I will go to the park. '
          'The birds are singing loudly.';

      final result = TextDiffer.diff(original, modified);
      expect(result.originalText, original);
      expect(result.modifiedText, modified);
      expect(result.isIdentical, isFalse);
      // The middle sentence is unchanged
      expect(
        result.unchanged.any((s) => s.text.contains('I will go to the park.')),
        isTrue,
      );
    });

    test('single character strings', () {
      final result = TextDiffer.diff('a', 'b');
      expect(result.originalText, 'a');
      expect(result.modifiedText, 'b');
      expect(result.deletions, hasLength(1));
      expect(result.insertions, hasLength(1));
    });

    test('insert into single character', () {
      final result = TextDiffer.diff('a', 'ab');
      expect(result.originalText, 'a');
      expect(result.modifiedText, 'ab');
    });

    test('delete from two characters', () {
      final result = TextDiffer.diff('ab', 'a');
      expect(result.originalText, 'ab');
      expect(result.modifiedText, 'a');
    });

    test('produces consistent results for symmetric edits', () {
      // Diff in one direction and the other should be complementary.
      final forward = TextDiffer.diff('hello world', 'hello there');
      final reverse = TextDiffer.diff('hello there', 'hello world');

      expect(forward.insertions.length, reverse.deletions.length);
      expect(forward.deletions.length, reverse.insertions.length);
    });
  });
}
