import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:llama_inference/src/bindings/llama_bindings.dart';
import 'package:llama_inference/src/inference_config.dart';
import 'package:llama_inference/src/inference_result.dart';
import 'package:llama_inference/src/llama_model.dart';
import 'package:logging/logging.dart';

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
      throw const LlamaContextException(
        'Cannot create context: model not loaded',
      );
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
      throw const LlamaContextException('Failed to create native context');
    }
    context
      .._nativeContext = ptr
      .._isActive = true;
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
      throw const LlamaContextException('Tokenization produced no tokens');
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
      throw const LlamaContextException('Failed to create sampler');
    }

    // 4. Generate tokens
    final output = StringBuffer();
    final utf8Decoder = _Utf8ChunkDecoder();
    var stoppedByStopToken = false;
    var pos = tokens.length;

    try {
      for (var i = 0; i < config.maxTokens; i++) {
        final tokenId = _b.samplerSample(sampler, _nativeContext!, -1);

        if (_b.tokenIsEog(model.nativePointer, tokenId)) break;

        _b.samplerAccept(sampler, tokenId);

        final pieceBytes = _detokenizeBytes(tokenId);
        final piece = utf8Decoder.add(pieceBytes);
        output.write(piece);

        // Stop at the first stop token occurrence, even if the model
        // continues with extra text in the same token piece.
        final trimmed = _trimAtStopToken(output.toString(), config.stopTokens);
        if (trimmed != null) {
          output
            ..clear()
            ..write(trimmed);
          stoppedByStopToken = true;
          break;
        }

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

    final tail = utf8Decoder.close();
    if (!stoppedByStopToken && tail.isNotEmpty) {
      output.write(tail);
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
      throw const LlamaContextException('Tokenization produced no tokens');
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
      throw const LlamaContextException('Failed to create sampler');
    }

    // 4. Generate and yield tokens
    final accumulated = StringBuffer();
    final utf8Decoder = _Utf8ChunkDecoder();
    var pos = tokens.length;

    try {
      for (var i = 0; i < config.maxTokens; i++) {
        final tokenId = _b.samplerSample(sampler, _nativeContext!, -1);
        final isEog = _b.tokenIsEog(model.nativePointer, tokenId);

        if (isEog) {
          final tail = utf8Decoder.close();
          yield StreamedToken(text: tail, isLast: true);
          break;
        }

        _b.samplerAccept(sampler, tokenId);
        final pieceBytes = _detokenizeBytes(tokenId);
        final piece = utf8Decoder.add(pieceBytes);
        final beforeLen = accumulated.length;
        accumulated.write(piece);
        var current = accumulated.toString();

        var hitStop = false;
        final trimmed = _trimAtStopToken(current, config.stopTokens);
        if (trimmed != null) {
          hitStop = true;
          accumulated
            ..clear()
            ..write(trimmed);
          current = trimmed;
        }

        var isLast = hitStop || i == config.maxTokens - 1;
        if (isLast && !hitStop) {
          final tail = utf8Decoder.close();
          if (tail.isNotEmpty) {
            accumulated.write(tail);
            current = accumulated.toString();
            final trimmedTail = _trimAtStopToken(current, config.stopTokens);
            if (trimmedTail != null) {
              hitStop = true;
              accumulated
                ..clear()
                ..write(trimmedTail);
              current = trimmedTail;
            }
          }
          isLast = true;
        }

        final emitStart =
            beforeLen <= current.length ? beforeLen : current.length;
        final emitText = current.substring(emitStart);

        if (emitText.isNotEmpty || isLast) {
          yield StreamedToken(text: emitText, isLast: isLast);
        }

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
      throw const LlamaContextException('Context is not active');
    }
  }

  /// Tokenize a string, returning a list of token IDs.
  List<int> _tokenize(String text, {bool addSpecial = true}) {
    final textNative = text.toNativeUtf8();
    final textLen = utf8.encode(text).length;

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

  /// Detokenize a single token ID to UTF-8 bytes.
  Uint8List _detokenizeBytes(int token) {
    var bufferSize = 128;
    while (true) {
      final buf = calloc<Uint8>(bufferSize);
      final len = _b.tokenToPiece(
        model.nativePointer,
        token,
        buf.cast<Utf8>(),
        bufferSize,
      );
      if (len == 0) {
        calloc.free(buf);
        return Uint8List(0);
      }

      // Some backends return required size when buffer is too small.
      if (len >= bufferSize || len < 0) {
        final requiredSize = len < 0 ? -len : len + 1;
        calloc.free(buf);
        bufferSize = requiredSize > bufferSize ? requiredSize : bufferSize * 2;
        continue;
      }

      final bytes = Uint8List.fromList(buf.asTypedList(len));
      calloc.free(buf);
      return bytes;
    }
  }

  /// Returns the text trimmed at the first stop token (inclusive), or null.
  static String? _trimAtStopToken(String text, List<String> stopTokens) {
    var earliestIndex = -1;
    var matchedStop = '';
    for (final stop in stopTokens) {
      final index = text.indexOf(stop);
      if (index < 0) continue;
      if (earliestIndex == -1 || index < earliestIndex) {
        earliestIndex = index;
        matchedStop = stop;
      }
    }
    if (earliestIndex == -1) return null;
    return text.substring(0, earliestIndex + matchedStop.length);
  }
}

class _Utf8ChunkDecoder {
  final StringBuffer _buffer = StringBuffer();
  late final ByteConversionSink _sink;

  _Utf8ChunkDecoder() {
    _sink = const Utf8Decoder(allowMalformed: true).startChunkedConversion(
      StringConversionSink.withCallback(_buffer.write),
    );
  }

  String add(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    _sink.add(bytes);
    return _drain();
  }

  String close() {
    _sink.close();
    return _drain();
  }

  String _drain() {
    if (_buffer.isEmpty) return '';
    final value = _buffer.toString();
    _buffer.clear();
    return value;
  }
}

/// Exception thrown by [LlamaContext] operations.
class LlamaContextException implements Exception {
  final String message;
  const LlamaContextException(this.message);

  @override
  String toString() => 'LlamaContextException: $message';
}
