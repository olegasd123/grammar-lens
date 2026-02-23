import 'package:flutter_test/flutter_test.dart';
import 'package:model_repository/model_repository.dart';

void main() {
  const enModel1 = ModelInfo(
    id: 'en-q4km',
    displayName: 'English Standard',
    languages: ['en'],
    quantization: 'Q4_K_M',
    fileSizeBytes: 2300000000,
    sha256: 'sha-en-q4',
    downloadUrl: 'https://example.com/en-q4.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  const enModel2 = ModelInfo(
    id: 'en-q5km',
    displayName: 'English HQ',
    languages: ['en'],
    quantization: 'Q5_K_M',
    fileSizeBytes: 2800000000,
    sha256: 'sha-en-q5',
    downloadUrl: 'https://example.com/en-q5.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  const esModel = ModelInfo(
    id: 'es-q4km',
    displayName: 'Spanish Standard',
    languages: ['es'],
    quantization: 'Q4_K_M',
    fileSizeBytes: 2300000000,
    sha256: 'sha-es-q4',
    downloadUrl: 'https://example.com/es-q4.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  const manifest = ModelManifest(
    models: [enModel1, enModel2, esModel],
    version: 2,
  );

  group('ModelManifest', () {
    test('getModelsForLanguage filters correctly', () {
      final enModels = manifest.getModelsForLanguage('en');
      expect(enModels, hasLength(2));
      expect(enModels[0].id, 'en-q4km');
      expect(enModels[1].id, 'en-q5km');
    });

    test('getModelsForLanguage is case insensitive', () {
      final enModels = manifest.getModelsForLanguage('EN');
      // The method lowercases the input, so 'EN' should match 'en'
      expect(enModels, hasLength(2));
    });

    test('getModelsForLanguage returns empty for unknown language', () {
      final result = manifest.getModelsForLanguage('ja');
      expect(result, isEmpty);
    });

    test('getModelsForLanguage maps zh-Hant aliases to zh models', () {
      const zhModel = ModelInfo(
        id: 'zh-q4km',
        displayName: 'Chinese Standard',
        languages: ['zh'],
        quantization: 'Q4_K_M',
        fileSizeBytes: 2300000000,
        sha256: 'sha-zh-q4',
        downloadUrl: 'https://example.com/zh-q4.gguf',
        minAppVersion: '0.1.0',
        contextLength: 4096,
      );
      const zhManifest = ModelManifest(models: [zhModel]);

      final zhHantModels = zhManifest.getModelsForLanguage('zh-Hant');
      expect(zhHantModels, hasLength(1));
      expect(zhHantModels.first.id, 'zh-q4km');
    });

    test('getModelById finds existing model', () {
      final model = manifest.getModelById('es-q4km');
      expect(model, isNotNull);
      expect(model!.displayName, 'Spanish Standard');
    });

    test('getModelById returns null for missing model', () {
      final model = manifest.getModelById('nonexistent');
      expect(model, isNull);
    });

    group('JSON serialization', () {
      test('toJson produces valid structure', () {
        final json = manifest.toJson();
        expect(json['version'], 2);
        final models = json['models'] as List;
        expect(models, hasLength(3));
      });

      test('fromJson restores manifest correctly', () {
        final json = manifest.toJson();
        final restored = ModelManifest.fromJson(json);
        expect(restored.version, 2);
        expect(restored.models, hasLength(3));
        expect(restored.models[0].id, 'en-q4km');
      });

      test('fromJson defaults version to 1', () {
        final json = <String, dynamic>{
          'models': [enModel1.toJson()],
        };
        final restored = ModelManifest.fromJson(json);
        expect(restored.version, 1);
      });

      test('roundtrip preserves all data', () {
        final roundtripped = ModelManifest.fromJson(manifest.toJson());
        expect(roundtripped.version, manifest.version);
        expect(roundtripped.models.length, manifest.models.length);
        for (var i = 0; i < manifest.models.length; i++) {
          expect(roundtripped.models[i].id, manifest.models[i].id);
          expect(
            roundtripped.models[i].fileSizeBytes,
            manifest.models[i].fileSizeBytes,
          );
        }
      });
    });

    group('bundledManifestJson', () {
      test('is parseable', () {
        final bundled =
            ModelManifest.fromJson(ModelManifest.bundledManifestJson);
        expect(bundled.models, isNotEmpty);
        expect(bundled.version, 1);
      });

      test('contains expected bundled model IDs', () {
        final bundled =
            ModelManifest.fromJson(ModelManifest.bundledManifestJson);
        final ids = bundled.models.map((m) => m.id).toSet();
        expect(
          ids,
          containsAll([
            'phi-3-mini-4k-instruct-q5_k_m',
            'aya-23-8B.Q2_K',
            'aya-23-8B.Q4_K_M',
            'phi-3-mini-4k-grammar-correction.Q2_K',
            'phi-3-mini-4k-grammar-correction.Q4_K_M',
          ]),
        );
        expect(ids, hasLength(5));
      });

      test('covers all supported languages', () {
        final bundled =
            ModelManifest.fromJson(ModelManifest.bundledManifestJson);
        final languages = bundled.models.expand((m) => m.languages).toSet();
        expect(
          languages,
          containsAll([
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
          ]),
        );
      });

      test('English includes Q2_K, Q4_K_M, and Q5_K_M quantization levels', () {
        final bundled =
            ModelManifest.fromJson(ModelManifest.bundledManifestJson);
        final enModels = bundled.getModelsForLanguage('en');
        expect(
          enModels.map((m) => m.quantization).toSet(),
          containsAll(['Q2_K', 'Q4_K_M', 'Q5_K_M']),
        );
      });
    });
  });
}
