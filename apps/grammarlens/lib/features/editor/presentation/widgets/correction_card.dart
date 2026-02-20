import 'package:flutter/material.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:grammarlens_ui/grammarlens_ui.dart';

/// A card displaying a single correction with accept/dismiss actions.
class CorrectionCard extends StatelessWidget {
  final Correction correction;
  final VoidCallback? onAccept;
  final VoidCallback? onDismiss;

  const CorrectionCard({
    super.key,
    required this.correction,
    this.onAccept,
    this.onDismiss,
  });

  Color get _typeColor {
    switch (correction.type) {
      case CorrectionType.grammar:
        return AppColors.errorRed;
      case CorrectionType.spelling:
        return AppColors.warningOrange;
      case CorrectionType.punctuation:
        return AppColors.punctuationYellow;
      case CorrectionType.style:
        return AppColors.styleBlue;
    }
  }

  String get _typeLabel {
    switch (correction.type) {
      case CorrectionType.grammar:
        return 'Grammar';
      case CorrectionType.spelling:
        return 'Spelling';
      case CorrectionType.punctuation:
        return 'Punctuation';
      case CorrectionType.style:
        return 'Style';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _typeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _typeLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: _typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),

            // Original → Corrected
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: correction.originalText,
                    style: AppTypography.correctionText.copyWith(
                      color: AppColors.textTertiary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const TextSpan(text: '  →  '),
                  TextSpan(
                    text: correction.correctedText,
                    style: AppTypography.correctionText.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Explanation
            if (correction.explanation.isNotEmpty) ...[
              Text(
                correction.explanation,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
