import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:grammarlens/features/editor/presentation/bloc/editor_state.dart';

/// Dedicated page for inspecting raw model output from the latest analysis.
class DebugOutputPage extends StatefulWidget {
  const DebugOutputPage({super.key});

  @override
  State<DebugOutputPage> createState() => _DebugOutputPageState();
}

class _DebugOutputPageState extends State<DebugOutputPage> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Output')),
      body: BlocBuilder<EditorBloc, EditorState>(
        buildWhen: (prev, curr) =>
            prev.rawModelOutput != curr.rawModelOutput ||
            prev.status != curr.status ||
            prev.selectedLanguage != curr.selectedLanguage ||
            prev.detectedLanguage != curr.detectedLanguage,
        builder: (context, state) {
          final raw = state.rawModelOutput ?? '';
          final hasRaw = raw.trim().isNotEmpty;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DebugMetaCard(state: state),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Card(
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: double.infinity,
                          height: constraints.maxHeight,
                          child: hasRaw
                              ? Scrollbar(
                                  controller: _verticalController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _verticalController,
                                    padding: const EdgeInsets.all(16),
                                    child: Scrollbar(
                                      controller: _horizontalController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      notificationPredicate: (notification) =>
                                          notification.depth == 1,
                                      child: SingleChildScrollView(
                                        controller: _horizontalController,
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: constraints.maxWidth - 32,
                                          ),
                                          child: SelectableText(
                                            raw,
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'No raw model output yet.\n\nRun an analysis in the editor first.',
                                    style: AppTypography.bodyMedium,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DebugMetaCard extends StatelessWidget {
  final EditorState state;

  const _DebugMetaCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _MetaChip(label: 'Status', value: state.status.name),
            _MetaChip(
              label: 'Selected',
              value: state.selectedLanguage ?? 'auto',
            ),
            _MetaChip(
              label: 'Detected',
              value: state.detectedLanguage ?? '-',
            ),
            _MetaChip(
              label: 'Corrections',
              value: '${state.activeCorrectionsCount}',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: AppTypography.labelSmall,
      ),
    );
  }
}
