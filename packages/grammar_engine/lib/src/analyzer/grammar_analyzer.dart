import 'package:grammar_engine/src/analyzer/correction_parser.dart';
import 'package:grammar_engine/src/analyzer/prompt_builder.dart';
import 'package:grammar_engine/src/analyzer/sentence_splitter.dart';
import 'package:grammar_engine/src/language_detection/language_detector.dart';
import 'package:grammar_engine/src/models/analysis_result.dart';
import 'package:grammar_engine/src/models/correction.dart';
import 'package:grammar_engine/src/models/language.dart';
import 'package:grammar_engine/src/statistics/text_statistics.dart';

/// Callback type for running model inference.
///
/// Takes a prompt string and returns the model's completion.
/// This abstraction allows the analyzer to be tested with mock inference.
typedef InferenceCallback = Future<String> Function(String prompt);

/// Main grammar analysis pipeline.
///
/// Coordinates sentence splitting, prompt building, model inference,
/// correction parsing, and statistics computation.
///
/// Usage:
/// ```dart
/// final analyzer = GrammarAnalyzer(
///   onInfer: (prompt) => llamaSession.complete(prompt),
/// );
///
/// final result = await analyzer.analyze(
///   'He dont likes the cake.',
///   language: SupportedLanguage.english,
/// );
/// ```
class GrammarAnalyzer {
  /// Callback to run model inference.
  final InferenceCallback onInfer;

  /// Number of sentences to process per inference call.
  /// More sentences = fewer API calls but larger context.
  final int sentencesPerBatch;

  /// Minimum confidence threshold. Corrections below this are filtered out.
  final double confidenceThreshold;

  /// Prompt format used to serialize model instructions.
  final PromptFormat promptFormat;

  final LanguageDetector _languageDetector;
  final TextStatisticsCalculator _statisticsCalculator;
  static const _placeholderOriginalTexts = {
    'erroneous text span',
    'texto erróneo',
    'texte erroné',
    'fehlerhafter text',
    'texto com erro',
  };
  static const _placeholderCorrectedTexts = {
    'fixed text span',
    'texto corregido',
    'texte corrigé',
    'korrigierter text',
    'texto corrigido',
  };
  static const _placeholderExplanations = {
    'brief explanation of the error',
    'breve explicación del error',
    "brève explication de l'erreur",
    'kurze erklärung des fehlers',
    'breve explicação do erro',
  };

  GrammarAnalyzer({
    required this.onInfer,
    this.sentencesPerBatch = 3,
    this.confidenceThreshold = 0.5,
    this.promptFormat = PromptFormat.phi3Chat,
    LanguageDetector? languageDetector,
    TextStatisticsCalculator? statisticsCalculator,
  })  : _languageDetector = languageDetector ?? const LanguageDetector(),
        _statisticsCalculator =
            statisticsCalculator ?? const TextStatisticsCalculator();

  /// Analyze text for grammar, spelling, punctuation, and style issues.
  ///
  /// [text] - The text to analyze.
  /// [language] - The language to check in. If null, auto-detected.
  Future<AnalysisResult> analyze(
    String text, {
    SupportedLanguage? language,
  }) async {
    if (text.trim().isEmpty) {
      return AnalysisResult.empty(language ?? SupportedLanguage.english);
    }

    final stopwatch = Stopwatch()..start();

    // Step 1: Detect language (if not specified)
    final detectedLanguage = language ?? _languageDetector.detect(text);

    // Step 2: Split into sentences
    final sentences = SentenceSplitter.split(text);
    if (sentences.isEmpty) {
      return AnalysisResult.empty(detectedLanguage);
    }

    // Step 3: Process in batches
    final allCorrections = <Correction>[];
    final rawOutputs = <String>[];

    for (var i = 0; i < sentences.length; i += sentencesPerBatch) {
      final end = (i + sentencesPerBatch).clamp(0, sentences.length);
      final batch = sentences.sublist(i, end);

      // Build prompt for this batch
      final prompt = PromptBuilder.build(
        batch,
        detectedLanguage,
        format: promptFormat,
      );

      // Run inference
      final rawOutput = await onInfer(prompt);
      rawOutputs.add(rawOutput);

      // Parse corrections
      final corrections = CorrectionParser.parse(
        rawOutput,
        batch,
        baseOffset: batch.first.startOffset,
      );

      // Filter by confidence
      allCorrections.addAll(
        corrections.where(
          (c) =>
              c.confidence >= confidenceThreshold &&
              _isValidCorrection(c, batch),
        ),
      );
    }

    // Step 4: Compute statistics
    final statistics = _statisticsCalculator.calculate(text, detectedLanguage);

    stopwatch.stop();

    return AnalysisResult(
      corrections: allCorrections,
      language: detectedLanguage,
      statistics: statistics,
      analysisTimeMs: stopwatch.elapsedMilliseconds,
      rawModelOutput: rawOutputs.join('\n\n----- BATCH -----\n\n'),
    );
  }

  /// Analyze only a single sentence (for quick incremental checks).
  ///
  /// Used by the real-time debounce system when only the current
  /// sentence has changed.
  Future<List<Correction>> analyzeSentence(
    String sentence, {
    required SupportedLanguage language,
    int offsetInDocument = 0,
  }) async {
    final span = SentenceSpan(
      text: sentence,
      startOffset: offsetInDocument,
      endOffset: offsetInDocument + sentence.length,
    );

    final prompt = PromptBuilder.build(
      [span],
      language,
      format: promptFormat,
    );
    final rawOutput = await onInfer(prompt);

    return CorrectionParser.parse(
      rawOutput,
      [span],
      baseOffset: offsetInDocument,
    ).where((c) => _isValidCorrection(c, [span])).toList();
  }

  bool _isValidCorrection(
    Correction correction,
    List<SentenceSpan> sentences,
  ) {
    if (!correction.hasChange) {
      return false;
    }

    final original = correction.originalText.trim();
    final corrected = correction.correctedText.trim();
    final explanation = correction.explanation.trim();

    if (original.isEmpty || corrected.isEmpty) {
      return false;
    }

    final originalLower = original.toLowerCase();
    final correctedLower = corrected.toLowerCase();
    final explanationLower = explanation.toLowerCase();

    if (_placeholderOriginalTexts.contains(originalLower) ||
        _placeholderCorrectedTexts.contains(correctedLower) ||
        _placeholderExplanations.contains(explanationLower)) {
      return false;
    }

    final sourceText = sentences.map((s) => s.text).join('\n').toLowerCase();
    return sourceText.contains(originalLower);
  }
}
