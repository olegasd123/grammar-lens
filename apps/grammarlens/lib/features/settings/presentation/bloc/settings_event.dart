import 'package:flutter/material.dart';

/// Events for [SettingsBloc].
sealed class SettingsEvent {
  const SettingsEvent();
}

/// Load preferences from storage.
class SettingsLoaded extends SettingsEvent {
  const SettingsLoaded();
}

/// Change theme mode.
class ThemeModeChanged extends SettingsEvent {
  final ThemeMode themeMode;
  const ThemeModeChanged({required this.themeMode});
}

/// Change default language.
class DefaultLanguageChanged extends SettingsEvent {
  final String languageCode;
  const DefaultLanguageChanged({required this.languageCode});
}

/// Toggle auto-check on type.
class AutoCheckToggled extends SettingsEvent {
  final bool enabled;
  const AutoCheckToggled({required this.enabled});
}

/// Change editor font scale.
class EditorFontScaleChanged extends SettingsEvent {
  final double scale;
  const EditorFontScaleChanged({required this.scale});
}

/// Change AI temperature.
class AiTemperatureChanged extends SettingsEvent {
  final double temperature;
  const AiTemperatureChanged({required this.temperature});
}

/// Change AI top-p.
class AiTopPChanged extends SettingsEvent {
  final double topP;
  const AiTopPChanged({required this.topP});
}

/// Change AI top-k.
class AiTopKChanged extends SettingsEvent {
  final int topK;
  const AiTopKChanged({required this.topK});
}

/// Change AI repeat penalty.
class AiRepeatPenaltyChanged extends SettingsEvent {
  final double repeatPenalty;
  const AiRepeatPenaltyChanged({required this.repeatPenalty});
}

/// Toggle visibility of debug output page in top menu.
class DebugMenuToggled extends SettingsEvent {
  final bool enabled;
  const DebugMenuToggled({required this.enabled});
}
