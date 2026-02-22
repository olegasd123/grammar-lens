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
  ///
  /// Implements the O(ND) algorithm from Eugene Myers' 1986 paper:
  /// "An O(ND) Difference Algorithm and Its Variations".
  ///
  /// N = n + m (total length), D = edit distance (number of
  /// insertions + deletions). For similar texts D is small, making
  /// this much faster than the O(n·m) LCS approach.
  static List<DiffSegment> _myersDiff(String a, String b) {
    final n = a.length;
    final m = b.length;

    if (n == 0 && m == 0) return [];

    if (n == 0) {
      return [DiffSegment(operation: DiffOperation.insert, text: b)];
    }

    if (m == 0) {
      return [DiffSegment(operation: DiffOperation.delete, text: a)];
    }

    // ── Forward pass: find the shortest edit distance D ────────────────
    //
    // v[k] holds the furthest-reaching x position on diagonal k,
    // where diagonal k is defined as x − y = k.
    //
    // We use an offset so that negative k values map to valid indices:
    //   v[k + offset] ↔ logical diagonal k.
    //
    // trace[d] stores v *after* processing step d, so that
    // trace[d-1] gives the state we came from when backtracking step d.

    final max = n + m;
    final offset = max;

    final v = List<int>.filled(2 * max + 1, 0);
    final trace = <List<int>>[];

    outer:
    for (var d = 0; d <= max; d++) {
      for (var k = -d; k <= d; k += 2) {
        // Pick the better predecessor: move down (insert) or right (delete).
        int x;
        if (k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset])) {
          x = v[k + 1 + offset]; // move down → insert from b
        } else {
          x = v[k - 1 + offset] + 1; // move right → delete from a
        }

        var y = x - k;

        // Follow the diagonal (snake) — matching characters are free.
        while (x < n && y < m && a[x] == b[y]) {
          x++;
          y++;
        }

        v[k + offset] = x;

        if (x >= n && y >= m) {
          // Save final state and stop.
          trace.add(List<int>.from(v));
          break outer;
        }
      }

      // Snapshot v *after* this step.
      trace.add(List<int>.from(v));
    }

    // ── Backtrack: reconstruct the edit script ─────────────────────────
    //
    // Walk backward from (n, m) through each step d = D, D-1, …, 1.
    // At each step we undo one edit (insert or delete) and the diagonal
    // snake that followed it.

    final segments = <DiffSegment>[];
    var x = n;
    var y = m;

    for (var d = trace.length - 1; d >= 1; d--) {
      final k = x - y;
      final vPrev = trace[d - 1]; // v after step d-1

      // Which diagonal did step d come from?
      int prevK;
      if (k == -d || (k != d && vPrev[k - 1 + offset] < vPrev[k + 1 + offset])) {
        prevK = k + 1; // insert (moved down)
      } else {
        prevK = k - 1; // delete (moved right)
      }

      final prevX = vPrev[prevK + offset];
      final prevY = prevX - prevK;

      // The edit moved from (prevX, prevY) to a mid-point; the snake
      // then ran from the mid-point to (x, y).
      //   insert → mid = (prevX,     prevY + 1)
      //   delete → mid = (prevX + 1, prevY    )
      final midX = prevK < k ? prevX + 1 : prevX;
      final midY = prevK > k ? prevY + 1 : prevY;

      // Emit the snake (equal characters) in reverse.
      while (x > midX && y > midY) {
        x--;
        y--;
        segments.add(DiffSegment(
          operation: DiffOperation.equal,
          text: a[x],
        ));
      }

      // Emit the edit.
      if (prevK > k) {
        // Insert: y decreased by 1.
        y--;
        segments.add(DiffSegment(
          operation: DiffOperation.insert,
          text: b[y],
        ));
      } else {
        // Delete: x decreased by 1.
        x--;
        segments.add(DiffSegment(
          operation: DiffOperation.delete,
          text: a[x],
        ));
      }
    }

    // Remaining diagonal from the initial snake at step 0.
    while (x > 0 && y > 0) {
      x--;
      y--;
      segments.add(DiffSegment(
        operation: DiffOperation.equal,
        text: a[x],
      ));
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
