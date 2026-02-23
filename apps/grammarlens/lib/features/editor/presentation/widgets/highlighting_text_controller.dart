import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:grammarlens_ui/grammarlens_ui.dart';

/// A [TextEditingController] that renders inline correction highlights
/// as coloured underlines and tinted backgrounds within the [TextField].
///
/// Call [updateCorrections] whenever the active corrections list changes.
/// The controller automatically rebuilds styled [TextSpan]s on the next
/// frame.
class HighlightingTextController extends TextEditingController {
  List<Correction> _corrections = const [];

  /// Replace the current set of active corrections.
  void updateCorrections(List<Correction> corrections) {
    if (_corrections == corrections) return;
    _corrections = corrections;
    // Force a rebuild of the text spans.
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fullText = text;

    if (_corrections.isEmpty || fullText.isEmpty) {
      return TextSpan(text: fullText, style: style);
    }

    // Sort corrections by start offset to merge into a linear span list.
    final sorted = _corrections.toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final correction in sorted) {
      final range = _resolveVisualRange(correction, fullText);
      if (range == null) {
        continue;
      }
      final start = range.start;
      final end = range.end;

      if (start < cursor) {
        // Overlapping correction — skip to avoid duplicated spans.
        continue;
      }

      // Plain text before this correction.
      if (cursor < start) {
        spans.add(TextSpan(text: fullText.substring(cursor, start)));
      }

      // Highlighted span.
      if (start < end) {
        spans.add(
          TextSpan(
            text: fullText.substring(start, end),
            style: _styleForType(correction.type),
          ),
        );
      }

      cursor = end;
    }

