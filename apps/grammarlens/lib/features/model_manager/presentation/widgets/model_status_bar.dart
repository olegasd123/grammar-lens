import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/model_manager/presentation/bloc/model_bloc.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_event.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_state.dart';

/// Banner shown at the top of the editor when no model is loaded.
///
/// Shows download/loading progress and a CTA to get started.
class ModelStatusBar extends StatelessWidget {
  const ModelStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelBloc, ModelState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.downloadProgress != curr.downloadProgress,
      builder: (context, state) {
        return switch (state.status) {
          ModelStatus.initial => const SizedBox.shrink(),
          ModelStatus.ready => const SizedBox.shrink(),
          ModelStatus.noModel => _NoModelBanner(state: state),
          ModelStatus.downloading => _DownloadingBanner(state: state),
          ModelStatus.loading => const _LoadingBanner(),
          ModelStatus.error => _ErrorBanner(message: state.errorMessage),
        };
      },
    );
  }
}

class _NoModelBanner extends StatelessWidget {
  final ModelState state;
  const _NoModelBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    // Find the recommended model (English Q4_K_M)
    final recommended = state.availableModels.where(
      (m) => m.language == 'en' && m.quantization == 'Q4_K_M',
    );

    // Check if any model is already installed
    final installedModels = state.availableModels.where(
      (m) => state.installedModelIds.contains(m.id),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.styleBlue.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.download_rounded, size: 20, color: AppColors.styleBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              installedModels.isNotEmpty
                  ? 'A model is available. Load it to start checking grammar.'
                  : 'Download a grammar model to get started.',
              style: AppTypography.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          if (installedModels.isNotEmpty)
            FilledButton.tonal(
              onPressed: () {
                context.read<ModelBloc>().add(
                      ModelLoadRequested(model: installedModels.first),
                    );
              },
              child: const Text('Load Model'),
            )
          else if (recommended.isNotEmpty)
            FilledButton.tonal(
              onPressed: () {
                context.read<ModelBloc>().add(
                      ModelDownloadRequested(model: recommended.first),
                    );
              },
              child: Text(
                'Download (${recommended.first.fileSizeFormatted})',
              ),
            ),
        ],
      ),
    );
  }
}

class _DownloadingBanner extends StatelessWidget {
  final ModelState state;
  const _DownloadingBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final percent = (state.downloadProgress * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.warningOrange.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Downloading model... $percent%',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.downloadProgress,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.styleBlue.withValues(alpha: 0.08),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading model into memory...'),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String? message;
  const _ErrorBanner({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.errorRed.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.errorRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? 'An error occurred with the model.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.errorRed,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              context.read<ModelBloc>().add(const ModelStatusChecked());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
