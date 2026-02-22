import 'dart:io' show Platform;

import 'package:logging/logging.dart';

import 'bindings/llama_bindings.dart';

final _log = Logger('GpuBackendDetector');

/// GPU compute backends supported by llama.cpp.
enum GpuBackend {
  /// Apple Metal (macOS, iOS).
  metal,

  /// Vulkan (Windows, Linux, Android).
  vulkan,

  /// NVIDIA CUDA (Windows, Linux).
  cuda,

  /// CPU fallback (all platforms).
  cpu,
}

/// Result of GPU detection, including the selected backend and system memory.
class GpuInfo {
  const GpuInfo({
    required this.backend,
    required this.isProbed,
    required this.systemMemoryBytes,
  });

  /// The detected GPU backend.
  final GpuBackend backend;

  /// Whether the detection was based on native probing (`true`) or
  /// OS-based heuristic fallback (`false`).
  final bool isProbed;

  /// Total physical RAM in bytes, or 0 if unknown.
  final int systemMemoryBytes;

  @override
  String toString() =>
      'GpuInfo(backend: $backend, isProbed: $isProbed, '
      'systemMemory: ${systemMemoryBytes ~/ (1024 * 1024)} MB)';
}

/// Detects the best available GPU backend for the current platform.
///
/// Prefers native probing via the FFI bridge to check which GPU backends
/// were actually compiled into the native library. Falls back to OS-based
/// heuristics if the native library is not available (e.g. in tests).
class GpuBackendDetector {
  const GpuBackendDetector._();

  /// Cached result from the last [probeGpuInfo] call.
  static GpuInfo? _cached;

  /// Auto-detect the optimal GPU backend for the current platform.
  ///
  /// Attempts native probing first, falling back to OS-based detection.
  /// Priority: CUDA → Metal → Vulkan → CPU.
  static GpuBackend detect() {
    return probeGpuInfo().backend;
  }

  /// Probe for GPU information via the native bridge.
  ///
  /// Returns a [GpuInfo] with the best backend, whether it was probed
  /// natively, and the total system memory. Results are cached.
  static GpuInfo probeGpuInfo() {
    if (_cached != null) return _cached!;

    _cached = _tryNativeProbe() ?? _osFallback();
    _log.info('GPU detection result: $_cached');
    return _cached!;
  }

  /// Reset the cached detection result (useful for testing).
  static void resetCache() {
    _cached = null;
  }

  /// Attempt to probe GPU info via the native FFI bridge.
  static GpuInfo? _tryNativeProbe() {
    try {
      final info = LlamaBindings.instance.detectGpu();

      final backend = _pickBackend(
        hasCuda: info.hasCuda,
        hasMetal: info.hasMetal,
        hasVulkan: info.hasVulkan,
      );

      return GpuInfo(
        backend: backend,
        isProbed: true,
        systemMemoryBytes: info.systemMemoryBytes,
      );
    } catch (e) {
      _log.fine('Native GPU probe unavailable, using OS fallback: $e');
      return null;
    }
  }

  /// Pick the best backend from the probed compile-time flags.
  ///
  /// Priority: CUDA → Metal → Vulkan → CPU.
  /// CUDA is preferred over Vulkan on systems where both are compiled in,
  /// since NVIDIA GPUs perform better with native CUDA support.
  static GpuBackend _pickBackend({
    required bool hasCuda,
    required bool hasMetal,
    required bool hasVulkan,
  }) {
    if (hasCuda) return GpuBackend.cuda;
    if (hasMetal) return GpuBackend.metal;
    if (hasVulkan) return GpuBackend.vulkan;
    return GpuBackend.cpu;
  }

  /// Fallback: guess backend based on the operating system.
  static GpuInfo _osFallback() {
    GpuBackend backend;
    if (Platform.isMacOS || Platform.isIOS) {
      backend = GpuBackend.metal;
    } else if (Platform.isAndroid || Platform.isWindows || Platform.isLinux) {
      backend = GpuBackend.vulkan;
    } else {
      backend = GpuBackend.cpu;
    }

    return GpuInfo(
      backend: backend,
      isProbed: false,
      systemMemoryBytes: 0,
    );
  }

  /// Returns the number of GPU layers to offload based on available memory.
  ///
  /// [availableMemoryMB] is the estimated free GPU memory in megabytes.
  /// [modelSizeMB] is the total model size in megabytes.
  /// [totalLayers] is the total number of model layers.
  static int recommendGpuLayers({
    required int availableMemoryMB,
    required int modelSizeMB,
    required int totalLayers,
  }) {
    if (availableMemoryMB <= 0) return 0;

    final memoryPerLayer = modelSizeMB / totalLayers;
    final maxLayers = (availableMemoryMB / memoryPerLayer).floor();

    return maxLayers.clamp(0, totalLayers);
  }
}
