import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_event.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_state.dart';

/// Application settings page.
///
/// Allows the user to configure theme, language, auto-check behaviour,
/// editor font size, and AI sampling parameters.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (!state.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final prefs = state.preferences;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Appearance ──────────────────────────────────
              Text('Appearance', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _ThemeModeTile(
                      current: prefs.themeMode,
                      onChanged: (mode) {
                        context.read<SettingsBloc>().add(
                              ThemeModeChanged(themeMode: mode),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    _FontScaleTile(
                      scale: prefs.editorFontScale,
                      onChanged: (scale) {
                        context.read<SettingsBloc>().add(
                              EditorFontScaleChanged(scale: scale),
                            );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Language & Analysis ─────────────────────────
              Text('Language & Analysis', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _DefaultLanguageTile(
                      current: prefs.defaultLanguage,
                      onChanged: (code) {
                        context.read<SettingsBloc>().add(
                              DefaultLanguageChanged(languageCode: code),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Auto-check while typing'),
                      subtitle: const Text(
                        'Analyse text as you type. Disable to check manually.',
                      ),
                      value: prefs.autoCheck,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                              AutoCheckToggled(enabled: value),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Show Debug Output in Menu'),
                      subtitle: const Text(
                        'Show a Debug page button in the top menu.',
                      ),
                      value: prefs.showDebugMenu,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                              DebugMenuToggled(enabled: value),
                            );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── AI Sampling ────────────────────────────────
              Text('AI Sampling', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _AiTemperatureTile(
                      temperature: prefs.aiTemperature,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                              AiTemperatureChanged(temperature: value),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    _AiTopPTile(
                      topP: prefs.aiTopP,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                              AiTopPChanged(topP: value),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    _AiTopKTile(
                      topK: prefs.aiTopK,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                              AiTopKChanged(topK: value),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    _AiRepeatPenaltyTile(
                      repeatPenalty: prefs.aiRepeatPenalty,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                              AiRepeatPenaltyChanged(repeatPenalty: value),
                            );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── About ──────────────────────────────────────
              Text('About', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GrammarLens', style: AppTypography.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Version 0.1.0',
                        style: AppTypography.bodySmall.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Privacy-first grammar checker powered by on-device AI. '
                        'All processing happens locally — your text never '
                        'leaves your device.',
                        style: AppTypography.bodySmall.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Theme mode selector tile.
class _ThemeModeTile extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeTile({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Theme'),
      subtitle: Text(_label(current)),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto),
            label: Text('Auto'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode),
            label: Text('Light'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode),
            label: Text('Dark'),
          ),
        ],
        selected: {current},
        onSelectionChanged: (selection) {
          onChanged(selection.first);
        },
      ),
    );
  }

  String _label(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Follow system setting',
      ThemeMode.light => 'Always light',
      ThemeMode.dark => 'Always dark',
    };
  }
}

/// Default language selector tile.
class _DefaultLanguageTile extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _DefaultLanguageTile({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Default Language'),
      subtitle: Text(_languageName(current)),
      trailing: DropdownButton<String>(
        value: current,
        underline: const SizedBox.shrink(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        items: const [
          DropdownMenuItem(value: 'auto', child: Text('Auto-detect')),
          DropdownMenuItem(value: 'ar', child: Text('Arabic')),
          DropdownMenuItem(
            value: 'zh',
            child: Text('Chinese (Simplified)'),
          ),
          DropdownMenuItem(
            value: 'zh-hant',
            child: Text('Chinese (Traditional)'),
          ),
          DropdownMenuItem(value: 'cs', child: Text('Czech')),
          DropdownMenuItem(value: 'nl', child: Text('Dutch')),
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'fr', child: Text('French')),
          DropdownMenuItem(value: 'de', child: Text('German')),
          DropdownMenuItem(value: 'el', child: Text('Greek')),
          DropdownMenuItem(value: 'he', child: Text('Hebrew')),
          DropdownMenuItem(value: 'hi', child: Text('Hindi')),
          DropdownMenuItem(value: 'id', child: Text('Indonesian')),
          DropdownMenuItem(value: 'it', child: Text('Italian')),
          DropdownMenuItem(value: 'ja', child: Text('Japanese')),
          DropdownMenuItem(value: 'ko', child: Text('Korean')),
          DropdownMenuItem(value: 'fa', child: Text('Persian')),
          DropdownMenuItem(value: 'pl', child: Text('Polish')),
          DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
          DropdownMenuItem(value: 'ro', child: Text('Romanian')),
          DropdownMenuItem(value: 'ru', child: Text('Russian')),
          DropdownMenuItem(value: 'es', child: Text('Spanish')),
          DropdownMenuItem(value: 'tr', child: Text('Turkish')),
          DropdownMenuItem(value: 'uk', child: Text('Ukrainian')),
          DropdownMenuItem(value: 'vi', child: Text('Vietnamese')),
        ],
      ),
    );
  }

  String _languageName(String code) {
    final normalized = code.trim().toLowerCase();
    return switch (normalized) {
      'auto' => 'Auto-detect',
      'ar' => 'Arabic',
      'zh' => 'Chinese (Simplified)',
      'zh-hans' => 'Chinese (Simplified)',
      'zh-hant' => 'Chinese (Traditional)',
      'zh-tw' => 'Chinese (Traditional)',
      'zh-hk' => 'Chinese (Traditional)',
      'zh-mo' => 'Chinese (Traditional)',
      'cs' => 'Czech',
      'nl' => 'Dutch',
      'en' => 'English',
      'fr' => 'French',
      'de' => 'German',
      'el' => 'Greek',
      'he' => 'Hebrew',
      'hi' => 'Hindi',
      'id' => 'Indonesian',
      'it' => 'Italian',
      'ja' => 'Japanese',
      'ko' => 'Korean',
      'fa' => 'Persian',
      'pl' => 'Polish',
      'pt' => 'Portuguese',
      'ro' => 'Romanian',
      'ru' => 'Russian',
      'es' => 'Spanish',
      'tr' => 'Turkish',
      'uk' => 'Ukrainian',
      'vi' => 'Vietnamese',
      _ => normalized.toUpperCase(),
    };
  }
}

/// Editor font scale slider tile.
class _FontScaleTile extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;

  const _FontScaleTile({
    required this.scale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Editor Font Size'),
      subtitle: Slider(
        value: scale,
        min: 0.8,
        max: 1.6,
        divisions: 8,
        label: '${(scale * 100).toStringAsFixed(0)}%',
        onChanged: onChanged,
      ),
      trailing: Text(
        '${(scale * 100).toStringAsFixed(0)}%',
        style: AppTypography.labelMedium,
      ),
    );
  }
}

/// AI temperature slider tile.
class _AiTemperatureTile extends StatelessWidget {
  final double temperature;
  final ValueChanged<double> onChanged;

  const _AiTemperatureTile({
    required this.temperature,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('AI Temperature'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Higher value gives more random suggestions.'),
          Slider(
            value: temperature,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: temperature.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ],
      ),
      trailing: Text(
        temperature.toStringAsFixed(2),
        style: AppTypography.labelMedium,
      ),
    );
  }
}

/// AI top-p slider tile.
class _AiTopPTile extends StatelessWidget {
  final double topP;
  final ValueChanged<double> onChanged;

  const _AiTopPTile({
    required this.topP,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('AI Top-p'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lower value keeps only safer token choices.'),
          Slider(
            value: topP,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: topP.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ],
      ),
      trailing: Text(
        topP.toStringAsFixed(2),
        style: AppTypography.labelMedium,
      ),
    );
  }
}

/// AI top-k slider tile.
class _AiTopKTile extends StatelessWidget {
  final int topK;
  final ValueChanged<int> onChanged;

  const _AiTopKTile({
    required this.topK,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('AI Top-k'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lower value limits choices. 0 means disabled.'),
          Slider(
            value: topK.toDouble(),
            min: 0,
            max: 200,
            divisions: 40,
            label: '$topK',
            onChanged: (value) => onChanged(value.round()),
          ),
        ],
      ),
      trailing: Text(
        '$topK',
        style: AppTypography.labelMedium,
      ),
    );
  }
}

/// AI repeat-penalty slider tile.
class _AiRepeatPenaltyTile extends StatelessWidget {
  final double repeatPenalty;
  final ValueChanged<double> onChanged;

  const _AiRepeatPenaltyTile({
    required this.repeatPenalty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('AI Repeat Penalty'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Higher value reduces repeated words.'),
          Slider(
            value: repeatPenalty,
            min: 1.0,
            max: 2.0,
            divisions: 20,
            label: repeatPenalty.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ],
      ),
      trailing: Text(
        repeatPenalty.toStringAsFixed(2),
        style: AppTypography.labelMedium,
      ),
    );
  }
}
