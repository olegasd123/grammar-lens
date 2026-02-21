import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

import 'package:llama_inference/src/bindings/llama_bindings.dart';
import 'package:llama_inference/src/inference_config.dart';
import 'package:llama_inference/src/inference_result.dart';
import 'package:llama_inference/src/llama_model.dart';

final _log = Logger('LlamaContext');
final _b = LlamaBindings.instance;

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

  /// Native context pointer.
  Pointer<Void>? _nativeContext;

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
    int threads = 0,
    int batchSize = 512,
  }) {
    if (!model.isLoaded) {
      throw LlamaContextException('Cannot create context: model not loaded');
    }

    _log.info('Creating context (size: $contextSize)');

    final context = LlamaContext._(
      model: model,
      contextSize: contextSize,
    );

    final nThreads = threads > 0 ? threads : _autoDetectThreads();
    final ptr = _b.contextCreate(
      model.nativePointer,
      contextSize,
      nThreads,
      batchSize,
    );
    if (ptr == nullptr) {
      throw LlamaContextException('Failed to create native context');
    }
    context._nativeContext = ptr;
    context._isActive = true;
    return context;
  }

  static int _autoDetectThreads() {
    // Use half of available cores, minimum 2
    final cores = Platform.numberOfProcessors;
    return (cores ~/ 2).clamp(2, 8);
  }

  /// Run a completion on the given prompt.
  ///
  /// Returns the complete generated text after all tokens are produced
  /// or a stop condition is met.
  Future<InferenceResult> complete(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) async {
    _assertActive();

    _log.fine('Starting completion (prompt length: ${prompt.length} chars)');

    _b.contextPerfReset(_nativeContext!);

    // 1. Tokenize prompt
    final tokens = _tokenize(prompt, addSpecial: true);
    if (tokens.isEmpty) {
      throw LlamaContextException('Tokenization produced no tokens');
    }
    _log.fine('Prompt tokenized: ${tokens.length} tokens');

    // 2. Decode prompt batch
    final tokenBuf = calloc<Int32>(tokens.length);
    for (var i = 0; i < tokens.length; i++) {
      tokenBuf[i] = tokens[i];
    }
    final decodeResult = _b.decodeBatch(
      _nativeContext!,
      tokenBuf,
      tokens.length,
      0,
    );
    calloc.free(tokenBuf);

    if (decodeResult != 0) {
      throw LlamaContextException('Prompt decode failed (code: $decodeResult)');
    }

    // 3. Create sampler
    final grammarNative = config.grammarGbnf?.toNativeUtf8() ?? nullptr;
    final sampler = _b.samplerCreate(
      model.nativePointer,
      config.temperature,
      config.topP,
      config.topK,
      config.repeatPenalty,
      64, // penalty_last_n
      config.seed == -1 ? 0xFFFFFFFF : config.seed,
      grammarNative,
    );
    if (grammarNative != nullptr) calloc.free(grammarNative);

    if (sampler == nullptr) {
      throw LlamaContextException('Failed to create sampler');
    }

    // 4. Generate tokens
    final output = StringBuffer();
    var pos = tokens.length;

    try {
      for (var i = 0; i < config.maxTokens; i++) {
        final tokenId = _b.samplerSample(sampler, _nativeContext!, -1);

        if (_b.tokenIsEog(model.nativePointer, tokenId)) break;

        _b.samplerAccept(sampler, tokenId);

        final piece = _detokenize(tokenId);
        output.write(piece);

        // Check stop tokens
        if (_matchesStopToken(output.toString(), config.stopTokens)) break;

        // Decode the new token for next iteration
        final rc = _b.decodeSingle(_nativeContext!, tokenId, pos);
        if (rc != 0) {
          throw LlamaContextException('Decode failed at pos $pos (code: $rc)');
        }
        pos++;
      }
    } finally {
      _b.samplerFree(sampler);
    }

    // 5. Collect perf stats
    final perf = _b.contextPerf(_nativeContext!);

    return InferenceResult(
      text: output.toString(),
      promptTokens: perf.nPromptTokens,
      completionTokens: perf.nEvalTokens,
      promptEvalTimeMs: perf.promptEvalTimeMs,
      completionTimeMs: perf.evalTimeMs,
    );
  }

  /// Run a streaming completion on the given prompt.
  ///
  /// Yields tokens as they are generated, enabling progressive UI updates.
  Stream<StreamedToken> completeStream(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) async* {
    _assertActive();

    _log.fine(
      'Starting streaming completion (prompt length: ${prompt.length} chars)',
    );

    _b.contextPerfReset(_nativeContext!);

    // 1. Tokenize prompt
    final tokens = _tokenize(prompt, addSpecial: true);
    if (tokens.isEmpty) {
      throw LlamaContextException('Tokenization produced no tokens');
    }

    // 2. Decode prompt batch
    final tokenBuf = calloc<Int32>(tokens.length);
    for (var i = 0; i < tokens.length; i++) {
      tokenBuf[i] = tokens[i];
    }
    final decodeResult = _b.decodeBatch(
      _nativeContext!,
      tokenBuf,
      tokens.length,
      0,
    );
    calloc.free(tokenBuf);

    if (decodeResult != 0) {
      throw LlamaContextException('Prompt decode failed (code: $decodeResult)');
    }

    // 3. Create sampler
    final grammarNative = config.grammarGbnf?.toNativeUtf8() ?? nullptr;
    final sampler = _b.samplerCreate(
      model.nativePointer,
      config.temperature,
      config.topP,
      config.topK,
      config.repeatPenalty,
      64,
      config.seed == -1 ? 0xFFFFFFFF : config.seed,
      grammarNative,
    );
    if (grammarNative != nullptr) calloc.free(grammarNative);

    if (sampler == nullptr) {
      throw LlamaContextException('Failed to create sampler');
    }

    // 4. Generate and yield tokens
    final accumulated = StringBuffer();
    var pos = tokens.length;

    try {
      for (var i = 0; i < config.maxTokens; i++) {
        final tokenId = _b.samplerSample(sampler, _nativeContext!, -1);
        final isEog = _b.tokenIsEog(model.nativePointer, tokenId);

        if (isEog) {
          yield const StreamedToken(text: '', isLast: true);
          break;
        }

        _b.samplerAccept(sampler, tokenId);
        final piece = _detokenize(tokenId);
        accumulated.write(piece);

        final hitStop = _matchesStopToken(
          accumulated.toString(),
          config.stopTokens,
        );
        final isLast = hitStop || i == config.maxTokens - 1;

        yield StreamedToken(text: piece, isLast: isLast);
        if (isLast) break;

        final rc = _b.decodeSingle(_nativeContext!, tokenId, pos);
        if (rc != 0) {
          throw LlamaContextException('Decode failed at pos $pos (code: $rc)');
        }
        pos++;
      }
    } finally {
      _b.samplerFree(sampler);
    }
  }

  /// Reset the KV-cache, preparing for a new prompt.
  void reset() {
    if (!_isActive || _nativeContext == null) return;

    _log.fine('Resetting context KV-cache');
    _b.contextKvCacheClear(_nativeContext!);
  }

  /// Free native resources.
  void dispose() {
    if (!_isActive) return;

    _log.info('Disposing context');

    if (_nativeContext != null) {
      _b.contextFree(_nativeContext!);
      _nativeContext = null;
    }
    _isActive = false;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  void _assertActive() {
    if (!_isActive || _nativeContext == null) {
      throw LlamaContextException('Context is not active');
    }
  }

  /// Tokenize a string, returning a list of token IDs.
  List<int> _tokenize(String text, {bool addSpecial = true}) {
    final textNative = text.toNativeUtf8();
    final textLen = text.length;

    // First call: get required token count
    final nTokens = _b.tokenize(
      model.nativePointer,
      textNative,
      textLen,
      nullptr,
      0,
      addSpecial,
    );

    // nTokens is negative => required buffer size is -nTokens
    final bufSize = nTokens < 0 ? -nTokens : nTokens;
    if (bufSize == 0) {
      calloc.free(textNative);
      return [];
    }

    final tokenBuf = calloc<Int32>(bufSize);
    final actual = _b.tokenize(
      model.nativePointer,
      textNative,
      textLen,
      tokenBuf,
      bufSize,
      addSpecial,
    );
    calloc.free(textNative);

    final count = actual < 0 ? 0 : actual;
    final result = List<int>.generate(count, (i) => tokenBuf[i]);
    calloc.free(tokenBuf);
    return result;
  }

  /// Detokenize a single token ID to a string.
  String _detokenize(int token) {
    final buf = calloc<Uint8>(128);
    final len = _b.tokenToPiece(model.nativePointer, token, buf.cast<Utf8>(), 128);
    if (len <= 0) {
      calloc.free(buf);
      return '';
    }
    // Read exactly `len` bytes from the buffer
    final result = buf.asTypedList(len);
    final str = String.fromCharCodes(result);
    calloc.free(buf);
    return str;
  }

  /// Check if the accumulated output ends with any stop token.
  static bool _matchesStopToken(String text, List<String> stopTokens) {
    for (final stop in stopTokens) {
      if (text.endsWith(stop)) return true;
    }
    return false;
  }
}

/// Exception thrown by [LlamaContext] operations.
class LlamaContextException implements Exception {
  final String message;
  const LlamaContextException(this.message);

  @override
  String toString() => 'LlamaContextException: $message';
}
