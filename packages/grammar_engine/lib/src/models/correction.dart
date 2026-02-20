import 'package:grammar_engine/src/models/correction_type.dart';

/// A single grammar/spelling/style correction.
class Correction {
  /// Character offset in the original text where the error starts.
  final int startOffset;

  /// Character offset in the original text where the error ends.
  final int endOffset;

  /// The original erroneous text span.
  final String originalText;

  /// The suggested corrected text.
  final String correctedText;

  /// Category of the correction.
  final CorrectionType type;

  /// Human-readable explanation of the error and correction.
  final String explanation;

  /// Confidence score (0.0 to 1.0), derived from model logprobs.
  /// Higher values indicate more certain corrections.
  final double confidence;

  /// Whether this correction has been accepted by the user.
  bool isAccepted;

  /// Whether this correction has been dismissed by the user.
  bool isDismissed;

  Correction({
    required this.startOffset,
    required this.endOffset,
    required this.originalText,
    required this.correctedText,
    required this.type,
    required this.explanation,
    this.confidence = 1.0,
    this.isAccepted = false,
    this.isDismissed = false,
  });

  /// The length of the original erroneous span.
  int get length => endOffset - startOffset;

  /// Whether this correction changes the text (not a no-op).
  bool get hasChange => originalText != correctedText;

  /// Create a copy with updated fields.
  Correction copyWith({
    int? startOffset,
    int? endOffset,
    String? originalText,
    String? correctedText,
    CorrectionType? type,
    String? explanation,
    double? confidence,
    bool? isAccepted,
    bool? isDismissed,
  }) {
    return Correction(
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      originalText: originalText ?? this.originalText,
      correctedText: correctedText ?? this.correctedText,
      type: type ?? this.type,
      explanation: explanation ?? this.explanation,
      confidence: confidence ?? this.confidence,
      isAccepted: isAccepted ?? this.isAccepted,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  @override
  String toString() {
    return 'Correction('
        '"$originalText" → "$correctedText" '
        '[$type] at $startOffset-$endOffset)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Correction &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset &&
          originalText == other.originalText &&
          correctedText == other.correctedText;

  @override
  int get hashCode => Object.hash(
        startOffset,
        endOffset,
        originalText,
        correctedText,
      );
}
