import 'package:grammar_engine/grammar_engine.dart';

/// Status of the external check flow.
enum ExternalCheckStatus {
  /// Idle — no external check in progress.
  initial,

  /// Accessibility permission is missing.
  noPermission,

  /// Reading text from the focused app and running analysis.
  loading,

  /// Analysis complete — corrections are ready for review.
  ready,

  /// Writing corrected text back to the external app.
  writingBack,

  /// Write-back succeeded. The panel can be dismissed.
  complete,

  /// An error occurred during the flow.
  error,
}

/// State for the external check BLoC.
class ExternalCheckState {
  /// Current status of the external check flow.
  final ExternalCheckStatus status;

  /// Name of the app that was focused when the check was triggered.
  final String? sourceAppName;

  /// Original text read from the external app.
  final String? originalText;

  /// Text with all accepted corrections applied.
  final String? correctedText;

  /// Corrections found by the grammar analyzer.
  final List<Correction> corrections;

  /// Human-readable error message.
  final String? errorMessage;

  const ExternalCheckState({
    this.status = ExternalCheckStatus.initial,
    this.sourceAppName,
    this.originalText,
    this.correctedText,
    this.corrections = const [],
    this.errorMessage,
  });

  /// Number of active (not yet accepted/dismissed) corrections.
  int get activeCorrectionsCount =>
      corrections.where((c) => !c.isAccepted && !c.isDismissed).length;

  /// Whether there are any corrections to show.
  bool get hasCorrections => corrections.isNotEmpty;

  ExternalCheckState copyWith({
    ExternalCheckStatus? status,
    String? sourceAppName,
    String? originalText,
    String? correctedText,
    List<Correction>? corrections,
    String? errorMessage,
  }) {
    return ExternalCheckState(
      status: status ?? this.status,
      sourceAppName: sourceAppName ?? this.sourceAppName,
      originalText: originalText ?? this.originalText,
      correctedText: correctedText ?? this.correctedText,
      corrections: corrections ?? this.corrections,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
