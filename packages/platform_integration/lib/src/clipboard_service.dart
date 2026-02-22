import 'package:flutter/services.dart';

/// Cross-platform clipboard access.
///
/// Provides a unified API for reading/writing the system clipboard
/// with change notifications where supported.
///
/// Platform-specific subclasses override [onClipboardChanged] to
/// provide native clipboard monitoring:
/// - macOS: [MacosClipboardService] using NSPasteboard changeCount polling
/// - Windows: AddClipboardFormatListener (future)
/// - Linux: X11 selection notifications (future)
/// - iOS/Android: Not reliably supported
class ClipboardService {
  ClipboardService();

  /// Read text from the system clipboard.
  ///
  /// Returns null if the clipboard is empty or doesn't contain text.
  Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  /// Write text to the system clipboard.
  Future<void> setText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Watch for clipboard changes.
  ///
  /// Emits the new clipboard text whenever it changes.
  /// On unsupported platforms, this stream never emits.
  ///
  /// Override in platform-specific subclasses to provide native monitoring.
  Stream<String> onClipboardChanged() {
    return const Stream.empty();
  }

  /// Release resources used by clipboard monitoring.
  ///
  /// Subclasses should override to stop native polling / listeners.
  void dispose() {}
}
