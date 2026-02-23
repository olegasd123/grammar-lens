import 'package:grammar_engine/src/models/correction.dart';
import 'package:grammar_engine/src/models/correction_type.dart';
import 'package:grammar_engine/src/models/language.dart';
import 'package:grammar_engine/src/statistics/text_statistics.dart';

/// Result of analyzing a text for grammar, spelling, and style issues.
class AnalysisResult {
  /// List of corrections found in the text.
  final List<Correction> corrections;

  /// Detected language of the text.
  final SupportedLanguage language;

  /// Text statistics (word count, readability, etc.)
  final TextStats? statistics;

  /// Time taken for the analysis in milliseconds.
  final int analysisTimeMs;

  /// Raw model output captured during analysis (for debugging).
  final String? rawModelOutput;

  const AnalysisResult({
    required this.corrections,
    required this.language,
    this.statistics,
    this.analysisTimeMs = 0,
    this.rawModelOutput,
  });

  /// Number of corrections found.
  int get correctionCount => corrections.length;

  /// Number of grammar corrections.
  int get grammarCount =>
      corrections.where((c) => c.type == CorrectionType.grammar).length;

  /// Number of spelling corrections.
  int get spellingCount =>
      corrections.where((c) => c.type == CorrectionType.spelling).length;

  /// Number of punctuation corrections.
  int get punctuationCount =>
      corrections.where((c) => c.type == CorrectionType.punctuation).length;

  /// Number of style suggestions.
  int get styleCount =>
      corrections.where((c) => c.type == CorrectionType.style).length;

  /// Whether the text has any issues.
  bool get hasIssues => corrections.isNotEmpty;

  /// Empty result with no corrections.
  static AnalysisResult empty(SupportedLanguage language) {
    return AnalysisResult(
      corrections: const [],
      language: language,
    );
  }

  @override
  String toString() {
    return 'AnalysisResult('
        'corrections: $correctionCount, '
        'language: ${language.displayName}, '
        'time: ${analysisTimeMs}ms)';
  }
}
