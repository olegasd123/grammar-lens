import 'dart:async';

import 'package:platform_integration/src/macos/macos_accessibility_channel.dart';
import 'package:platform_integration/src/platform_text_service.dart';

/// macOS implementation of [PlatformTextService] using AXUIElement APIs.
///
/// Shares the same [MacosAccessibilityChannel] as [MacosAccessibilityService],
/// since both are backed by the same native AXUIElement bridge.
class MacosPlatformTextService implements PlatformTextService {
  final MacosAccessibilityChannel _channel;

  MacosPlatformTextService({required MacosAccessibilityChannel channel})
      : _channel = channel;

  @override
  Future<String?> getActiveTextFieldContent() {
    return _channel.invoke<String?>('readFocusedElement');
  }

  @override
  Future<bool> setActiveTextFieldContent(String text) async {
    final result = await _channel.invoke<bool>(
      'writeFocusedElement',
      {'text': text},
    );
    return result ?? false;
  }

  @override
  Future<String?> getSelectedText() {
    return _channel.invoke<String?>('getSelectedText');
  }

  @override
  Future<bool> replaceSelectedText(String replacement) async {
    final result = await _channel.invoke<bool>(
      'replaceSelectedText',
      {'text': replacement},
    );
    return result ?? false;
  }

  @override
  Stream<String> onFocusedTextChanged() => _channel.textChanges;

  @override
  Future<bool> isAvailable() async {
    final result = await _channel.invoke<bool>('hasPermission');
    return result ?? false;
  }
}
