import 'package:grammar_engine/grammar_engine.dart';

const _initialTextStats = TextStats(
  wordCount: 0,
  characterCount: 0,
  characterCountNoSpaces: 0,
  sentenceCount: 0,
  paragraphCount: 0,
  avgWordsPerSentence: 0,
  avgWordLength: 0,
  readingTimeMinutes: 0,
  speakingTimeMinutes: 0,
  vocabularyRichness: 0,
);

/// Status of the grammar analysis.
enum AnalysisStatus {
  /// No analysis running, no results.
  idle,

  /// Analysis is in progress.
  analyzing,

  /// Analysis completed successfully.
  complete,

  /// Analysis failed with an error.
  error,
}

/// State for the editor BLoC.
class EditorState {
  /// The current text in the editor.
  final String text;

  /// Current analysis status.
  final AnalysisStatus status;

  /// List of corrections from the last analysis.
  final List<Correction> corrections;

  /// Text statistics (word count, readability, etc.)
  final TextStats? statistics;

  /// User-selected language code (null = auto-detect).
  final String? selectedLanguage;

  /// Detected language code from the last analysis.
  final String? detectedLanguage;

  /// Error message if status is [AnalysisStatus.error].
  final String? errorMessage;

  /// Raw model output from the last analysis (debug view).
  final String? rawModelOutput;

  const EditorState({
    this.text = '',
    this.status = AnalysisStatus.idle,
    this.corrections = const [],
    this.statistics = _initialTextStats,
    this.selectedLanguage,
    this.detectedLanguage,
    this.errorMessage,
    this.rawModelOutput,
  });

  /// Number of active (not accepted, not dismissed) corrections.
  int get activeCorrectionsCount =>
      corrections.where((c) => !c.isAccepted && !c.isDismissed).length;

  /// The effective language (user-selected or auto-detected).
  String get effectiveLanguage => selectedLanguage ?? detectedLanguage ?? 'en';

  EditorState copyWith({
    String? text,
    AnalysisStatus? status,
    List<Correction>? corrections,
    TextStats? statistics,
    String? selectedLanguage,
    bool clearSelectedLanguage = false,
    String? detectedLanguage,
    String? errorMessage,
    String? rawModelOutput,
    bool clearRawModelOutput = false,
  }) {
    return EditorState(
      text: text ?? this.text,
      status: status ?? this.status,
      corrections: corrections ?? this.corrections,
      statistics: statistics ?? this.statistics,
      selectedLanguage: clearSelectedLanguage
          ? null
          : (selectedLanguage ?? this.selectedLanguage),
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      errorMessage: errorMessage ?? this.errorMessage,
      rawModelOutput:
          clearRawModelOutput ? null : (rawModelOutput ?? this.rawModelOutput),
    );
  }
}
