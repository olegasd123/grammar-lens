import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:platform_integration/platform_integration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Base ClipboardService ─────────────────────────────────────────────

  group('ClipboardService (base)', () {
    late ClipboardService service;

    setUp(() {
      service = ClipboardService();
    });

    test('onClipboardChanged returns empty stream', () async {
      final events = await service.onClipboardChanged().toList();
      expect(events, isEmpty);
    });

    test('dispose can be called without error', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });

  // ── MacosClipboardService ─────────────────────────────────────────────

  group('MacosClipboardService', () {
    const channel = MethodChannel('com.grammarlens/clipboard');
    late MacosClipboardService service;
    late List<MethodCall> log;

    setUp(() {
      log = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        switch (call.method) {
          case 'startMonitoring':
            return true;
          case 'stopMonitoring':
            return true;
          default:
            return null;
        }
      });

      service = MacosClipboardService();
    });

    tearDown(() {
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('onClipboardChanged calls startMonitoring on first listen', () async {
      final stream = service.onClipboardChanged();

      final texts = <String>[];
      final sub = stream.listen(texts.add);

      // Give time for the async startMonitoring call
      await Future<void>.delayed(Duration.zero);

      expect(
        log.any((call) => call.method == 'startMonitoring'),
        isTrue,
      );

      await sub.cancel();
    });

    test('onClipboardChanged does not call startMonitoring twice', () async {
      // First call triggers startMonitoring
      final sub1 = service.onClipboardChanged().listen((_) {});
      await Future<void>.delayed(Duration.zero);

      // Second call should not trigger again
      final sub2 = service.onClipboardChanged().listen((_) {});
      await Future<void>.delayed(Duration.zero);

      final startCalls =
          log.where((call) => call.method == 'startMonitoring').length;
      expect(startCalls, 1);

      await sub1.cancel();
      await sub2.cancel();
    });

    test('emits text when native sends onClipboardChanged', () async {
      final texts = <String>[];
      final sub = service.onClipboardChanged().listen(texts.add);
      await Future<void>.delayed(Duration.zero);

      // Simulate native clipboard change callback
      await _simulateNativeCallback(
        channel,
        'onClipboardChanged',
        'Hello from clipboard',
      );
      await Future<void>.delayed(Duration.zero);

      expect(texts, hasLength(1));
      expect(texts.first, 'Hello from clipboard');

      await sub.cancel();
    });

    test('emits multiple changes in order', () async {
      final texts = <String>[];
      final sub = service.onClipboardChanged().listen(texts.add);
      await Future<void>.delayed(Duration.zero);

      await _simulateNativeCallback(channel, 'onClipboardChanged', 'First');
      await _simulateNativeCallback(channel, 'onClipboardChanged', 'Second');
      await _simulateNativeCallback(channel, 'onClipboardChanged', 'Third');
      await Future<void>.delayed(Duration.zero);

      expect(texts, ['First', 'Second', 'Third']);

      await sub.cancel();
    });

    test('ignores null arguments from native', () async {
      final texts = <String>[];
      final sub = service.onClipboardChanged().listen(texts.add);
      await Future<void>.delayed(Duration.zero);

      await _simulateNativeCallback(channel, 'onClipboardChanged', null);
      await Future<void>.delayed(Duration.zero);

      expect(texts, isEmpty);

      await sub.cancel();
    });

    test('dispose calls stopMonitoring', () async {
      // Start monitoring first
      final sub = service.onClipboardChanged().listen((_) {});
      await Future<void>.delayed(Duration.zero);

      service.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(
        log.any((call) => call.method == 'stopMonitoring'),
        isTrue,
      );

      await sub.cancel();
    });

    test('broadcast stream supports multiple listeners', () async {
      final texts1 = <String>[];
      final texts2 = <String>[];

      final sub1 = service.onClipboardChanged().listen(texts1.add);
      final sub2 = service.onClipboardChanged().listen(texts2.add);
      await Future<void>.delayed(Duration.zero);

      await _simulateNativeCallback(
        channel,
        'onClipboardChanged',
        'Shared event',
      );
      await Future<void>.delayed(Duration.zero);

      expect(texts1, ['Shared event']);
      expect(texts2, ['Shared event']);

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}

/// Simulate a native → Dart callback on the given channel.
Future<void> _simulateNativeCallback(
  MethodChannel channel,
  String method,
  dynamic arguments,
) async {
  final data = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    channel.name,
    data,
    (ByteData? reply) {},
  );
}
