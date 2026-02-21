import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:platform_integration/platform_integration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.grammarlens/accessibility');
  late MacosAccessibilityChannel sharedChannel;
  late MacosAccessibilityService service;
  late List<MethodCall> log;

  setUp(() {
    log = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      switch (call.method) {
        case 'hasPermission':
          return true;
        case 'requestPermission':
          return true;
        case 'readFocusedElement':
          return 'Hello world';
        case 'writeFocusedElement':
          return true;
        case 'getFocusedAppName':
          return 'TextEdit';
        case 'startFocusMonitoring':
          return true;
        default:
          return null;
      }
    });

    sharedChannel = MacosAccessibilityChannel();
    service = MacosAccessibilityService(channel: sharedChannel);
  });

  tearDown(() {
    sharedChannel.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MacosAccessibilityService', () {
    test('hasPermission sends correct method and returns result', () async {
      final result = await service.hasPermission();
      expect(result, isTrue);
      expect(log.last.method, 'hasPermission');
    });

    test('requestPermission sends correct method and returns result',
        () async {
      final result = await service.requestPermission();
      expect(result, isTrue);
      expect(log.last.method, 'requestPermission');
    });

    test('readFocusedElement returns text from native', () async {
      final result = await service.readFocusedElement();
      expect(result, 'Hello world');
      expect(log.last.method, 'readFocusedElement');
    });

    test('writeFocusedElement sends text as argument', () async {
      final result = await service.writeFocusedElement('Corrected text');
      expect(result, isTrue);
      expect(log.last.method, 'writeFocusedElement');
      expect(
        log.last.arguments,
        {'text': 'Corrected text'},
      );
    });

    test('getFocusedAppName returns app name from native', () async {
      final result = await service.getFocusedAppName();
      expect(result, 'TextEdit');
      expect(log.last.method, 'getFocusedAppName');
    });

    test('onFocusChanged starts monitoring and returns stream', () async {
      final stream = service.onFocusChanged();
      expect(log.last.method, 'startFocusMonitoring');

      // Simulate a native callback
      final events = <FocusEvent>[];
      final sub = stream.listen(events.add);

      // Simulate native sending a focus event
      await _simulateNativeCallback(
        channel,
        'onFocusChanged',
        {
          'appName': 'Safari',
          'elementType': 'TextField',
          'text': 'some text',
        },
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.appName, 'Safari');
      expect(events.first.elementType, 'TextField');
      expect(events.first.text, 'some text');

      await sub.cancel();
    });

    test('hasPermission returns false when native returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return call.method == 'hasPermission' ? false : null;
      });

      // Recreate channel and service to pick up new handler
      sharedChannel.dispose();
      sharedChannel = MacosAccessibilityChannel();
      service = MacosAccessibilityService(channel: sharedChannel);

      final result = await service.hasPermission();
      expect(result, isFalse);
    });

    test('readFocusedElement returns null when no focused element', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return call.method == 'readFocusedElement' ? null : null;
      });

      sharedChannel.dispose();
      sharedChannel = MacosAccessibilityChannel();
      service = MacosAccessibilityService(channel: sharedChannel);

      final result = await service.readFocusedElement();
      expect(result, isNull);
    });

    test('writeFocusedElement returns false when write fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return call.method == 'writeFocusedElement' ? false : null;
      });

      sharedChannel.dispose();
      sharedChannel = MacosAccessibilityChannel();
      service = MacosAccessibilityService(channel: sharedChannel);

      final result = await service.writeFocusedElement('text');
      expect(result, isFalse);
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
