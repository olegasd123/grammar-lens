import 'package:flutter/services.dart';

/// Cross-platform clipboard access.
///
/// Provides a unified API for reading/writing the system clipboard
/// with change notifications where supported.
class ClipboardService {
  const ClipboardService();

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
  /// Note: Clipboard change monitoring is not supported on all platforms.
  /// On unsupported platforms, this stream never emits.
  ///
  /// TODO: Implement platform-specific clipboard monitoring:
  /// - macOS: NSPasteboard changeCount polling
  /// - Windows: AddClipboardFormatListener
  /// - Linux: X11 selection notifications
  /// - iOS/Android: Not reliably supported
  Stream<String> onClipboardChanged() {
    // Placeholder — will be implemented per-platform
    return const Stream.empty();
  }
}
