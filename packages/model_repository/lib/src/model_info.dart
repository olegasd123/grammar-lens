/// Metadata describing a single downloadable GGUF model.
class ModelInfo {
  /// Unique identifier (e.g., "phi3-mini-grammar-en-q4km").
  final String id;

  /// Human-readable name (e.g., "English Grammar (Standard)").
  final String displayName;

  /// ISO 639-1 language code (e.g., "en").
  final String language;

  /// Quantization level (e.g., "Q4_K_M", "Q5_K_M", "Q8_0").
  final String quantization;

  /// File size in bytes.
  final int fileSizeBytes;

  /// Expected SHA-256 checksum of the file.
  final String sha256;

  /// Download URL for the GGUF file.
  final String downloadUrl;

  /// Minimum app version required to use this model.
  final String minAppVersion;

  /// Maximum context length supported.
  final int contextLength;

  const ModelInfo({
    required this.id,
    required this.displayName,
    required this.language,
    required this.quantization,
    required this.fileSizeBytes,
    required this.sha256,
    required this.downloadUrl,
    required this.minAppVersion,
    required this.contextLength,
  });

  /// Human-readable file size (e.g., "2.2 GB").
  String get fileSizeFormatted {
    if (fileSizeBytes >= 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (fileSizeBytes >= 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
  }

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      language: json['language'] as String,
      quantization: json['quantization'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int,
      sha256: json['sha256'] as String,
      downloadUrl: json['downloadUrl'] as String,
      minAppVersion: json['minAppVersion'] as String? ?? '0.1.0',
      contextLength: json['contextLength'] as int? ?? 4096,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'language': language,
        'quantization': quantization,
        'fileSizeBytes': fileSizeBytes,
        'sha256': sha256,
        'downloadUrl': downloadUrl,
        'minAppVersion': minAppVersion,
        'contextLength': contextLength,
      };

  @override
  String toString() =>
      'ModelInfo($id, $language, $quantization, $fileSizeFormatted)';
}
