import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = Logger('GlobalHotkeyService');

/// System-wide hotkey registration for desktop platforms.
///
/// Allows GrammarLens to be triggered from any application
/// via a global keyboard shortcut (e.g., Cmd+Shift+G).
class GlobalHotkeyService {
  static const _channel = MethodChannel('com.grammarlens/hotkey');

  final Map<String, VoidCallback> _registeredHotkeys = {};

  GlobalHotkeyService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Register a global hotkey.
  ///
  /// [shortcut] - Key combination string (e.g., "cmd+shift+g", "ctrl+shift+g").
  /// [onPressed] - Callback when the hotkey is pressed.
  ///
  /// The shortcut format uses modifier names separated by '+':
  /// - "cmd" / "ctrl" (platform-adaptive)
  /// - "shift"
  /// - "alt" / "option"
  /// - Single character key (a-z, 0-9)
  Future<void> registerHotkey(
    String shortcut,
    VoidCallback onPressed,
  ) async {
    try {
      await _channel.invokeMethod('registerHotkey', {'shortcut': shortcut});
      _registeredHotkeys[shortcut] = onPressed;
      _log.info('Registered global hotkey: $shortcut');
    } catch (e) {
      _log.warning('Failed to register hotkey $shortcut: $e');
    }
  }

  /// Unregister a previously registered hotkey.
  Future<void> unregisterHotkey(String shortcut) async {
    try {
      await _channel.invokeMethod('unregisterHotkey', {'shortcut': shortcut});
      _registeredHotkeys.remove(shortcut);
      _log.info('Unregistered global hotkey: $shortcut');
    } catch (e) {
      _log.warning('Failed to unregister hotkey $shortcut: $e');
    }
  }

  /// Unregister all hotkeys and clean up.
  Future<void> dispose() async {
    for (final shortcut in _registeredHotkeys.keys.toList()) {
      await unregisterHotkey(shortcut);
    }
  }

  /// Handle method calls from the native side when a hotkey is pressed.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onHotkeyPressed') {
      final shortcut = call.arguments as String?;
      if (shortcut != null && _registeredHotkeys.containsKey(shortcut)) {
        _registeredHotkeys[shortcut]!();
      }
    }
  }
}
