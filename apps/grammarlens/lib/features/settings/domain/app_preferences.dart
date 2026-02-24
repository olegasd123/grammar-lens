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

  /// Sampling temperature for AI requests.
  final double aiTemperature;

  /// Nucleus sampling threshold for AI requests.
  final double aiTopP;

  /// Top-K sampling for AI requests. 0 = disabled.
  final int aiTopK;

  /// Repetition penalty for AI requests. 1.0 = disabled.
  final double aiRepeatPenalty;

  /// Whether to show the debug output page in the top menu.
  final bool showDebugMenu;

  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.defaultLanguage = 'auto',
    this.autoCheck = true,
    this.editorFontScale = 1.0,
    this.aiTemperature = 0.1,
    this.aiTopP = 0.9,
    this.aiTopK = 40,
    this.aiRepeatPenalty = 1.1,
    this.showDebugMenu = true,
  });

  AppPreferences copyWith({
    ThemeMode? themeMode,
    String? defaultLanguage,
    bool? autoCheck,
    double? editorFontScale,
    double? aiTemperature,
    double? aiTopP,
    int? aiTopK,
    double? aiRepeatPenalty,
    bool? showDebugMenu,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      autoCheck: autoCheck ?? this.autoCheck,
      editorFontScale: editorFontScale ?? this.editorFontScale,
      aiTemperature: aiTemperature ?? this.aiTemperature,
      aiTopP: aiTopP ?? this.aiTopP,
      aiTopK: aiTopK ?? this.aiTopK,
      aiRepeatPenalty: aiRepeatPenalty ?? this.aiRepeatPenalty,
      showDebugMenu: showDebugMenu ?? this.showDebugMenu,
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
          editorFontScale == other.editorFontScale &&
          aiTemperature == other.aiTemperature &&
          aiTopP == other.aiTopP &&
          aiTopK == other.aiTopK &&
          aiRepeatPenalty == other.aiRepeatPenalty &&
          showDebugMenu == other.showDebugMenu;

  @override
  int get hashCode => Object.hash(
        themeMode,
        defaultLanguage,
        autoCheck,
        editorFontScale,
        aiTemperature,
        aiTopP,
        aiTopK,
        aiRepeatPenalty,
        showDebugMenu,
      );
}
