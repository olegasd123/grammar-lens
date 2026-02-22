import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_event.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_state.dart';

/// Application settings page.
///
/// Allows the user to configure theme, language, auto-check behaviour,
/// and editor font size.
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
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'es', child: Text('Spanish')),
          DropdownMenuItem(value: 'fr', child: Text('French')),
          DropdownMenuItem(value: 'de', child: Text('German')),
          DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
        ],
      ),
    );
  }

  String _languageName(String code) {
    return switch (code) {
      'auto' => 'Auto-detect',
      'en' => 'English',
      'es' => 'Spanish',
      'fr' => 'French',
      'de' => 'German',
      'pt' => 'Portuguese',
      _ => code.toUpperCase(),
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
