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
    final codes = _matchingLanguageCodes(languageCode);
    return models
        .where(
          (m) => m.languages.any(
            (lang) => codes.contains(lang.trim().toLowerCase()),
          ),
        )
        .toList();
  }

  Set<String> _matchingLanguageCodes(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    return switch (normalized) {
      'zh' || 'zh-cn' || 'zh-sg' || 'zh-hans' => {'zh'},
      // Allow Traditional Chinese to match either explicit or generic Chinese
      // model labels for backwards compatibility with older manifests.
      'zh-hant' || 'zh-tw' || 'zh-hk' || 'zh-mo' => {'zh-hant', 'zh'},
      _ => {normalized},
    };
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
  /// In production, the publish_models.sh script replaces placeholder hashes
  /// and URLs with real values from GitHub Releases.
  static const bundledManifestJson = {
    'version': 1,
    'models': [
      {
        'id': 'phi-3-mini-4k-instruct-q5_k_m',
        'displayName': 'Grammar phi-3-mini',
        'languages': ['en'],
        'quantization': 'Q5_K_M',
        'fileSizeBytes': 2815274944,
        'sha256':
            '589fe69682475914b9d61beaa37876a49ac9f28f552363d28ab44dab67f7315b',
        'downloadUrl':
            'https://huggingface.co/Marlon81/Phi-3-mini-4k-instruct-Q5_K_M-GGUF/resolve/main/phi-3-mini-4k-instruct-q5_k_m.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'aya-23-8B.Q2_K',
        'displayName': 'Multi-language Grammar (Lower Quality)',
        'languages': [
          'ar',
          'zh',
          'zh-hant',
          'cs',
          'nl',
          'en',
          'fr',
          'de',
          'el',
          'he',
          'hi',
          'id',
          'it',
          'ja',
          'ko',
          'fa',
          'pl',
          'pt',
          'ro',
          'ru',
          'es',
          'tr',
          'uk',
          'vi',
        ],
        'quantization': 'Q2_K',
        'fileSizeBytes': 3438504832,
        'sha256':
            'a36462c4c01335288758c91fb5d9530c91a767240f8784094df4920a263fbfc6',
        'downloadUrl':
            'https://huggingface.co/QuantFactory/aya-23-8B-GGUF/resolve/main/aya-23-8B.Q2_K.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'aya-23-8B.Q4_K_M',
        'displayName': 'Multi-language Grammar (Standard Quality)',
        'languages': [
          'ar',
          'zh',
          'zh-hant',
          'cs',
          'nl',
          'en',
          'fr',
          'de',
          'el',
          'he',
          'hi',
          'id',
          'it',
          'ja',
          'ko',
          'fa',
          'pl',
          'pt',
          'ro',
          'ru',
          'es',
          'tr',
          'uk',
          'vi',
        ],
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 5056981888,
        'sha256':
            'e3bdf877d47c45a675e6e689226f376a78d5d055b12c394ce0858a2ebca3c1e0',
        'downloadUrl':
            'https://huggingface.co/QuantFactory/aya-23-8B-GGUF/resolve/main/aya-23-8B.Q4_K_M.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'phi-3-mini-4k-grammar-correction.Q2_K',
        'displayName': 'English Grammar (Lower Quality)',
        'languages': ['en'],
        'quantization': 'Q2_K',
        'fileSizeBytes': 1416202976,
        'sha256':
            '2ee82a1ad7f53ae8583aa465b63e4aa245572843ad195e63c037a03832dda5c4',
        'downloadUrl':
            'https://huggingface.co/afrideva/Phi-3-mini-4k-grammar-correction-GGUF/resolve/main/phi-3-mini-4k-grammar-correction.Q2_K.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
      {
        'id': 'phi-3-mini-4k-grammar-correction.Q4_K_M',
        'displayName': 'English Grammar (Standard Quality)',
        'languages': ['en'],
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 2393231072,
        'sha256':
            'da14a00718821f0510cb63c3c184dde97f05d4063abce0ad9e2c86bdfae93bf3',
        'downloadUrl':
            'https://huggingface.co/afrideva/Phi-3-mini-4k-grammar-correction-GGUF/resolve/main/phi-3-mini-4k-grammar-correction.Q4_K_M.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 4096,
      },
    ],
  };
}
