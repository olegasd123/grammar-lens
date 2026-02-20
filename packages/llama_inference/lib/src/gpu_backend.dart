import 'dart:io' show Platform;

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

/// Detects the best available GPU backend for the current platform.
class GpuBackendDetector {
  const GpuBackendDetector._();

  /// Auto-detect the optimal GPU backend for the current platform.
  ///
  /// Returns [GpuBackend.metal] on Apple platforms,
  /// [GpuBackend.vulkan] on Windows/Linux/Android,
  /// and [GpuBackend.cpu] as final fallback.
  static GpuBackend detect() {
    if (Platform.isMacOS || Platform.isIOS) {
      return GpuBackend.metal;
    }
    if (Platform.isAndroid || Platform.isWindows || Platform.isLinux) {
      // TODO: Probe for actual Vulkan/CUDA availability via platform channel
      return GpuBackend.vulkan;
    }
    return GpuBackend.cpu;
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
