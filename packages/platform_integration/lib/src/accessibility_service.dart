/// Event emitted when the focused UI element changes.
class FocusEvent {
  /// The name of the application that has focus.
  final String appName;

  /// The type of UI element (e.g., "TextField", "TextArea", "ContentEditable").
  final String elementType;

  /// The text content of the focused element (if readable).
  final String? text;

  const FocusEvent({
    required this.appName,
    required this.elementType,
    this.text,
  });

  @override
  String toString() =>
      'FocusEvent(app: $appName, type: $elementType, text: ${text?.length ?? 0} chars)';
}

/// Abstract interface for OS-level accessibility integration.
///
/// Used on desktop platforms to read and write text in arbitrary
/// applications (Notes, Teams, text editors, etc.) via the
/// platform's accessibility framework.
///
/// Implementations:
/// - macOS: `AccessibilityBridge` using AXUIElement
/// - Windows: `UIAutomationBridge` using IUIAutomation
/// - Linux: AT-SPI bridge
abstract class AccessibilityService {
  /// Request accessibility permission from the user.
  ///
  /// On macOS, this opens the Accessibility pane in System Preferences.
  /// On Android, this navigates to the Accessibility settings.
  /// Returns true if permission was already granted.
  Future<bool> requestPermission();

  /// Check if accessibility permission is currently granted.
  Future<bool> hasPermission();

  /// Read the text content of the currently focused UI element.
  ///
  /// Returns null if:
  /// - No element is focused
  /// - The focused element is not a text field
  /// - Permission is not granted
  Future<String?> readFocusedElement();

  /// Write text to the currently focused UI element.
  ///
  /// Returns true if the text was successfully updated.
  /// Returns false if the element is not writable or permission is denied.
  Future<bool> writeFocusedElement(String text);

  /// Stream of focus change events.
  ///
  /// Emits whenever the user focuses a different UI element.
  /// Useful for tracking when the user moves to a new text field.
  Stream<FocusEvent> onFocusChanged();

  /// Get the name of the currently focused application.
  Future<String?> getFocusedAppName();
}
