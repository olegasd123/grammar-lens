import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_state.dart';
import 'package:grammarlens_ui/grammarlens_ui.dart';

/// Full-page statistics dashboard.
///
/// Shows detailed text metrics, readability scores, and correction
/// summary from the current editor text.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: BlocBuilder<EditorBloc, EditorState>(
        builder: (context, state) {
          final stats = state.statistics;
          if (stats == null || state.text.trim().isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No text to analyze',
                    style: AppTypography.bodyLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type something in the editor to see statistics.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final language = SupportedLanguage.fromCode(state.effectiveLanguage);
          final readability = ReadabilityScorer.score(state.text, language);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Counts section
              const _SectionHeader(title: 'Counts'),
              const SizedBox(height: 8),
              _MetricGrid(
                children: [
                  _MetricCard(
                    label: 'Words',
                    value: '${stats.wordCount}',
                    icon: Icons.text_fields,
                  ),
                  _MetricCard(
                    label: 'Characters',
                    value: '${stats.characterCount}',
                    icon: Icons.abc,
                  ),
                  _MetricCard(
                    label: 'Sentences',
                    value: '${stats.sentenceCount}',
                    icon: Icons.short_text,
                  ),
                  _MetricCard(
                    label: 'Paragraphs',
                    value: '${stats.paragraphCount}',
                    icon: Icons.view_headline,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Time estimates
              const _SectionHeader(title: 'Time Estimates'),
              const SizedBox(height: 8),
              _MetricGrid(
                children: [
                  _MetricCard(
                    label: 'Reading Time',
                    value: _formatTime(stats.readingTimeMinutes),
                    icon: Icons.menu_book,
                  ),
                  _MetricCard(
                    label: 'Speaking Time',
                    value: _formatTime(stats.speakingTimeMinutes),
                    icon: Icons.record_voice_over,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Readability
              const _SectionHeader(title: 'Readability'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ReadabilityGauge(
                              label: 'Reading Ease',
                              value: readability.fleschReadingEase ?? 0,
                              maxValue: 100,
                              description: readability.readabilityLabel,
                            ),
                          ),
                          if (readability.fleschKincaidGrade != null) ...[
                            const SizedBox(width: 24),
                            Expanded(
                              child: _ReadabilityGauge(
                                label: 'Grade Level',
                                value: readability.fleschKincaidGrade!,
                                maxValue: 20,
                                description:
                                    'Grade ${readability.fleschKincaidGrade!.toStringAsFixed(1)}',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      _StatRow(
                        label: 'Avg words per sentence',
                        value: stats.avgWordsPerSentence.toStringAsFixed(1),
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        label: 'Avg word length',
                        value:
                            '${stats.avgWordLength.toStringAsFixed(1)} chars',
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        label: 'Vocabulary richness',
                        value:
                            '${(stats.vocabularyRichness * 100).toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Corrections summary
              const _SectionHeader(title: 'Corrections'),
              const SizedBox(height: 8),
              _CorrectionsSummary(corrections: state.corrections),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(double minutes) {
    if (minutes < 1) {
      return '${(minutes * 60).toStringAsFixed(0)} sec';
    }
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(1)} min';
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).toStringAsFixed(0);
    return '$hours h $mins min';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.headlineSmall);
  }
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> children;
  const _MetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children.map((c) => SizedBox(width: 160, child: c)).toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(value, style: AppTypography.headlineMedium),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadabilityGauge extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final String description;

  const _ReadabilityGauge({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (value / maxValue).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(_gaugeColor(fraction)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: AppTypography.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _gaugeColor(double fraction) {
    if (fraction >= 0.7) return AppColors.successGreen;
    if (fraction >= 0.4) return AppColors.warningOrange;
    return AppColors.errorRed;
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: AppTypography.labelMedium),
      ],
    );
  }
}

class _CorrectionsSummary extends StatelessWidget {
  final List<Correction> corrections;
  const _CorrectionsSummary({required this.corrections});

  @override
  Widget build(BuildContext context) {
    final active =
        corrections.where((c) => !c.isAccepted && !c.isDismissed).toList();
    final accepted = corrections.where((c) => c.isAccepted).length;
    final dismissed = corrections.where((c) => c.isDismissed).length;

    final byType = <CorrectionType, int>{};
    for (final c in active) {
      byType[c.type] = (byType[c.type] ?? 0) + 1;
    }

    if (corrections.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.successGreen),
              const SizedBox(width: 12),
              Text(
                'No issues found',
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(
              label: 'Active issues',
              value: '${active.length}',
            ),
            const SizedBox(height: 8),
            _StatRow(label: 'Accepted', value: '$accepted'),
            const SizedBox(height: 8),
            _StatRow(label: 'Dismissed', value: '$dismissed'),
            if (byType.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              ...byType.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _StatRow(
                      label: _typeLabel(e.key),
                      value: '${e.value}',
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(CorrectionType type) {
    return switch (type) {
      CorrectionType.grammar => 'Grammar',
      CorrectionType.spelling => 'Spelling',
      CorrectionType.punctuation => 'Punctuation',
      CorrectionType.style => 'Style',
    };
  }
}
