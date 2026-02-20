/// Languages supported by GrammarLens.
enum SupportedLanguage {
  english('en', 'English'),
  spanish('es', 'Spanish'),
  french('fr', 'French'),
  german('de', 'German'),
  portuguese('pt', 'Portuguese');

  /// ISO 639-1 language code.
  final String code;

  /// Human-readable display name.
  final String displayName;

  const SupportedLanguage(this.code, this.displayName);

  /// Look up a language by its ISO 639-1 code.
  ///
  /// Throws [ArgumentError] if the code is not supported.
  static SupportedLanguage fromCode(String code) {
    return SupportedLanguage.values.firstWhere(
      (lang) => lang.code == code.toLowerCase(),
      orElse: () => throw ArgumentError('Unsupported language code: $code'),
    );
  }
}
