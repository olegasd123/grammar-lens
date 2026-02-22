/// Core grammar analysis engine for GrammarLens.
///
/// Provides sentence splitting, prompt building, correction parsing,
/// language detection, text statistics, and diff computation.
/// This package is pure Dart with no Flutter dependency.
library;

// Analyzer
export 'src/analyzer/correction_parser.dart';
export 'src/analyzer/grammar_analyzer.dart';
export 'src/analyzer/prompt_builder.dart';
export 'src/analyzer/sentence_splitter.dart';

// Diff
export 'src/diff/diff_result.dart';
export 'src/diff/text_differ.dart';

// Language Detection
export 'src/language_detection/language_detector.dart';

// Models
export 'src/models/analysis_result.dart';
export 'src/models/correction.dart';
export 'src/models/correction_type.dart';
export 'src/models/language.dart';

// Statistics
export 'src/statistics/readability_scorer.dart';
export 'src/statistics/text_statistics.dart';
