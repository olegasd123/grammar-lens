import 'dart:math' as math;

import 'package:grammar_engine/src/diff/diff_result.dart';

/// Character-level text diff using the Myers diff algorithm.
///
/// Produces a minimal edit script showing insertions and deletions
/// needed to transform one text into another.
class TextDiffer {
  const TextDiffer._();

  /// Compute the diff between [original] and [modified] text.
  ///
  /// Returns a [DiffResult] with the minimal set of changes.
  static DiffResult diff(String original, String modified) {
    if (original == modified) {
      return DiffResult([
        DiffSegment(operation: DiffOperation.equal, text: original),
      ]);
    }

    if (original.isEmpty) {
      return DiffResult([
        DiffSegment(operation: DiffOperation.insert, text: modified),
      ]);
    }

    if (modified.isEmpty) {
      return DiffResult([
        DiffSegment(operation: DiffOperation.delete, text: original),
      ]);
    }

    // Find common prefix
    final prefixLength = _commonPrefix(original, modified);
    // Find common suffix (after prefix)
    final suffixLength = _commonSuffix(
      original.substring(prefixLength),
      modified.substring(prefixLength),
    );

    final origMiddle = original.substring(
      prefixLength,
      original.length - suffixLength,
    );
    final modMiddle = modified.substring(
      prefixLength,
      modified.length - suffixLength,
    );

    // Run Myers diff on the middle portion
    final middleDiff = _myersDiff(origMiddle, modMiddle);

    // Assemble the full result
    final segments = <DiffSegment>[];

    // Common prefix
    if (prefixLength > 0) {
      segments.add(DiffSegment(
        operation: DiffOperation.equal,
        text: original.substring(0, prefixLength),
      ));
    }

    // Middle changes
    segments.addAll(middleDiff);

    // Common suffix
    if (suffixLength > 0) {
      segments.add(DiffSegment(
        operation: DiffOperation.equal,
        text: original.substring(original.length - suffixLength),
      ));
    }

    return DiffResult(_mergeSegments(segments));
  }

  /// Myers diff algorithm on character sequences.
  static List<DiffSegment> _myersDiff(String a, String b) {
    final n = a.length;
    final m = b.length;
    final max = n + m;

    if (max == 0) return [];

    // For short strings, use simple LCS approach
    if (n * m < 10000) {
      return _simpleDiff(a, b);
    }

    // For longer strings, use the full Myers algorithm
    return _simpleDiff(a, b); // TODO: Implement full Myers for O(ND)
  }

  /// Simple LCS-based diff for short strings.
  static List<DiffSegment> _simpleDiff(String a, String b) {
    final n = a.length;
    final m = b.length;

    // Build LCS table
    final dp = List.generate(
      n + 1,
      (_) => List.filled(m + 1, 0),
    );

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    // Backtrack to build diff
    final segments = <DiffSegment>[];
    var i = n;
    var j = m;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
        segments.add(DiffSegment(
          operation: DiffOperation.equal,
          text: a[i - 1],
        ));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        segments.add(DiffSegment(
          operation: DiffOperation.insert,
          text: b[j - 1],
        ));
        j--;
      } else {
        segments.add(DiffSegment(
          operation: DiffOperation.delete,
          text: a[i - 1],
        ));
        i--;
      }
    }

    return _mergeSegments(segments.reversed.toList());
  }

  /// Find the length of the common prefix.
  static int _commonPrefix(String a, String b) {
    final max = math.min(a.length, b.length);
    for (var i = 0; i < max; i++) {
      if (a[i] != b[i]) return i;
    }
    return max;
  }

  /// Find the length of the common suffix.
  static int _commonSuffix(String a, String b) {
    final max = math.min(a.length, b.length);
    for (var i = 0; i < max; i++) {
      if (a[a.length - 1 - i] != b[b.length - 1 - i]) return i;
    }
    return max;
  }

  /// Merge adjacent segments with the same operation.
  static List<DiffSegment> _mergeSegments(List<DiffSegment> segments) {
    if (segments.isEmpty) return segments;

    final merged = <DiffSegment>[];
    var current = segments.first;

    for (var i = 1; i < segments.length; i++) {
      if (segments[i].operation == current.operation) {
        current = DiffSegment(
          operation: current.operation,
          text: current.text + segments[i].text,
        );
      } else {
        if (current.text.isNotEmpty) merged.add(current);
        current = segments[i];
      }
    }
    if (current.text.isNotEmpty) merged.add(current);

    return merged;
  }
}
