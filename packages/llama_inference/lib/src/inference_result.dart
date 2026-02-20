/// Result of a completed inference call.
class InferenceResult {
  /// The generated text.
  final String text;

  /// Number of prompt tokens evaluated.
  final int promptTokens;

  /// Number of tokens generated.
  final int completionTokens;

  /// Time spent evaluating the prompt (milliseconds).
  final double promptEvalTimeMs;

  /// Time spent generating tokens (milliseconds).
  final double completionTimeMs;

  /// Tokens per second during generation.
  double get tokensPerSecond {
    if (completionTimeMs <= 0) return 0;
    return (completionTokens / completionTimeMs) * 1000;
  }

  /// Total inference time in milliseconds.
  double get totalTimeMs => promptEvalTimeMs + completionTimeMs;

  const InferenceResult({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.promptEvalTimeMs,
    required this.completionTimeMs,
  });

  @override
  String toString() {
    return 'InferenceResult('
        'tokens: $completionTokens, '
        'speed: ${tokensPerSecond.toStringAsFixed(1)} t/s, '
        'total: ${totalTimeMs.toStringAsFixed(0)}ms)';
  }
}

/// A single streamed token during inference.
class StreamedToken {
  /// The token text.
  final String text;

  /// Whether this is the final token (generation complete).
  final bool isLast;

  /// Log probability of this token (if available).
  final double? logProb;

  const StreamedToken({
    required this.text,
    this.isLast = false,
    this.logProb,
  });
}
