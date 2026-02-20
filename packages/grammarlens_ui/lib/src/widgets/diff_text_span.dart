import 'package:flutter/material.dart';

import 'package:grammarlens_ui/src/theme/app_colors.dart';

/// Operation type for diff segments.
enum DiffOp { equal, insert, delete }

/// A segment in a text diff.
class DiffSpanSegment {
  final DiffOp operation;
  final String text;

  const DiffSpanSegment({required this.operation, required this.text});
}

/// Utility to build styled [TextSpan] trees from text diffs.
///
/// - Deleted text: gray with strikethrough
/// - Inserted text: bold green
/// - Equal text: normal style
abstract final class DiffTextSpan {
  /// Build a list of [TextSpan] from diff segments.
  static List<TextSpan> buildSpans(
    List<DiffSpanSegment> segments, {
    TextStyle? baseStyle,
  }) {
    return segments.map((segment) {
      switch (segment.operation) {
        case DiffOp.equal:
          return TextSpan(
            text: segment.text,
            style: baseStyle,
          );
        case DiffOp.delete:
          return TextSpan(
            text: segment.text,
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: AppColors.textTertiary,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.errorRed,
              decorationThickness: 2,
            ),
          );
        case DiffOp.insert:
          return TextSpan(
            text: segment.text,
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: AppColors.successGreen,
              fontWeight: FontWeight.w600,
              backgroundColor: AppColors.successGreenLight.withValues(
                alpha: 0.3,
              ),
            ),
          );
      }
    }).toList();
  }

  /// Build a [RichText] widget from diff segments.
  static Widget buildRichText(
    List<DiffSpanSegment> segments, {
    TextStyle? baseStyle,
    TextAlign textAlign = TextAlign.start,
  }) {
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        children: buildSpans(segments, baseStyle: baseStyle),
      ),
    );
  }
}
