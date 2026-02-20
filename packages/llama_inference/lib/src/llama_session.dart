import 'package:logging/logging.dart';

import 'package:llama_inference/src/gpu_backend.dart';
import 'package:llama_inference/src/inference_config.dart';
import 'package:llama_inference/src/inference_result.dart';
import 'package:llama_inference/src/llama_context.dart';
import 'package:llama_inference/src/llama_model.dart';

final _log = Logger('LlamaSession');

/// High-level session that manages model + context lifecycle.
///
/// This is the main entry point for consumers. It loads a model,
/// creates a context, and provides a simple API for completions.
///
/// Usage:
/// ```dart
/// final session = await LlamaSession.create(
///   modelPath: '/path/to/grammar-model.gguf',
/// );
///
/// final result = await session.complete('Check this text...');
/// print(result.text);
///
/// session.dispose();
/// ```
class LlamaSession {
  /// The loaded model.
  final LlamaModel model;

  /// The active inference context.
  final LlamaContext context;

  /// Whether this session is ready for inference.
  bool get isReady => model.isLoaded && context.isActive;

  LlamaSession._({
    required this.model,
    required this.context,
  });

  /// Create a new session by loading a model and creating a context.
  ///
  /// [modelPath] - Path to the .gguf model file.
  /// [contextSize] - KV-cache size. 2048 is sufficient for grammar correction.
  /// [gpuLayers] - Number of layers to offload to GPU. 99 = all layers.
  /// [gpuBackend] - Explicit GPU backend. Null = auto-detect.
  static Future<LlamaSession> create({
    required String modelPath,
    int contextSize = 2048,
    int gpuLayers = 99,
    GpuBackend? gpuBackend,
  }) async {
    _log.info('Creating session for model: $modelPath');

    final model = await LlamaModel.load(
      modelPath,
      gpuLayers: gpuLayers,
      gpuBackend: gpuBackend,
    );

    final context = LlamaContext.create(model, contextSize: contextSize);

    return LlamaSession._(model: model, context: context);
  }

  /// Run a completion and return the full result.
  Future<InferenceResult> complete(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) async {
    _assertReady();
    context.reset();
    return context.complete(prompt, config: config);
  }

  /// Run a streaming completion, yielding tokens as they are generated.
  Stream<StreamedToken> completeStream(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) {
    _assertReady();
    context.reset();
    return context.completeStream(prompt, config: config);
  }

  /// Release all native resources.
  void dispose() {
    _log.info('Disposing session');
    context.dispose();
    model.dispose();
  }

  void _assertReady() {
    if (!isReady) {
      throw StateError(
        'LlamaSession is not ready. '
        'Model loaded: ${model.isLoaded}, Context active: ${context.isActive}',
      );
    }
  }
}
