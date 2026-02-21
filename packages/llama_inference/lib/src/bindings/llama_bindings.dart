// Hand-crafted FFI bindings for the GrammarLens native bridge.
//
// These bind to grammarlens_bridge.h — a thin C wrapper over llama.cpp.
// Using hand-crafted bindings instead of ffigen for a focused, stable API.

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

// ── Native library loader ────────────────────────────────────────────────────

/// Loads the platform-specific native library.
DynamicLibrary _loadLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('llama_inference_native.framework/llama_inference_native');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libllama_inference_native.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('llama_inference_native.dll');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

/// The loaded native library. Lazily initialized.
final DynamicLibrary _lib = _loadLibrary();

// ── Performance data struct ──────────────────────────────────────────────────

/// Mirrors `gl_perf_data` from the C bridge.
final class GlPerfData extends Struct {
  @Double()
  external double promptEvalTimeMs;

  @Double()
  external double evalTimeMs;

  @Int32()
  external int nPromptTokens;

  @Int32()
  external int nEvalTokens;
}

// ── Native function typedefs ─────────────────────────────────────────────────

// Lifecycle
typedef _GLBackendInitC = Void Function();
typedef _GLBackendInitDart = void Function();
typedef _GLBackendFreeC = Void Function();
typedef _GLBackendFreeDart = void Function();

// Model
typedef _GLModelLoadC = Pointer<Void> Function(
    Pointer<Utf8> path, Int32 nGpuLayers, Bool useMmap, Bool useMlock);
typedef _GLModelLoadDart = Pointer<Void> Function(
    Pointer<Utf8> path, int nGpuLayers, bool useMmap, bool useMlock);
typedef _GLModelFreeC = Void Function(Pointer<Void> model);
typedef _GLModelFreeDart = void Function(Pointer<Void> model);
typedef _GLModelNCtxTrainC = Int32 Function(Pointer<Void> model);
typedef _GLModelNCtxTrainDart = int Function(Pointer<Void> model);
typedef _GLModelNLayerC = Int32 Function(Pointer<Void> model);
typedef _GLModelNLayerDart = int Function(Pointer<Void> model);
typedef _GLModelSizeC = Uint64 Function(Pointer<Void> model);
typedef _GLModelSizeDart = int Function(Pointer<Void> model);
typedef _GLModelDescC = Int32 Function(
    Pointer<Void> model, Pointer<Utf8> buf, Int32 bufSize);
typedef _GLModelDescDart = int Function(
    Pointer<Void> model, Pointer<Utf8> buf, int bufSize);

// Context
typedef _GLContextCreateC = Pointer<Void> Function(
    Pointer<Void> model, Int32 nCtx, Int32 nThreads, Int32 nBatch);
typedef _GLContextCreateDart = Pointer<Void> Function(
    Pointer<Void> model, int nCtx, int nThreads, int nBatch);
typedef _GLContextFreeC = Void Function(Pointer<Void> ctx);
typedef _GLContextFreeDart = void Function(Pointer<Void> ctx);
typedef _GLContextKvCacheClearC = Void Function(Pointer<Void> ctx);
typedef _GLContextKvCacheClearDart = void Function(Pointer<Void> ctx);

// Tokenization
typedef _GLTokenizeC = Int32 Function(Pointer<Void> model, Pointer<Utf8> text,
    Int32 textLen, Pointer<Int32> tokens, Int32 nMaxTokens, Bool addSpecial);
typedef _GLTokenizeDart = int Function(Pointer<Void> model, Pointer<Utf8> text,
    int textLen, Pointer<Int32> tokens, int nMaxTokens, bool addSpecial);
typedef _GLTokenToPieceC = Int32 Function(
    Pointer<Void> model, Int32 token, Pointer<Utf8> buf, Int32 bufSize);
typedef _GLTokenToPieceDart = int Function(
    Pointer<Void> model, int token, Pointer<Utf8> buf, int bufSize);
typedef _GLTokenIsEogC = Bool Function(Pointer<Void> model, Int32 token);
typedef _GLTokenIsEogDart = bool Function(Pointer<Void> model, int token);
typedef _GLTokenBosC = Int32 Function(Pointer<Void> model);
typedef _GLTokenBosDart = int Function(Pointer<Void> model);
typedef _GLTokenEosC = Int32 Function(Pointer<Void> model);
typedef _GLTokenEosDart = int Function(Pointer<Void> model);

// Decoding
typedef _GLDecodeBatchC = Int32 Function(
    Pointer<Void> ctx, Pointer<Int32> tokens, Int32 nTokens, Int32 posStart);
typedef _GLDecodeBatchDart = int Function(
    Pointer<Void> ctx, Pointer<Int32> tokens, int nTokens, int posStart);
typedef _GLDecodeSingleC = Int32 Function(
    Pointer<Void> ctx, Int32 token, Int32 pos);
typedef _GLDecodeSingleDart = int Function(
    Pointer<Void> ctx, int token, int pos);

// Sampling
typedef _GLSamplerCreateC = Pointer<Void> Function(
    Pointer<Void> model,
    Float temp,
    Float topP,
    Int32 topK,
    Float repeatPenalty,
    Int32 penaltyLastN,
    Uint32 seed,
    Pointer<Utf8> grammarGbnf);
typedef _GLSamplerCreateDart = Pointer<Void> Function(
    Pointer<Void> model,
    double temp,
    double topP,
    int topK,
    double repeatPenalty,
    int penaltyLastN,
    int seed,
    Pointer<Utf8> grammarGbnf);
