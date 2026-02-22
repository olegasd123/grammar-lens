import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/editor/presentation/widgets/correction_card.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_bloc.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_event.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_state.dart';

/// Compact panel for reviewing and applying corrections to external app text.
///
/// Shown as a dialog/modal when the global hotkey triggers an external check.
/// Displays the source app name, a list of corrections, and action buttons.
class ExternalCheckPanel extends StatelessWidget {
  const ExternalCheckPanel({super.key});

  /// Show the external check panel as a dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ExternalCheckBloc>(),
        child: const Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 80, vertical: 40),
          child: ExternalCheckPanel(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExternalCheckBloc, ExternalCheckState>(
      listenWhen: (prev, curr) =>
          curr.status == ExternalCheckStatus.complete ||
          curr.status == ExternalCheckStatus.initial,
      listener: (context, state) {
        if (state.status == ExternalCheckStatus.complete ||
            state.status == ExternalCheckStatus.initial) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
            maxHeight: 600,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, state),
                const SizedBox(height: 16),
                Flexible(child: _buildBody(context, state)),
                const SizedBox(height: 16),
                _buildActions(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ExternalCheckState state) {
    return Row(
      children: [
        const Icon(Icons.spellcheck, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'External Check',
                style: AppTypography.headlineSmall,
              ),
              if (state.sourceAppName != null)
                Text(
                  'Source: ${state.sourceAppName}',
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context
                .read<ExternalCheckBloc>()
                .add(const ExternalCheckDismissed());
          },
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ExternalCheckState state) {
    switch (state.status) {
      case ExternalCheckStatus.initial:
        return const SizedBox.shrink();

      case ExternalCheckStatus.noPermission:
        return _buildPermissionPrompt(context);

      case ExternalCheckStatus.loading:
        return _buildLoading();

      case ExternalCheckStatus.ready:
        return _buildCorrectionsList(context, state);

      case ExternalCheckStatus.writingBack:
        return _buildWritingBack();

      case ExternalCheckStatus.complete:
        return _buildComplete(state);

      case ExternalCheckStatus.error:
        return _buildError(context, state);
    }
  }

  Widget _buildPermissionPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.accessibility_new,
              size: 48,
              color: AppColors.warningOrange.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Accessibility Permission Required',
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'GrammarLens needs Accessibility access to read and '
              'correct text in other applications.\n\n'
              'Please grant permission in System Settings → '
              'Privacy & Security → Accessibility.',
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                context
                    .read<ExternalCheckBloc>()
                    .add(const ExternalCheckTriggered());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Reading text and analyzing…'),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectionsList(
    BuildContext context,
    ExternalCheckState state,
  ) {
    final active = state.corrections
        .where((c) => !c.isAccepted && !c.isDismissed)
        .toList();

    if (active.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppColors.successGreen.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'All corrections reviewed!',
                style: AppTypography.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${active.length} correction${active.length == 1 ? '' : 's'} found',
          style: AppTypography.labelLarge,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: active.length,
            itemBuilder: (context, index) {
              final correction = active[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: CorrectionCard(
                  correction: correction,
                  onAccept: () {
                    context.read<ExternalCheckBloc>().add(
                          ExternalCorrectionAccepted(
                            correction: correction,
                          ),
                        );
                  },
                  onDismiss: () {
                    context.read<ExternalCheckBloc>().add(
                          ExternalCorrectionDismissed(
                            correction: correction,
                          ),
                        );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWritingBack() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Writing corrected text back…'),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete(ExternalCheckState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 48,
              color: AppColors.successGreen.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'No issues found!',
              style: AppTypography.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, ExternalCheckState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.errorRed.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? 'An unexpected error occurred.',
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ExternalCheckState state) {
    if (state.status != ExternalCheckStatus.ready) {
      return const SizedBox.shrink();
    }

    final hasActive =
        state.corrections.any((c) => !c.isAccepted && !c.isDismissed);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () {
            context
                .read<ExternalCheckBloc>()
                .add(const ExternalCheckDismissed());
          },
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: hasActive
              ? () {
                  context
                      .read<ExternalCheckBloc>()
                      .add(const ExternalCorrectionsDone());
                }
              : null,
          icon: const Icon(Icons.check),
          label: const Text('Apply All'),
        ),
      ],
    );
  }
}
