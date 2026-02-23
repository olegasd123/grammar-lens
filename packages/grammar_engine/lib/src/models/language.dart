/// Languages supported by GrammarLens.
enum SupportedLanguage {
  arabic('ar', 'Arabic'),
  chineseSimplified('zh', 'Chinese (Simplified)'),
  chineseTraditional('zh-hant', 'Chinese (Traditional)'),
  czech('cs', 'Czech'),
  dutch('nl', 'Dutch'),
  english('en', 'English'),
  french('fr', 'French'),
  german('de', 'German'),
  greek('el', 'Greek'),
  hebrew('he', 'Hebrew'),
  hindi('hi', 'Hindi'),
  indonesian('id', 'Indonesian'),
  italian('it', 'Italian'),
  japanese('ja', 'Japanese'),
  korean('ko', 'Korean'),
  persian('fa', 'Persian'),
  polish('pl', 'Polish'),
  portuguese('pt', 'Portuguese'),
  romanian('ro', 'Romanian'),
  russian('ru', 'Russian'),
  spanish('es', 'Spanish'),
  turkish('tr', 'Turkish'),
  ukrainian('uk', 'Ukrainian'),
  vietnamese('vi', 'Vietnamese');

  /// ISO 639-1 language code.
  final String code;

  /// Human-readable display name.
  final String displayName;

  const SupportedLanguage(this.code, this.displayName);

  /// Look up a language by its ISO 639-1 code.
  ///
  /// Throws [ArgumentError] if the code is not supported.
  static SupportedLanguage fromCode(String code) {
    final normalized = _normalizeCode(code);
    return SupportedLanguage.values.firstWhere(
      (lang) => lang.code == normalized,
      orElse: () => throw ArgumentError('Unsupported language code: $code'),
    );
  }

  static String _normalizeCode(String code) {
    final normalized = code.trim().toLowerCase();
    return switch (normalized) {
      'zh' || 'zh-cn' || 'zh-sg' || 'zh-hans' => 'zh',
      'zh-hant' || 'zh-tw' || 'zh-hk' || 'zh-mo' => 'zh-hant',
      _ => normalized,
    };
  }
}
