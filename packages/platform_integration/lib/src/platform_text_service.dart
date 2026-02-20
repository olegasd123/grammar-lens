/// Abstract interface for reading/writing text in the currently
/// focused text field across any application.
///
/// Each platform has a different implementation:
/// - macOS: Accessibility API (AXUIElement)
/// - Windows: UI Automation (IUIAutomation)
/// - Linux: AT-SPI / IBus
/// - iOS: Keyboard Extension with App Groups IPC
/// - Android: AccessibilityService / InputMethodService
abstract class PlatformTextService {
  /// Read the full text content of the focused text field.
  ///
  /// Returns null if no text field is focused or access is denied.
  Future<String?> getActiveTextFieldContent();

  /// Replace the full text of the focused text field.
  ///
  /// Returns true if the text was successfully updated.
  Future<bool> setActiveTextFieldContent(String text);

  /// Read only the currently selected text.
  ///
  /// Returns null if nothing is selected or no text field is focused.
  Future<String?> getSelectedText();

  /// Replace the current text selection with [replacement].
  ///
  /// Returns true if the replacement was successful.
  Future<bool> replaceSelectedText(String replacement);

  /// Stream of text changes in the focused text field.
  ///
  /// Emits whenever the text content changes.
  Stream<String> onFocusedTextChanged();

  /// Check if platform text integration is available and permitted.
  ///
  /// On macOS, this checks Accessibility permission.
  /// On Android, this checks AccessibilityService status.
  Future<bool> isAvailable();
}
