import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'package:platform_integration/src/clipboard_service.dart';

final _log = Logger('MacosClipboardService');

/// macOS implementation of [ClipboardService] with native clipboard monitoring.
///
/// Uses NSPasteboard `changeCount` polling via a MethodChannel to detect
/// clipboard changes from any application. The polling interval is ~500 ms
/// on the native side.
///
/// Call [dispose] when the service is no longer needed to stop polling.
class MacosClipboardService extends ClipboardService {
  static const _channel = MethodChannel('com.grammarlens/clipboard');

  final _controller = StreamController<String>.broadcast();
  bool _monitoring = false;

  MacosClipboardService() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  @override
  Stream<String> onClipboardChanged() {
    if (!_monitoring) {
      _startMonitoring();
    }
    return _controller.stream;
  }

  @override
  void dispose() {
    _stopMonitoring();
    _channel.setMethodCallHandler(null);
    _controller.close();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _startMonitoring() async {
    try {
      await _channel.invokeMethod<bool>('startMonitoring');
      _monitoring = true;
      _log.info('Clipboard monitoring started');
    } catch (e) {
      _log.warning('Failed to start clipboard monitoring: $e');
    }
  }

  Future<void> _stopMonitoring() async {
    if (!_monitoring) return;
    try {
      await _channel.invokeMethod<bool>('stopMonitoring');
      _monitoring = false;
      _log.info('Clipboard monitoring stopped');
    } catch (e) {
      _log.warning('Failed to stop clipboard monitoring: $e');
    }
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onClipboardChanged':
        final text = call.arguments as String?;
        if (text != null && !_controller.isClosed) {
          _controller.add(text);
        }
    }
  }
}
