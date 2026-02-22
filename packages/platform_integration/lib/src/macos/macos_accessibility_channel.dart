import 'dart:async';

import 'package:flutter/services.dart';
import 'package:platform_integration/platform_integration.dart' show MacosAccessibilityService, MacosPlatformTextService;

import 'package:platform_integration/src/accessibility_service.dart';
import 'package:platform_integration/src/macos/macos_accessibility_service.dart' show MacosAccessibilityService;
import 'package:platform_integration/src/macos/macos_platform_text_service.dart' show MacosPlatformTextService;

/// Shared MethodChannel manager for macOS accessibility and text services.
///
/// Both [MacosAccessibilityService] and [MacosPlatformTextService] delegate
/// to this class, which holds the single MethodChannel handler. This avoids
/// the Flutter restriction of one handler per channel.
class MacosAccessibilityChannel {
  static const _channel = MethodChannel('com.grammarlens/accessibility');

  final _focusController = StreamController<FocusEvent>.broadcast();
  final _textChangedController = StreamController<String>.broadcast();

  /// Stream of focus change events from the native side.
  Stream<FocusEvent> get focusChanges => _focusController.stream;

  /// Stream of text-changed events for the focused element.
  Stream<String> get textChanges => _textChangedController.stream;

  MacosAccessibilityChannel() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  /// Invoke a method on the native accessibility channel.
  Future<T?> invoke<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  /// Dispose of streams and clear the method call handler.
  void dispose() {
    _channel.setMethodCallHandler(null);
    _focusController.close();
    _textChangedController.close();
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onFocusChanged':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _focusController.add(FocusEvent(
          appName: args['appName'] as String? ?? '',
          elementType: args['elementType'] as String? ?? '',
          text: args['text'] as String?,
        ),);
      case 'onFocusedTextChanged':
        final text = call.arguments as String?;
        if (text != null) {
          _textChangedController.add(text);
        }
    }
  }
}
