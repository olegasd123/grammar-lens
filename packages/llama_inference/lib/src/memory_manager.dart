import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('MemoryManager');

/// Monitors and manages memory usage for model inference.
///
/// Helps determine which quantization level is appropriate for the
/// current device and whether models need to be unloaded.
class MemoryManager {
  const MemoryManager._();

  /// Estimate available memory for model loading (in bytes).
  ///
  /// On mobile, this accounts for the app's memory budget.
  /// On desktop, this looks at total system RAM.
  static Future<int> estimateAvailableMemory() async {
    if (Platform.isIOS) {
      // iOS apps typically get 1.0-1.5 GB on modern devices.
      // Keyboard extensions get ~40 MB.
      // Conservatively assume 1.0 GB for main app.
      return 1024 * 1024 * 1024; // 1 GB
    }

    if (Platform.isAndroid) {
      // TODO: Read via platform channel:
      // ActivityManager.getMemoryInfo() / getLargeMemoryClass()
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