    // Remaining plain text after the last correction.
    if (cursor < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(cursor)));
    }

    return TextSpan(style: style, children: spans);
  }

  _HighlightRange? _resolveVisualRange(Correction correction, String fullText) {
    final baseStart = correction.startOffset.clamp(0, fullText.length);
    final baseEnd = correction.endOffset.clamp(baseStart, fullText.length);
    if (baseStart == baseEnd) return null;

    final originalSpan = _findOriginalSpan(correction, fullText);

    var range = _resolveDiffAnchoredRange(correction, originalSpan) ??
        _narrowChangedRange(
          _HighlightRange(start: baseStart, end: baseEnd),
          correction,
        );

    // Insert-only edits can collapse to a caret. Keep one visible char.
    if (range.start == range.end) {
      if (range.start < fullText.length) {
        range = _HighlightRange(start: range.start, end: range.start + 1);
      } else if (range.start > 0) {
        range = _HighlightRange(start: range.start - 1, end: range.start);
      }
    }

    range = _expandToWordBoundaries(
      text: fullText,
      range: range,
      minStart: originalSpan?.start ?? baseStart,
      maxEnd: originalSpan?.end ?? baseEnd,
    );

    if (range.start >= range.end) return null;
    return range;
  }

  _HighlightRange? _findOriginalSpan(Correction correction, String fullText) {
    final original = correction.originalText;
    if (original.isEmpty) return null;

    final offset = correction.startOffset;
    if (offset >= 0 &&
        offset + original.length <= fullText.length &&
        fullText.substring(offset, offset + original.length) == original) {
      return _HighlightRange(start: offset, end: offset + original.length);
    }

    final exact = fullText.indexOf(original);
    if (exact >= 0) {
      return _HighlightRange(start: exact, end: exact + original.length);
    }

    final lowerText = fullText.toLowerCase();
    final lowerOriginal = original.toLowerCase();
    final insensitive = lowerText.indexOf(lowerOriginal);
    if (insensitive >= 0) {
      return _HighlightRange(
        start: insensitive,
        end: insensitive + original.length,
      );
    }

    return null;
  }

  _HighlightRange? _resolveDiffAnchoredRange(
    Correction correction,
    _HighlightRange? originalSpan,
  ) {
    if (originalSpan == null) return null;

    final changed = _collectChangedRanges(
      correction.originalText,
      correction.correctedText,
    );
    if (changed.isEmpty) return null;

    final nonCollapsed = changed.where((r) => r.start < r.end).toList();
    final candidates = nonCollapsed.isNotEmpty ? nonCollapsed : changed;

    final relativeOffset = (correction.startOffset - originalSpan.start)
        .clamp(0, originalSpan.end - originalSpan.start);
    var best = candidates.first;
    var bestDistance = _distanceToRange(relativeOffset, best);

    for (final range in candidates.skip(1)) {
      final distance = _distanceToRange(relativeOffset, range);
      if (distance < bestDistance) {
        best = range;
        bestDistance = distance;
      }
    }

    final start = originalSpan.start + best.start;
    final end = originalSpan.start + best.end;
    return _HighlightRange(start: start, end: end);
  }

  List<_HighlightRange> _collectChangedRanges(
      String original, String corrected) {
    if (original.isEmpty || corrected.isEmpty || original == corrected) {
      return const [];
    }

    final diff = TextDiffer.diff(original, corrected);
    final ranges = <_HighlightRange>[];
    var originalCursor = 0;

    for (final segment in diff.segments) {
      if (segment.isEqual) {
        originalCursor += segment.text.length;
        continue;
      }

      if (segment.isDelete) {
        ranges.add(
          _HighlightRange(
            start: originalCursor,
            end: originalCursor + segment.text.length,
          ),
        );
        originalCursor += segment.text.length;
        continue;
      }

      // Insertion in corrected text: anchor to the current original position.
      ranges.add(_HighlightRange(start: originalCursor, end: originalCursor));
    }

    if (ranges.isEmpty) return ranges;

    final merged = <_HighlightRange>[ranges.first];
    for (final range in ranges.skip(1)) {
      final last = merged.last;
      if (range.start <= last.end + 1) {
        merged[merged.length - 1] = _HighlightRange(
          start: last.start,
          end: math.max(last.end, range.end),
        );
      } else {
        merged.add(range);
      }
    }

    return merged;
  }

  int _distanceToRange(int offset, _HighlightRange range) {
    if (offset < range.start) {
      return range.start - offset;
    }
    if (offset > range.end) {
      return offset - range.end;
    }
    return 0;
  }

  _HighlightRange _narrowChangedRange(
    _HighlightRange base,
    Correction correction,
  ) {
    final original = correction.originalText;
    final corrected = correction.correctedText;
    if (original.isEmpty || corrected.isEmpty) {
      return base;
    }

    final minLength = math.min(original.length, corrected.length);
    var prefix = 0;
    while (prefix < minLength &&
        original.codeUnitAt(prefix) == corrected.codeUnitAt(prefix)) {
      prefix++;
    }

    var suffix = 0;
    while (suffix < (minLength - prefix) &&
        original.codeUnitAt(original.length - 1 - suffix) ==
            corrected.codeUnitAt(corrected.length - 1 - suffix)) {
      suffix++;
    }

    final narrowedStart = (base.start + prefix).clamp(base.start, base.end);
    final narrowedEnd = (base.end - suffix).clamp(narrowedStart, base.end);

    return _HighlightRange(
      start: narrowedStart,
      end: narrowedEnd,
    );
  }

  _HighlightRange _expandToWordBoundaries({
    required String text,
    required _HighlightRange range,
    required int minStart,
    required int maxEnd,
  }) {
    if (text.isEmpty) return range;

    var start = range.start;
    var end = range.end;

    if (start < text.length && _isWordCharacter(text[start])) {
      while (start > minStart && _isWordCharacter(text[start - 1])) {
        start--;
      }
    }

    if (end > 0 && end <= text.length && _isWordCharacter(text[end - 1])) {
      while (end < maxEnd && end < text.length && _isWordCharacter(text[end])) {
        end++;
      }
    }

    return _HighlightRange(start: start, end: end);
  }

  bool _isWordCharacter(String char) {
    if (char.isEmpty) return false;

    final code = char.codeUnitAt(0);
    final isDigit = code >= 0x30 && code <= 0x39;
    final isLetter = char.toLowerCase() != char.toUpperCase();

    return isDigit ||
        isLetter ||
        char == '_' ||
        char == '\'' ||
        char == '’' ||
        char == '-';
  }

  /// Returns a [TextStyle] that adds a coloured underline + tinted
  /// background for the given correction type.
  TextStyle _styleForType(CorrectionType type) {
    return switch (type) {
      CorrectionType.grammar => TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: AppColors.errorRed,
          decorationStyle: TextDecorationStyle.wavy,
          decorationThickness: 2,
          backgroundColor: AppColors.errorRedLight.withValues(alpha: 0.25),
        ),
      CorrectionType.spelling => TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: AppColors.warningOrange,
          decorationStyle: TextDecorationStyle.wavy,
          decorationThickness: 2,
          backgroundColor: AppColors.warningOrangeLight.withValues(alpha: 0.25),
        ),
      CorrectionType.punctuation => TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: AppColors.punctuationYellow,
          decorationStyle: TextDecorationStyle.wavy,
          decorationThickness: 2,
          backgroundColor:
              AppColors.punctuationYellowLight.withValues(alpha: 0.25),
        ),
      CorrectionType.style => TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: AppColors.styleBlue,
          decorationStyle: TextDecorationStyle.wavy,
          decorationThickness: 2,
          backgroundColor: AppColors.styleBlueLight.withValues(alpha: 0.25),
        ),
    };
  }
}

class _HighlightRange {
  final int start;
  final int end;

  const _HighlightRange({
    required this.start,
    required this.end,
  });
}
