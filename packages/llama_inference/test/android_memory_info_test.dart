import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_inference/llama_inference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidMemoryInfo', () {
    test('fromMap parses all fields correctly', () {
      final info = AndroidMemoryInfo.fromMap({
        'totalMemBytes': 8589934592, // 8 GB
        'availMemBytes': 4294967296, // 4 GB
        'lowMemory': false,
        'threshold': 536870912, // 512 MB
        'largeMemoryClass': 512,
        'memoryClass': 256,
        'isLowRamDevice': false,
      });

      expect(info.totalMemBytes, 8589934592);
      expect(info.availMemBytes, 4294967296);
      expect(info.lowMemory, isFalse);
      expect(info.threshold, 536870912);
      expect(info.largeMemoryClass, 512);
      expect(info.memoryClass, 256);
      expect(info.isLowRamDevice, isFalse);
    });

    test('fromMap handles low-RAM device values', () {
      final info = AndroidMemoryInfo.fromMap({
        'totalMemBytes': 2147483648, // 2 GB
        'availMemBytes': 536870912, // 512 MB
        'lowMemory': true,
        'threshold': 268435456, // 256 MB
        'largeMemoryClass': 128,
        'memoryClass': 64,
        'isLowRamDevice': true,
      });

      expect(info.totalMemBytes, 2147483648);
      expect(info.availMemBytes, 536870912);
      expect(info.lowMemory, isTrue);
      expect(info.isLowRamDevice, isTrue);
      expect(info.largeMemoryClass, 128);
    });

    test('toString is human-readable', () {
      final info = AndroidMemoryInfo.fromMap({
        'totalMemBytes': 8589934592,
        'availMemBytes': 4294967296,
        'lowMemory': false,
        'threshold': 536870912,
        'largeMemoryClass': 512,
        'memoryClass': 256,
        'isLowRamDevice': false,
      });

      final str = info.toString();
      expect(str, contains('AndroidMemoryInfo'));
      expect(str, contains('total:'));
      expect(str, contains('avail:'));
      expect(str, contains('lowRamDevice:'));
    });
  });

  group('AndroidMemoryChannel', () {
    const channel = MethodChannel('com.grammarlens/memory');

    setUp(() {
      AndroidMemoryChannel.resetCache();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getMemoryInfo returns parsed data from platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getMemoryInfo') {
          return {
            'totalMemBytes': 6442450944, // 6 GB
            'availMemBytes': 3221225472, // 3 GB
            'lowMemory': false,
            'threshold': 536870912,
            'largeMemoryClass': 384,
            'memoryClass': 192,
            'isLowRamDevice': false,
          };
        }
        return null;
      });

      final info = await AndroidMemoryChannel.getMemoryInfo();

      expect(info, isNotNull);
      expect(info!.totalMemBytes, 6442450944);
      expect(info.availMemBytes, 3221225472);
      expect(info.lowMemory, isFalse);
      expect(info.largeMemoryClass, 384);
      expect(info.isLowRamDevice, isFalse);
    });

    test('getMemoryInfo returns null when channel unavailable', () async {
      // No mock handler set — simulates missing plugin
      final info = await AndroidMemoryChannel.getMemoryInfo();
      expect(info, isNull);
    });

    test('getMemoryInfo caches result', () async {
      var callCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        callCount++;
        return {
          'totalMemBytes': 4294967296,
          'availMemBytes': 2147483648,
          'lowMemory': false,
          'threshold': 268435456,
          'largeMemoryClass': 256,
          'memoryClass': 128,
          'isLowRamDevice': false,
        };
      });

      final first = await AndroidMemoryChannel.getMemoryInfo();
      final second = await AndroidMemoryChannel.getMemoryInfo();

      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
      expect(callCount, 1); // Only called native once
    });

    test('getMemoryInfo forceRefresh bypasses cache', () async {
      var callCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        callCount++;
        return {
          'totalMemBytes': 4294967296,
          'availMemBytes': 2147483648 + callCount * 1024, // slightly different
          'lowMemory': false,
          'threshold': 268435456,
          'largeMemoryClass': 256,
          'memoryClass': 128,
          'isLowRamDevice': false,
        };
      });

      await AndroidMemoryChannel.getMemoryInfo();
      await AndroidMemoryChannel.getMemoryInfo(forceRefresh: true);

      expect(callCount, 2); // Called native twice
    });

    test('resetCache clears cached result', () async {
      var callCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        callCount++;
        return {
          'totalMemBytes': 4294967296,
          'availMemBytes': 2147483648,
          'lowMemory': false,
          'threshold': 268435456,
          'largeMemoryClass': 256,
          'memoryClass': 128,
          'isLowRamDevice': false,
        };
      });

      await AndroidMemoryChannel.getMemoryInfo();
      AndroidMemoryChannel.resetCache();
      await AndroidMemoryChannel.getMemoryInfo();

      expect(callCount, 2);
    });

    test('getMemoryInfo returns null on channel error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR', message: 'Service unavailable');
      });

      final info = await AndroidMemoryChannel.getMemoryInfo();
      expect(info, isNull);
    });
  });
}
