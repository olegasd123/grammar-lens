import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:model_repository/model_repository.dart';

class MockClient extends Mock implements http.Client {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  late MockClient mockClient;
  late ModelDownloader downloader;
  late Directory tempDir;

  const testModel = ModelInfo(
    id: 'test-model',
    displayName: 'Test Model',
    language: 'en',
    quantization: 'Q4_K_M',
    fileSizeBytes: 100,
    sha256: 'test-sha',
    downloadUrl: 'https://example.com/model.gguf',
    minAppVersion: '0.1.0',
    contextLength: 4096,
  );

  setUpAll(() {
    registerFallbackValue(FakeBaseRequest());
  });

  setUp(() {
    mockClient = MockClient();
    downloader = ModelDownloader(client: mockClient);
    tempDir = Directory.systemTemp.createTempSync('model_downloader_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ModelDownloader', () {
    test('downloads file successfully', () async {
      final destPath = '${tempDir.path}/model.gguf';
      final content = List.filled(100, 42);

      final streamedResponse = http.StreamedResponse(
        Stream.value(content),
        200,
        contentLength: 100,
      );

      when(() => mockClient.send(any())).thenAnswer(
        (_) async => streamedResponse,
      );

      final progressValues = <double>[];
      final file = await downloader.download(
        testModel,
        destPath,
        onProgress: progressValues.add,
      );

      expect(file.path, destPath);
      expect(progressValues, isNotEmpty);
      expect(progressValues.last, closeTo(1.0, 0.01));
    });

    test('reports progress during download', () async {
      final destPath = '${tempDir.path}/progress_model.gguf';

      // Stream data in two chunks.
      final controller = StreamController<List<int>>();
      final streamedResponse = http.StreamedResponse(
        controller.stream,
        200,
        contentLength: 100,
      );

      when(() => mockClient.send(any())).thenAnswer(
        (_) async => streamedResponse,
      );

      final progressValues = <double>[];
      final future = downloader.download(
        testModel,
        destPath,
        onProgress: progressValues.add,
      );

      controller.add(List.filled(50, 1));
      await Future<void>.delayed(Duration.zero);
      controller.add(List.filled(50, 2));
      await controller.close();

      await future;

      expect(progressValues.length, greaterThanOrEqualTo(2));
      expect(progressValues.first, closeTo(0.5, 0.01));
      expect(progressValues.last, closeTo(1.0, 0.01));
    });

    test('throws ModelDownloadException on HTTP error', () async {
      final destPath = '${tempDir.path}/fail.gguf';

      final streamedResponse = http.StreamedResponse(
        const Stream.empty(),
        500,
      );

      when(() => mockClient.send(any())).thenAnswer(
        (_) async => streamedResponse,
      );

      expect(
        () => downloader.download(testModel, destPath),
        throwsA(isA<ModelDownloadException>()),
      );
    });

    test('throws ModelDownloadException on network error', () async {
      final destPath = '${tempDir.path}/network_fail.gguf';

      when(() => mockClient.send(any())).thenThrow(
        const SocketException('Connection refused'),
      );

      expect(
        () => downloader.download(testModel, destPath),
        throwsA(isA<ModelDownloadException>()),
      );
    });

    test('cancelDownload cancels an in-progress download', () async {
      final destPath = '${tempDir.path}/cancel.gguf';

      // Use a slow stream that emits one chunk then waits.
      final controller = StreamController<List<int>>();
      final streamedResponse = http.StreamedResponse(
        controller.stream,
        200,
        contentLength: 100,
      );

      when(() => mockClient.send(any())).thenAnswer(
        (_) async => streamedResponse,
      );

      final future = downloader.download(testModel, destPath);

      controller.add(List.filled(50, 1));
      await Future<void>.delayed(Duration.zero);

      // Cancel after first chunk.
      downloader.cancelDownload();

      controller.add(List.filled(50, 2));
      await controller.close();

      expect(future, throwsA(isA<ModelDownloadCancelledException>()));
    });

    test('cleanupPartial removes .part files', () async {
      final destPath = '${tempDir.path}/cleanup.gguf';
      final partFile = File('$destPath.part')..writeAsBytesSync([1, 2, 3]);

      expect(partFile.existsSync(), isTrue);

      await downloader.cleanupPartial(destPath);

      expect(partFile.existsSync(), isFalse);
    });

    test('cleanupPartial does nothing if no .part file', () async {
      final destPath = '${tempDir.path}/no_partial.gguf';
      // Should not throw.
      await downloader.cleanupPartial(destPath);
    });
  });
}
