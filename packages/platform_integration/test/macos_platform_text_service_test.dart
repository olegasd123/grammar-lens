import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:platform_integration/platform_integration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.grammarlens/accessibility');
  late MacosAccessibilityChannel sharedChannel;
  late MacosPlatformTextService service;
  late List<MethodCall> log;

  setUp(() {
    log = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      switch (call.method) {
        case 'readFocusedElement':
          return 'Current text content';
        case 'writeFocusedElement':
          return true;
        case 'getSelectedText':
          return 'selected';
        case 'replaceSelectedText':
          return true;
        case 'hasPermission':
          return true;
        default:
          return null;
      }
    });

    sharedChannel = MacosAccessibilityChannel();
    service = MacosPlatformTextService(channel: sharedChannel);
  });

  tearDown(() {
    sharedChannel.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MacosPlatformTextService', () {
    test('getActiveTextFieldContent calls readFocusedElement', () async {
      final result = await service.getActiveTextFieldContent();
      expect(result, 'Current text content');
      expect(log.last.method, 'readFocusedElement');
    });

    test('setActiveTextFieldContent calls writeFocusedElement', () async {
      final result =
          await service.setActiveTextFieldContent('New content');
      expect(result, isTrue);
      expect(log.last.method, 'writeFocusedElement');
      expect(log.last.arguments, {'text': 'New content'});
    });

    test('getSelectedText calls getSelectedText', () async {
      final result = await service.getSelectedText();
      expect(result, 'selected');
      expect(log.last.method, 'getSelectedText');
    });

    test('replaceSelectedText calls replaceSelectedText with args',
        () async {
      final result = await service.replaceSelectedText('replacement');
      expect(result, isTrue);
      expect(log.last.method, 'replaceSelectedText');
      expect(log.last.arguments, {'text': 'replacement'});
    });

    test('isAvailable calls hasPermission', () async {
      final result = await service.isAvailable();
      expect(result, isTrue);
      expect(log.last.method, 'hasPermission');
    });

    test('onFocusedTextChanged returns stream from channel', () async {
      final stream = service.onFocusedTextChanged();

      final texts = <String>[];
      final sub = stream.listen(texts.add);

      // Simulate native sending a text-changed event
      await _simulateNativeCallback(
        channel,
        'onFocusedTextChanged',
        'Updated text',
      );

      await Future<void>.delayed(Duration.zero);

      expect(texts, hasLength(1));
      expect(texts.first, 'Updated text');

      await sub.cancel();
    });

    test('setActiveTextFieldContent returns false when write fails',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return call.method == 'writeFocusedElement' ? false : null;
      });

      sharedChannel.dispose();
      sharedChannel = MacosAccessibilityChannel();
      service = MacosPlatformTextService(channel: sharedChannel);

      final result = await service.setActiveTextFieldContent('text');
      expect(result, isFalse);
    });

    test('getSelectedText returns null when nothing selected', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return call.method == 'getSelectedText' ? null : null;
      });

      sharedChannel.dispose();
      sharedChannel = MacosAccessibilityChannel();
      service = MacosPlatformTextService(channel: sharedChannel);

      final result = await service.getSelectedText();
      expect(result, isNull);
    });

    test('replaceSelectedText returns false when replace fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return call.method == 'replaceSelectedText' ? false : null;
      });

      sharedChannel.dispose();
      sharedChannel = MacosAccessibilityChannel();
      service = MacosPlatformTextService(channel: sharedChannel);

      final result = await service.replaceSelectedText('text');
      expect(result, isFalse);
    });

    test('isAvailable returns false when no permission', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return call.method == 'hasPermission' ? false : null;
      });

      sharedChannel.dispose();
      sharedChannel = MacosAccessibilityChannel();
      service = MacosPlatformTextService(channel: sharedChannel);

      final result = await service.isAvailable();
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
