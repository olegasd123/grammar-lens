import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_event.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_state.dart';
import 'package:grammarlens/features/editor/presentation/widgets/correction_card.dart';
import 'package:grammarlens/features/editor/presentation/widgets/suggestion_panel.dart';

/// Main editor page — the core GrammarLens experience.
///
/// Layout:
/// - Top: Toolbar with language selector, stats, and status
/// - Center: Text editor
/// - Right/Bottom: Suggestion panel with corrections
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController _textController;
  late final EditorBloc _editorBloc;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editorBloc = EditorBloc();
  }

  @override
  void dispose() {
    _textController.dispose();
    _editorBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _editorBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('GrammarLens'),
          actions: [
            // Language selector
            BlocBuilder<EditorBloc, EditorState>(
              buildWhen: (prev, curr) =>
                  prev.effectiveLanguage != curr.effectiveLanguage,
              builder: (context, state) {
                return LanguageSelector(
                  selectedCode: state.selectedLanguage ?? 'auto',
                  onChanged: (code) {
                    _editorBloc.add(LanguageChanged(
                      languageCode: code == 'auto' ? 'en' : code,
                    ));
                  },
                );
              },
            ),
            const SizedBox(width: 8),

            // Analysis status indicator
            BlocBuilder<EditorBloc, EditorState>(
              buildWhen: (prev, curr) => prev.status != curr.status,
              builder: (context, state) {
                return _StatusIndicator(status: state.status);
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            if (isWide) {
              // Desktop layout: editor on left, suggestions on right
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildEditorSection(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 1,
                    child: _buildSuggestionSection(),
                  ),
                ],
              );
            } else {
              // Mobile layout: editor on top, suggestions below
              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildEditorSection(),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    flex: 1,
                    child: _buildSuggestionSection(),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEditorSection() {
    return Column(
      children: [
        // Stats bar
        BlocBuilder<EditorBloc, EditorState>(
          buildWhen: (prev, curr) => prev.statistics != curr.statistics,
          builder: (context, state) {
            final stats = state.statistics;
            if (stats == null) return const SizedBox(height: 40);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  _StatChip(
                    label: 'Words',
                    value: '${stats.wordCount}',
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    label: 'Sentences',
                    value: '${stats.sentenceCount}',
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    label: 'Reading',
                    value: '${stats.readingTimeMinutes.toStringAsFixed(1)} min',
                  ),
                  const Spacer(),
                  BlocBuilder<EditorBloc, EditorState>(
                    buildWhen: (prev, curr) =>
                        prev.activeCorrectionsCount !=
                        curr.activeCorrectionsCount,
                    builder: (context, state) {
                      if (state.activeCorrectionsCount == 0) {
                        return const SizedBox.shrink();
                      }
                      return TextButton.icon(
                        onPressed: () {
                          _editorBloc.add(const AcceptAllCorrections());
                        },
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(
                          'Fix all (${state.activeCorrectionsCount})',
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),

        // Text editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTypography.editorText,
              decoration: const InputDecoration(
                hintText:
                    'Start typing or paste your text here...\n\n'
                    'GrammarLens will check for grammar, spelling, '
                    'punctuation, and style issues.',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (text) {
                _editorBloc.add(TextChanged(text: text));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionSection() {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        return SuggestionPanel(
          corrections: state.corrections
              .where((c) => !c.isAccepted && !c.isDismissed)
              .toList(),
          onAccept: (correction) {
            _editorBloc.add(CorrectionAccepted(correction: correction));
            // Update text controller
            _textController.text = _editorBloc.state.text;
          },
          onDismiss: (correction) {
            _editorBloc.add(CorrectionDismissed(correction: correction));
          },
        );
      },
    );
  }
}

/// Small status indicator in the app bar.
class _StatusIndicator extends StatelessWidget {
  final AnalysisStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AnalysisStatus.idle:
        return const SizedBox.shrink();
      case AnalysisStatus.analyzing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case AnalysisStatus.complete:
        return const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20);
      case AnalysisStatus.error:
        return const Icon(Icons.error, color: AppColors.errorRed, size: 20);
    }
  }
}

/// Small stat chip widget.
class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Text(value, style: AppTypography.labelSmall),
      ],
    );
  }
}
