import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_repository/model_repository.dart';

class MockModelStorage extends Mock implements ModelStorage {}

void main() {
  late MockModelStorage mockStorage;
  late ModelRegistry registry;
  late Directory tempDir;

  const testModel = ModelInfo(
    id: 'test-en-q4km',
    displayName: 'Test English',
    language: 'en',
    quantization: 'Q4_K_M',
    fileSizeBytes: 2300000000,
    sha256: 'abc123',
    downloadUrl: 'https://example.com/model.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  const testModel2 = ModelInfo(
    id: 'test-es-q4km',
    displayName: 'Test Spanish',
    language: 'es',
    quantization: 'Q4_K_M',
    fileSizeBytes: 2300000000,
    sha256: 'def456',
    downloadUrl: 'https://example.com/es-model.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  setUp(() {
    mockStorage = MockModelStorage();
    registry = ModelRegistry(storage: mockStorage);
    tempDir = Directory.systemTemp.createTempSync('model_registry_test_');

    when(() => mockStorage.getModelsDirectory())
        .thenAnswer((_) async => tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ModelRegistry', () {
    test('getInstalledModels returns empty list when no registry file', () async {
      final models = await registry.getInstalledModels();
      expect(models, isEmpty);
    });

    test('registerModel adds model and persists', () async {
      await registry.registerModel(testModel);

      final models = await registry.getInstalledModels();
      expect(models, hasLength(1));
      expect(models.first.id, 'test-en-q4km');
      expect(models.first.displayName, 'Test English');
    });

    test('registerModel replaces existing model with same ID', () async {
      await registry.registerModel(testModel);
      // Register again with updated display name.
      const updatedModel = ModelInfo(
        id: 'test-en-q4km',
        displayName: 'Updated English',
        language: 'en',
        quantization: 'Q4_K_M',
        fileSizeBytes: 2300000000,
        sha256: 'abc123',
        downloadUrl: 'https://example.com/model.gguf',
        minAppVersion: '0.1.0',
        contextLength: 4096,
      );
      await registry.registerModel(updatedModel);

      final models = await registry.getInstalledModels();
      expect(models, hasLength(1));
      expect(models.first.displayName, 'Updated English');
    });

    test('registerModel adds multiple different models', () async {
      await registry.registerModel(testModel);
      await registry.registerModel(testModel2);

      final models = await registry.getInstalledModels();
      expect(models, hasLength(2));
    });

    test('unregisterModel removes a model', () async {
      await registry.registerModel(testModel);
      await registry.registerModel(testModel2);

      await registry.unregisterModel('test-en-q4km');

      final models = await registry.getInstalledModels();
      expect(models, hasLength(1));
      expect(models.first.id, 'test-es-q4km');
    });

    test('unregisterModel also removes from active models', () async {
      await registry.registerModel(testModel);
      await registry.setActiveModel('en', 'test-en-q4km');

      // Verify it is active.
      var active = await registry.getActiveModel('en');
      expect(active, isNotNull);

      // Unregister should clear active.
      await registry.unregisterModel('test-en-q4km');
      active = await registry.getActiveModel('en');
      expect(active, isNull);
    });

    test('unregisterModel is no-op for unknown model ID', () async {
      await registry.registerModel(testModel);
      await registry.unregisterModel('nonexistent');

      final models = await registry.getInstalledModels();
      expect(models, hasLength(1));
    });

    group('active model', () {
      test('setActiveModel and getActiveModel roundtrip', () async {
        await registry.registerModel(testModel);
        await registry.setActiveModel('en', 'test-en-q4km');

        final active = await registry.getActiveModel('en');
        expect(active, isNotNull);
        expect(active!.id, 'test-en-q4km');
      });

      test('getActiveModel returns null when no active model set', () async {
        final active = await registry.getActiveModel('en');
        expect(active, isNull);
      });

      test('getActiveModel returns null when model not installed', () async {
        // Set active model but don't register it.
        await registry.setActiveModel('en', 'nonexistent');
        final active = await registry.getActiveModel('en');
        expect(active, isNull);
      });

      test('supports different active models per language', () async {
        await registry.registerModel(testModel);
        await registry.registerModel(testModel2);
        await registry.setActiveModel('en', 'test-en-q4km');
        await registry.setActiveModel('es', 'test-es-q4km');

        final enActive = await registry.getActiveModel('en');
        final esActive = await registry.getActiveModel('es');
        expect(enActive!.id, 'test-en-q4km');
        expect(esActive!.id, 'test-es-q4km');
      });
    });

    test('handles corrupted registry file gracefully', () async {
      // Write invalid JSON to registry.
      final registryFile = File('${tempDir.path}/registry.json');
      registryFile.writeAsStringSync('not valid json {{{{');

      final models = await registry.getInstalledModels();
      expect(models, isEmpty);
    });

    test('registry file is valid JSON after operations', () async {
      await registry.registerModel(testModel);

      final registryFile = File('${tempDir.path}/registry.json');
      expect(registryFile.existsSync(), isTrue);

      final content = registryFile.readAsStringSync();
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      expect(parsed.containsKey('installed'), isTrue);
    });
  });
}
