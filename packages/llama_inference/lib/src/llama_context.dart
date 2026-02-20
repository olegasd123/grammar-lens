import 'package:logging/logging.dart';

import 'package:llama_inference/src/inference_config.dart';
import 'package:llama_inference/src/inference_result.dart';
import 'package:llama_inference/src/llama_model.dart';

final _log = Logger('LlamaContext');

/// An inference context bound to a [LlamaModel].
///
/// Manages the KV-cache, token buffer, and sampling state for a single
/// inference session. Create one context per concurrent inference.
///
/// Usage:
/// ```dart
/// final context = LlamaContext.create(model, contextSize: 4096);
/// final result = await context.complete('Hello, world!', config);
/// context.dispose();
/// ```
class LlamaContext {
  /// The model this context is bound to.
  final LlamaModel model;

  /// Context size (max tokens in KV-cache).
  final int contextSize;

  /// Whether this context is active and usable.
  bool get isActive => _isActive;
  bool _isActive = false;

  LlamaContext._({
    required this.model,
    required this.contextSize,
  });

  /// Create a new inference context for the given model.
  ///
  /// [contextSize] sets the KV-cache size. Larger values allow longer
  /// prompts + completions but use more memory. For grammar correction
  /// with 3-sentence batches, 2048 is sufficient.
  static LlamaContext create(
    LlamaModel model, {
    int contextSize = 2048,
  }) {
    if (!model.isLoaded) {
      throw LlamaContextException('Cannot create context: model not loaded');
    }

    _log.info('Creating context (size: $contextSize)');

    final context = LlamaContext._(
      model: model,
      contextSize: contextSize,
    );

    // TODO: Actual native context creation via FFI:
    // 1. llama_context_default_params() -> set n_ctx
    // 2. llama_new_context_with_model(model.nativePointer, params)
    // 3. Store native context pointer

    context._isActive = true;
    return context;
  }

  /// Run a completion on the given prompt.
  ///
  /// Returns the complete generated text after all tokens are produced
  /// or a stop condition is met.
  Future<InferenceResult> complete(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) async {
    if (!_isActive) {
      throw LlamaContextException('Context is not active');
    }

    final stopwatch = Stopwatch()..start();

    _log.fine('Starting completion (prompt length: ${prompt.length} chars)');

    // TODO: Actual inference via FFI:
    // 1. Tokenize prompt with llama_tokenize()
    // 2. Evaluate prompt tokens with llama_decode()
    // 3. Sample loop:
    //    a. llama_sampling_sample() to get next token
    //    b. Check for stop tokens / EOS / max_tokens
    //    c. llama_decode() for next token
    //    d. Detokenize and accumulate text
    // 4. Return InferenceResult with timing stats

    stopwatch.stop();

    // Placeholder result
    return InferenceResult(
      text: '<corrections></corrections>',
      promptTokens: prompt.length ~/ 4, // Rough estimate
      completionTokens: 0,
      promptEvalTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
      completionTimeMs: 0,
    );
  }

  /// Run a streaming completion on the given prompt.
  ///
  /// Yields tokens as they are generated, enabling progressive UI updates.
  Stream<StreamedToken> completeStream(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) async* {
    if (!_isActive) {
      throw LlamaContextException('Context is not active');
    }

    _log.fine(
      'Starting streaming completion (prompt length: ${prompt.length} chars)',
    );

    // TODO: Actual streaming inference via FFI:
    // Same as complete() but yield each token as StreamedToken
    // The caller can use CorrectionParser to process partial XML

    yield const StreamedToken(
      text: '<corrections></corrections>',
      isLast: true,
    );
  }

  /// Reset the KV-cache, preparing for a new prompt.
  void reset() {
    if (!_isActive) return;

    _log.fine('Resetting context KV-cache');

    // TODO: llama_kv_cache_clear(nativeContext)
  }

  /// Free native resources.
  void dispose() {
    if (!_isActive) return;

    _log.info('Disposing context');

    // TODO: llama_free(nativeContext)
    _isActive = false;
  }
}

/// Exception thrown by [LlamaContext] operations.
class LlamaContextException implements Exception {
  final String message;
  const LlamaContextException(this.message);

  @override
  String toString() => 'LlamaContextException: $message';
}
