import 'package:flutter/material.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/editor/presentation/widgets/correction_card.dart';

/// Side panel (or bottom panel on mobile) showing all correction suggestions.
class SuggestionPanel extends StatelessWidget {
  final List<Correction> corrections;
  final ValueChanged<Correction>? onAccept;
  final ValueChanged<Correction>? onDismiss;

  const SuggestionPanel({
    super.key,
    required this.corrections,
    this.onAccept,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (corrections.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: AppColors.successGreen.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No issues found',
                        style: AppTypography.bodyLarge.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start typing to check your text',
                        style: AppTypography.bodySmall.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${corrections.length} suggestion${corrections.length == 1 ? '' : 's'}',
            style: AppTypography.labelLarge,
          ),
        ),

        // Corrections list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: corrections.length,
            itemBuilder: (context, index) {
              final correction = corrections[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: CorrectionCard(
                  correction: correction,
                  onAccept: () => onAccept?.call(correction),
                  onDismiss: () => onDismiss?.call(correction),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
