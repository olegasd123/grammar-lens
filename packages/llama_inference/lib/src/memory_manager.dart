import 'dart:io';

import 'package:logging/logging.dart';

import 'package:llama_inference/src/gpu_backend.dart';

final _log = Logger('MemoryManager');

/// Monitors and manages memory usage for model inference.
///
/// Helps determine which quantization level is appropriate for the
/// current device and whether models need to be unloaded.
class MemoryManager {
  const MemoryManager._();

  /// Estimate available memory for model loading (in bytes).
  ///
  /// Uses real system memory from native probing when available.
  /// On mobile, applies a conservative headroom (~60% of physical RAM).
  /// On desktop, applies a larger budget (~80% of physical RAM).
  /// Falls back to hardcoded estimates if native probing is unavailable.
  static Future<int> estimateAvailableMemory() async {
    final gpuInfo = GpuBackendDetector.probeGpuInfo();

    if (gpuInfo.isProbed && gpuInfo.systemMemoryBytes > 0) {
      return _applyHeadroom(gpuInfo.systemMemoryBytes);
    }

    // Fallback: hardcoded per-platform estimates.
    return _hardcodedEstimate();
  }

  /// Apply platform-specific headroom to real system memory.
  ///
  /// Mobile devices need more headroom for the OS and other apps.
  /// Desktop systems can afford to use a larger fraction.
  static int _applyHeadroom(int totalBytes) {
    final double fraction;
    if (Platform.isIOS || Platform.isAndroid) {
      fraction = 0.60; // 60% on mobile — leave room for OS + apps
    } else {
      fraction = 0.80; // 80% on desktop
    }

    final usable = (totalBytes * fraction).toInt();
    _log.info(
      'System RAM: ${totalBytes ~/ (1024 * 1024)} MB, '
      'usable for inference: ${usable ~/ (1024 * 1024)} MB '
      '(${(fraction * 100).toInt()}%)',
    );
    return usable;
  }

  /// Hardcoded estimates when native probing is unavailable.
  static int _hardcodedEstimate() {
    if (Platform.isIOS) {
      // iOS apps typically get 1.0-1.5 GB on modern devices.
      // Keyboard extensions get ~40 MB.
      // Conservatively assume 1.0 GB for main app.
      return 1024 * 1024 * 1024; // 1 GB
    }

    if (Platform.isAndroid) {
      return 2 * 1024 * 1024 * 1024; // 2 GB estimate
    }

    // Desktop: assume at least 4 GB available
    return 4 * 1024 * 1024 * 1024;
  }

  /// Recommend the best quantization level for the current device.
  ///
  /// Returns a string like "Q4_K_M", "Q5_K_M", or "Q8_0".
  static Future<String> recommendQuantization() async {
    final availableBytes = await estimateAvailableMemory();
    final availableMB = availableBytes ~/ (1024 * 1024);

    _log.info('Available memory: $availableMB MB');

    if (availableMB >= 6000) {
      return 'Q8_0'; // ~4 GB for Phi-3-mini
    } else if (availableMB >= 4000) {
      return 'Q5_K_M'; // ~2.8 GB for Phi-3-mini
    } else if (availableMB >= 2500) {
      return 'Q4_K_M'; // ~2.2 GB for Phi-3-mini
    } else {
      return 'Q3_K_M'; // ~1.8 GB for Phi-3-mini (minimum viable)
    }
  }

  /// Check if a model of the given size (bytes) can fit in memory.
  static Future<bool> canFitModel(int modelSizeBytes) async {
    final available = await estimateAvailableMemory();
    // Leave 20% headroom for context, temp buffers, etc.
    final usable = (available * 0.8).toInt();
    return modelSizeBytes <= usable;
  }
}
