import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens/features/settings/data/preferences_repository.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_event.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_state.dart';

/// Manages application settings / user preferences.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final PreferencesRepository _repository;

  SettingsBloc({required PreferencesRepository repository})
      : _repository = repository,
        super(const SettingsState()) {
    on<SettingsLoaded>(_onLoaded);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<DefaultLanguageChanged>(_onDefaultLanguageChanged);
    on<AutoCheckToggled>(_onAutoCheckToggled);
    on<EditorFontScaleChanged>(_onEditorFontScaleChanged);
  }

  Future<void> _onLoaded(
    SettingsLoaded event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await _repository.load();
    emit(state.copyWith(preferences: prefs, isLoaded: true));
  }

  Future<void> _onThemeModeChanged(
    ThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.preferences.copyWith(themeMode: event.themeMode);
    emit(state.copyWith(preferences: updated));
    await _repository.saveThemeMode(event.themeMode);
  }

  Future<void> _onDefaultLanguageChanged(
    DefaultLanguageChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated =
        state.preferences.copyWith(defaultLanguage: event.languageCode);
    emit(state.copyWith(preferences: updated));
    await _repository.saveDefaultLanguage(event.languageCode);
  }

  Future<void> _onAutoCheckToggled(
    AutoCheckToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.preferences.copyWith(autoCheck: event.enabled);
    emit(state.copyWith(preferences: updated));
    await _repository.saveAutoCheck(enabled: event.enabled);
  }

  Future<void> _onEditorFontScaleChanged(
    EditorFontScaleChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.preferences.copyWith(editorFontScale: event.scale);
    emit(state.copyWith(preferences: updated));
    await _repository.saveEditorFontScale(event.scale);
  }
}
