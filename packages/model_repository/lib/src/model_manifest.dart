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
      {
        'id': 'Mistral-7B-UA-Grammar-GRPO.Q2_K',
        'displayName': 'Ukrainian Grammar (Lower Quality)',
        'languages': ['uk'],
        'quantization': 'Q2_K',
        'fileSizeBytes': 2720000000,
        'sha256':
            '06ee25c8e4dcb5387abcf2d2f032aa8a0ee04f6462a14eaa7959e36650843b6f',
        'downloadUrl':
            'https://huggingface.co/mradermacher/Mistral-7B-UA-Grammar-GRPO-GGUF/resolve/main/Mistral-7B-UA-Grammar-GRPO.Q2_K.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 32768,
      },
      {
        'id': 'Mistral-7B-UA-Grammar-GRPO.Q4_K_M',
        'displayName': 'Ukrainian Grammar (Standard Quality)',
        'languages': ['uk'],
        'quantization': 'Q4_K_M',
        'fileSizeBytes': 4370000000,
        'sha256':
            '23e86b08d3ae26e6aa270891bb1ba4000c98320cac4c8cc0a6ad47959a4d59bf',
        'downloadUrl':
            'https://huggingface.co/mradermacher/Mistral-7B-UA-Grammar-GRPO-GGUF/resolve/main/Mistral-7B-UA-Grammar-GRPO.Q4_K_M.gguf',
        'minAppVersion': '0.1.0',
        'contextLength': 32768,
      },
    ],
  };
}
