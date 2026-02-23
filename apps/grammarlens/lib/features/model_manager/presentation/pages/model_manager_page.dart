import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';
import 'package:model_repository/model_repository.dart';

import 'package:grammarlens/features/model_manager/presentation/bloc/model_bloc.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_event.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_state.dart';

/// Full-page model management screen.
///
/// Lists all available models from the manifest, shows download status,
/// and allows download/delete/activate actions.
class ModelManagerPage extends StatelessWidget {
  const ModelManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
      ),
      body: BlocBuilder<ModelBloc, ModelState>(
        builder: (context, state) {
          if (state.availableModels.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Group models by language (a model may appear in multiple groups)
          final byLanguage = <String, List<ModelInfo>>{};
          for (final model in state.availableModels) {
            for (final lang in model.languages) {
              byLanguage.putIfAbsent(lang, () => []).add(model);
            }
          }

          final languages = byLanguage.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final langCode = languages[index];
              final models = byLanguage[langCode]!;
              final langName = _languageName(langCode);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      langName,
                      style: AppTypography.headlineSmall,
                    ),
                  ),
                  ...models.map((model) {
                    final isInstalled =
                        state.installedModelIds.contains(model.id);
                    final isActive = state.activeModel?.id == model.id;
                    final isDownloading =
                        state.status == ModelStatus.downloading &&
                            state.downloadingModelId == model.id;

                    ModelTileState tileState;
                    if (isDownloading) {
                      tileState = ModelTileState.downloading;
                    } else if (isInstalled) {
                      tileState = ModelTileState.installed;
                    } else {
                      tileState = ModelTileState.available;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ModelDownloadTile(
                        name: model.displayName,
                        language: langName,
                        size: model.fileSizeFormatted,
                        quantization: model.quantization,
                        state: tileState,
                        progress: state.downloadProgress,
                        isActive: isActive,
                        onDownload: () {
                          context.read<ModelBloc>().add(
                                ModelDownloadRequested(model: model),
                              );
                        },
                        onCancel: isDownloading
                            ? () {
                                context.read<ModelBloc>().add(
                                      const ModelDownloadCancelled(),
                                    );
                              }
                            : null,
                        onSetActive: () {
                          context.read<ModelBloc>().add(
                                ModelLoadRequested(model: model),
                              );
                        },
                        onDelete: () {
                          _confirmDelete(context, model);
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ModelInfo model) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Delete ${model.displayName} (${model.fileSizeFormatted})? '
          'You can re-download it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ModelBloc>().add(
                    ModelDeleteRequested(model: model),
                  );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _languageName(String code) {
    return switch (code) {
      'ar' => 'Arabic',
      'zh' => 'Chinese (Simplified)',
      'zh-Hans' => 'Chinese (Simplified)',
      'zh-Hant' => 'Chinese (Traditional)',
      'zh-TW' => 'Chinese (Traditional)',
      'cs' => 'Czech',
      'nl' => 'Dutch',
      'en' => 'English',
      'fr' => 'French',
      'de' => 'German',
      'el' => 'Greek',
      'he' => 'Hebrew',
      'hi' => 'Hindi',
      'id' => 'Indonesian',
      'it' => 'Italian',
      'ja' => 'Japanese',
      'ko' => 'Korean',
      'fa' => 'Persian',
      'pl' => 'Polish',
      'pt' => 'Portuguese',
      'ro' => 'Romanian',
      'ru' => 'Russian',
      'es' => 'Spanish',
      'tr' => 'Turkish',
      'uk' => 'Ukrainian',
      'vi' => 'Vietnamese',
      _ => code.toUpperCase(),
    };
  }
}
