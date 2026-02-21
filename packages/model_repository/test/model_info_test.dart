import 'package:flutter_test/flutter_test.dart';
import 'package:model_repository/model_repository.dart';

void main() {
  const testModel = ModelInfo(
    id: 'test-model-en-q4km',
    displayName: 'Test English Model',
    language: 'en',
    quantization: 'Q4_K_M',
    fileSizeBytes: 2300000000,
    sha256: 'abc123def456',
    downloadUrl: 'https://example.com/model.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  group('ModelInfo', () {
    group('fileSizeFormatted', () {
      test('formats bytes in GB for >= 1 GB', () {
        expect(testModel.fileSizeFormatted, '2.1 GB');
      });

      test('formats bytes in MB for >= 1 MB and < 1 GB', () {
        const mbModel = ModelInfo(
          id: 'small',
          displayName: 'Small',
          language: 'en',
          quantization: 'Q4_K_M',
          fileSizeBytes: 500 * 1024 * 1024, // 500 MB
          sha256: 'x',
          downloadUrl: 'https://example.com/model.gguf',
          minAppVersion: '0.1.0',
          contextLength: 4096,
        );
        expect(mbModel.fileSizeFormatted, '500 MB');
      });

      test('formats bytes in KB for < 1 MB', () {
        const kbModel = ModelInfo(
          id: 'tiny',
          displayName: 'Tiny',
          language: 'en',
          quantization: 'Q4_K_M',
          fileSizeBytes: 512 * 1024, // 512 KB
          sha256: 'x',
          downloadUrl: 'https://example.com/model.gguf',
          minAppVersion: '0.1.0',
          contextLength: 4096,
        );
        expect(kbModel.fileSizeFormatted, '512 KB');
      });
    });

    group('JSON serialization', () {
      test('toJson produces valid map', () {
        final json = testModel.toJson();
        expect(json['id'], 'test-model-en-q4km');
        expect(json['displayName'], 'Test English Model');
        expect(json['language'], 'en');
        expect(json['quantization'], 'Q4_K_M');
        expect(json['fileSizeBytes'], 2300000000);
        expect(json['sha256'], 'abc123def456');
        expect(json['downloadUrl'], 'https://example.com/model.gguf');
        expect(json['minAppVersion'], '0.1.0');
        expect(json['contextLength'], 4096);
      });

      test('fromJson restores model correctly', () {
        final json = testModel.toJson();
        final restored = ModelInfo.fromJson(json);

        expect(restored.id, testModel.id);
        expect(restored.displayName, testModel.displayName);
        expect(restored.language, testModel.language);
        expect(restored.quantization, testModel.quantization);
        expect(restored.fileSizeBytes, testModel.fileSizeBytes);
        expect(restored.sha256, testModel.sha256);
        expect(restored.downloadUrl, testModel.downloadUrl);
        expect(restored.minAppVersion, testModel.minAppVersion);
        expect(restored.contextLength, testModel.contextLength);
      });

      test('fromJson applies defaults for optional fields', () {
        final json = <String, dynamic>{
          'id': 'test',
          'displayName': 'Test',
          'language': 'en',
          'quantization': 'Q4_K_M',
          'fileSizeBytes': 1000,
          'sha256': 'abc',
          'downloadUrl': 'https://example.com/model.gguf',
        };
        final model = ModelInfo.fromJson(json);
        expect(model.minAppVersion, '0.1.0');
        expect(model.contextLength, 4096);
      });

      test('roundtrip: toJson -> fromJson preserves all fields', () {
        final roundtripped = ModelInfo.fromJson(testModel.toJson());
        expect(roundtripped.id, testModel.id);
        expect(roundtripped.fileSizeBytes, testModel.fileSizeBytes);
        expect(roundtripped.contextLength, testModel.contextLength);
      });
    });

    test('toString includes key information', () {
      final str = testModel.toString();
      expect(str, contains('test-model-en-q4km'));
      expect(str, contains('en'));
      expect(str, contains('Q4_K_M'));
    });
  });
}
