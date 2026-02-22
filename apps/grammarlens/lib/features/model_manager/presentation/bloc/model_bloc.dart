import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import 'package:llama_inference/llama_inference.dart';
import 'package:model_repository/model_repository.dart';

import 'package:grammarlens/features/model_manager/presentation/bloc/model_event.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_state.dart';

final _log = Logger('ModelBloc');

/// Manages model lifecycle: discovery, download, loading, and unloading.
///
/// Exposes the [IsolateInference] engine once a model is ready, so that
/// other features (e.g. EditorBloc) can use it for grammar analysis.
class ModelBloc extends Bloc<ModelEvent, ModelState> {
  final ModelRegistry _registry;
  final ModelStorage _storage;
  final ModelDownloader _downloader;
  final ModelManifestFetcher _manifestFetcher;

  /// The active inference engine. Non-null when [state.isReady].
  IsolateInference? _engine;

  /// Public accessor so EditorBloc can wire up the inference callback.
  IsolateInference? get engine => _engine;

  ModelBloc({
    required ModelRegistry registry,
    required ModelStorage storage,
    required ModelDownloader downloader,
    ModelManifestFetcher? manifestFetcher,
  })  : _registry = registry,
        _storage = storage,
        _downloader = downloader,
        _manifestFetcher = manifestFetcher ?? ModelManifestFetcher(),
        super(const ModelState()) {
    on<ModelStatusChecked>(_onStatusChecked);
    on<ModelLoadRequested>(_onLoadRequested);
    on<ModelUnloadRequested>(_onUnloadRequested);
    on<ModelDownloadRequested>(_onDownloadRequested);
    on<ModelDeleteRequested>(_onDeleteRequested);
    on<ModelDownloadProgressUpdated>(_onProgressUpdated);
  }

  Future<void> _onStatusChecked(
    ModelStatusChecked event,
    Emitter<ModelState> emit,
  ) async {
    _log.info('Checking model status');

    try {
      // Fetch latest manifest (falls back to bundled on network failure)
      final manifest = await _manifestFetcher.fetchManifest();

      // Check which models are installed
      final installedIds = <String>{};
      for (final model in manifest.models) {
        if (await _storage.isModelDownloaded(model.id)) {
          installedIds.add(model.id);
        }
      }

      // Check for an active model (try English first)
      final activeModel = await _registry.getActiveModel('en');

      emit(state.copyWith(
        status: ModelStatus.noModel,
        availableModels: manifest.models,
        installedModelIds: installedIds,
      ));

      // Auto-load if there's an active model
      if (activeModel != null && installedIds.contains(activeModel.id)) {
        add(ModelLoadRequested(model: activeModel));
      }
    } catch (e) {
      _log.severe('Failed to check model status: $e');
      emit(state.copyWith(
        status: ModelStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadRequested(
    ModelLoadRequested event,
    Emitter<ModelState> emit,
  ) async {
    _log.info('Loading model: ${event.model.id}');

    // Unload existing model if any
    if (_engine != null) {
      _engine!.dispose();
      _engine = null;
    }

    emit(state.copyWith(status: ModelStatus.loading));

    try {
      final modelPath = await _storage.getModelPath(event.model.id);

      _engine = IsolateInference();
      await _engine!.initialize(
        modelPath: modelPath,
        contextSize: event.model.contextLength,
      );

      await _registry.setActiveModel(event.model.language, event.model.id);

      emit(state.copyWith(
        status: ModelStatus.ready,
        activeModel: event.model,
      ));

      _log.info('Model loaded successfully: ${event.model.id}');
    } catch (e) {
      _log.severe('Failed to load model: $e');
      _engine?.dispose();
      _engine = null;

      emit(state.copyWith(
        status: ModelStatus.error,
        errorMessage: 'Failed to load model: $e',
      ));
    }
  }

  Future<void> _onUnloadRequested(
    ModelUnloadRequested event,
    Emitter<ModelState> emit,
  ) async {
    _log.info('Unloading model');

    _engine?.dispose();
    _engine = null;

    emit(state.copyWith(
      status: ModelStatus.noModel,
      clearActiveModel: true,
    ));
  }

  Future<void> _onDownloadRequested(
    ModelDownloadRequested event,
    Emitter<ModelState> emit,
  ) async {
    _log.info('Downloading model: ${event.model.id}');

    emit(state.copyWith(
      status: ModelStatus.downloading,
      downloadProgress: 0,
    ));

    try {
      final destPath = await _storage.getModelPath(event.model.id);

      await _downloader.download(
        event.model,
        destPath,
        onProgress: (progress) {
          add(ModelDownloadProgressUpdated(progress: progress));
        },
      );

      // Verify integrity (skip for placeholder hashes during development)
      if (!event.model.sha256.startsWith('placeholder')) {
        emit(state.copyWith(status: ModelStatus.verifying));
        _log.info('Verifying checksum for ${event.model.id}');

        final valid = await ModelIntegrity.verifyChecksum(
          destPath,
          event.model.sha256,
        );

        if (!valid) {
          _log.severe('Checksum mismatch for ${event.model.id}');
          await _storage.deleteModel(event.model.id);
          emit(state.copyWith(
            status: ModelStatus.error,
            errorMessage:
                'Integrity check failed for ${event.model.displayName}. '
                'The file may be corrupted. Please try again.',
          ));
          return;
        }
      } else {
        _log.warning(
          'Skipping checksum verification (placeholder hash) '
          'for ${event.model.id}',
        );
      }

      // Register the model
      await _registry.registerModel(event.model);

      final updatedInstalled = {...state.installedModelIds, event.model.id};

      emit(state.copyWith(
        status: ModelStatus.noModel,
        installedModelIds: updatedInstalled,
        downloadProgress: 1.0,
      ));

      _log.info('Download complete: ${event.model.id}');

      // Auto-load the downloaded model
      add(ModelLoadRequested(model: event.model));
    } catch (e) {
      _log.severe('Download failed: $e');
      emit(state.copyWith(
        status: ModelStatus.error,
        errorMessage: 'Download failed: $e',
      ));
    }
  }

  Future<void> _onDeleteRequested(
    ModelDeleteRequested event,
    Emitter<ModelState> emit,
  ) async {
    _log.info('Deleting model: ${event.model.id}');

    // Unload if this is the active model
    if (state.activeModel?.id == event.model.id) {
      _engine?.dispose();
      _engine = null;
    }

    await _storage.deleteModel(event.model.id);
    await _registry.unregisterModel(event.model.id);

    final updatedInstalled = {...state.installedModelIds}
      ..remove(event.model.id);

    emit(state.copyWith(
      status: state.activeModel?.id == event.model.id
          ? ModelStatus.noModel
          : state.status,
      installedModelIds: updatedInstalled,
      clearActiveModel: state.activeModel?.id == event.model.id,
    ));
  }

  void _onProgressUpdated(
    ModelDownloadProgressUpdated event,
    Emitter<ModelState> emit,
  ) {
    emit(state.copyWith(downloadProgress: event.progress));
  }

  @override
  Future<void> close() {
    _engine?.dispose();
    _manifestFetcher.dispose();
    return super.close();
  }
}
