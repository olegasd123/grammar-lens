import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grammarlens/features/settings/domain/app_preferences.dart';

/// Keys for SharedPreferences storage.
abstract final class _Keys {
  static const themeMode = 'pref_theme_mode';
  static const defaultLanguage = 'pref_default_language';
  static const autoCheck = 'pref_auto_check';
  static const editorFontScale = 'pref_editor_font_scale';
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
    final themeMode = themeModeIndex != null && themeModeIndex < ThemeMode.values.length
        ? ThemeMode.values[themeModeIndex]
        : ThemeMode.system;

    return AppPreferences(
      themeMode: themeMode,
      defaultLanguage: prefs.getString(_Keys.defaultLanguage) ?? 'auto',
      autoCheck: prefs.getBool(_Keys.autoCheck) ?? true,
      editorFontScale: prefs.getDouble(_Keys.editorFontScale) ?? 1.0,
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
}
