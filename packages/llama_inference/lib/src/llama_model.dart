import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

import 'package:llama_inference/src/bindings/llama_bindings.dart';
import 'package:llama_inference/src/gpu_backend.dart';

final _log = Logger('LlamaModel');
final _b = LlamaBindings.instance;

/// Represents a loaded GGUF model.
///
/// Handles model lifecycle: loading from disk, GPU layer offloading,
/// memory-mapped I/O, and cleanup.
///
/// Usage:
/// ```dart
/// final model = await LlamaModel.load(
///   '/path/to/model.gguf',
///   gpuLayers: 99,
///   useMmap: true,
/// );
/// // ... use model with LlamaContext ...
/// model.dispose();
/// ```
class LlamaModel {
  /// Path to the loaded GGUF file.
  final String modelPath;

  /// GPU backend used for this model.
  final GpuBackend gpuBackend;

  /// Number of layers offloaded to GPU.
  final int gpuLayers;

  /// Whether the model is currently loaded.
  bool get isLoaded => _isLoaded;
  bool _isLoaded = false;

  /// Estimated memory usage in bytes.
  int get memoryUsageBytes => _memoryUsageBytes;
  int _memoryUsageBytes = 0;

  /// Context length supported by this model.
  int get contextLength => _contextLength;
  int _contextLength = 0;

  /// Native model pointer (opaque, platform-specific).
  /// In the real implementation, this would be Pointer<llama_model>.
  Pointer<Void>? _nativeModel;

  LlamaModel._({
    required this.modelPath,
    required this.gpuBackend,
    required this.gpuLayers,
  });

  /// Load a GGUF model from disk.
  ///
  /// [path] - Absolute path to the .gguf model file.
  /// [gpuLayers] - Number of layers to offload to GPU. Use 99 for all layers.
  /// [useMmap] - Use memory-mapped file I/O. Critical for mobile platforms
  ///   where the OS can page out model weights instead of keeping all resident.
  /// [useMlock] - Lock model in RAM (prevents paging). Only recommended on
  ///   desktop systems with sufficient RAM (16GB+).
  /// [gpuBackend] - GPU backend to use. Defaults to auto-detection.
  static Future<LlamaModel> load(
    String path, {
    int gpuLayers = 99,
    bool useMmap = true,
    bool useMlock = false,
    GpuBackend? gpuBackend,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw LlamaModelException('Model file not found: $path');
    }

    final detectedBackend = gpuBackend ?? GpuBackendDetector.detect();
    _log.info(
      'Loading model: $path '
      '(gpu: $detectedBackend, layers: $gpuLayers, '
      'mmap: $useMmap, mlock: $useMlock)',
    );

    final model = LlamaModel._(
      modelPath: path,
      gpuBackend: detectedBackend,
      gpuLayers: gpuLayers,
    );

    final pathNative = path.toNativeUtf8();
    try {
      final ptr = _b.modelLoad(pathNative, gpuLayers, useMmap, useMlock);
      if (ptr == nullptr) {
        throw LlamaModelException('Failed to load model: $path');
      }
      model._nativeModel = ptr;
    } finally {
      calloc.free(pathNative);
    }

    model._isLoaded = true;
    model._memoryUsageBytes = _b.modelSize(model._nativeModel!);
    model._contextLength = _b.modelNCtxTrain(model._nativeModel!);

    _log.info(
      'Model loaded successfully. '
      'Memory: ${(model._memoryUsageBytes / 1024 / 1024).toStringAsFixed(0)} MB, '
      'Context: ${model._contextLength}',
    );

    return model;
  }

  /// Free native memory and unload the model.
  void dispose() {
    if (!_isLoaded) return;

    _log.info('Disposing model: $modelPath');

    if (_nativeModel != null) {
      _b.modelFree(_nativeModel!);
    }
    _nativeModel = null;
    _isLoaded = false;
    _memoryUsageBytes = 0;
  }

  /// Number of model layers.
  int get layerCount {
    if (!_isLoaded || _nativeModel == null) return 0;
    return _b.modelNLayer(_nativeModel!);
  }

  /// Human-readable model description.
  String get description {
    if (!_isLoaded || _nativeModel == null) return '';
    final buf = calloc<Uint8>(256);
    _b.modelDesc(_nativeModel!, buf.cast<Utf8>(), 256);
    final desc = buf.cast<Utf8>().toDartString();
    calloc.free(buf);
    return desc;
  }

  /// Get the native model pointer for use with [LlamaContext].
  ///
  /// Throws if the model is not loaded.
  Pointer<Void> get nativePointer {
    if (!_isLoaded || _nativeModel == null) {
      throw LlamaModelException('Model is not loaded');
    }
    return _nativeModel!;
  }

  @override
  String toString() {
    return 'LlamaModel('
        'path: $modelPath, '
        'loaded: $_isLoaded, '
        'gpu: $gpuBackend, '
        'memory: ${(_memoryUsageBytes / 1024 / 1024).toStringAsFixed(0)} MB)';
  }
}

/// Exception thrown by [LlamaModel] operations.
class LlamaModelException implements Exception {
  final String message;
  const LlamaModelException(this.message);

  @override
  String toString() => 'LlamaModelException: $message';
}
