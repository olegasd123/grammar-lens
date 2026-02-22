import 'package:model_repository/model_repository.dart';

/// Status of the model engine.
enum ModelStatus {
  /// Initial state, checking what's installed.
  initial,

  /// No model installed or loaded.
  noModel,

  /// A model is being downloaded.
  downloading,

  /// A downloaded model is being verified (SHA-256 checksum).
  verifying,

  /// A model is being loaded into memory.
  loading,

  /// A model is loaded and ready for inference.
  ready,

  /// An error occurred.
  error,
}

/// State for the model manager.
class ModelState {
  /// Current model lifecycle status.
  final ModelStatus status;

  /// All models available in the manifest.
  final List<ModelInfo> availableModels;

  /// IDs of models that are downloaded locally.
  final Set<String> installedModelIds;

  /// The currently loaded (active) model, if any.
  final ModelInfo? activeModel;

  /// Download progress (0.0 - 1.0) when status is [ModelStatus.downloading].
  final double downloadProgress;

  /// Error message if status is [ModelStatus.error].
  final String? errorMessage;

  const ModelState({
    this.status = ModelStatus.initial,
    this.availableModels = const [],
    this.installedModelIds = const {},
    this.activeModel,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  /// Whether inference is available.
  bool get isReady => status == ModelStatus.ready && activeModel != null;

  ModelState copyWith({
    ModelStatus? status,
    List<ModelInfo>? availableModels,
    Set<String>? installedModelIds,
    ModelInfo? activeModel,
    bool clearActiveModel = false,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return ModelState(
      status: status ?? this.status,
      availableModels: availableModels ?? this.availableModels,
      installedModelIds: installedModelIds ?? this.installedModelIds,
      activeModel: clearActiveModel ? null : (activeModel ?? this.activeModel),
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
