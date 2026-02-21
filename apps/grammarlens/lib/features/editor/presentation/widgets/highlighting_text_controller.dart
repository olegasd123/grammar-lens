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
      // Clamp offsets to text length to avoid range errors.
      final start = correction.startOffset.clamp(0, fullText.length);
      final end = correction.endOffset.clamp(start, fullText.length);

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
          backgroundColor:
              AppColors.warningOrangeLight.withValues(alpha: 0.25),
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
