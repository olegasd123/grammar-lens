/// Categories of text corrections.
enum CorrectionType {
  /// Grammatical errors (subject-verb agreement, tense, articles, etc.)
  grammar('grammar'),

  /// Spelling mistakes.
  spelling('spelling'),

  /// Punctuation errors (commas, periods, apostrophes, etc.)
  punctuation('punctuation'),

  /// Style suggestions (wordiness, passive voice, clarity, etc.)
  style('style');

  /// String identifier used in model output parsing.
  final String value;

  const CorrectionType(this.value);

  /// Parse a correction type from the model output string.
  ///
  /// Returns [CorrectionType.grammar] as fallback for unknown types.
  static CorrectionType fromString(String value) {
    return CorrectionType.values.firstWhere(
      (type) => type.value == value.toLowerCase().trim(),
      orElse: () => CorrectionType.grammar,
    );
  }
}
