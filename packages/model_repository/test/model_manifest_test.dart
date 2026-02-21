import 'package:flutter_test/flutter_test.dart';
import 'package:model_repository/model_repository.dart';

void main() {
  const enModel1 = ModelInfo(
    id: 'en-q4km',
    displayName: 'English Standard',
    language: 'en',
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
    language: 'en',
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
    language: 'es',
    quantization: 'Q4_K_M',
    fileSizeBytes: 2300000000,
    sha256: 'sha-es-q4',
    downloadUrl: 'https://example.com/es-q4.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  final manifest = ModelManifest(
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

      test('contains all 6 expected models', () {
        final bundled =
            ModelManifest.fromJson(ModelManifest.bundledManifestJson);
        expect(bundled.models, hasLength(6));
      });

      test('covers all supported languages', () {
        final bundled =
            ModelManifest.fromJson(ModelManifest.bundledManifestJson);
        final languages = bundled.models.map((m) => m.language).toSet();
        expect(languages, containsAll(['en', 'es', 'fr', 'de', 'pt']));
      });

      test('English has two quantization levels', () {
        final bundled =
            ModelManifest.fromJson(ModelManifest.bundledManifestJson);
        final enModels = bundled.getModelsForLanguage('en');
        expect(enModels, hasLength(2));
        expect(enModels.map((m) => m.quantization).toSet(),
            containsAll(['Q4_K_M', 'Q5_K_M']));
      });
    });
  });
}
