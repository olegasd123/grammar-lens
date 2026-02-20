/// Configuration for a single inference (completion) call.
class InferenceConfig {
  /// Maximum number of tokens to generate.
  final int maxTokens;

  /// Sampling temperature. Lower = more deterministic.
  /// For grammar correction, use 0.1-0.3.
  final double temperature;

  /// Nucleus sampling threshold.
  final double topP;

  /// Top-K sampling. 0 = disabled.
  final int topK;

  /// Repetition penalty. 1.0 = no penalty.
  final double repeatPenalty;

  /// Stop sequences. Generation stops when any of these are produced.
  final List<String> stopTokens;

  /// GBNF grammar string for constrained generation.
  /// If non-null, output is forced to match this grammar.
  final String? grammarGbnf;

  /// Random seed. -1 = random.
  final int seed;

  /// Number of threads for CPU inference.
  /// 0 = auto-detect based on CPU cores.
  final int threads;

  /// Number of tokens to evaluate in parallel (batch size).
  final int batchSize;

  const InferenceConfig({
    this.maxTokens = 512,
    this.temperature = 0.1,
    this.topP = 0.9,
    this.topK = 40,
    this.repeatPenalty = 1.1,
    this.stopTokens = const ['</corrections>'],
    this.grammarGbnf,
    this.seed = -1,
    this.threads = 0,
    this.batchSize = 512,
  });

  /// Default config optimized for grammar correction tasks.
  const InferenceConfig.grammar()
      : maxTokens = 512,
        temperature = 0.1,
        topP = 0.9,
        topK = 40,
        repeatPenalty = 1.1,
        stopTokens = const ['</corrections>'],
        grammarGbnf = null,
        seed = -1,
        threads = 0,
        batchSize = 512;

  InferenceConfig copyWith({
    int? maxTokens,
    double? temperature,
    double? topP,
    int? topK,
    double? repeatPenalty,
    List<String>? stopTokens,
    String? grammarGbnf,
    int? seed,
    int? threads,
    int? batchSize,
  }) {
    return InferenceConfig(
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      stopTokens: stopTokens ?? this.stopTokens,
      grammarGbnf: grammarGbnf ?? this.grammarGbnf,
      seed: seed ?? this.seed,
      threads: threads ?? this.threads,
      batchSize: batchSize ?? this.batchSize,
    );
  }
}
