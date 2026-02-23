import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_repository/model_repository.dart';

import 'package:grammarlens/features/model_manager/presentation/bloc/model_bloc.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_event.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_state.dart';

class MockModelRegistry extends Mock implements ModelRegistry {}

class MockModelStorage extends Mock implements ModelStorage {}

class MockModelDownloader extends Mock implements ModelDownloader {}

class MockModelManifestFetcher extends Mock implements ModelManifestFetcher {}

void main() {
  late MockModelRegistry mockRegistry;
  late MockModelStorage mockStorage;
  late MockModelDownloader mockDownloader;
  late MockModelManifestFetcher mockManifestFetcher;
  late Directory tempDir;

  const testModel = ModelInfo(
    id: 'test-en-q4km',
    displayName: 'Test English',
    languages: ['en'],
    quantization: 'Q4_K_M',
    fileSizeBytes: 2300000000,
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    downloadUrl: 'https://example.com/model.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  setUp(() {
    mockRegistry = MockModelRegistry();
    mockStorage = MockModelStorage();
    mockDownloader = MockModelDownloader();
    mockManifestFetcher = MockModelManifestFetcher();
    tempDir = Directory.systemTemp.createTempSync('model_bloc_test_');
    when(() => mockManifestFetcher.fetchManifest()).thenAnswer(
      (_) async => ModelManifest.fromJson(ModelManifest.bundledManifestJson),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ModelBloc buildBloc() => ModelBloc(
        registry: mockRegistry,
        storage: mockStorage,
        downloader: mockDownloader,
        manifestFetcher: mockManifestFetcher,
      );

  group('ModelBloc', () {
    group('initial state', () {
      test('has initial status with no models', () {
        final bloc = buildBloc();
        expect(bloc.state.status, ModelStatus.initial);
        expect(bloc.state.availableModels, isEmpty);
        expect(bloc.state.installedModelIds, isEmpty);
        expect(bloc.state.activeModel, isNull);
        expect(bloc.engine, isNull);
        bloc.close();
      });
    });

    group('ModelStatusChecked', () {
      blocTest<ModelBloc, ModelState>(
        'loads manifest and checks installed models',
        setUp: () {
          // No models installed
          when(() => mockStorage.isModelDownloaded(any()))
              .thenAnswer((_) async => false);
          when(() => mockRegistry.getActiveModel(any()))
              .thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ModelStatusChecked()),
        expect: () => [
          isA<ModelState>()
              .having((s) => s.status, 'status', ModelStatus.noModel)
              .having(
                (s) => s.availableModels,
                'availableModels',
                isNotEmpty,
              )
              .having(
                (s) => s.installedModelIds,
                'installedModelIds',
                isEmpty,
              ),
        ],
      );

      blocTest<ModelBloc, ModelState>(
        'detects installed models',
        setUp: () {
          when(() => mockStorage.isModelDownloaded('phi3-mini-grammar-en-q4km'))
              .thenAnswer((_) async => true);
          when(() => mockStorage.isModelDownloaded(any()))
              .thenAnswer((_) async => false);
          // Override specific model
          when(() => mockStorage.isModelDownloaded('phi3-mini-grammar-en-q4km'))
              .thenAnswer((_) async => true);
          when(() => mockRegistry.getActiveModel(any()))
              .thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ModelStatusChecked()),
        expect: () => [
          isA<ModelState>().having(
            (s) => s.status,
            'status',
            ModelStatus.noModel,
          ),
        ],
        verify: (bloc) {
          expect(
            bloc.state.installedModelIds,
            contains('phi3-mini-grammar-en-q4km'),
          );
        },
      );
    });

    group('ModelUnloadRequested', () {
      blocTest<ModelBloc, ModelState>(
        'transitions to noModel and clears active model',
        build: buildBloc,
        seed: () => const ModelState(
          status: ModelStatus.ready,
          activeModel: testModel,
        ),
        act: (bloc) => bloc.add(const ModelUnloadRequested()),
        expect: () => [
          isA<ModelState>()
              .having((s) => s.status, 'status', ModelStatus.noModel)
              .having((s) => s.activeModel, 'activeModel', isNull),
        ],
      );
    });

    group('ModelDownloadProgressUpdated', () {
      blocTest<ModelBloc, ModelState>(
        'updates download progress',
        build: buildBloc,
        seed: () => const ModelState(
          status: ModelStatus.downloading,
          downloadProgress: 0,
          downloadingModelId: 'test-en-q4km',
        ),
        act: (bloc) => bloc.add(const ModelDownloadProgressUpdated(
          modelId: 'test-en-q4km',
          progress: 0.42,
        )),
        expect: () => [
          isA<ModelState>().having(
            (s) => s.downloadProgress,
            'downloadProgress',
            closeTo(0.42, 0.001),
          ),
        ],
      );
    });

    group('ModelDownloadCancelled', () {
      blocTest<ModelBloc, ModelState>(
        'calls downloader cancel when a download is active',
        build: buildBloc,
        seed: () => const ModelState(
          status: ModelStatus.downloading,
          downloadingModelId: 'test-en-q4km',
          downloadProgress: 0.3,
        ),
        act: (bloc) => bloc.add(const ModelDownloadCancelled()),
        verify: (_) {
          verify(() => mockDownloader.cancelDownload()).called(1);
        },
      );
    });

    group('ModelDeleteRequested', () {
      blocTest<ModelBloc, ModelState>(
        'removes model from installed set',
        setUp: () {
          when(() => mockStorage.deleteModel(testModel.id))
              .thenAnswer((_) async {});
          when(() => mockRegistry.unregisterModel(testModel.id))
              .thenAnswer((_) async {});
        },
        build: buildBloc,
        seed: () => ModelState(
          status: ModelStatus.noModel,
          installedModelIds: {testModel.id, 'other-model'},
        ),
        act: (bloc) => bloc.add(const ModelDeleteRequested(model: testModel)),
        verify: (bloc) {
          expect(
            bloc.state.installedModelIds,
            isNot(contains(testModel.id)),
          );
          expect(
            bloc.state.installedModelIds,
            contains('other-model'),
          );
          verify(() => mockStorage.deleteModel(testModel.id)).called(1);
          verify(() => mockRegistry.unregisterModel(testModel.id)).called(1);
        },
      );

      blocTest<ModelBloc, ModelState>(
        'transitions to noModel when deleting the active model',
        setUp: () {
          when(() => mockStorage.deleteModel(testModel.id))
              .thenAnswer((_) async {});
          when(() => mockRegistry.unregisterModel(testModel.id))
              .thenAnswer((_) async {});
        },
        build: buildBloc,
        seed: () => ModelState(
          status: ModelStatus.ready,
          activeModel: testModel,
          installedModelIds: {testModel.id},
        ),
        act: (bloc) => bloc.add(const ModelDeleteRequested(model: testModel)),
        expect: () => [
          isA<ModelState>()
              .having((s) => s.status, 'status', ModelStatus.noModel)
              .having((s) => s.activeModel, 'activeModel', isNull)
              .having(
                (s) => s.installedModelIds,
                'installedModelIds',
                isEmpty,
              ),
        ],
      );
    });

    group('ModelDownloadRequested', () {
      blocTest<ModelBloc, ModelState>(
        'emits downloading status on start',
        setUp: () {
          var getModelPathCalls = 0;
          when(() => mockStorage.getModelPath(testModel.id))
              .thenAnswer((_) async {
            getModelPathCalls += 1;
            if (getModelPathCalls == 1) {
              return '${tempDir.path}/model.gguf';
            }
            throw StateError('Model load is not part of this test');
          });
          when(() => mockDownloader.download(
                testModel,
                any(),
                onProgress: any(named: 'onProgress'),
              )).thenAnswer((_) async {
            final file = File('${tempDir.path}/model.gguf');
            await file.writeAsBytes(const []);
            return file;
          });
          when(() => mockRegistry.registerModel(testModel))
              .thenAnswer((_) async {});
          for (final lang in testModel.languages) {
            when(
              () => mockRegistry.setActiveModel(lang, testModel.id),
            ).thenAnswer((_) async {});
          }
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ModelDownloadRequested(model: testModel)),
        wait: const Duration(milliseconds: 50),
        verify: (bloc) {
          verify(() => mockDownloader.download(
                testModel,
                any(),
                onProgress: any(named: 'onProgress'),
              )).called(1);
          verify(() => mockRegistry.registerModel(testModel)).called(1);
        },
      );

      blocTest<ModelBloc, ModelState>(
        'emits error when download fails',
        setUp: () {
          when(() => mockStorage.getModelPath(testModel.id))
              .thenAnswer((_) async => '${tempDir.path}/model.gguf');
          when(() => mockDownloader.download(
                testModel,
                any(),
                onProgress: any(named: 'onProgress'),
              )).thenThrow(
            const ModelDownloadException('Network error'),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ModelDownloadRequested(model: testModel)),
        expect: () => [
          // downloading
          isA<ModelState>().having(
            (s) => s.status,
            'status',
            ModelStatus.downloading,
          ),
          // error
          isA<ModelState>()
              .having((s) => s.status, 'status', ModelStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('ModelState', () {
      test('isReady is true when status is ready and model is set', () {
        const state = ModelState(
          status: ModelStatus.ready,
          activeModel: testModel,
        );
        expect(state.isReady, isTrue);
      });

      test('isReady is false when status is not ready', () {
        const state = ModelState(
          status: ModelStatus.loading,
          activeModel: testModel,
        );
        expect(state.isReady, isFalse);
      });

      test('isReady is false when no active model', () {
        const state = ModelState(status: ModelStatus.ready);
        expect(state.isReady, isFalse);
      });

      test('copyWith clearActiveModel sets activeModel to null', () {
        const state = ModelState(activeModel: testModel);
        final updated = state.copyWith(clearActiveModel: true);
        expect(updated.activeModel, isNull);
      });

      test('copyWith preserves activeModel when clearActiveModel is false', () {
        const state = ModelState(activeModel: testModel);
        final updated = state.copyWith(status: ModelStatus.loading);
        expect(updated.activeModel, testModel);
      });
    });
  });
}
