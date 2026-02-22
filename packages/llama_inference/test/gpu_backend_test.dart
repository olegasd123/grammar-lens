import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_inference/llama_inference.dart';

void main() {
  group('GpuBackendDetector', () {
    setUp(() {
      // Reset cached detection before each test so fallback is exercised.
      GpuBackendDetector.resetCache();
    });

    // ── Fallback behavior (native library not available in tests) ──────

    test('detect() returns a valid backend via OS fallback', () {
      final backend = GpuBackendDetector.detect();
      expect(backend, isA<GpuBackend>());
      expect(backend, isNot(equals(null)));
    });

    test('probeGpuInfo() returns fallback when native unavailable', () {
      final info = GpuBackendDetector.probeGpuInfo();
      // In test environment, native library won't load, so isProbed = false.
      expect(info.isProbed, isFalse);
      expect(info.systemMemoryBytes, 0);
    });

    test('fallback returns Metal on macOS', () {
      final info = GpuBackendDetector.probeGpuInfo();
      if (Platform.isMacOS) {
        expect(info.backend, GpuBackend.metal);
      }
    }, skip: !Platform.isMacOS ? 'Only runs on macOS' : null);

    test('fallback returns Vulkan on Linux', () {
      final info = GpuBackendDetector.probeGpuInfo();
      if (Platform.isLinux) {
        expect(info.backend, GpuBackend.vulkan);
      }
    }, skip: !Platform.isLinux ? 'Only runs on Linux' : null);

    test('fallback returns Vulkan on Windows', () {
      final info = GpuBackendDetector.probeGpuInfo();
      if (Platform.isWindows) {
        expect(info.backend, GpuBackend.vulkan);
      }
    }, skip: !Platform.isWindows ? 'Only runs on Windows' : null);

    test('probeGpuInfo() caches result', () {
      final first = GpuBackendDetector.probeGpuInfo();
      final second = GpuBackendDetector.probeGpuInfo();
      expect(identical(first, second), isTrue);
    });

    test('resetCache() clears cached result', () {
      final first = GpuBackendDetector.probeGpuInfo();
      GpuBackendDetector.resetCache();
      final second = GpuBackendDetector.probeGpuInfo();
      // Not identical objects since cache was cleared and re-created.
      expect(first.backend, second.backend);
      expect(identical(first, second), isFalse);
    });

    test('GpuInfo toString is human-readable', () {
      final info = GpuBackendDetector.probeGpuInfo();
      final str = info.toString();
      expect(str, contains('GpuInfo'));
      expect(str, contains('backend'));
      expect(str, contains('isProbed'));
      expect(str, contains('systemMemory'));
    });

    // ── recommendGpuLayers ────────────────────────────────────────────

    test('recommendGpuLayers returns 0 for zero memory', () {
      final layers = GpuBackendDetector.recommendGpuLayers(
        availableMemoryMB: 0,
        modelSizeMB: 2000,
        totalLayers: 32,
      );
      expect(layers, 0);
    });

    test('recommendGpuLayers returns all layers when memory is sufficient', () {
      final layers = GpuBackendDetector.recommendGpuLayers(
        availableMemoryMB: 4000,
        modelSizeMB: 2000,
        totalLayers: 32,
      );
      expect(layers, 32);
    });

    test('recommendGpuLayers returns partial layers for limited memory', () {
      final layers = GpuBackendDetector.recommendGpuLayers(
        availableMemoryMB: 1000,
        modelSizeMB: 2000,
        totalLayers: 32,
      );
      expect(layers, greaterThan(0));
      expect(layers, lessThan(32));
    });

    test('recommendGpuLayers never exceeds total layers', () {
      final layers = GpuBackendDetector.recommendGpuLayers(
        availableMemoryMB: 100000,
        modelSizeMB: 100,
        totalLayers: 32,
      );
      expect(layers, 32);
    });
  });

  group('MemoryManager', () {
    setUp(() {
      GpuBackendDetector.resetCache();
    });

    test('estimateAvailableMemory returns a positive value', () async {
      final memory = await MemoryManager.estimateAvailableMemory();
      expect(memory, greaterThan(0));
    });

    test('recommendQuantization returns a known quantization string', () async {
      final quant = await MemoryManager.recommendQuantization();
      expect(
        quant,
        isIn(['Q3_K_M', 'Q4_K_M', 'Q5_K_M', 'Q8_0']),
      );
    });

    test('canFitModel returns true for small models', () async {
      final canFit = await MemoryManager.canFitModel(100 * 1024 * 1024); // 100 MB
      expect(canFit, isTrue);
    });

    test('canFitModel returns false for extremely large models', () async {
      final canFit = await MemoryManager.canFitModel(
        1000 * 1024 * 1024 * 1024, // 1 TB
      );
      expect(canFit, isFalse);
    });
  });

  group('GpuBackend enum', () {
    test('has all expected values', () {
      expect(GpuBackend.values, containsAll([
        GpuBackend.metal,
        GpuBackend.vulkan,
        GpuBackend.cuda,
        GpuBackend.cpu,
      ]));
    });
  });
}
