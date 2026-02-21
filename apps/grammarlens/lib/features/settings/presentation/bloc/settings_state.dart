import 'package:grammarlens/features/settings/domain/app_preferences.dart';

/// State for [SettingsBloc].
class SettingsState {
  /// Current preferences.
  final AppPreferences preferences;

  /// Whether preferences have been loaded.
  final bool isLoaded;

  const SettingsState({
    this.preferences = const AppPreferences(),
    this.isLoaded = false,
  });

  SettingsState copyWith({
    AppPreferences? preferences,
    bool? isLoaded,
  }) {
    return SettingsState(
      preferences: preferences ?? this.preferences,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}
