import 'dart:async';

import 'package:platform_integration/src/accessibility_service.dart';
import 'package:platform_integration/src/macos/macos_accessibility_channel.dart';

/// macOS implementation of [AccessibilityService] using AXUIElement APIs.
///
/// Delegates all MethodChannel communication to a shared
/// [MacosAccessibilityChannel] instance.
class MacosAccessibilityService implements AccessibilityService {
  final MacosAccessibilityChannel _channel;

  MacosAccessibilityService({required MacosAccessibilityChannel channel})
      : _channel = channel;

  @override
  Future<bool> requestPermission() async {
    final result = await _channel.invoke<bool>('requestPermission');
    return result ?? false;
  }

  @override
  Future<bool> hasPermission() async {
    final result = await _channel.invoke<bool>('hasPermission');
    return result ?? false;
  }

  @override
  Future<String?> readFocusedElement() {
    return _channel.invoke<String?>('readFocusedElement');
  }

  @override
  Future<bool> writeFocusedElement(String text) async {
    final result = await _channel.invoke<bool>(
      'writeFocusedElement',
      {'text': text},
    );
    return result ?? false;
  }

  @override
  Stream<FocusEvent> onFocusChanged() {
    _channel.invoke<bool>('startFocusMonitoring');
    return _channel.focusChanges;
  }

  @override
  Future<String?> getFocusedAppName() {
    return _channel.invoke<String?>('getFocusedAppName');
  }
}
