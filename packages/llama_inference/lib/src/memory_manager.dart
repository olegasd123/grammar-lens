import 'dart:io';

import 'package:llama_inference/src/android_memory_info.dart';
import 'package:llama_inference/src/gpu_backend.dart';
import 'package:logging/logging.dart';

final _log = Logger('MemoryManager');

/// Monitors and manages memory usage for model inference.
///
/// Helps determine which quantization level is appropriate for the
/// current device and whether models need to be unloaded.
///
/// Memory estimation priority chain:
/// 1. Android: `ActivityManager` via platform channel (available + low-RAM check)
/// 2. All platforms: native FFI probe for total system RAM (via `gl_detect_gpu`)
/// 3. Hardcoded per-platform estimates as final fallback
class MemoryManager {
  const MemoryManager._();

  /// Estimate available memory for model loading (in bytes).
  ///
  /// Uses the best available source of memory information:
  /// - On Android, queries `ActivityManager` for real-time available memory
  ///   and device characteristics (low-RAM flag, large-heap class).
  /// - On other platforms, uses total system RAM from the native FFI probe.
  /// - Falls back to hardcoded estimates if neither source is available.
  static Future<int> estimateAvailableMemory() async {
    // Android-specific: use ActivityManager for accurate runtime data.
    if (Platform.isAndroid) {
      final androidMem = await _estimateAndroidMemory();
      if (androidMem != null) return androidMem;
    }

    // Cross-platform: use native FFI probe for total system RAM.
    final gpuInfo = GpuBackendDetector.probeGpuInfo();
    if (gpuInfo.isProbed && gpuInfo.systemMemoryBytes > 0) {
      return _applyHeadroom(gpuInfo.systemMemoryBytes);
    }

    // Final fallback: hardcoded per-platform estimates.
    return _hardcodedEstimate();
  }

  /// Estimate memory on Android using ActivityManager data.
  ///
  /// This gives us real-time available memory and device-level signals
  /// (low-RAM device, low-memory state) that are much more accurate than
  /// total RAM alone.
  ///
  /// Strategy:
  /// - On low-RAM devices, use a conservative budget (40% of available).
  /// - On regular devices in low-memory state, use 50% of available.
  /// - Otherwise, use 70% of available memory.
  /// - Never exceed what the large-heap class allows, converted to native
  ///   memory terms (×3 multiplier, since native allocations aren't
  ///   bounded by the Dalvik heap but the signal is useful as a cap).
  static Future<int?> _estimateAndroidMemory() async {
    final info = await AndroidMemoryChannel.getMemoryInfo();
    if (info == null) return null;

    final double fraction;
    if (info.isLowRamDevice) {
      fraction = 0.40;
    } else if (info.lowMemory) {
      fraction = 0.50;
    } else {
      fraction = 0.70;
    }

    // Budget based on currently available memory.
    var budget = (info.availMemBytes * fraction).toInt();

    // Cap: use largeMemoryClass as a soft ceiling.
    // Native memory isn't heap-limited, but this is a reasonable signal
    // for how much the device can sustain without being killed.
    final nativeCap = info.largeMemoryClass * 1024 * 1024 * 3;
    if (budget > nativeCap) {
      budget = nativeCap;
    }

    _log.info(
      'Android memory: avail=${info.availMemBytes ~/ (1024 * 1024)} MB, '
      'budget=${budget ~/ (1024 * 1024)} MB '
      '(${(fraction * 100).toInt()}%), '
      'lowRam=${info.isLowRamDevice}, lowMem=${info.lowMemory}',
    );

    return budget;
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

  /// Hardcoded estimates when no runtime data is available.
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
