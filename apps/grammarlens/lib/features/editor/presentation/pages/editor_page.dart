import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammar_engine/grammar_engine.dart';
import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_event.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_state.dart';
import 'package:grammarlens/features/editor/presentation/widgets/highlighting_text_controller.dart';
import 'package:grammarlens/features/editor/presentation/widgets/suggestion_panel.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_bloc.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_state.dart';
import 'package:grammarlens/features/external_check/presentation/pages/external_check_panel.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_bloc.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_state.dart';
import 'package:grammarlens/features/model_manager/presentation/pages/model_manager_page.dart';
import 'package:grammarlens/features/model_manager/presentation/widgets/model_status_bar.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:grammarlens/features/settings/presentation/pages/settings_page.dart';
import 'package:grammarlens/features/statistics/presentation/pages/statistics_page.dart';

/// Main editor page — the core GrammarLens experience.
///
/// Layout:
/// - Top: Model status bar (when no model loaded)
/// - Top: Toolbar with language selector, stats, and status
/// - Center: Text editor
/// - Right/Bottom: Suggestion panel with corrections
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final HighlightingTextController _textController;
  EditorBloc? _editorBloc;

  @override
  void initState() {
    super.initState();
    _textController = HighlightingTextController();
    // Create initial EditorBloc without analyzer (no model yet)
    _editorBloc = EditorBloc();
  }

  @override
  void dispose() {
    _textController.dispose();
    _editorBloc?.close();
    super.dispose();
  }

  /// Rebuild the EditorBloc with a working GrammarAnalyzer once the model
  /// is ready. Preserves the current text.
  void _onModelReady(ModelBloc modelBloc) {
    final engine = modelBloc.engine;
    if (engine == null) return;

    final currentText = _editorBloc?.state.text ?? '';
    final currentLanguage = _editorBloc?.state.selectedLanguage;

    _editorBloc?.close();

    final analyzer = GrammarAnalyzer(
      onInfer: (prompt) async {
        final result = await engine.complete(prompt);
        return result.text;
      },
    );

    _editorBloc = EditorBloc(analyzer: analyzer);

    // Restore text and trigger re-analysis
    if (currentText.isNotEmpty) {
      _editorBloc!.add(TextChanged(text: currentText));
      if (currentLanguage != null) {
        _editorBloc!.add(LanguageChanged(languageCode: currentLanguage));
      }
    }

    setState(() {});
  }

  /// When model is unloaded, recreate bloc without analyzer.
  void _onModelUnloaded() {
    final currentText = _editorBloc?.state.text ?? '';
    _editorBloc?.close();
    _editorBloc = EditorBloc();

    if (currentText.isNotEmpty) {
      _editorBloc!.add(TextChanged(text: currentText));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ModelBloc, ModelState>(
          listenWhen: (prev, curr) => prev.status != curr.status,
          listener: (context, modelState) {
            if (modelState.status == ModelStatus.ready) {
              _onModelReady(context.read<ModelBloc>());
            } else if (modelState.status == ModelStatus.noModel ||
                modelState.status == ModelStatus.error) {
              if (_editorBloc?.state.status == AnalysisStatus.analyzing) {
                _onModelUnloaded();
              }
            }
          },
        ),
        if (Platform.isMacOS)
          BlocListener<ExternalCheckBloc, ExternalCheckState>(
            listenWhen: (prev, curr) =>
                curr.status == ExternalCheckStatus.loading ||
                curr.status == ExternalCheckStatus.ready ||
                curr.status == ExternalCheckStatus.noPermission ||
                curr.status == ExternalCheckStatus.error,
            listener: (context, state) {
              if (state.status != ExternalCheckStatus.initial) {
                ExternalCheckPanel.show(context);
              }
            },
          ),
      ],
      child: BlocProvider.value(
        value: _editorBloc!,
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
                      _editorBloc!.add(LanguageChanged(
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
              const SizedBox(width: 8),

              // Statistics button
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: _editorBloc!,
                        child: const StatisticsPage(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: 'Statistics',
              ),

              // Model manager button
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ModelBloc>(),
                        child: const ModelManagerPage(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.memory),
                tooltip: 'Models',
              ),

              // Settings button
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: context.read<SettingsBloc>(),
                        child: const SettingsPage(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Model status bar (shown when model not ready)
              const ModelStatusBar(),

              // Main content
              Expanded(
                child: LayoutBuilder(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorSection() {
    return BlocListener<EditorBloc, EditorState>(
      listenWhen: (prev, curr) => prev.corrections != curr.corrections,
      listener: (context, state) {
        final active = state.corrections
            .where((c) => !c.isAccepted && !c.isDismissed)
            .toList();
        _textController.updateCorrections(active);
      },
      child: Column(
        children: [
          // Stats bar
          BlocBuilder<EditorBloc, EditorState>(
            buildWhen: (prev, curr) => prev.statistics != curr.statistics,
            builder: (context, state) {
              final stats = state.statistics;
              if (stats == null) return const SizedBox(height: 40);

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      value:
                          '${stats.readingTimeMinutes.toStringAsFixed(1)} min',
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
                            _editorBloc!.add(const AcceptAllCorrections());
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
                  hintText: 'Start typing or paste your text here...\n\n'
                      'GrammarLens will check for grammar, spelling, '
                      'punctuation, and style issues.',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (text) {
                  _editorBloc!.add(TextChanged(text: text));
                },
              ),
            ),
          ),
        ],
      ),
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
            _editorBloc!.add(CorrectionAccepted(correction: correction));
            // Update text controller
            _textController.text = _editorBloc!.state.text;
          },
          onDismiss: (correction) {
            _editorBloc!.add(CorrectionDismissed(correction: correction));
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
        return const Icon(Icons.check_circle,
            color: AppColors.successGreen, size: 20);
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
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: AppTypography.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: AppTypography.labelSmall),
      ],
    );
  }
}