typedef _GLSamplerSampleC = Int32 Function(
    Pointer<Void> sampler, Pointer<Void> ctx, Int32 idx);
typedef _GLSamplerSampleDart = int Function(
    Pointer<Void> sampler, Pointer<Void> ctx, int idx);
typedef _GLSamplerAcceptC = Void Function(Pointer<Void> sampler, Int32 token);
typedef _GLSamplerAcceptDart = void Function(Pointer<Void> sampler, int token);
typedef _GLSamplerResetC = Void Function(Pointer<Void> sampler);
typedef _GLSamplerResetDart = void Function(Pointer<Void> sampler);
typedef _GLSamplerFreeC = Void Function(Pointer<Void> sampler);
typedef _GLSamplerFreeDart = void Function(Pointer<Void> sampler);

// Performance
typedef _GLContextPerfC = GlPerfData Function(Pointer<Void> ctx);
typedef _GLContextPerfDart = GlPerfData Function(Pointer<Void> ctx);
typedef _GLContextPerfResetC = Void Function(Pointer<Void> ctx);
typedef _GLContextPerfResetDart = void Function(Pointer<Void> ctx);

// System info
typedef _GLSystemInfoC = Pointer<Utf8> Function();
typedef _GLSystemInfoDart = Pointer<Utf8> Function();

// ── Binding class ────────────────────────────────────────────────────────────

/// Provides access to the GrammarLens native bridge functions.
class LlamaBindings {
  LlamaBindings._();

  static final LlamaBindings instance = LlamaBindings._();

  // ── Lifecycle ──

  final backendInit = _lib
      .lookupFunction<_GLBackendInitC, _GLBackendInitDart>('gl_backend_init');

  final backendFree = _lib
      .lookupFunction<_GLBackendFreeC, _GLBackendFreeDart>('gl_backend_free');

  // ── Model ──

  final modelLoad = _lib
      .lookupFunction<_GLModelLoadC, _GLModelLoadDart>('gl_model_load');

  final modelFree = _lib
      .lookupFunction<_GLModelFreeC, _GLModelFreeDart>('gl_model_free');

  final modelNCtxTrain = _lib
      .lookupFunction<_GLModelNCtxTrainC, _GLModelNCtxTrainDart>(
          'gl_model_n_ctx_train');

  final modelNLayer = _lib
      .lookupFunction<_GLModelNLayerC, _GLModelNLayerDart>('gl_model_n_layer');

  final modelSize = _lib
      .lookupFunction<_GLModelSizeC, _GLModelSizeDart>('gl_model_size');

  final modelDesc = _lib
      .lookupFunction<_GLModelDescC, _GLModelDescDart>('gl_model_desc');

  // ── Context ──

  final contextCreate = _lib
      .lookupFunction<_GLContextCreateC, _GLContextCreateDart>(
          'gl_context_create');

  final contextFree = _lib
      .lookupFunction<_GLContextFreeC, _GLContextFreeDart>('gl_context_free');

  final contextKvCacheClear = _lib
      .lookupFunction<_GLContextKvCacheClearC, _GLContextKvCacheClearDart>(
          'gl_context_kv_cache_clear');

  // ── Tokenization ──

  final tokenize = _lib
      .lookupFunction<_GLTokenizeC, _GLTokenizeDart>('gl_tokenize');

  final tokenToPiece = _lib
      .lookupFunction<_GLTokenToPieceC, _GLTokenToPieceDart>(
          'gl_token_to_piece');

  final tokenIsEog = _lib
      .lookupFunction<_GLTokenIsEogC, _GLTokenIsEogDart>('gl_token_is_eog');

  final tokenBos = _lib
      .lookupFunction<_GLTokenBosC, _GLTokenBosDart>('gl_token_bos');

  final tokenEos = _lib
      .lookupFunction<_GLTokenEosC, _GLTokenEosDart>('gl_token_eos');

  // ── Decoding ──

  final decodeBatch = _lib
      .lookupFunction<_GLDecodeBatchC, _GLDecodeBatchDart>('gl_decode_batch');

  final decodeSingle = _lib
      .lookupFunction<_GLDecodeSingleC, _GLDecodeSingleDart>(
          'gl_decode_single');

  // ── Sampling ──

  final samplerCreate = _lib
      .lookupFunction<_GLSamplerCreateC, _GLSamplerCreateDart>(
          'gl_sampler_create');

  final samplerSample = _lib
      .lookupFunction<_GLSamplerSampleC, _GLSamplerSampleDart>(
          'gl_sampler_sample');

  final samplerAccept = _lib
      .lookupFunction<_GLSamplerAcceptC, _GLSamplerAcceptDart>(
          'gl_sampler_accept');

  final samplerReset = _lib
      .lookupFunction<_GLSamplerResetC, _GLSamplerResetDart>(
          'gl_sampler_reset');

  final samplerFree = _lib
      .lookupFunction<_GLSamplerFreeC, _GLSamplerFreeDart>('gl_sampler_free');

  // ── Performance ──

  final contextPerf = _lib
      .lookupFunction<_GLContextPerfC, _GLContextPerfDart>('gl_context_perf');

  final contextPerfReset = _lib
      .lookupFunction<_GLContextPerfResetC, _GLContextPerfResetDart>(
          'gl_context_perf_reset');

  // ── System Info ──

  final systemInfo = _lib
      .lookupFunction<_GLSystemInfoC, _GLSystemInfoDart>('gl_system_info');
}
