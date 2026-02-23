import 'package:flutter/material.dart';

import 'package:grammarlens_ui/src/theme/app_typography.dart';

/// Supported language option for the selector.
class LanguageOption {
  /// ISO 639-1 code.
  final String code;

  /// Display name.
  final String name;

  /// Flag emoji.
  final String flag;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.flag,
  });
}

/// Dropdown selector for choosing the grammar check language.
class LanguageSelector extends StatelessWidget {
  /// Currently selected language code.
  final String selectedCode;

  /// Callback when a language is selected.
  final ValueChanged<String> onChanged;

  /// Whether "Auto-detect" option is shown.
  final bool showAutoDetect;

  const LanguageSelector({
    super.key,
    required this.selectedCode,
    required this.onChanged,
    this.showAutoDetect = true,
  });

  /// Default supported languages.
  static const defaultLanguages = [
    LanguageOption(code: 'ar', name: 'Arabic', flag: '\u{1F1F8}\u{1F1E6}'),
    LanguageOption(
      code: 'zh',
      name: 'Chinese (Simplified)',
      flag: '\u{1F1E8}\u{1F1F3}',
    ),
    LanguageOption(
      code: 'zh-hant',
      name: 'Chinese (Traditional)',
      flag: '\u{1F1F9}\u{1F1FC}',
    ),
    LanguageOption(code: 'cs', name: 'Czech', flag: '\u{1F1E8}\u{1F1FF}'),
    LanguageOption(code: 'nl', name: 'Dutch', flag: '\u{1F1F3}\u{1F1F1}'),
    LanguageOption(code: 'en', name: 'English', flag: '\u{1F1EC}\u{1F1E7}'),
    LanguageOption(code: 'fr', name: 'French', flag: '\u{1F1EB}\u{1F1F7}'),
    LanguageOption(code: 'de', name: 'German', flag: '\u{1F1E9}\u{1F1EA}'),
    LanguageOption(code: 'el', name: 'Greek', flag: '\u{1F1EC}\u{1F1F7}'),
    LanguageOption(code: 'he', name: 'Hebrew', flag: '\u{1F1EE}\u{1F1F1}'),
    LanguageOption(code: 'hi', name: 'Hindi', flag: '\u{1F1EE}\u{1F1F3}'),
    LanguageOption(
      code: 'id',
      name: 'Indonesian',
      flag: '\u{1F1EE}\u{1F1E9}',
    ),
    LanguageOption(code: 'it', name: 'Italian', flag: '\u{1F1EE}\u{1F1F9}'),
    LanguageOption(code: 'ja', name: 'Japanese', flag: '\u{1F1EF}\u{1F1F5}'),
    LanguageOption(code: 'ko', name: 'Korean', flag: '\u{1F1F0}\u{1F1F7}'),
    LanguageOption(code: 'fa', name: 'Persian', flag: '\u{1F1EE}\u{1F1F7}'),
    LanguageOption(code: 'pl', name: 'Polish', flag: '\u{1F1F5}\u{1F1F1}'),
    LanguageOption(code: 'pt', name: 'Portuguese', flag: '\u{1F1E7}\u{1F1F7}'),
    LanguageOption(code: 'ro', name: 'Romanian', flag: '\u{1F1F7}\u{1F1F4}'),
    LanguageOption(code: 'ru', name: 'Russian', flag: '\u{1F1F7}\u{1F1FA}'),
    LanguageOption(code: 'es', name: 'Spanish', flag: '\u{1F1EA}\u{1F1F8}'),
    LanguageOption(code: 'tr', name: 'Turkish', flag: '\u{1F1F9}\u{1F1F7}'),
    LanguageOption(
      code: 'uk',
      name: 'Ukrainian',
      flag: '\u{1F1FA}\u{1F1E6}',
    ),
    LanguageOption(
      code: 'vi',
      name: 'Vietnamese',
      flag: '\u{1F1FB}\u{1F1F3}',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[];

    if (showAutoDetect) {
      items.add(
        DropdownMenuItem(
          value: 'auto',
          child: Text(
            '\u{1F310}  Auto-detect',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }

    for (final lang in defaultLanguages) {
      items.add(
        DropdownMenuItem(
          value: lang.code,
          child: Text(
            '${lang.flag}  ${lang.name}',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }

    return DropdownButton<String>(
      value: selectedCode,
      items: items,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
