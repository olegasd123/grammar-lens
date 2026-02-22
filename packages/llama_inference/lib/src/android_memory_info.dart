import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = Logger('AndroidMemoryInfo');

/// Memory information retrieved from Android's [ActivityManager].
///
/// Provides runtime memory data that is more accurate than static estimates
/// for deciding model quantization and GPU layer offloading on Android.
class AndroidMemoryInfo {
  const AndroidMemoryInfo({
    required this.totalMemBytes,
    required this.availMemBytes,
    required this.lowMemory,
    required this.threshold,
    required this.largeMemoryClass,
    required this.memoryClass,
    required this.isLowRamDevice,
  });

  /// Total physical RAM in bytes.
  final int totalMemBytes;

  /// Currently available RAM in bytes.
  final int availMemBytes;

  /// Whether the system considers itself in a low-memory state.
  final bool lowMemory;

  /// The memory threshold (bytes) below which the system is "low memory".
  final int threshold;

  /// Max heap size (MB) available with `android:largeHeap="true"`.
  final int largeMemoryClass;

  /// Default max heap size (MB) for the app.
  final int memoryClass;

  /// Whether ActivityManager considers this a low-RAM device.
  final bool isLowRamDevice;

  /// Parse from the map returned by the platform channel.
  factory AndroidMemoryInfo.fromMap(Map<String, dynamic> map) {
    return AndroidMemoryInfo(
      totalMemBytes: (map['totalMemBytes'] as num).toInt(),
      availMemBytes: (map['availMemBytes'] as num).toInt(),
      lowMemory: map['lowMemory'] as bool,
      threshold: (map['threshold'] as num).toInt(),
      largeMemoryClass: (map['largeMemoryClass'] as num).toInt(),
      memoryClass: (map['memoryClass'] as num).toInt(),
      isLowRamDevice: map['isLowRamDevice'] as bool,
    );
  }

  @override
  String toString() =>
      'AndroidMemoryInfo('
      'total: ${totalMemBytes ~/ (1024 * 1024)} MB, '
      'avail: ${availMemBytes ~/ (1024 * 1024)} MB, '
      'lowMemory: $lowMemory, '
      'largeHeap: $largeMemoryClass MB, '
      'lowRamDevice: $isLowRamDevice)';
}

/// Reads memory information from Android's ActivityManager via platform channel.
///
/// Returns `null` if the platform channel is not available (e.g. in tests
/// or on non-Android platforms).
class AndroidMemoryChannel {
  AndroidMemoryChannel._();

  static const _channel = MethodChannel('com.grammarlens/memory');

  /// Cached result from the last successful query.
  static AndroidMemoryInfo? _cached;

  /// Query Android memory info, returning a cached result if available.
  ///
  /// Returns `null` if the channel is unavailable or the call fails.
  static Future<AndroidMemoryInfo?> getMemoryInfo({
    bool forceRefresh = false,
  }) async {
    if (_cached != null && !forceRefresh) return _cached;

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getMemoryInfo',
      );
      if (result == null) return null;

      _cached = AndroidMemoryInfo.fromMap(result);
      _log.info('Android memory info: $_cached');
      return _cached;
    } on MissingPluginException {
      _log.fine('Android memory channel not available');
      return null;
    } catch (e) {
      _log.warning('Failed to read Android memory info: $e');
      return null;
    }
  }

  /// Reset the cached result (useful for testing).
  static void resetCache() {
    _cached = null;
  }
}
