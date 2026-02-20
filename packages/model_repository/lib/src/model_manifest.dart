import 'package:model_repository/src/model_info.dart';

/// Catalog of all available models for download.
class ModelManifest {
  /// All available models.
  final List<ModelInfo> models;

  /// Manifest version for update tracking.
  final int version;

  const ModelManifest({required this.models, this.version = 1});

  /// Get all models for a specific language.
  List<ModelInfo> getModelsForLanguage(String languageCode) {
    return models
        .where((m) => m.language == languageCode.toLowerCase())
        .toList();
  }

  /// Get a specific model by ID.
  ModelInfo? getModelById(String id) {
    try {
      return models.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  factory ModelManifest.fromJson(Map<String, dynamic> json) {
    final modelsJson = json['models'] as List<dynamic>;
    return ModelManifest(
      models: modelsJson
          .map((m) => ModelInfo.fromJson(m as Map<String, dynamic>))
          .toList(),
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'models': models.map((m) => m.toJson()).toList(),
      };

  /// Bundled manifest with placeholder entries.
  ///
  /// In production, download URLs and checksums will point to the CDN.
  static const bundledManifestJson = {
    'version': 1,
    'models': [
      {
        'id': 'phi3-mini-grammar-en-q4km',
        'displayName': 'English Grammar (Standard)',
        'language': 'en',
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 2300000000,
        'sha256': 'placeholder-sha256-en-q4km',
        'downloadUrl':
            'https://cdn.grammarlens.app/models/phi3-mini-grammar-en-q4km-v1.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'phi3-mini-grammar-en-q5km',
        'displayName': 'English Grammar (High Quality)',
        'language': 'en',
        'quantization': 'Q5_K_M',
        'fileSizeBytes': 2800000000,
        'sha256': 'placeholder-sha256-en-q5km',
        'downloadUrl':
            'https://cdn.grammarlens.app/models/phi3-mini-grammar-en-q5km-v1.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'phi3-mini-grammar-es-q4km',
        'displayName': 'Spanish Grammar (Standard)',
        'language': 'es',
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 2300000000,
        'sha256': 'placeholder-sha256-es-q4km',
        'downloadUrl':
            'https://cdn.grammarlens.app/models/phi3-mini-grammar-es-q4km-v1.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'phi3-mini-grammar-fr-q4km',
        'displayName': 'French Grammar (Standard)',
        'language': 'fr',
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 2300000000,
        'sha256': 'placeholder-sha256-fr-q4km',
        'downloadUrl':
            'https://cdn.grammarlens.app/models/phi3-mini-grammar-fr-q4km-v1.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'phi3-mini-grammar-de-q4km',
        'displayName': 'German Grammar (Standard)',
        'language': 'de',
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 2300000000,
        'sha256': 'placeholder-sha256-de-q4km',
        'downloadUrl':
            'https://cdn.grammarlens.app/models/phi3-mini-grammar-de-q4km-v1.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'phi3-mini-grammar-pt-q4km',
        'displayName': 'Portuguese Grammar (Standard)',
        'language': 'pt',
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 2300000000,
        'sha256': 'placeholder-sha256-pt-q4km',
        'downloadUrl':
            'https://cdn.grammarlens.app/models/phi3-mini-grammar-pt-q4km-v1.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
    ],
  };
}
