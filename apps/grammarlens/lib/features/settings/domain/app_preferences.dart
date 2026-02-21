import 'package:flutter/material.dart';

/// Immutable snapshot of user preferences.
class AppPreferences {
  /// Theme mode: system, light, or dark.
  final ThemeMode themeMode;

  /// Default language code (e.g., 'en', 'auto').
  final String defaultLanguage;

  /// Whether to auto-check text as the user types.
  final bool autoCheck;

  /// Editor font size scale factor (1.0 = normal).
  final double editorFontScale;

  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.defaultLanguage = 'auto',
    this.autoCheck = true,
    this.editorFontScale = 1.0,
  });

  AppPreferences copyWith({
    ThemeMode? themeMode,
    String? defaultLanguage,
    bool? autoCheck,
    double? editorFontScale,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      autoCheck: autoCheck ?? this.autoCheck,
      editorFontScale: editorFontScale ?? this.editorFontScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPreferences &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          defaultLanguage == other.defaultLanguage &&
          autoCheck == other.autoCheck &&
          editorFontScale == other.editorFontScale;

  @override
  int get hashCode => Object.hash(
        themeMode,
        defaultLanguage,
        autoCheck,
        editorFontScale,
      );
}
