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
    on<AiTemperatureChanged>(_onAiTemperatureChanged);
    on<AiTopPChanged>(_onAiTopPChanged);
    on<AiTopKChanged>(_onAiTopKChanged);
    on<AiRepeatPenaltyChanged>(_onAiRepeatPenaltyChanged);
    on<DebugMenuToggled>(_onDebugMenuToggled);
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

  Future<void> _onAiTemperatureChanged(
    AiTemperatureChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final normalized = event.temperature.clamp(0.0, 1.0).toDouble();
    final updated = state.preferences.copyWith(aiTemperature: normalized);
    emit(state.copyWith(preferences: updated));
    await _repository.saveAiTemperature(normalized);
  }

  Future<void> _onAiTopPChanged(
    AiTopPChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final normalized = event.topP.clamp(0.0, 1.0).toDouble();
    final updated = state.preferences.copyWith(aiTopP: normalized);
    emit(state.copyWith(preferences: updated));
    await _repository.saveAiTopP(normalized);
  }

  Future<void> _onAiTopKChanged(
    AiTopKChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final normalized = event.topK.clamp(0, 200);
    final updated = state.preferences.copyWith(aiTopK: normalized);
    emit(state.copyWith(preferences: updated));
    await _repository.saveAiTopK(normalized);
  }

  Future<void> _onAiRepeatPenaltyChanged(
    AiRepeatPenaltyChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final normalized = event.repeatPenalty.clamp(1.0, 2.0).toDouble();
    final updated = state.preferences.copyWith(aiRepeatPenalty: normalized);
    emit(state.copyWith(preferences: updated));
    await _repository.saveAiRepeatPenalty(normalized);
  }

  Future<void> _onDebugMenuToggled(
    DebugMenuToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.preferences.copyWith(showDebugMenu: event.enabled);
    emit(state.copyWith(preferences: updated));
    await _repository.saveShowDebugMenu(enabled: event.enabled);
  }
}
