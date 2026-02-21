import 'package:model_repository/model_repository.dart';

/// Base class for model manager events.
sealed class ModelEvent {
  const ModelEvent();
}

/// Check which models are installed and which is active.
class ModelStatusChecked extends ModelEvent {
  const ModelStatusChecked();
}

/// User requested to load a specific model for inference.
class ModelLoadRequested extends ModelEvent {
  final ModelInfo model;
  const ModelLoadRequested({required this.model});
}

/// User requested to unload the current model.
class ModelUnloadRequested extends ModelEvent {
  const ModelUnloadRequested();
}

/// User requested to download a model from the manifest.
class ModelDownloadRequested extends ModelEvent {
  final ModelInfo model;
  const ModelDownloadRequested({required this.model});
}

/// User requested to delete a downloaded model.
class ModelDeleteRequested extends ModelEvent {
  final ModelInfo model;
  const ModelDeleteRequested({required this.model});
}

/// Download progress update (internal).
class ModelDownloadProgressUpdated extends ModelEvent {
  final double progress;
  const ModelDownloadProgressUpdated({required this.progress});
}
