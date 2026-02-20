import 'package:flutter/material.dart';

import 'package:grammarlens_ui/src/theme/app_colors.dart';

/// Type of grammar correction, used to determine underline color.
enum HighlightType { grammar, spelling, punctuation, style }

/// A widget that renders a wavy underline beneath text to indicate
/// a grammar, spelling, punctuation, or style error.
///
/// Tapping the highlight triggers [onTap] to show the correction card.
class CorrectionHighlight extends StatelessWidget {
  /// The text to highlight.
  final String text;

  /// The type of correction (determines underline color).
  final HighlightType type;

  /// Callback when the highlight is tapped.
  final VoidCallback? onTap;

  /// Optional tooltip text shown on hover/long-press.
  final String? tooltip;

  /// Text style for the highlighted text.
  final TextStyle? textStyle;

  const CorrectionHighlight({
    super.key,
    required this.text,
    required this.type,
    this.onTap,
    this.tooltip,
    this.textStyle,
  });

  /// Get the underline color for this correction type.
  Color get underlineColor {
    switch (type) {
      case HighlightType.grammar:
        return AppColors.errorRed;
      case HighlightType.spelling:
        return AppColors.warningOrange;
      case HighlightType.punctuation:
        return AppColors.punctuationYellow;
      case HighlightType.style:
        return AppColors.styleBlue;
    }
  }

  /// Get the background color for this correction type.
  Color get backgroundColor {
    switch (type) {
      case HighlightType.grammar:
        return AppColors.errorRedLight;
      case HighlightType.spelling:
        return AppColors.warningOrangeLight;
      case HighlightType.punctuation:
        return AppColors.punctuationYellowLight;
      case HighlightType.style:
        return AppColors.styleBlueLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Container(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: underlineColor,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      child: Text(
        text,
        style: textStyle,
      ),
    );

    if (onTap != null) {
      child = GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: child,
        ),
      );
    }

    if (tooltip != null) {
      child = Tooltip(
        message: tooltip!,
        child: child,
      );
    }

    return child;
  }
}
