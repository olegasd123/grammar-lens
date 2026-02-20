import 'package:flutter/material.dart';

import 'package:grammarlens_ui/src/theme/app_colors.dart';
import 'package:grammarlens_ui/src/theme/app_typography.dart';

/// State of a model download tile.
enum ModelTileState {
  /// Model is available for download.
  available,

  /// Model is currently downloading.
  downloading,

  /// Model is downloaded and ready to use.
  installed,
}

/// A list tile showing model info with download/cancel/delete actions.
class ModelDownloadTile extends StatelessWidget {
  /// Model display name.
  final String name;

  /// Language name (e.g., "English").
  final String language;

  /// File size string (e.g., "2.2 GB").
  final String size;

  /// Quantization level (e.g., "Q4_K_M").
  final String quantization;

  /// Current state of the tile.
  final ModelTileState state;

  /// Download progress (0.0 to 1.0). Only used when [state] is downloading.
  final double progress;

  /// Whether this model is the active model for its language.
  final bool isActive;

  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onSetActive;

  const ModelDownloadTile({
    super.key,
    required this.name,
    required this.language,
    required this.size,
    required this.quantization,
    this.state = ModelTileState.available,
    this.progress = 0,
    this.isActive = false,
    this.onDownload,
    this.onCancel,
    this.onDelete,
    this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        '$language  •  $quantization  •  $size',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successGreenLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Active',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.successGreen,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                _buildActionButton(),
              ],
            ),
            if (state == ModelTileState.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.borderLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    switch (state) {
      case ModelTileState.available:
        return IconButton(
          onPressed: onDownload,
          icon: const Icon(Icons.download),
          tooltip: 'Download',
          color: AppColors.primary,
        );
      case ModelTileState.downloading:
        return IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          color: AppColors.errorRed,
        );
      case ModelTileState.installed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isActive)
              IconButton(
                onPressed: onSetActive,
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Set as active',
                color: AppColors.primary,
              ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              color: AppColors.textTertiary,
            ),
          ],
        );
    }
  }
}
