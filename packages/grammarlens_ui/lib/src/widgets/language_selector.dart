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
    LanguageOption(code: 'en', name: 'English', flag: '\u{1F1EC}\u{1F1E7}'),
    LanguageOption(code: 'es', name: 'Spanish', flag: '\u{1F1EA}\u{1F1F8}'),
    LanguageOption(code: 'fr', name: 'French', flag: '\u{1F1EB}\u{1F1F7}'),
    LanguageOption(code: 'de', name: 'German', flag: '\u{1F1E9}\u{1F1EA}'),
    LanguageOption(code: 'pt', name: 'Portuguese', flag: '\u{1F1E7}\u{1F1F7}'),
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
    );
  }
}
