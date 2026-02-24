import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grammarlens/features/settings/domain/app_preferences.dart';

/// Keys for SharedPreferences storage.
abstract final class _Keys {
  static const themeMode = 'pref_theme_mode';
  static const defaultLanguage = 'pref_default_language';
  static const autoCheck = 'pref_auto_check';
  static const editorFontScale = 'pref_editor_font_scale';
  static const aiTemperature = 'pref_ai_temperature';
  static const aiTopP = 'pref_ai_top_p';
  static const aiTopK = 'pref_ai_top_k';
  static const aiRepeatPenalty = 'pref_ai_repeat_penalty';
  static const showDebugMenu = 'pref_show_debug_menu';
}

/// Persists and loads [AppPreferences] via SharedPreferences.
class PreferencesRepository {
  SharedPreferences? _prefs;

  /// Ensure SharedPreferences instance is initialised.
  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Load all preferences from disk.
  Future<AppPreferences> load() async {
    final prefs = await _ensurePrefs();

    final themeModeIndex = prefs.getInt(_Keys.themeMode);
    final themeMode =
        themeModeIndex != null && themeModeIndex < ThemeMode.values.length
            ? ThemeMode.values[themeModeIndex]
            : ThemeMode.system;
    final aiTemperature = _normalizeTemperature(
      prefs.getDouble(_Keys.aiTemperature),
    );
    final aiTopP = _normalizeTopP(prefs.getDouble(_Keys.aiTopP));
    final aiTopK = _normalizeTopK(prefs.getInt(_Keys.aiTopK));
    final aiRepeatPenalty = _normalizeRepeatPenalty(
      prefs.getDouble(_Keys.aiRepeatPenalty),
    );

    return AppPreferences(
      themeMode: themeMode,
      defaultLanguage: prefs.getString(_Keys.defaultLanguage) ?? 'auto',
      autoCheck: prefs.getBool(_Keys.autoCheck) ?? true,
      editorFontScale: prefs.getDouble(_Keys.editorFontScale) ?? 1.0,
      aiTemperature: aiTemperature,
      aiTopP: aiTopP,
      aiTopK: aiTopK,
      aiRepeatPenalty: aiRepeatPenalty,
      showDebugMenu: prefs.getBool(_Keys.showDebugMenu) ?? true,
    );
  }

  /// Persist a single preference change.
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(_Keys.themeMode, mode.index);
  }

  /// Persist the default language setting.
  Future<void> saveDefaultLanguage(String languageCode) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_Keys.defaultLanguage, languageCode);
  }

  /// Persist the auto-check toggle.
  Future<void> saveAutoCheck({required bool enabled}) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_Keys.autoCheck, enabled);
  }

  /// Persist the editor font scale.
  Future<void> saveEditorFontScale(double scale) async {
    final prefs = await _ensurePrefs();
    await prefs.setDouble(_Keys.editorFontScale, scale);
  }

  /// Persist the AI temperature.
  Future<void> saveAiTemperature(double temperature) async {
    final prefs = await _ensurePrefs();
    await prefs.setDouble(
      _Keys.aiTemperature,
      _normalizeTemperature(temperature),
    );
  }

  /// Persist AI top-p.
  Future<void> saveAiTopP(double topP) async {
    final prefs = await _ensurePrefs();
    await prefs.setDouble(_Keys.aiTopP, _normalizeTopP(topP));
  }

  /// Persist AI top-k.
  Future<void> saveAiTopK(int topK) async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(_Keys.aiTopK, _normalizeTopK(topK));
  }

  /// Persist AI repeat penalty.
  Future<void> saveAiRepeatPenalty(double repeatPenalty) async {
    final prefs = await _ensurePrefs();
    await prefs.setDouble(
      _Keys.aiRepeatPenalty,
      _normalizeRepeatPenalty(repeatPenalty),
    );
  }

  /// Persist visibility of the debug menu item.
  Future<void> saveShowDebugMenu({required bool enabled}) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_Keys.showDebugMenu, enabled);
  }

  double _normalizeTemperature(double? value) {
    if (value == null || value.isNaN || !value.isFinite) {
      return 0.0;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  double _normalizeTopP(double? value) {
    if (value == null || value.isNaN || !value.isFinite) {
      return 0.9;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  int _normalizeTopK(int? value) {
    if (value == null) {
      return 10;
    }
    return value.clamp(0, 200);
  }

  double _normalizeRepeatPenalty(double? value) {
    if (value == null || value.isNaN || !value.isFinite) {
      return 1.1;
    }
    return value.clamp(1.0, 2.0).toDouble();
  }
}
